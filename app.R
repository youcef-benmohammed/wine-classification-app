# Wine Cultivar Prediction – Shiny app
# The model is trained offline by train_model.R; the app only loads it.
library(shiny)
library(bslib)
library(plotly)
library(DT)
library(randomForest)

source("R/wine.R")

model <- readRDS("model/wine_model.rds")
metrics <- readRDS("model/metrics.rds")
ranges <- metrics$ranges

CLASS_COLORS <- c(Barolo = "#7B1E3A", Grignolino = "#D98C5F", Barbera = "#3E5C76")

feature_input <- function(f) {
  r <- ranges[ranges$feature == f, ]
  step <- signif((r$max - r$min) / 100, 1)
  numericInput(f, r$label, value = signif(r$median, 4), min = r$min, max = r$max, step = step)
}

ui <- page_navbar(
  title = "Wine Cultivar Prediction",
  bg = "#7B1E3A",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#7B1E3A", success = "#3E5C76") |>
    bs_add_rules(".navbar .nav-link.active { color: #fff !important; font-weight: 600;
                   border-bottom: 2px solid #fff; }"),

  nav_panel(
    "Single wine",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        helpText("Values default to the dataset medians; limits are the range observed in the 178 wines."),
        lapply(names(FEATURES), feature_input),
        actionButton("predict_one", "Predict", class = "btn-primary"),
        actionButton("reset", "Reset to medians", class = "btn-outline-primary")
      ),
      card(
        card_header("Prediction"),
        uiOutput("single_status"),
        tableOutput("single_table"),
        plotlyOutput("single_plot", height = "260px")
      )
    )
  ),

  nav_panel(
    "Batch (CSV)",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        fileInput("upload", "Upload a CSV file", accept = c(".csv", "text/csv")),
        helpText("Same columns as data/test_data.csv. An optional 'cultivar' column with the true class is used to compute accuracy."),
        downloadButton("download_example", "Example file (held-out wines)", class = "btn-outline-primary"),
        hr(),
        downloadButton("download_pred", "Download predictions", class = "btn-primary")
      ),
      uiOutput("batch_status"),
      layout_columns(
        col_widths = c(5, 7),
        card(card_header("Predicted cultivars"), plotlyOutput("batch_plot", height = "300px")),
        card(card_header("Accuracy (if true labels are provided)"), uiOutput("batch_accuracy"),
             tableOutput("batch_confusion"))
      ),
      card(card_header("Predictions"), DTOutput("batch_table"))
    )
  ),

  nav_panel(
    "Model",
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box("Held-out accuracy", sprintf("%.1f %%", 100 * metrics$test_accuracy),
                p(sprintf("%d wines never seen in training", metrics$n_test))),
      value_box("Out-of-bag error", sprintf("%.1f %%", 100 * metrics$oob_error),
                p(sprintf("%d training wines", metrics$n_train))),
      value_box("Random forest", sprintf("%d trees", metrics$ntree),
                p(sprintf("mtry = %d of %d variables", metrics$mtry, length(FEATURES))))
    ),
    layout_columns(
      col_widths = c(5, 7),
      card(card_header("Confusion matrix (held-out set)"), tableOutput("confusion")),
      card(card_header("Variable importance (mean decrease in accuracy)"), plotlyOutput("importance", height = "380px"))
    ),
    card(
      card_header("Data and method"),
      markdown(paste0(
        "**Data:** UCI Wine dataset – chemical analysis of 178 wines from three cultivars grown in the same region of Italy ",
        "(Forina et al., PARVUS; [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/109/wine)).\n\n",
        "**Method:** stratified split, 70 % training / 30 % held-out test (seed 42). Random forest (`randomForest`, ",
        metrics$ntree, " trees, default mtry = √p) trained once by `train_model.R`; the app only loads the saved model, ",
        "so predictions are reproducible.\n\n",
        "**Caveat:** with 178 samples and well-separated classes this is a teaching dataset; ",
        "inputs far outside the observed range are extrapolations."))
    )
  ),
  nav_spacer(),
  nav_item(tags$a("Code", href = "https://github.com/youcef-benmohammed/wine-classification-app", target = "_blank"))
)

