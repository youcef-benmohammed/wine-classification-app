# Import libraries
library(tidyverse)
library(shiny)
library(shinythemes)
library(data.table)
library(randomForest)
library(shinyWidgets)
library(plotly)

# Read data
wine <- read.csv("data/wine.data.csv") %>%
  mutate(cultivar = as.factor(c('Barolo', 'Grignolino', 'Barbera'))[cultivar])

# Build model
model <- randomForest(cultivar ~ ., data = wine, ntree = 500, mtry = 13, importance = TRUE)

# Save model RDS file
saveRDS(model, "wine_model.rds")
model <- readRDS("wine_model.rds")

min_values <- sapply(wine[, -1], min)
max_values <- sapply(wine[, -1], max)

####################################
# User interface                   #
####################################

ui <- fluidPage(
  theme = shinytheme("united"),
  tags$head(
    tags$style(
      HTML(
        '
        body {
          background-image: url("background_image.jpeg");
          background-size: cover;
          background-repeat: no-repeat;
          background-attachment: fixed;
          background-position: center;
          height: 100%;
          width: 100%;
          margin: 0;
          padding: 0;
          overflow-x: hidden;
        }'
      )
    )
  ),
  

  headerPanel(
    tags$div(
      style = "background-color: rgb(240, 239, 136); padding: 10px; border-radius: 5px;",
      tags$h1("Wine Cultivar Prediction")
    )
  ),
  
 
  tabsetPanel(
    tabPanel("Predict a Single Wine",
             sidebarPanel(
               HTML("<h3>Input parameters</h3>"),
               
               numericInput("alcohol", label = "Alcohol:", min = 10, max = 15, value = 10, step = 0.01),
               numericInput("malic.acid", "Malic acid:", min = 0, max = 6, value = 0, step = 0.001),
               numericInput("ash", "Ash:", min = 1, max = 4, value = 1, step = 0.001),
               numericInput("alcalinity.of.ash", "Alcalinity of Ash:", min = 10, max = 30, value = 10, step = 0.01),
               numericInput("magnesium", "Magnesium:", min = 70, max = 200, value = 70, step = 0.01),
               numericInput("total.phenols", "Total phenols:", min = 0, max = 4, value = 0, step = 0.001),
               numericInput("flavnoids", "Flavnoids:", min = 0, max = 6, value = 0, step = 0.001),
               numericInput("nonflavnoid.phenols", "Non-Flavnoid Phenols:", min = 0, max = 1, value = 0, step = 0.0001),
               numericInput("proanthocyanins", "Proanthocyanins:", min = 0, max = 4, value = 0, step = 0.001),
               numericInput("color.intensity", "Color intensity:", min = 1, max = 13, value = 0, step = 0.001),
               numericInput("hue", "Hue:", min = 0, max = 2, value = 0, step = 0.0001),
               numericInput("od280.od315.of.diluted.wines", "od280 od315 of diluted wines:", min = 1, max = 4, value = 1, step = 0.001),
               numericInput("proline", "Proline:", min = 100, max = 2000, value = 100, step = 0.1),
               
               actionButton("submitbutton", "Submit", class = "btn btn-primary")
             ),
             
             mainPanel(
               tags$label(h3('Status/Output')), # Status/Output Text Box
               verbatimTextOutput('contents'),
               tableOutput('tabledata') # Prediction results table
             )
    ),
    
    tabPanel("Predict from CSV",
             sidebarPanel(
               fileInput("uploadFile", "Upload data", 
                         accept = c('text/csv', 'text/comma-separated-values', 'text/plain', '.csv')),
               actionButton("predictButton", "Get predictions", class = "btn btn-primary")
             ),
             
             mainPanel(
               tags$label(h3('Status/Output')), # Status/Output Text Box
               verbatimTextOutput('csv_status'),  # Output for CSV prediction status
               plotlyOutput("treemap")    # Output for treemap
             )
    )
  )
)

####################################
# Server                           #
####################################

# server.R

server <- function(input, output, session) {
  
  predictions_data <- reactiveValues(output = NULL) 
  
  observeEvent(input$predictButton, {
    req(input$uploadFile)  
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    prediction_file <- paste0("predictions_", timestamp, ".csv")
    
    # Définir le chemin où le fichier sera sauvegardé
    full_path  <- normalizePath(file.path(getwd(), prediction_file))
    
    inFile <- input$uploadFile
    df_uploaded <- read.csv(inFile$datapath)
    
    if (!all(colnames(df_uploaded) %in% colnames(wine))) {
      output$csv_status <- renderText("The uploaded file has an incorrect structure.")
      return(NULL)
    }
    
    predictions <- predict(model, df_uploaded)
    output_df <- data.frame(df_uploaded, Prediction = predictions)
    
    write.csv(output_df, full_path, row.names = FALSE)  
    
    predictions_data$output <- output_df  
    
    output$csv_status <- renderText(paste("Predictions have been made and saved at:", full_path))
  })
  
  datasetInput <- reactive({
    req(input$submitbutton)  
    
    new_data <- data.frame(
      alcohol = input$alcohol,
      malic.acid = input$malic.acid,
      ash = input$ash,
      alcalinity.of.ash = input$alcalinity.of.ash,
      magnesium = input$magnesium,
      total.phenols = input$total.phenols,
      flavonoids = input$flavnoids,
      nonflavonoid.phenols = input$nonflavnoid.phenols,
      proanthocyanins = input$proanthocyanins,
      color.intensity = input$color.intensity,
      hue = input$hue,
      od280.od315.of.diluted.wines = input$od280.od315.of.diluted.wines,
      proline = input$proline
    )
    
    predictions <- predict(model, new_data)
    prediction_prob <- round(predict(model, new_data, type = "prob"), 3)
    
    result <- data.frame(Prediction = predictions, prediction_prob)
    return(result)
  })
  
  output$contents <- renderPrint({
    if (input$submitbutton > 0) {
      isolate("Calculation complete.")
    } else {
      return("Server is ready for calculation.")
    }
  })
  
  output$tabledata <- renderTable({
    if (input$submitbutton > 0) {
      isolate(datasetInput())
    }
  })
  
  output$treemap <- renderPlotly({
    req(predictions_data$output)  
    
    df <- predictions_data$output
    
    treemap_data <- df %>%
      group_by(Prediction) %>%
      summarise(count = n(), .groups = 'drop')
    
    if (nrow(treemap_data) == 0) {
      return(NULL)  
    }
    
    treemap_plot = plot_ly(
      labels = treemap_data$Prediction,
      values = treemap_data$count,
      parents = rep("", nrow(treemap_data)), 
      type = 'treemap'
    ) %>%
      layout(title = "Treemap of Predictions")
    
    treemap_plot  
  })
}

####################################
# Create the shiny app             #
####################################
shinyApp(ui = ui, server = server)
