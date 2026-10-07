# Train the random forest once, offline, and save everything the app needs.
#   Rscript train_model.R
# Outputs: model/wine_model.rds, model/metrics.rds, data/test_data.csv
source("R/wine.R")

wine <- read_wine("data/wine.data.csv")
parts <- split_stratified(wine, prop_train = 0.7, seed = 42)

model <- train_forest(parts$train, ntree = 500, seed = 42)
test_eval <- evaluate_model(model, parts$test)

metrics <- list(
  n_train = nrow(parts$train),
  n_test = nrow(parts$test),
  mtry = model$mtry,
  ntree = model$ntree,
  oob_error = unname(model$err.rate[model$ntree, "OOB"]),
  test_accuracy = test_eval$accuracy,
  test_confusion = test_eval$confusion,
  importance = randomForest::importance(model, type = 1),  # mean decrease in accuracy
  ranges = feature_ranges(wine),  # observed domain (all 178 wines), for inputs and warnings
  trained_on = format(Sys.Date())
)

dir.create("model", showWarnings = FALSE)
saveRDS(model, "model/wine_model.rds")
saveRDS(metrics, "model/metrics.rds")

# Held-out wines (never seen during training), with their true cultivar so the
# app can report accuracy when this file is uploaded.
test_out <- parts$test[, c(names(FEATURES), "cultivar")]
names(test_out) <- gsub(".", "-", names(test_out), fixed = TRUE)
utils::write.csv(test_out, "data/test_data.csv", row.names = FALSE, quote = FALSE)

cat(sprintf("mtry = %d, OOB error = %.3f, held-out accuracy = %.3f (%d wines)\n",
            model$mtry, metrics$oob_error, metrics$test_accuracy, metrics$n_test))
print(test_eval$confusion)