server <- function(input, output, session) {
  # ---- single wine --------------------------------------------------------
  observeEvent(input$reset, {
    for (f in names(FEATURES)) {
      updateNumericInput(session, f, value = signif(ranges$median[ranges$feature == f], 4))
    }
  })

  single <- eventReactive(input$predict_one, {
    values <- lapply(names(FEATURES), function(f) input[[f]])
    names(values) <- names(FEATURES)
    df <- as.data.frame(values)
    check <- validate_upload(df, ranges)
    if (!check$ok) return(list(error = "Please fill in every field with a number."))
    list(pred = predict_wines(model, df), warnings = check$warnings)
  })

  output$single_status <- renderUI({
    s <- single()
    if (!is.null(s$error)) return(div(class = "alert alert-danger", s$error))
    tagList(
      h4(sprintf("Predicted cultivar: %s (%.0f %% of trees)", s$pred$Prediction,
                 100 * s$pred$Confidence)),
      if (length(s$warnings)) div(class = "alert alert-warning", s$warnings)
    )
  })

  output$single_table <- renderTable({
    s <- single()
    req(is.null(s$error))
    s$pred[, CULTIVARS]
  }, digits = 3)

  output$single_plot <- renderPlotly({
    s <- single()
    req(is.null(s$error))
    p <- unlist(s$pred[1, CULTIVARS])
    plot_ly(x = factor(names(p), levels = CULTIVARS), y = p, type = "bar",
            marker = list(color = CLASS_COLORS[names(p)])) |>
      layout(yaxis = list(title = "Probability", range = c(0, 1)), xaxis = list(title = ""))
  })

  # ---- batch ----------------------------------------------------------------
  batch <- reactive({
    req(input$upload)
    df <- tryCatch(utils::read.csv(input$upload$datapath),
                   error = function(e) NULL)
    if (is.null(df)) return(list(ok = FALSE, message = "Could not read the file as CSV."))
    check <- validate_upload(df, ranges)
    if (!check$ok) return(check)
    pred <- predict_wines(model, check$data)
    check$result <- cbind(check$data, pred)
    check
  })

  output$batch_status <- renderUI({
    if (is.null(input$upload)) {
      return(div(class = "alert alert-info", "Upload a CSV file, or download the example file to try the app."))
    }
    b <- batch()
    if (!b$ok) return(div(class = "alert alert-danger", style = "white-space: pre-line;", b$message))
    tagList(div(class = "alert alert-success", b$message),
            if (length(b$warnings)) div(class = "alert alert-warning", b$warnings))
  })

  output$batch_table <- renderDT({
    b <- batch()
    req(b$ok)
    datatable(b$result, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE) |>
      formatRound(c(CULTIVARS, "Confidence"), 3)
  })

  output$batch_plot <- renderPlotly({
    b <- batch()
    req(b$ok)
    counts <- table(factor(b$result$Prediction, levels = CULTIVARS))
    plot_ly(x = factor(names(counts), levels = CULTIVARS), y = as.integer(counts), type = "bar",
            marker = list(color = CLASS_COLORS[names(counts)])) |>
      layout(yaxis = list(title = "Number of wines"), xaxis = list(title = ""))
  })

  output$batch_accuracy <- renderUI({
    b <- batch()
    req(b$ok)
    if (!"cultivar" %in% names(b$data) || all(is.na(b$data$cultivar))) {
      return(p("No 'cultivar' column in the file: accuracy cannot be computed."))
    }
    known <- !is.na(b$data$cultivar)
    acc <- mean(b$result$Prediction[known] == b$data$cultivar[known])
    h4(sprintf("Accuracy: %.1f %% (%d labelled wines)", 100 * acc, sum(known)))
  })

  output$batch_confusion <- renderTable({
    b <- batch()
    req(b$ok, "cultivar" %in% names(b$data))
    known <- !is.na(b$data$cultivar)
    req(any(known))
    as.data.frame.matrix(table(Observed = b$data$cultivar[known],
                               Predicted = b$result$Prediction[known]))
  }, rownames = TRUE)

  output$download_pred <- downloadHandler(
    filename = function() paste0("wine_predictions_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
    content = function(file) {
      b <- batch()
      validate(need(b$ok, "No valid predictions to download."))
      utils::write.csv(b$result, file, row.names = FALSE)
    }
  )

  output$download_example <- downloadHandler(
    filename = function() "test_data.csv",
    content = function(file) file.copy("data/test_data.csv", file)
  )

  # ---- model ----------------------------------------------------------------
  output$confusion <- renderTable(as.data.frame.matrix(metrics$test_confusion), rownames = TRUE)

  output$importance <- renderPlotly({
    imp <- sort(metrics$importance[, 1])
    plot_ly(x = imp, y = factor(FEATURES[names(imp)], levels = FEATURES[names(imp)]),
            type = "bar", orientation = "h", marker = list(color = "#7B1E3A")) |>
      layout(xaxis = list(title = "Mean decrease in accuracy"), yaxis = list(title = ""),
             margin = list(l = 200))
  })
}

shinyApp(ui, server)
