# docs/r.md, "Read a sheet" (the guessing table) and "Column types".

mixed <- function(...) quietly(read_xlsx(edge(), sheet = "Mixed", ...))

test_that("a guess looks at every cell and never loses a value", {
  df <- mixed()
  expect_identical(df$num_text, c("1", "2", "three", "4"))
  expect_identical(df$whole, 1:4)
  expect_identical(df$frac, c(1, 2.5, 3, 4))
  expect_identical(df$big, c(1, 2, 3e9, 4))
  expect_identical(df$neg, c(-2147483647L, 2147483647L, 0L, -5L))
  expect_identical(df$lgl, c(TRUE, FALSE, NA, TRUE))
  expect_identical(df$empty, rep(NA, 4))
  expect_identical(df$spaces, c("a", NA, "b", NA))
  expect_s3_class(df$date_dttm, "POSIXct")
  expect_identical(attr(df$date_dttm, "tzone"), "UTC")
  expect_identical(format(df$date_dttm), c("2024-01-01 00:00:00", "2024-01-02 12:00:00", NA, NA))
  # Kinds that no one type holds become text, as Excel shows them.
  expect_identical(df$bool_num, c("TRUE", "1", "FALSE", "0"))
  expect_identical(df$date_num, c("2024-01-01", "5", NA, NA))
})

test_that("a text cell deep in a column of numbers makes it text, with a message naming the cells", {
  path <- xlkit_example("messy.xlsx")
  msg <- expect_message(df <- read_xlsx(path, sheet = "Types"), class = "rlang_message")
  expect_type(df$amount, "character")
  expect_identical(nrow(df), 2003L)
  expect_identical(
    first_line(msg),
    "`amount` is text because 2 of its 2,003 values are not numbers:\nC2003 (\"n/a\") and C2004 (\"12,5\")."
  )
  expect_match(
    conditionMessage(msg),
    "To read it as numbers, use `types = c(amount = \"number\")`; those cells become NA.",
    fixed = TRUE
  )
  expect_identical(df$amount[[2002]], "n/a")
  expect_identical(df$zip[1:2], c(60614L, 94110L))
  expect_identical(nrow(xlsx_problems(df)), 0L)
})

test_that("the message comes only for a few cells", {
  # 1 text cell among 4 values is not fewer than 1 in 10.
  expect_no_message(read_xlsx(edge(), sheet = "Mixed"))
  kinds <- c(rep(1L, 95), rep(7L, 5))
  expect_false(is.null(xlkit:::text_because(kinds, c(rep(1, 95), rep(NA, 5)))))
  kinds <- c(rep(1L, 200), rep(7L, 11))
  expect_null(xlkit:::text_because(kinds, c(rep(1, 200), rep(NA, 11))))
  dates <- xlkit:::text_because(c(2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 7L), rep(45000, 12))
  expect_identical(dates$type, "date")
})

test_that("types names some columns and the rest are guessed; cells that do not fit warn", {
  path <- xlkit_example("messy.xlsx")
  w <- expect_warning(
    df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number")),
    class = "rlang_warning"
  )
  expect_identical(
    first_line(w),
    "2 cells in `amount` could not be read as numbers and are NA:\nC2003 (\"n/a\") and C2004 (\"12,5\")."
  )
  expect_match(conditionMessage(w), "See them all with `xlsx_problems(df)`.", fixed = TRUE)
  expect_type(df$id, "integer")
  expect_identical(df$zip[c(1, 4, 6)], c("60614", "01002", "02139"))
  expect_type(df$amount, "double")
  expect_identical(df$amount[2002:2003], c(NA_real_, NA_real_))
  p <- xlsx_problems(df)
  expect_identical(names(p), c("cell", "column", "row", "value", "problem"))
  expect_identical(p$cell, c("C2003", "C2004"))
  expect_identical(p$column, c("amount", "amount"))
  expect_identical(p$row, c(2003L, 2004L))
  expect_identical(p$value, c("n/a", "12,5"))
  expect_identical(p$problem, c("not a number", "not a number"))
})

