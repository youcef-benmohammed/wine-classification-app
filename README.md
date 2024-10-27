# Wine Cultivar Prediction Shiny App

## Overview
This Shiny application enables users to predict wine cultivars based on input parameters using a pre-trained Random Forest model. The model has been trained on a dataset containing various chemical properties of wines.

## Application Structure
The application comprises two main panels:
- **Sidebar Panel**: Allows users to input wine parameters for prediction.
- **Main Panel**:
  - Displays status/output messages.
  - Shows prediction results in a tabular format.

## How to Use
1. **Input Parameters**: On the sidebar, input the desired wine parameters:
   - Alcohol
   - Malic acid
   - Ash
   - Alcalinity of ash
   - Magnesium
   - Total phenols
   - Flavnoids
   - Non-Flavnoid phenols
   - Proanthocyanins
   - Color intensity
   - Hue
   - OD280/OD315 of diluted wines
   - Proline

2. **Getting Predictions**:
   - Click the "Submit" button to trigger the prediction based on the provided parameters.
   - Alternatively, users can upload a dataset in CSV format using the "Upload Data" option and click the "Get Predictions" button to obtain predictions for the uploaded data.

3. **Output**:
   - The output section will display the prediction status or inform you when the server is ready for calculations.
   - Once the prediction is complete, the table will display the predicted wine cultivars based on the input parameters or the uploaded dataset.

## Model Information
The predictive model used in this application is a Random Forest classifier trained on a wine dataset. The model has been saved as `wine_model.rds`.

## Files Included
- `app.R`: Contains the code for the Shiny application.
- `wine.data.csv`: The original dataset used to train the predictive model.
- `predictions.csv`: Output file containing predictions when using the "Get Predictions" button with an uploaded dataset.
- `wine_model.rds`: Saved Random Forest model used for predictions.

## Requirements
- R libraries: `tidyverse`, `shiny`, `shinythemes`, `data.table`, `randomForest`, `shinyWidgets`.

## Setup and Execution
1. Install the required R libraries using `install.packages('library_name')`.
2. Run the Shiny application using RStudio or execute the `app.R` script in your R environment.
3. Access the application through the web browser at the following address: [Wine Cultivar Prediction App](https://5lhxiz-youcef-ben0mohammed.shinyapps.io/wine_classification_shiny-main/).
