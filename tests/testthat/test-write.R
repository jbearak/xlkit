# docs/r.md, "Write a table": what each column type becomes, NA, text
# that is never a formula or a link, the defaults, and Excel's limits.
# Values are read back with xlkit's reader and readxl; formats, fonts,
# widths and frozen panes with openpyxl.

types_df <- function() {
  df <- data.frame(
    int = c(1L, NA, 3L, 4L),
    dbl = c(1.5, NA, -2.25, 1e10),
    chr = c("a", NA, "=A1+1", "https://example.com"),
    lgl = c(TRUE, FALSE, NA, TRUE),
    day = as.Date(c("2024-01-15", NA, "1900-01-01", "1900-02-28")),
    fct = factor(c("low", "high", NA, "low"), levels = c("low", "high")),
    stringsAsFactors = FALSE
  )
  df$stamp <- as.POSIXct(c("2024-01-15 08:30:00", NA, "2024-02-29 17:05:30", "2024-12-31 23:59:59"), tz = "UTC")
  df$clock <- hms::hms(c(30600, NA, 61530, 86399))
  df
}

test_that("each column type reads back as itself", {
  path <- temp_xlsx()
  expect_identical(write_xlsx(types_df(), path), path)
  back <- read_xlsx(path)
  df <- types_df()
  expect_identical(names(back), names(df))
  expect_identical(back$int, df$int)
  expect_identical(back$dbl, df$dbl)
  expect_identical(back$chr, df$chr)
  expect_identical(back$lgl, df$lgl)
  expect_identical(back$day, df$day)
  expect_identical(back$fct, as.character(df$fct))
  expect_equal(back$stamp, df$stamp)
  expect_equal(as.numeric(back$clock), as.numeric(df$clock))
  expect_s3_class(back$clock, "hms")
})

test_that("readxl reads the same values and types", {
  skip_if_not_installed("readxl")
  path <- temp_xlsx()
  write_xlsx(types_df(), path)
  theirs <- readxl::read_excel(path)
  df <- types_df()
  expect_identical(as.integer(theirs$int), df$int)
  expect_identical(theirs$dbl, df$dbl)
  expect_identical(theirs$chr, df$chr)
  expect_identical(theirs$lgl, df$lgl)
  expect_identical(as.Date(theirs$day), df$day)
  expect_equal(theirs$stamp, df$stamp)
  expect_identical(theirs$fct, as.character(df$fct))
})

test_that("strings stay strings, NA is an empty cell, dates have their formats", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  write_xlsx(types_df(), path)
  seen <- openpyxl(path)
  # "=A1+1" and "https://..." are text, not a formula or a link.
  expect_identical(xl_cell(seen, "C4")$type, "s")
  expect_identical(xl_cell(seen, "C4")$value, "'=A1+1'")
  expect_identical(xl_cell(seen, "C5")$type, "s")
  expect_identical(xl_cell(seen, "C5")$value, "'https://example.com'")
  # NA is no cell at all (openpyxl lists only cells with a value or style).
  expect_null(xl_cell(seen, "A3"))
  expect_null(xl_cell(seen, "C3"))
  expect_identical(xl_cell(seen, "D2")$type, "b")
  expect_identical(xl_cell(seen, "E2")$format, "yyyy-mm-dd")
  expect_identical(xl_cell(seen, "G2")$format, "yyyy-mm-dd hh:mm:ss")
  expect_identical(xl_cell(seen, "H2")$format, "hh:mm:ss")
  expect_identical(xl_cell(seen, "B2")$format, "General")
})

test_that("the defaults: bold header, frozen header row, fitted widths up to 60", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  df <- data.frame(id = 1:3, note = c("short", strrep("long text ", 20), "x"))
  write_xlsx(df, path)
  seen <- openpyxl(path)
  expect_identical(seen$sheets$name, "Sheet1")
  expect_identical(seen$sheets$freeze, "'A2'")
  expect_identical(seen$sheets$filter, "")
  expect_true(xl_cell(seen, "A1")$bold)
  expect_true(xl_cell(seen, "B1")$bold)
  expect_false(xl_cell(seen, "A2")$bold)
  w <- setNames(seen$widths$width, seen$widths$col)
  # rust_xlsxwriter adds Excel's padding of about 0.71 to the width.
  expect_lte(w[["B"]], 61)
  expect_gte(w[["B"]], 60)
  expect_lt(w[["A"]], 8)
})

