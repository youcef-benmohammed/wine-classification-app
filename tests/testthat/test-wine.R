root <- file.path("..", "..")
wine <- read_wine(file.path(root, "data", "wine.data.csv"))
model <- readRDS(file.path(root, "model", "wine_model.rds"))
metrics <- readRDS(file.path(root, "model", "metrics.rds"))
test_data <- read_wine(file.path(root, "data", "test_data.csv"))

test_that("data are read with cultivar names and the expected columns", {
  expect_equal(nrow(wine), 178)
  expect_true(all(names(FEATURES) %in% names(wine)))
  expect_equal(levels(wine$cultivar), CULTIVARS)
  expect_equal(as.integer(table(wine$cultivar)), c(59L, 71L, 48L))
})

test_that("the split is stratified and has no overlap", {
  parts <- split_stratified(wine, 0.7, seed = 42)
  expect_equal(nrow(parts$train) + nrow(parts$test), nrow(wine))
  expect_length(intersect(rownames(parts$train), rownames(parts$test)), 0)
  expect_equal(as.numeric(prop.table(table(parts$train$cultivar))),
               as.numeric(prop.table(table(wine$cultivar))), tolerance = 0.02)
})

test_that("the shipped test file contains only held-out wines", {
  key <- function(df) apply(df[names(FEATURES)], 1, paste, collapse = "|")
  parts <- split_stratified(wine, 0.7, seed = 42)
  expect_length(intersect(key(test_data), key(parts$train)), 0)
})

test_that("training is reproducible and uses default mtry", {
  parts <- split_stratified(wine, 0.7, seed = 42)
  m1 <- train_forest(parts$train, ntree = 100, seed = 1)
  m2 <- train_forest(parts$train, ntree = 100, seed = 1)
  expect_identical(predict(m1, parts$test), predict(m2, parts$test))
  expect_equal(m1$mtry, floor(sqrt(length(FEATURES))))
})

test_that("the saved model performs well on held-out wines", {
  expect_gt(evaluate_model(model, test_data)$accuracy, 0.9)
  expect_equal(metrics$test_accuracy, evaluate_model(model, test_data)$accuracy)
})

test_that("upload validation reports missing columns, non-numeric values and NAs", {
  ranges <- metrics$ranges
  expect_true(validate_upload(test_data, ranges)$ok)
  expect_match(validate_upload(test_data[, -2], ranges)$message, "Missing column")
  bad <- test_data; bad$alcohol <- "x"
  expect_match(validate_upload(bad, ranges)$message, "Non-numeric")
  bad <- test_data; bad$hue[3] <- NA
  expect_match(validate_upload(bad, ranges)$message, "row\\(s\\): 3")
  far <- test_data[1, ]; far$hue <- 0
  expect_length(validate_upload(far, ranges)$warnings, 1)
})

test_that("predictions return one class and probabilities summing to 1", {
  p <- predict_wines(model, test_data[1:5, ])
  expect_equal(nrow(p), 5)
  expect_equal(unname(rowSums(p[CULTIVARS])), rep(1, 5), tolerance = 0.01)
})
