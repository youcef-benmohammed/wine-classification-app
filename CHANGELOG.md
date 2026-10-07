# Changelog

## [0.2] - 2026-10-07

### Method
- The model is trained once by `train_model.R` (seed 42) and only loaded by the app.
  Before, it was retrained without a seed at every app start, so predictions could change.
- Random forest now uses the default `mtry` (√13 ≈ 3). `mtry = 13` made it plain bagging:
  OOB error drops from 2.8 % to 1.6 %.
- Stratified 70/30 train/test split. `data/test_data.csv` now only contains the 53 held-out
  wines (before, 32 of its 72 rows were training wines), with their true cultivar.
- New **Model** tab: held-out accuracy (96.2 %), OOB error, confusion matrix and variable
  importance.

### Bugs
- Input defaults are now the medians of the dataset, with min/max set to the observed range
  (before: values such as colour intensity = 0, outside the data, giving meaningless predictions).
- CSV validation checks missing columns, non-numeric values and missing values, and warns
  for values far outside the observed range. Before, a file with missing columns crashed `predict()`.
- Predictions are offered as a download instead of being written on the server
  (the app used to display a server path).
- When the uploaded file has a `cultivar` column, accuracy and a confusion matrix are shown.

### Presentation
- Typos fixed (Flavonoids, `environment.yml`); cleaner Bootstrap 5 interface without background image;
  bar charts instead of a treemap.
- README with data source (UCI Wine, Forina et al.), method, metrics and screenshots; MIT license.
- Single deployment name documented (`wine_classification_shiny-main`); `rsconnect/` no longer committed.
- Removed the outdated `Forest_explained.html` (it described the previous model) and the unused root `wine_model.rds`.
- Unit tests (testthat) run in GitHub Actions; tags and releases are created automatically from `VERSION`.

## [0.1] - 2024-11-20
Initial version.