test_that("each type converts what it can and reports the rest", {
  # Text: " 42 ", "1e3", "12,5", 2.5 | "7", "7.5", "x", 3 | "TRUE",
  # "false", "yes", 0 | "2024-03-01", "01/03/2024", "2024-02-30", 45306 |
  # "2024-03-01 14:30:00", "2024-03-01", "soon", 45306.25 | "14:30",
  # "14:30:15", "noon", 0.5
  expect_warning(
    df <- read_xlsx(edge(), sheet = "Text", types = c("number", "integer", "logical", "date", "datetime", "time")),
    "1 cell in `num` could not be read as numbers and is NA:\nA4 (\"12,5\").", fixed = TRUE
  )
  expect_identical(df$num, c(42, 1000, NA, 2.5))
  expect_identical(df$int, c(7L, NA, NA, 3L))
  expect_identical(df$lgl, c(TRUE, FALSE, NA, FALSE))
  expect_identical(df$date, as.Date(c("2024-03-01", NA, NA, "2024-01-15")))
  expect_identical(
    df$dttm,
    as.POSIXct(c("2024-03-01 14:30:00", "2024-03-01 00:00:00", NA, "2024-01-15 06:00:00"), tz = "UTC")
  )
  expect_s3_class(df$time, "hms")
  expect_identical(as.numeric(df$time), c(14.5 * 3600, 14 * 3600 + 30 * 60 + 15, NA, 12 * 3600))
  p <- xlsx_problems(df)
  expect_identical(p$cell, c("A4", "B3", "B4", "C4", "D3", "D4", "E4", "F4"))
  expect_identical(p$problem, c(
    "not a number", "not a whole number", "not a number", "not TRUE or FALSE",
    "not a date", "not a date", "not a date-time", "not a time"
  ))
  w <- tryCatch(
    read_xlsx(edge(), sheet = "Text", types = c("number", "integer", "logical", "date", "datetime", "time")),
    warning = function(w) w
  )
  msg <- conditionMessage(w)
  expect_match(msg, "2 cells in `int` could not be read as whole numbers and are NA:\nB3 (\"7.5\") and B4 (\"x\").", fixed = TRUE)
  expect_match(msg, "1 cell in `lgl` could not be read as TRUE or FALSE and is NA:", fixed = TRUE)
  expect_match(msg, "2 cells in `date` could not be read as dates and are NA:", fixed = TRUE)
  expect_match(msg, "1 cell in `dttm` could not be read as date-times and is NA:", fixed = TRUE)
  expect_match(msg, "1 cell in `time` could not be read as times and is NA:", fixed = TRUE)
})

test_that("text writes numbers as Excel shows them", {
  df <- read_xlsx(edge(), sheet = "Formats", types = "text")
  expect_identical(df$zip, "02139")
  expect_identical(df$general, "0.1")
  expect_identical(df$thousands, "1234567")
  expect_identical(df$sci, "12345.678")
  expect_identical(df$locale_date, "2024-01-15")
  expect_identical(df$dttm, "2024-01-15 12:00:00")
  expect_identical(df$ampm, "18:00:00")
  expect_identical(df$duration, "36:00:00")
  expect_identical(xlkit:::number_text(c(0.1 + 0.2, 1 / 3, 1e20, 123456789012345678)),
                   c("0.3", "0.333333333333333", "1e+20", "1.23456789012346e+17"))
  expect_identical(read_xlsx(edge(), sheet = "Mixed", types = "text")$lgl, c("TRUE", "FALSE", NA, "TRUE"))
})

test_that("integer reads numbers that are not whole, or too large, as NA with a warning", {
  expect_warning(df <- read_xlsx(edge(), sheet = "Mixed", types = c(frac = "integer", big = "integer")),
                 "could not be read as whole numbers")
  expect_identical(df$frac, c(1L, NA, 3L, 4L))
  expect_identical(df$big, c(1L, 2L, NA, 4L))
  p <- xlsx_problems(df)
  expect_identical(p$problem, c("too large for an integer", "not a whole number"))
})

test_that("logical reads 0 as FALSE and other numbers as TRUE", {
  df <- read_xlsx(edge(), sheet = "Mixed", types = c(whole = "logical", neg = "logical"))
  expect_identical(df$whole, rep(TRUE, 4))
  expect_identical(df$neg, c(TRUE, TRUE, FALSE, TRUE))
})

test_that("types can be one for all, one per column, aliases, or skip", {
  report <- xlkit_example("report.xlsx")
  all_text <- read_xlsx(report, types = "text")
  expect_true(all(vapply(all_text, is.character, logical(1))))
  expect_identical(all_text$joined[[1]], "2024-01-15")
  expect_identical(all_text$passed[[2]], "FALSE")
  per_col <- read_xlsx(report, types = c("character", "guess", "numeric", "skip", "double"))
  expect_identical(names(per_col), c("id", "name", "score", "joined"))
  expect_identical(per_col$id, c("1", "2", "3", "4"))
  expect_identical(per_col$joined, c(45306, 45325, 45342, 45352))
  skipped <- read_xlsx(report, types = c(name = "skip"))
  expect_identical(names(skipped), c("id", "score", "passed", "joined"))
})

test_that("a type or a column that is not there stops with the choices", {
  report <- xlkit_example("report.xlsx")
  expect_error(read_xlsx(report, types = c(scor = "number")), "`types` names `scor`, which is not a column.", fixed = TRUE)
  expect_error(read_xlsx(report, types = c(scor = "number")), "Did you mean `score`?", fixed = TRUE)
  expect_error(read_xlsx(report, types = c(scor = "number")), "The columns are `id`, `name`, `score`, `passed` and `joined`.", fixed = TRUE)
  expect_error(read_xlsx(report, types = c(score = "nmber")), "`types` has \"nmber\", which is not a type.", fixed = TRUE)
  expect_error(read_xlsx(report, types = c(score = "nmber")), "Did you mean \"number\"?", fixed = TRUE)
  expect_error(read_xlsx(report, types = c("text", "text")), "`types` has 2 types, but the sheet has 5 columns.", fixed = TRUE)
  expect_error(read_xlsx(report, types = c(id = "text", "text")), "must name every type or none")
  expect_error(read_xlsx(report, types = 1), "`types` must be a character vector")
})
