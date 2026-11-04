# ADR 0006: every part a write may not change is byte-identical, and in
# each worksheet written, every byte outside the cells written is too.

# The parts a write may change, as ADR 0006 lists them.
may_change <- function(sheet_parts, extra = character()) {
  c(sheet_parts, "xl/styles.xml", "xl/workbook.xml", extra)
}

expect_kept <- function(before, after, allowed, sheets = list()) {
  changed <- changed_parts(before, after)
  expect_true(all(changed %in% allowed), info = paste(setdiff(changed, allowed), collapse = ", "))
  for (part in names(sheets)) {
    expect_identical(
      outside_cells(part_text(after, part), sheets[[part]]),
      outside_cells(part_text(before, part), sheets[[part]])
    )
  }
}

test_that("write_cells() keeps every other byte of the template", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  before <- zip_parts(path)
  write_cells(path, "Cover", C4 = 1250, C5 = as.Date("2024-12-31"), E7 = "note", A9 = c(1, 2, 3))
  after <- zip_parts(path)
  expect_kept(before, after, may_change("xl/worksheets/sheet1.xml"),
              list("xl/worksheets/sheet1.xml" = c("C4", "C5", "E7", "A9", "A10", "A11")))
})

test_that("write_sheet() keeps every part but the sheet, styles and workbook", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  before <- zip_parts(path)
  write_sheet(data.frame(month = month.abb, value = 1:12), path, sheet = "Data")
  after <- zip_parts(path)
  expect_kept(before, after, may_change("xl/worksheets/sheet2.xml"))
  # Outside <sheetData> and <dimension>, the sheet is byte-identical.
  strip <- function(x) sub("<sheetData>.*</sheetData>", "", sub("<dimension [^>]*/>", "", x))
  expect_identical(strip(part_text(after, "xl/worksheets/sheet2.xml")),
                   strip(part_text(before, "xl/worksheets/sheet2.xml")))
})

for (file in c("features.xlsx", "features.xlsm")) {
  test_that(paste("comments, conditional formats, validation, names, images and charts stay in", file), {
    path <- temp_copy(fixture(file))
    before <- zip_parts(path)
    write_cells(path, "Report", B4 = 99.5, B5 = "Yes", C3 = as.Date("2024-01-31"),
                styles = list(C3 = xl_style(bold = TRUE)))
    after <- zip_parts(path)
    expect_kept(before, after, may_change("xl/worksheets/sheet1.xml"),
                list("xl/worksheets/sheet1.xml" = c("B4", "B5", "C3")))
    # The part every edit changes in the workbook part is its calcPr.
    strip <- function(x) gsub("<calcPr[^>]*/>", "", x)
    expect_identical(strip(part_text(after, "xl/workbook.xml")), strip(part_text(before, "xl/workbook.xml")))
    # Styles are only appended to.
    old <- part_text(before, "xl/styles.xml")
    new <- part_text(after, "xl/styles.xml")
    drop_counts <- function(x) gsub(' count="[0-9]+"', "", gsub("<numFmts[^>]*/>|<numFmts.*?</numFmts>", "", x, perl = TRUE))
    expect_true(nchar(new) > nchar(old))
    pieces <- strsplit(drop_counts(old), "</(numFmts|fonts|fills|borders|cellXfs)>")[[1]]
    for (p in pieces) expect_true(grepl(p, drop_counts(new), fixed = TRUE))

    path <- temp_copy(fixture(file))
    before <- zip_parts(path)
    write_sheet(data.frame(x = 1:3, y = c("a", "b", "c")), path, sheet = "Data", at = "D20")
    after <- zip_parts(path)
    expect_kept(before, after, may_change("xl/worksheets/sheet2.xml"),
                list("xl/worksheets/sheet2.xml" = cells_of("D20:E23")))

    skip_if_no_openpyxl()
    seen <- openpyxl(path)
    expect_identical(nrow(seen$sheets), 2L)
  })
}

test_that("a value over a formula removes the calculation chain, which lists it", {
  path <- temp_copy(fixture("features.xlsx"))
  before <- zip_parts(path)
  write_cells(path, "Report", B3 = 1)
  after <- zip_parts(path)
  expect_false("xl/calcChain.xml" %in% names(after))
  expect_kept(before, after, may_change("xl/worksheets/sheet1.xml",
                                        c("xl/calcChain.xml", "xl/_rels/workbook.xml.rels", "[Content_Types].xml")),
              list("xl/worksheets/sheet1.xml" = "B3"))
  # A write that overwrites no formula keeps it.
  path <- temp_copy(fixture("features.xlsx"))
  write_cells(path, "Report", B4 = 1)
  expect_true("xl/calcChain.xml" %in% names(zip_parts(path)))
})

test_that("unchanged parts keep their compressed bytes too", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  before <- utils::unzip(path, list = TRUE)
  write_cells(path, "Cover", C4 = 1)
  after <- utils::unzip(path, list = TRUE)
  expect_identical(after$Name, before$Name)
  kept <- !after$Name %in% c("xl/worksheets/sheet1.xml", "xl/styles.xml", "xl/workbook.xml")
  expect_identical(after$Length[kept], before$Length[kept])
  expect_identical(after$Date[kept], before$Date[kept])
})

test_that("the results open in readxl", {
  skip_if_not_installed("readxl")
  path <- temp_copy(xlkit_example("template.xlsx"))
  write_cells(path, "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
  write_sheet(data.frame(month = month.abb, value = 1:12), path, sheet = "Data")
  write_sheet(data.frame(a = 1:2), path, sheet = "New", after = "Cover")
  expect_identical(readxl::excel_sheets(path), c("Cover", "New", "Chart", "Data"))
  cover <- quietly(readxl::read_excel(path, sheet = "Cover", col_names = FALSE, .name_repair = "minimal"))
  expect_identical(cover[[2]][[3]], 1250)
  c5 <- readxl::read_excel(path, sheet = "Cover", range = "C5", col_names = FALSE, .name_repair = "minimal")
  expect_identical(as.Date(c5[[1]]), as.Date("2024-12-31"))
  expect_identical(readxl::read_excel(path, sheet = "Data")$value, as.double(1:12))
  expect_identical(readxl::read_excel(path, sheet = "New")$a, c(1, 2))
})
