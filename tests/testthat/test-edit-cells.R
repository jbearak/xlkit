template <- function() temp_copy(xlkit_example("template.xlsx"))

test_that("write_cells() writes values that keep their cells' formats", {
  path <- template()
  expect_identical(write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31")), path)
  cover <- read_xlsx(path, sheet = "Cover", header = FALSE)
  expect_identical(cover$C[3], "1250")
  df <- read_xlsx(path, sheet = "Cover", range = "C5:C5", header = FALSE)
  expect_identical(df[[1]], as.Date("2024-12-31"))

  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  c4 <- xl_cell(seen, "C4", "Cover")
  expect_identical(c4$value, "1250")
  expect_identical(c4$format, "#,##0")
  expect_identical(c4$fill, "DDEBF7")
  expect_identical(c4$top, "'thin'")
  c5 <- xl_cell(seen, "C5", "Cover")
  expect_identical(c5$format, "d mmm yyyy")
  expect_identical(c5$value, "2024-12-31 00:00:00")
})

test_that("a date in a cell whose format shows no date gets yyyy-mm-dd and keeps the rest", {
  path <- template()
  write_cells(path, "Cover", C4 = as.Date("2024-03-01"), D4 = as.POSIXct("2024-03-01 08:30:00", tz = "UTC"),
              D5 = hms::hms(3600 * 30))
  expect_identical(read_xlsx(path, "Cover", range = "C4:C4", header = FALSE)[[1]], as.Date("2024-03-01"))
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  c4 <- xl_cell(seen, "C4", "Cover")
  expect_identical(c4$format, "yyyy-mm-dd")
  expect_identical(c4$fill, "DDEBF7")
  expect_identical(c4[c("top", "right", "bottom", "left")], list(top = "'thin'", right = "'thin'", bottom = "'thin'", left = "'thin'"))
  expect_identical(xl_cell(seen, "D4", "Cover")$format, "yyyy-mm-dd hh:mm:ss")
  expect_identical(xl_cell(seen, "D5", "Cover")$format, "[h]:mm:ss")
  # The font of a formatted cell is kept too.
  path <- temp_copy(fixture("features.xlsx"))
  write_cells(path, "Report", B4 = as.Date("2024-06-30"))
  b4 <- xl_cell(openpyxl(path), "B4", "Report")
  expect_identical(b4$format, "yyyy-mm-dd")
  expect_true(b4$italic)
  expect_identical(b4$color, "C00000")
  expect_identical(b4$fill, "FFF2CC")
  expect_identical(b4$top, "'thin'")
})

test_that("vectors, matrices, data frames, formulas and NA", {
  path <- template()
  m <- matrix(1:4, 2, dimnames = list(c("a", "b"), c("x", "y")))
  write_cells(path, "Cover",
              E2 = c(1.5, 2.5, 3.5),
              G2 = m,
              G6 = unname(m),
              E8 = data.frame(id = 1:2, name = c("Ana", "Ben")),
              F2 = xl_formula("SUM(E2:E4)"),
              C4 = NA)
  got <- read_xlsx(path, "Cover", range = "E2:E4", header = FALSE)
  expect_identical(got[[1]], c(1.5, 2.5, 3.5))
  block <- quietly(read_xlsx(path, "Cover", range = "G2:I4"))
  expect_identical(block$x, 1:2)
  expect_identical(block[[1]], c("a", "b"))
  expect_identical(unname(as.matrix(read_xlsx(path, "Cover", range = "G6:H7", header = FALSE))), unname(m))
  expect_identical(bare(read_xlsx(path, "Cover", range = "E8:F10")), tibble::tibble(id = 1:2, name = c("Ana", "Ben")))
  expect_identical(read_xlsx(path, "Cover", range = "B4:C4", header = FALSE, types = "text")$C, NA_character_)

  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(xl_cell(seen, "F2", "Cover")$value, "'=SUM(E2:E4)'")
  # NA empties the cell and keeps its format.
  c4 <- xl_cell(seen, "C4", "Cover")
  expect_identical(c4$value, "")
  expect_identical(c4$format, "#,##0")
  expect_identical(c4$fill, "DDEBF7")
})

test_that("styles and merge by range", {
  path <- template()
  write_cells(
    path, sheet = "Cover",
    B2 = "Results for 2024",
    styles = list(B2 = xl_style(bold = TRUE, size = 14), "B4:B5" = xl_style(italic = TRUE)),
    merge = "B2:F2"
  )
  expect_identical(read_xlsx(path, "Cover", range = "B2:B2", header = FALSE)[[1]], "Results for 2024")
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  b2 <- xl_cell(seen, "B2", "Cover")
  expect_true(b2$bold)
  expect_identical(b2$size, "14.0")
  # B2's own color stays: a style changes only what it sets.
  expect_identical(b2$color, "1F4E79")
  expect_identical(seen$merged$range[seen$merged$sheet == "Cover"], "B2:F2")
  b4 <- xl_cell(seen, "B4", "Cover")
  expect_true(b4$italic)
  expect_true(b4$bold)
  expect_identical(b4$value, "'Total'")
})

test_that("the workbook recalculates its formulas when opened", {
  path <- temp_copy(fixture("features.xlsx"))
  write_cells(path, "Data", B2 = 1000)
  wb <- part_text(zip_parts(path), "xl/workbook.xml")
  expect_match(wb, "<calcPr [^>]*fullCalcOnLoad=\"1\"")
})

test_that("a sheet or a file that does not exist is made", {
  path <- template()
  write_cells(path, "Extra", A1 = "new")
  expect_identical(xlsx_sheets(path), c("Cover", "Chart", "Data", "Extra"))
  expect_identical(read_xlsx(path, "Extra", header = FALSE)[[1]], "new")
  path <- temp_xlsx("made.xlsx")
  write_cells(path, "Totals", B2 = 3)
  expect_identical(xlsx_sheets(path), "Totals")
  expect_identical(read_xlsx(path, header = FALSE)[[1]], 3L)
})

test_that("writing into an Excel table's body grows it", {
  path <- temp_copy(fixture("features.xlsx"))
  write_cells(path, "Data", A13 = c("Dec", "Jan", "Feb"), B13 = c(130, 140, 150))
  table <- part_text(zip_parts(path), "xl/tables/table1.xml")
  expect_match(table, 'ref="A1:B15"')
  expect_identical(nrow(read_xlsx(path, range = "Sales")), 14L)
})

test_that("a vector's values are checked as write_xlsx() checks them", {
  path <- template()
  expect_snapshot(error = TRUE, {
    write_cells(path, "Cover", C4 = as.Date("1850-01-01"))
    write_cells(path, "Cover", 1250)
    write_cells(path, "Cover", "C4:C5" = 1)
    write_cells(path, "Cover", C4 = list(1, 2))
    write_cells(path, "Cover", styles = list(region = xl_style(bold = TRUE)))
  })
  expect_warning(write_cells(path, "Cover", C4 = NaN), "NaN or Inf")
})
