# Values checked against readxl, an independent reader, on the example
# workbooks, where the two agree by design. Where they differ by design
# (integer columns, Date rather than POSIXct, zero-padded text, Excel
# errors) the comparison converts or leaves the column out.

skip_if_not_installed("readxl")

rx <- function(...) suppressWarnings(suppressMessages(readxl::read_excel(...)))

same_values <- function(ours, theirs) {
  expect_identical(names(ours), names(theirs))
  for (col in names(ours)) {
    a <- ours[[col]]
    b <- theirs[[col]]
    if (inherits(a, "Date")) b <- as.Date(b)
    if (inherits(a, "hms")) b <- as.numeric(b) %% 86400
    if (is.integer(a) || inherits(a, "hms")) a <- as.numeric(a)
    attr(a, "label") <- NULL
    attributes(b) <- attributes(a)
    expect_equal(a, b, label = col, tolerance = 1e-9)
  }
}

test_that("report.xlsx reads as readxl reads it", {
  path <- xlkit_example("report.xlsx")
  same_values(read_xlsx(path), rx(path))
})

test_that("every sheet of sales.xlsx reads as readxl reads it", {
  path <- xlkit_example("sales.xlsx")
  for (sheet in c("Summary", "Regions", "Notes")) {
    same_values(read_xlsx(path, sheet = sheet), rx(path, sheet = sheet))
  }
  for (sheet in c("Sales 2023", "Sales 2024")) {
    ours <- read_xlsx(path, sheet = sheet, range = "B5:F40")
    same_values(ours, rx(path, sheet = sheet, range = "B5:F40"))
    # readxl's skip counts from the first row with data, row 1 here.
    same_values(read_xlsx(path, sheet = sheet, header = 5), rx(path, sheet = sheet, skip = 4))
  }
})

test_that("dates.xlsx and dates1904.xlsx read as readxl reads them", {
  for (name in c("dates.xlsx", "dates1904.xlsx")) {
    path <- xlkit_example(name)
    same_values(read_xlsx(path), rx(path))
  }
})

test_that("messy.xlsx reads as readxl reads it", {
  path <- xlkit_example("messy.xlsx")
  two <- read_xlsx(path, sheet = "Two-row header", header = 4:5)
  theirs <- rx(path, sheet = "Two-row header", range = "A6:D9", col_names = names(two))
  same_values(two, theirs)

  types <- read_xlsx(path, sheet = "Types", types = c(amount = "number")) |> suppressWarnings()
  theirs <- rx(path, sheet = "Types", col_types = c("numeric", "numeric", "numeric"))
  same_values(types, theirs)

  missing <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-")) |> suppressWarnings()
  theirs <- rx(path, sheet = "Missing", na = c("NA", ".", "-"), col_types = c("numeric", "text", "numeric", "numeric"))
  same_values(missing, theirs)

  headers <- read_xlsx(path, sheet = "Headers", header = FALSE)
  theirs <- rx(path, sheet = "Headers", col_names = FALSE, col_types = "text")
  names(theirs) <- names(headers)
  expect_identical(
    lapply(headers, function(x) ifelse(is.na(x), NA, as.character(x))),
    lapply(as.list(theirs), function(x) ifelse(is.na(x), NA, x))
  )
})

test_that("edge cases agree with readxl where both read numbers", {
  path <- fixture("edge.xlsx")
  ours <- read_xlsx(path, sheet = "Formats", dates = FALSE)
  theirs <- rx(path, sheet = "Formats", col_types = "numeric")
  same_values(ours, theirs)
  # Day 60 of the 1900 system: readxl also has no date for it.
  early <- read_xlsx(path, sheet = "Early") |> suppressWarnings()
  theirs <- rx(path, sheet = "Early")
  expect_identical(early$day[-3], as.Date(theirs$day)[-3])
})
