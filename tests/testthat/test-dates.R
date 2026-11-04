# docs/r.md, "Dates and times".

dates <- function() xlkit_example("dates.xlsx")

test_that("the number format decides Date, POSIXct in UTC, or hms", {
  df <- read_xlsx(dates())
  expect_s3_class(df$day, "Date")
  expect_identical(df$day, as.Date(c("2024-01-15", "2024-02-29", "2024-12-31")))
  expect_s3_class(df$stamp, "POSIXct")
  expect_identical(attr(df$stamp, "tzone"), "UTC")
  expect_identical(
    df$stamp,
    as.POSIXct(c("2024-01-15 08:30:00", "2024-02-29 17:05:30", "2024-12-31 23:59:59"), tz = "UTC")
  )
  expect_s3_class(df$clock, "hms")
  expect_identical(as.numeric(df$clock), c(8.5 * 3600, 17 * 3600 + 5 * 60 + 30, 86399))
})

test_that("date-times do not depend on the session's time zone", {
  old <- Sys.getenv("TZ", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("TZ") else Sys.setenv(TZ = old))
  Sys.setenv(TZ = "America/New_York")
  ny <- read_xlsx(dates())
  Sys.setenv(TZ = "Asia/Tokyo")
  tokyo <- read_xlsx(dates())
  expect_identical(ny, tokyo)
  expect_identical(format(ny$stamp[[1]]), "2024-01-15 08:30:00")
})

test_that("the 1904 date system is read from the workbook", {
  expect_identical(read_xlsx(xlkit_example("dates1904.xlsx")), read_xlsx(dates()))
  early <- read_xlsx(fixture("edge1904.xlsx"))
  expect_identical(early$day, as.Date(c("1904-01-01", "1904-01-02", "1904-03-01", "2024-01-15")))
})

test_that("Excel's 1900 leap-day bug: day 60 is NA with a warning, days around it are right", {
  w <- expect_warning(df <- read_xlsx(edge(), sheet = "Early"), class = "rlang_warning")
  expect_identical(
    first_line(w),
    "1 cell in `day` could not be read as dates and is NA:\nA4 (\"1900-02-29\")."
  )
  # Serials 1, 59, 60, 61 and 0.
  expect_identical(df$day, as.Date(c("1900-01-01", "1900-02-28", NA, "1900-03-01", "1899-12-31")))
  p <- xlsx_problems(df)
  expect_identical(p$cell, "A4")
  expect_identical(p$problem, "29 February 1900, a day that did not exist")
})

test_that("asking for numbers gives Excel's day count and the fraction of a day", {
  df <- read_xlsx(dates(), types = c(day = "number", clock = "number"))
  expect_identical(df$day, c(45306, 45351, 45657))
  expect_equal(df$clock, c(8.5, 17 + 5 / 60 + 30 / 3600, 23 + 59 / 60 + 59 / 3600) / 24)
  expect_s3_class(df$stamp, "POSIXct")
  expect_identical(read_xlsx(xlkit_example("dates1904.xlsx"), types = c(day = "number"))$day,
                   c(45306, 45351, 45657) - 1462)
})

test_that("dates = FALSE reads every date as its number", {
  df <- read_xlsx(dates(), dates = FALSE)
  expect_identical(df$day, c(45306L, 45351L, 45657L))
  expect_type(df$stamp, "double")
  expect_type(df$clock, "double")
  # Asking for a type still works.
  expect_identical(read_xlsx(dates(), dates = FALSE, types = c(day = "date"))$day, read_xlsx(dates())$day)
})

test_that("odd number formats are read as the docs say", {
  df <- read_xlsx(edge(), sheet = "Formats")
  expect_type(df$percent, "double")
  expect_s3_class(df$duration, "hms")
  expect_identical(as.numeric(df$duration), 36 * 3600)
  expect_type(df$red, "double")
  expect_s3_class(df$minsec, "hms")
  expect_identical(df$locale_date, as.Date("2024-01-15"))
  expect_type(df$thousands, "integer")
  expect_type(df$zip, "integer")
  expect_s3_class(df$ampm, "hms")
  expect_s3_class(df$dttm, "POSIXct")
  expect_type(df$quoted, "integer")
  expect_identical(df$daymonth, as.Date("2024-01-15"))
  expect_identical(df$builtin14, as.Date("2024-01-15"))
  expect_s3_class(df$elapsed_s, "hms")
  expect_type(df$escaped, "integer")
  expect_type(df$sci, "double")
})

test_that("a date typed as text stays text unless asked for", {
  df <- read_xlsx(edge(), sheet = "Text", types = c(date = "guess"))
  expect_type(df$date, "character")
  expect_identical(
    quietly(read_xlsx(edge(), sheet = "Text", types = c(date = "date")))$date[[1]],
    as.Date("2024-03-01")
  )
})

test_that("a column of dates with a stray text cell is text, with a message that suggests \"date\"", {
  msg <- expect_message(xlkit:::text_message(
    list(type = "date", cells = "A12", values = 11, values_text = "unknown", name = "day"),
    identity
  ))
  expect_identical(first_line(msg), "`day` is text because 1 of its 11 values is not a date:\nA12 (\"unknown\").")
  expect_match(conditionMessage(msg), "To read it as dates, use `types = c(day = \"date\")`; that cell becomes NA.", fixed = TRUE)
})
