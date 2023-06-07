# Import libraries
library(shiny)
library(shinythemes)
library(data.table)
library(randomForest)
library(shinyWidgets)

# Read data
wine <- read.csv("wine.data.csv")%>%
  mutate(cultivar=as.factor( c('Barolo','Grignolino','Barbera'))[ cultivar ] )

# Build model
model <- randomForest(cultivar ~ ., data = wine, ntree = 500, mtry = 13, importance = TRUE)

# Save model to RDS file
saveRDS(model, "wine_model.rds")

# Read in the RF model
model <- readRDS("wine_model.rds")

####################################
# User interface                   #
####################################

ui <- fluidPage(theme = shinytheme("united"),
  setBackgroundColor(
    color = c("#F7FBFF", "#722F37"),
    gradient = "linear",
    direction = "bottom"
  ),
                
  # Page header
  headerPanel('Wine Cultivar'),
  
  # Input values
  sidebarPanel(
    HTML("<h3>Input parameters</h3>"),
    
    numericInput("alcohol", label = "Alcohol:", 
                min = 10, max = 15,
                value = 10, step= 0.01),
    numericInput("malic.acid", "Malic acid:",
                min = 0, max = 6,
                value = 0, step= 0.001),
    numericInput("ash", "Ash:",
                min = 1, max = 4,
                value = 1, step= 0.001),
    numericInput("alcalinity.of.ash", "Alcalinity of Ash:",
                min = 10, max = 30,
                value = 10, step= 0.01),
    numericInput("magnesium", "Magnesium:",
                min = 70, max = 200,
                value = 70, step= 0.01),
    numericInput("total.phenols", "Total phenols:",
                min = 0, max = 4,
                value = 0, step= 0.001),
    numericInput("flavnoids", "Flavnoids:",
                min = 0, max = 6,
                value = 0, step= 0.001),
    numericInput("nonflavnoid.phenols", "Non-Flavnoid Phenols:",
                min = 0, max = 1, 
                value = 0, step= 0.0001
                ),
    numericInput("proanthocyanins", "Proanthocyanins:",
                min = 0, max = 4,
                value = 0, step= 0.001),
    numericInput("color.intensity", "Color intensity:",
                min = 1, max = 13,
                value = 0, step= 0.001),
    numericInput("hue", "Hue:",
                min = 0, max = 2,
                value = 0, step= 0.0001),
    numericInput("od280.od315.of.diluted.wines", "od280 od315 of diluted wines:",
                min = 1, max = 4,
                value = 1, step= 0.001),
    numericInput("proline", "Proline:",
                min = 100, max = 2000,
                value = 100, step= 0.1),
    actionButton("submitbutton", "Submit", class = "btn btn-primary")
  ),
  
  mainPanel(
    tags$label(h3('Status/Output')), # Status/Output Text Box
    verbatimTextOutput('contents'),
    tableOutput('tabledata') # Prediction results table
    
  )
)

####################################
# Server                           #
####################################

server <- function(input, output, session) {

  # Input Data
  datasetInput <- reactive({  
    
  # outlook,temperature,humidity,windy,play
  df <- data.frame(
    Name = c("alcohol", "malic.acid",  "ash", "alcalinity.of.ash",
             "magnesium", "total.phenols", "flavonoids", "nonflavonoid.phenols", 
             "proanthocyanins", "color.intensity",  "hue",    "od280.od315.of.diluted.wines", "proline"),
    Value = as.character(c(input$alcohol,
                           input$malic.acid,
                           input$ash,
                           input$alcalinity.of.ash,
                           input$magnesium,
                           input$total.phenols,
                           input$flavnoids,
                           input$nonflavnoid.phenols,
                           input$proanthocyanins,
                           input$color.intensity,
                           input$hue,
                           input$od280.od315.of.diluted.wines,
                           input$proline
                           )),
    stringsAsFactors = FALSE)
  
  cultivar <- "cultivar"
  df <- rbind(df, cultivar)
  input <- transpose(df)
  write.table(input,"input.csv", sep=",", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
  test <- read.csv(paste("input", ".csv", sep=""), header = TRUE)
  
  Output <- data.frame(Prediction=predict(model,test), round(predict(model,test,type="prob"), 3))
  print(Output)
  
  })
  
  # Status/Output Text Box
  output$contents <- renderPrint({
    if (input$submitbutton>0) { 
      isolate("Calculation complete.") 
    } else {
      return("Server is ready for calculation.")
    }
  })
  
  # Prediction results table
  output$tabledata <- renderTable({
    if (input$submitbutton>0) { 
      isolate(datasetInput()) 
    } 
  })
  
}

####################################
# Create the shiny app             #
####################################
shinyApp(ui = ui, server = server)