test_that("sheet names the sheet", {
  path <- temp_xlsx()
  write_xlsx(data.frame(a = 1), path, sheet = "Scores")
  expect_identical(xlsx_sheets(path), "Scores")
})

test_that("POSIXct is written on the clock of its own time zone", {
  path <- temp_xlsx()
  ny <- as.POSIXct("2024-07-01 09:15:00", tz = "America/New_York")
  write_xlsx(data.frame(t = ny, u = as.POSIXct("2024-07-01 09:15:00", tz = "UTC")), path)
  back <- read_xlsx(path)
  # Excel has no time zones: both show 09:15, read back as UTC.
  expect_identical(format(back$t, "%Y-%m-%d %H:%M:%S"), "2024-07-01 09:15:00")
  expect_identical(format(back$u, "%Y-%m-%d %H:%M:%S"), "2024-07-01 09:15:00")
})

test_that("a time of 24 hours or more is shown [h]:mm:ss", {
  path <- temp_xlsx()
  write_xlsx(data.frame(d = as.difftime(c(90, 1500), units = "mins")), path)
  back <- read_xlsx(path)
  expect_equal(as.numeric(back$d), c(5400, 90000))
  skip_if_no_openpyxl()
  expect_identical(xl_cell(openpyxl(path), "A2")$format, "[h]:mm:ss")
})

test_that("NA can be written as text with `na`", {
  path <- temp_xlsx()
  write_xlsx(data.frame(x = c(1, NA), y = c(NA, "b")), path, na = "NA")
  back <- read_xlsx(path)
  expect_identical(back$x, c("1", "NA"))
  expect_identical(back$y, c("NA", "b"))
})

test_that("NaN and Inf are blank with a warning that names the cells", {
  path <- temp_xlsx()
  w <- expect_warning(write_xlsx(data.frame(x = c(1, NaN, Inf, -Inf, NA, 2)), path), class = "rlang_warning")
  expect_identical(
    first_line(w),
    "3 cells hold NaN or Inf, which Excel cannot store, and are blank: A3 (NaN), A4 (Inf) and A5 (-Inf)."
  )
  expect_identical(read_xlsx(path)$x, c(1L, NA, NA, NA, NA, 2L))
  # `na` text is for NA only; NaN is still blank.
  path2 <- temp_xlsx()
  expect_warning(write_xlsx(data.frame(x = c(NaN, NA, 3)), path2, na = "."), class = "rlang_warning")
  expect_identical(read_xlsx(path2, types = "text")$x, c(NA, ".", "3"))
})

test_that("xl_formula() columns write formulas, with or without =", {
  path <- temp_xlsx()
  df <- data.frame(x = 1:3)
  df$y <- xl_formula(c("A2*2", "=A3*2", NA))
  write_xlsx(df, path)
  # Until Excel calculates them, the file stores no result.
  expect_identical(read_xlsx(path)$y, c(NA, NA, NA))
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(xl_cell(seen, "B2")$type, "f")
  expect_identical(xl_cell(seen, "B2")$value, "'=A2*2'")
  expect_identical(xl_cell(seen, "B3")$value, "'=A3*2'")
  expect_null(xl_cell(seen, "B4"))
})

test_that("xl_formula() keeps its class and prints with =", {
  f <- xl_formula(c("SUM(A1:A3)", "=B1"))
  expect_s3_class(f, "xl_formula")
  expect_identical(format(f), c("=SUM(A1:A3)", "=B1"))
  expect_s3_class(f[1], "xl_formula")
  expect_error(xl_formula(1:3), "must be a character vector of formulas")
})

test_that("a list column stops with its name", {
  df <- tibble::tibble(id = 1:2, data = list(1, 2))
  err <- expect_error(write_xlsx(df, temp_xlsx()), class = "rlang_error")
  expect_identical(first_line(err), "`data` is a list column, and a cell holds one value.")
})

