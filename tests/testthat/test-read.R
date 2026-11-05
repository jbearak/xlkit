# docs/r.md, "Read a sheet" and "The example workbooks".

test_that("xlkit_example() lists and finds the example workbooks", {
  expect_identical(
    xlkit_example(),
    c("births.xlsx", "dates.xlsx", "dates1904.xlsx", "messy.xlsx", "report.xlsx", "template.xlsx")
  )
  expect_true(file.exists(xlkit_example("report.xlsx")))
  expect_error(xlkit_example("reprot.xlsx"), "has no example workbook \"reprot.xlsx\"")
  expect_error(xlkit_example("reprot.xlsx"), "Did you mean \"report.xlsx\"")
})

test_that("the example workbooks hold what the docs say", {
  expect_identical(xlsx_sheets(xlkit_example("report.xlsx")), "Scores")
  expect_identical(
    xlsx_sheets(xlkit_example("births.xlsx")),
    c("Summary", "Births 2023", "Births 2024", "Regions", "Notes")
  )
  expect_identical(
    xlsx_sheets(xlkit_example("messy.xlsx")),
    c("Headers", "Two-row header", "Types", "Missing")
  )
  expect_identical(xlsx_sheets(xlkit_example("template.xlsx")), c("Cover", "Chart", "Data"))
  expect_identical(xlsx_sheets(xlkit_example("dates1904.xlsx")), xlsx_sheets(xlkit_example("dates.xlsx")))
  cover <- read_xlsx(xlkit_example("template.xlsx"), sheet = "Cover", range = "B2:C5", header = FALSE)
  expect_identical(cover$B, c("Monthly report", NA, "Total", "As of"))
  data <- read_xlsx(xlkit_example("template.xlsx"), sheet = "Data")
  expect_identical(dim(data), c(12L, 2L))
})

test_that("read_xlsx() reads the first sheet with its types", {
  scores <- read_xlsx(xlkit_example("report.xlsx"))
  expect_s3_class(scores, "tbl_df")
  expect_identical(names(scores), c("id", "name", "score", "passed", "joined"))
  expect_identical(scores$id, 1:4)
  expect_identical(scores$name, c("Ana", "Ben", "Chen", "Dee"))
  expect_identical(scores$score, c(91.5, 78, 85.2, NA))
  expect_identical(scores$passed, c(TRUE, FALSE, TRUE, NA))
  expect_identical(scores$joined, as.Date(c("2024-01-15", "2024-02-03", "2024-02-20", "2024-03-01")))
  expect_identical(nrow(xlsx_problems(scores)), 0L)
})

test_that("a path that does not exist names a similar file", {
  dir <- tempfile("xlkit-")
  dir.create(dir)
  file.copy(xlkit_example("report.xlsx"), file.path(dir, "report.xlsx"))
  old <- setwd(dir)
  on.exit(setwd(old))
  err <- expect_error(read_xlsx("reprot.xlsx"), class = "rlang_error")
  expect_identical(
    first_line(err),
    "reprot.xlsx does not exist."
  )
  expect_match(conditionMessage(err), "Did you mean report.xlsx?", fixed = TRUE)
  expect_identical(format(err$call), "read_xlsx(\"reprot.xlsx\")")
  expect_error(read_xlsx("nothing-like-it.xlsx"), "does not exist\\.$")
  expect_error(read_xlsx("no-folder/x.xlsx"), "Its folder, no-folder, does not exist either")
})

test_that("files that are not .xlsx workbooks say what they look like", {
  csv <- temp_file("data.xlsx", lines = c("a,b", "1,2"))
  expect_error(read_xlsx(csv), "data.xlsx is not an .xlsx workbook (it looks like text)", fixed = TRUE)
  expect_error(xlsx_sheets(csv), "it looks like text", fixed = TRUE)
  empty <- temp_file("empty.xlsx", bytes = raw())
  expect_error(read_xlsx(empty), "(it is empty)", fixed = TRUE)
  ole <- temp_file("old.xlsx", bytes = as.raw(c(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1)))
  expect_error(read_xlsx(ole), "looks like an .xls workbook", fixed = TRUE)
  pdf <- temp_file("doc.xlsx", bytes = charToRaw("%PDF-1.7\n"))
  expect_error(read_xlsx(pdf), "looks like a PDF", fixed = TRUE)
  binary <- temp_file("blob.xlsx", bytes = as.raw(c(0x00, 0x01, 0x02, 0xff)))
  expect_error(read_xlsx(binary), "not a zip archive", fixed = TRUE)
  # A zip archive that is not a workbook.
  zip <- temp_file("notes.xlsx", bytes = as.raw(c(0x50, 0x4b, 0x03, 0x04, rep(0, 26))))
  expect_error(read_xlsx(zip), "notes.xlsx is not an .xlsx workbook", fixed = TRUE)
  expect_error(read_xlsx(tempdir()), "is a folder")
  expect_error(read_xlsx(c("a", "b")), "`path` must be")
})

test_that("an empty sheet reads as a tibble with no rows and no columns", {
  empty <- read_xlsx(edge(), sheet = "Empty")
  expect_s3_class(empty, "tbl_df")
  expect_identical(dim(empty), c(0L, 0L))
  expect_identical(nrow(xlsx_problems(empty)), 0L)
})

test_that("arguments are checked", {
  path <- xlkit_example("report.xlsx")
  expect_error(read_xlsx(path, header = 0), "`header` must be")
  expect_error(read_xlsx(path, header = c(4, 6)), "consecutive rows")
  expect_error(read_xlsx(path, header = "yes"), "`header` must be")
  expect_error(read_xlsx(path, names = "camel"), "`names` must be")
  expect_error(read_xlsx(path, names = c("snake", "stata")), "`names` must be")
  expect_error(read_xlsx(path, na = NA), "`na` must be")
  expect_error(read_xlsx(path, dates = "no"), "`dates` must be TRUE or FALSE")
  expect_error(read_xlsx(path, sheet = 1.5), "`sheet` must be")
  expect_error(read_xlsx(path, sheet = c("a", "b")), "`sheet` must be")
})
