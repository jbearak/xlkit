# Cases from the first review of write_sheet() and write_cells().

test_that("dates follow the workbook's 1904 date system in every edit mode", {
  day <- as.Date("2024-01-01")
  path <- temp_copy(fixture("edge1904.xlsx"))
  write_cells(path, "Early", C1 = day)
  expect_identical(read_xlsx(path, "Early", range = "C1:C1", header = FALSE)[[1]], day)
  write_sheet(data.frame(d = day), path, sheet = "Early", at = "E1")
  expect_identical(read_xlsx(path, "Early", range = "E1:E2")$d, day)
  write_sheet(data.frame(d = day, t = as.POSIXct("2024-01-01 12:00:00", tz = "UTC")), path, sheet = "Added")
  added <- read_xlsx(path, "Added")
  expect_identical(added$d, day)
  expect_equal(added$t, as.POSIXct("2024-01-01 12:00:00", tz = "UTC"))
  write_sheet(data.frame(d = day), path, sheet = "Early")
  expect_identical(read_xlsx(path, "Early")$d, day)
  expect_snapshot(error = TRUE, write_cells(path, "Early", C1 = as.Date("1903-12-31")))
})

test_that("a cell with no style of its own keeps its column's and row's format when restyled", {
  skip_if_no_openpyxl()
  path <- temp_copy(fixture("inherited.xlsx"))
  write_cells(path, "Sheet1", A1 = as.Date("2024-01-01"), B3 = 8, styles = list(B3 = xl_style(underline = TRUE)))
  seen <- openpyxl(path)
  a1 <- xl_cell(seen, "A1", "Sheet1")
  expect_identical(a1$format, "yyyy-mm-dd")
  expect_true(a1$italic)
  expect_identical(a1$fill, "FFFF00")
  b3 <- xl_cell(seen, "B3", "Sheet1")
  expect_true(b3$bold)
  expect_identical(b3$underline, "'single'")
})

test_that("a style alone does not let a merge hide a cell's value", {
  path <- temp_copy(fixture("features.xlsx"))
  expect_error(
    write_cells(path, "Report", styles = list(B3 = xl_style(bold = TRUE)), merge = "A3:B3"),
    "would hide the value in B3"
  )
  expect_error(write_cells(path, "Report", merge = list("A3:B3" = xl_style(bold = TRUE))), "would hide the value in B3")
})
