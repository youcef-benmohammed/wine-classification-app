# Helper functions shared by the training script, the Shiny app and the tests.

CULTIVARS <- c("Barolo", "Grignolino", "Barbera")  # classes 1, 2, 3 of the UCI dataset

FEATURES <- c(
  alcohol = "Alcohol (%)",
  malic.acid = "Malic acid (g/L)",
  ash = "Ash (g/L)",
  alcalinity.of.ash = "Alcalinity of ash",
  magnesium = "Magnesium (mg/L)",
  total.phenols = "Total phenols",
  flavonoids = "Flavonoids",
  nonflavonoid.phenols = "Non-flavonoid phenols",
  proanthocyanins = "Proanthocyanins",
  color.intensity = "Colour intensity",
  hue = "Hue",
  od280.od315.of.diluted.wines = "OD280/OD315 of diluted wines",
  proline = "Proline (mg/L)"
)

#' Read the UCI wine data. Column names such as "malic-acid" become
#' "malic.acid"; the numeric class becomes a factor with cultivar names.
read_wine <- function(path) {
  df <- utils::read.csv(path)
  if ("cultivar" %in% names(df) && is.numeric(df$cultivar)) {
    df$cultivar <- factor(CULTIVARS[df$cultivar], levels = CULTIVARS)
  }
  df
}

#' Stratified train/test split (same class proportions in both sets).
split_stratified <- function(df, prop_train = 0.7, seed = 42) {
  set.seed(seed)
  idx <- unlist(lapply(split(seq_len(nrow(df)), df$cultivar), function(i) {
    i[sample.int(length(i), round(length(i) * prop_train))]
  }))
  list(train = df[sort(idx), ], test = df[-idx, ])
}

#' Random forest with the default mtry (sqrt of the number of features).
#' The seed makes the model reproducible.
train_forest <- function(train, ntree = 500, seed = 42) {
  set.seed(seed)
  randomForest::randomForest(cultivar ~ ., data = train, ntree = ntree, importance = TRUE)
}

#' Accuracy and confusion matrix on labelled data.
evaluate_model <- function(model, df) {
  pred <- stats::predict(model, df)
  cm <- table(Observed = df$cultivar, Predicted = pred)
  list(accuracy = mean(pred == df$cultivar), confusion = cm)
}

#' Min / median / max of each feature, used for input defaults and checks.
feature_ranges <- function(df) {
  data.frame(
    feature = names(FEATURES),
    label = unname(FEATURES),
    min = vapply(names(FEATURES), function(f) min(df[[f]]), numeric(1)),
    median = vapply(names(FEATURES), function(f) stats::median(df[[f]]), numeric(1)),
    max = vapply(names(FEATURES), function(f) max(df[[f]]), numeric(1)),
    row.names = NULL
  )
}

#' Check an uploaded table before prediction.
#'
#' @param tolerance fraction of the training span allowed beyond min/max before warning.
#' @return list(ok, message, data, warnings). Extra columns are allowed and
#'   kept; a `cultivar` column, if present, is used to compute accuracy.
validate_upload <- function(df, ranges, tolerance = 0.1) {
  missing <- setdiff(names(FEATURES), names(df))
  if (length(missing) > 0) {
    return(list(ok = FALSE, message = paste(
      "Missing column(s):", paste(missing, collapse = ", "),
      "\nExpected columns (as in data/test_data.csv):", paste(names(FEATURES), collapse = ", "))))
  }
  if (nrow(df) == 0) return(list(ok = FALSE, message = "The file contains no rows."))
  non_numeric <- names(FEATURES)[!vapply(df[names(FEATURES)], is.numeric, logical(1))]
  if (length(non_numeric) > 0) {
    return(list(ok = FALSE, message = paste("Non-numeric column(s):", paste(non_numeric, collapse = ", "))))
  }
  na_rows <- which(!stats::complete.cases(df[names(FEATURES)]))
  if (length(na_rows) > 0) {
    return(list(ok = FALSE, message = paste("Missing values in row(s):", paste(utils::head(na_rows, 10), collapse = ", "))))
  }
  # Warn only when a value is clearly outside the training range
  # (more than `tolerance` x the observed span beyond min or max).
  out_of_range <- names(FEATURES)[vapply(names(FEATURES), function(f) {
    r <- ranges[ranges$feature == f, ]
    margin <- tolerance * (r$max - r$min)
    any(df[[f]] < r$min - margin | df[[f]] > r$max + margin)
  }, logical(1))]
  warnings <- if (length(out_of_range)) {
    paste("Some values are well outside the range seen during training for:",
          paste(unname(FEATURES[out_of_range]), collapse = ", "),
          "- predictions for these wines are extrapolations.")
  } else character(0)
  if ("cultivar" %in% names(df)) {
    df$cultivar <- factor(df$cultivar, levels = CULTIVARS)
  }
  list(ok = TRUE, message = sprintf("%d wine(s) ready for prediction.", nrow(df)),
       data = df, warnings = warnings)
}

#' Predicted class and class probabilities.
predict_wines <- function(model, df) {
  prob <- stats::predict(model, df[names(FEATURES)], type = "prob")
  out <- data.frame(Prediction = stats::predict(model, df[names(FEATURES)]),
                    round(as.data.frame(unclass(prob)), 3), check.names = FALSE)
  out$Confidence <- apply(prob, 1, max)
  out
}
