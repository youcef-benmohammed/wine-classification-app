# Run from the repository root: Rscript tests/testthat.R
library(testthat)
suppressPackageStartupMessages(library(randomForest))
source("R/wine.R")
test_dir("tests/testthat", stop_on_failure = TRUE)
