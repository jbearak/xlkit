template <- function() temp_copy(xlkit_example("template.xlsx"))
months <- data.frame(month = month.abb, value = seq(10, 120, by = 10))

test_that("write_sheet() replaces a sheet's cells and keeps the sheet", {
  path <- template()
  before <- zip_parts(path)
  write_sheet(months, path, sheet = "Data")
  expect_identical(xlsx_sheets(path), c("Cover", "Chart", "Data"))
  expect_identical(bare(read_xlsx(path, sheet = "Data")), tibble::as_tibble(transform(months, value = as.integer(value))))
  after <- zip_parts(path)
  # The chart sheet's chart still plots Data, byte for byte.
  expect_identical(after[["xl/charts/chart1.xml"]], before[["xl/charts/chart1.xml"]])
  expect_match(part_text(after, "xl/charts/chart1.xml"), "'Data'!\\$B\\$2:\\$B\\$13")
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(seen$sheets$freeze[seen$sheets$name == "Data"], "'A2'")
  expect_true(xl_cell(seen, "A1", "Data")$bold)
})

test_that("the cells, formats and merged ranges of the old sheet go", {
  path <- temp_copy(fixture("features.xlsx"))
  write_sheet(data.frame(a = 1), path, sheet = "Report")
  sheet <- part_text(zip_parts(path), "xl/worksheets/sheet1.xml")
  expect_false(grepl("mergeCell", sheet))
  expect_false(grepl("B4", sheet))
  expect_match(sheet, '<dimension ref="A1:A2"')
  # The formula is gone, and so is the calculation chain that listed it.
  parts <- zip_parts(path)
  expect_false("xl/calcChain.xml" %in% names(parts))
  expect_false(grepl("calcChain", part_text(parts, "xl/_rels/workbook.xml.rels")))
  expect_false(grepl("calcChain", part_text(parts, "[Content_Types].xml")))
  # The conditional format, data validation and comment stay.
  expect_match(sheet, "<conditionalFormatting")
  expect_match(sheet, "<dataValidations")
  expect_true("xl/comments/comment1.xml" %in% names(parts))
})

test_that("`at` writes only the cells the table covers", {
  path <- template()
  before <- zip_parts(path)
  write_sheet(head(mtcars[, 1:3], 3), path, sheet = "Data", at = "H2")
  got <- read_xlsx(path, sheet = "Data", range = "H2:J5")
  expect_identical(names(got), c("mpg", "cyl", "disp"))
  expect_identical(got$mpg, c(21, 21, 22.8))
  expect_identical(read_xlsx(path, sheet = "Data", range = "A1:B13")$value[1:2], c(114L, 151L))
  old <- outside_cells(part_text(before, "xl/worksheets/sheet2.xml"), cells_of("H2:J5"))
  new <- outside_cells(part_text(zip_parts(path), "xl/worksheets/sheet2.xml"), cells_of("H2:J5"))
  expect_identical(new, old)
  # With `at`, the header keeps its cells' formats: not bold.
  skip_if_no_openpyxl()
  expect_false(xl_cell(openpyxl(path), "H2", "Data")$bold)
})

test_that("a new sheet goes after the last tab, or after `after`", {
  path <- template()
  write_sheet(months, path, sheet = "Last")
  write_sheet(months, path, sheet = "Second", after = "Cover")
  expect_identical(xlsx_sheets(path), c("Cover", "Second", "Chart", "Data", "Last"))
  expect_identical(nrow(read_xlsx(path, sheet = "Second")), 12L)
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(seen$sheets$freeze[seen$sheets$name == "Second"], "'A2'")
  expect_true(xl_cell(seen, "A1", "Second")$bold)
  expect_true(any(seen$widths$sheet == "Second"))
  expect_snapshot(error = TRUE, write_sheet(months, path, sheet = "Third", after = "Cuver"))
})

test_that("a print area moves with its sheet when a sheet is put before it", {
  path <- temp_copy(fixture("features.xlsx"))
  write_sheet(months, path, sheet = "First", after = NULL)
  write_sheet(months, path, sheet = "Zero", after = "Report")
  wb <- part_text(zip_parts(path), "xl/workbook.xml")
  # The print area of Report (sheet 0) stays 0; nothing came before it.
  expect_match(wb, 'localSheetId="0"')
  path <- temp_copy(fixture("features.xlsx"))
  write_cells(path, "Before", A1 = 1)
  wb <- part_text(zip_parts(path), "xl/workbook.xml")
  expect_match(wb, 'localSheetId="0"')
})

test_that("a file that does not exist becomes a new workbook, as write_xlsx() makes it", {
  path <- temp_xlsx("fresh.xlsx")
  write_sheet(months, path, sheet = "Data")
  other <- temp_xlsx("other.xlsx")
  write_xlsx(months, other, sheet = "Data")
  expect_identical(read_xlsx(path), read_xlsx(other))
  skip_if_no_openpyxl()
  expect_identical(openpyxl(path), openpyxl(other))
})

test_that("a chart over a fixed range is named when the rows no longer match", {
  path <- template()
  expect_snapshot(write_sheet(months[1:5, ], path, sheet = "Data"))
  expect_silent(write_sheet(months, path, sheet = "Data"))
})

test_that("writing a table at an Excel table's top-left cell resizes it", {
  path <- temp_copy(fixture("features.xlsx"))
  df <- data.frame(Month = c(month.abb, month.abb[1:8]), Sales = 1:20, Units = 21:40)
  write_sheet(df, path, sheet = "Data", at = "A1")
  parts <- zip_parts(path)
  table <- part_text(parts, "xl/tables/table1.xml")
  expect_match(table, 'ref="A1:C21"')
  expect_match(table, '<autoFilter ref="A1:C21"')
  expect_match(table, '<tableColumns count="3"><tableColumn id="1" name="Month" ?/><tableColumn id="2" name="Sales" ?/><tableColumn id="3" name="Units"/></tableColumns>')
  # The chart that plots the table's columns follows it.
  chart <- part_text(parts, "xl/charts/chart1.xml")
  expect_match(chart, "'Data'!\\$B\\$2:\\$B\\$21")
  expect_match(chart, "'Data'!\\$A\\$2:\\$A\\$21")
  expect_identical(bare(read_xlsx(path, range = "Sales")), tibble::as_tibble(df))
  # A smaller table clears the rows the old one had.
  write_sheet(df[1:3, 1:2], path, sheet = "Data", at = "A1")
  expect_match(part_text(zip_parts(path), "xl/tables/table1.xml"), 'ref="A1:B4"')
  expect_identical(nrow(read_xlsx(path, range = "Sales")), 3L)
  expect_error(read_xlsx(path, sheet = "Data", range = "A5:C21"), "lies outside")
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(nrow(seen$sheets), 2L)
})