test_that("Excel's limits stop before anything is written", {
  path <- temp_xlsx()
  long <- data.frame(x = c("ok", strrep("a", 32768)))
  err <- expect_error(write_xlsx(long, path), class = "rlang_error")
  expect_identical(first_line(err), "`x` has text longer than the 32,767 characters a cell holds: A3 (32,768 characters).")
  expect_false(file.exists(path))

  rows <- data.frame(x = integer(1048576))
  err <- expect_error(write_xlsx(rows, path), class = "rlang_error")
  expect_identical(first_line(err), "The sheet would have 1,048,577 rows, and a sheet holds at most 1,048,576.")
  expect_match(conditionMessage(err), "Split the table across sheets", fixed = TRUE)

  wide <- as.data.frame(matrix(0L, nrow = 1, ncol = 16385))
  err <- expect_error(write_xlsx(wide, path), class = "rlang_error")
  expect_identical(first_line(err), "The table has 16,385 columns, and a sheet holds at most 16,384.")
  expect_false(file.exists(path))

  early <- data.frame(d = as.Date(c("2024-01-01", "1899-12-31")))
  err <- expect_error(write_xlsx(early, path), class = "rlang_error")
  expect_identical(
    first_line(err),
    "`d` has dates Excel cannot hold, which shows only 1900-01-01 to 9999-12-31: A3 (1899-12-31)."
  )
  expect_false(file.exists(path))
})

test_that("a table of 1,048,575 rows and its header fits", {
  skip_on_cran()
  path <- temp_xlsx()
  write_xlsx(data.frame(x = rep(1L, 1048575)), path, widths = 10)
  expect_identical(nrow(read_xlsx(path)), 1048575L)
})

test_that("path must be an .xlsx file in a folder that exists", {
  df <- data.frame(a = 1)
  expect_error(write_xlsx(df, file.path(tempdir(), "x.xls")), "must end in .xlsx")
  expect_error(write_xlsx(df, file.path(tempdir(), "no-such-folder", "x.xlsx")), "does not exist")
  folder <- temp_xlsx("folder.xlsx")
  dir.create(folder)
  expect_error(write_xlsx(df, folder), "is a folder")
})

test_that("arguments are checked before anything is written", {
  df <- data.frame(a = 1)
  p <- temp_xlsx()
  expect_error(write_xlsx(df, p, header = "label"), "`header` must be \"names\", \"labels\", \"both\" or FALSE.", fixed = TRUE)
  expect_error(write_xlsx(df, p, values = "code"), "`values` must be \"labels\" or \"codes\".", fixed = TRUE)
  expect_error(write_xlsx(df, p, freeze = "B2:C3"), "`freeze` must be TRUE, FALSE or a cell such as \"B2\".", fixed = TRUE)
  expect_error(write_xlsx(df, p, filter = NA), "`filter` must be TRUE or FALSE.", fixed = TRUE)
  expect_error(write_xlsx(df, p, gap = -1), "`gap` must be a number of blank rows", fixed = TRUE)
  expect_error(write_xlsx(df, p, na = NA), "`na` must be one string", fixed = TRUE)
  expect_error(write_xlsx(df, p, replace = "yes"), "`replace` must be TRUE or FALSE.", fixed = TRUE)
  expect_error(write_xlsx(df, p, header_style = list(bold = TRUE)), "`header_style` must be a style from `xl_style()`", fixed = TRUE)
  expect_error(write_xlsx(1:3, p), "`x` must be a data frame, or a named list of data frames.", fixed = TRUE)
  expect_false(file.exists(p))
})

test_that("zero rows write the header; zero columns an empty sheet", {
  path <- temp_xlsx()
  write_xlsx(data.frame(a = integer(), b = character()), path)
  back <- read_xlsx(path)
  expect_identical(names(back), c("a", "b"))
  expect_identical(nrow(back), 0L)
  path2 <- temp_xlsx()
  write_xlsx(data.frame(), path2)
  expect_identical(dim(read_xlsx(path2)), c(0L, 0L))
})

test_that("text in any encoding is written as UTF-8", {
  path <- temp_xlsx()
  s <- c("café", "日本", "naïve")
  latin <- iconv(s[[1]], "UTF-8", "latin1")
  write_xlsx(data.frame(s = c(s, latin)), path)
  expect_identical(read_xlsx(path)$s, c(s, s[[1]]))
})

test_that("text that is not valid in its encoding stops, naming the cells", {
  bad <- "caf\xe9"
  Encoding(bad) <- "UTF-8"
  err <- expect_error(write_xlsx(data.frame(s = c("ok", bad)), temp_xlsx()), class = "rlang_error")
  expect_identical(first_line(err), "`s` has text that is not valid in its encoding: A3.")
})

test_that("a blank column name is a blank header cell", {
  df <- data.frame(a = 1:2, b = 3:4)
  names(df) <- c("a", "")
  path <- temp_xlsx()
  write_xlsx(df, path, formats = c(a = "0.0"))
  grid <- read_xlsx(path, header = FALSE, types = "text")
  expect_identical(grid$A, c("a", "1", "2"))
  expect_identical(grid$B, c(NA, "3", "4"))
})
