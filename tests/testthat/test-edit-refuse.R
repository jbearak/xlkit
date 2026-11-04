# What write_sheet() and write_cells() refuse, leaving the file as it was.

expect_untouched <- function(path, expr) {
  before <- readBin(path, "raw", file.size(path))
  expect_error(expr)
  expect_identical(readBin(path, "raw", file.size(path)), before)
  expect_identical(list.files(dirname(path)), basename(path))
}

test_that("other formats and password-protected files are refused", {
  xls <- temp_file("old.xls", bytes = as.raw(c(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1)))
  locked <- temp_file("locked.xlsx", bytes = as.raw(c(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1)))
  expect_snapshot(error = TRUE, {
    write_cells(xls, "Sheet1", A1 = 1)
    write_sheet(data.frame(a = 1), sub("xls$", "xlsb", xls), "Sheet1")
    write_cells(locked, "Sheet1", A1 = 1)
    write_cells(sub("locked", "notes", sub("xlsx$", "txt", locked)), "Sheet1", A1 = 1)
  })
  expect_untouched(locked, write_cells(locked, "Sheet1", A1 = 1))
})

test_that("worksheet XML that cannot be edited safely is refused", {
  path <- temp_copy(fixture("unsafe.xlsx"))
  expect_snapshot(error = TRUE, write_cells(path, "Sheet1", A1 = 2))
  expect_untouched(path, write_cells(path, "Sheet1", A1 = 2))
})

test_that("a merged range's other cells and a table's header are refused", {
  path <- temp_copy(fixture("features.xlsx"))
  expect_snapshot(error = TRUE, {
    write_cells(path, "Report", B1 = "x")
    write_cells(path, "Data", B1 = "Amount")
    write_sheet(data.frame(a = 1), path, sheet = "Data", at = "B1")
    write_cells(path, "Report", merge = "A3:B3")
    write_cells(path, "Report", merge = "C1:E1")
  })
  expect_untouched(path, write_cells(path, "Report", B1 = "x"))
  expect_untouched(path, write_cells(path, "Data", B1 = "Amount"))
  # The top-left cell of a merged range is written.
  write_cells(path, "Report", A1 = "Annual report")
  expect_identical(read_xlsx(path, "Report", range = "A1:A1", header = FALSE)[[1]], "Annual report")
  # Without `at`, a table at A1 is resized to the new data.
  write_sheet(data.frame(a = 1), path, sheet = "Data")
  expect_match(part_text(zip_parts(path), "xl/tables/table1.xml"), 'ref="A1:A2"')
})

test_that("write_sheet() without `at` will not clear a table that is not at A1", {
  path <- temp_copy(fixture("features.xlsx"))
  write_sheet(data.frame(month = "Jan", value = 1), path, sheet = "Data", at = "D20")
  write_sheet(data.frame(x = 1:3), path, sheet = "Moved")
  # Move the table by writing a sheet whose table starts lower: make one.
  path <- temp_copy(fixture("review.xlsx"))
  expect_snapshot(error = TRUE, write_sheet(data.frame(a = 1), path, sheet = "Tables"))
})

test_that("chart sheets are not written", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  expect_snapshot(error = TRUE, write_cells(path, "Chart", A1 = 1))
})

test_that("a sheet name Excel does not allow stops before anything is written", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  expect_snapshot(error = TRUE, write_sheet(data.frame(a = 1), path, sheet = "Q1/Q2"))
})
