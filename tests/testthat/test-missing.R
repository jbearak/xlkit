# docs/r.md, "Missing values and Excel errors".

messy <- function() xlkit_example("messy.xlsx")

test_that("na marks text as missing, whole cell after trimming, text cells only", {
  w <- expect_warning(
    df <- read_xlsx(messy(), sheet = "Missing", na = c("NA", ".", "-")),
    class = "rlang_warning"
  )
  expect_identical(
    first_line(w),
    "2 cells hold Excel errors and are NA: D4 (#N/A) and D9 (#DIV/0!)."
  )
  expect_match(conditionMessage(w), "See them all with `xlsx_problems(df)`.", fixed = TRUE)
  # "NA", ".", "-" and " NA " are missing; the number -1 is not.
  expect_identical(df$score, c(12L, NA, 7L, NA, -1L, NA, 9L, 11L, NA))
  expect_identical(df$rate, c(0.5, 0.25, NA, 0.75, 0.1, 0.3, 0.45, NA, 0.6))
  p <- xlsx_problems(df)
  expect_identical(p$cell, c("D4", "D9"))
  expect_identical(p$column, c("rate", "rate"))
  expect_identical(p$row, c(4L, 9L))
  expect_identical(p$value, c("#N/A", "#DIV/0!"))
  expect_identical(p$problem, c("Excel error", "Excel error"))
})

test_that("the default na is only blank cells", {
  df <- quietly(read_xlsx(messy(), sheet = "Missing"))
  expect_identical(df$score, c("12", "NA", "7", ".", "-1", "-", "9", "11", " NA "))
  expect_identical(read_xlsx(messy(), sheet = "Missing", na = "-1", types = c(rate = "text"))$score[[5]], "-1")
})

test_that("Excel errors are NA in every type but text, and never make a column text", {
  w <- expect_warning(df <- read_xlsx(edge(), sheet = "Errors"), class = "rlang_warning")
  expect_identical(
    first_line(w),
    "7 cells hold Excel errors and are NA: A2 (#N/A), A3 (#DIV/0!), A4 (#VALUE!), A5 (#REF!), A6 (#NAME?) and 2 more."
  )
  expect_identical(df$x, rep(NA, 7))
  expect_identical(df$y, 2:8)
  expect_identical(xlsx_problems(df)$value, c("#N/A", "#DIV/0!", "#VALUE!", "#REF!", "#NAME?", "#NUM!", "#NULL!"))
  for (type in c("number", "integer", "logical", "date", "datetime", "time")) {
    expect_warning(read_xlsx(edge(), sheet = "Errors", types = c(x = type)), "hold Excel errors")
  }
  rate <- suppressWarnings(read_xlsx(messy(), sheet = "Missing", na = c("NA", ".", "-")))$rate
  expect_type(rate, "double")
})

test_that("reading as text keeps the error text without a warning", {
  expect_no_warning(df <- read_xlsx(edge(), sheet = "Errors", types = c(x = "text")))
  expect_identical(df$x, c("#N/A", "#DIV/0!", "#VALUE!", "#REF!", "#NAME?", "#NUM!", "#NULL!"))
  expect_identical(nrow(xlsx_problems(df)), 0L)
})

test_that("one warning covers conversions and errors together", {
  ws <- list()
  withCallingHandlers(
    df <- read_xlsx(messy(), sheet = "Missing", na = c("."), types = c(score = "number")),
    warning = function(w) {
      ws[[length(ws) + 1]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  expect_length(ws, 1)
  msg <- conditionMessage(ws[[1]])
  expect_match(msg, "3 cells in `score` could not be read as numbers and are NA:\nC3 (\"NA\"), C7 (\"-\") and C10 (\" NA \").", fixed = TRUE)
  expect_match(msg, "\n2 cells hold Excel errors and are NA: D4 (#N/A) and D9 (#DIV/0!).", fixed = TRUE)
  expect_identical(xlsx_problems(df)$cell, c("C3", "C7", "C10", "D4", "D9"))
})

test_that("xlsx_problems() gives zero rows without problems and checks its input", {
  p <- xlsx_problems(read_xlsx(xlkit_example("report.xlsx")))
  expect_identical(dim(p), c(0L, 5L))
  expect_identical(names(p), c("cell", "column", "row", "value", "problem"))
  expect_identical(nrow(xlsx_problems(data.frame(x = 1))), 0L)
  expect_error(xlsx_problems(1), "`x` must be a tibble read by `read_xlsx()`", fixed = TRUE)
})
