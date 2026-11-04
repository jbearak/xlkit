# docs/r.md, "Choose a sheet and a range".

sales <- function() xlkit_example("sales.xlsx")

test_that("a sheet is chosen by name or by position", {
  by_name <- read_xlsx(sales(), sheet = "Regions")
  by_position <- read_xlsx(sales(), sheet = 4)
  expect_identical(by_name, by_position)
  expect_identical(names(by_name), c("region", "manager", "office"))
})

test_that("a sheet name that is not there stops with the names that are", {
  err <- expect_error(read_xlsx(sales(), sheet = "Sales 2042"), class = "rlang_error")
  expect_identical(first_line(err), "sales.xlsx has no sheet \"Sales 2042\".")
  msg <- conditionMessage(err)
  expect_match(msg, "Did you mean \"Sales 2024\"?", fixed = TRUE)
  expect_match(msg, "Its sheets are \"Summary\", \"Sales 2023\", \"Sales 2024\", \"Regions\" and \"Notes\".", fixed = TRUE)
  expect_error(read_xlsx(sales(), sheet = 9), "sales.xlsx has 5 sheets, so there is no sheet 9.", fixed = TRUE)
  expect_error(read_xlsx(sales(), sheet = "zzzzzzzz"), "has no sheet \"zzzzzzzz\"")
})

test_that("chart sheets are listed, and reading one is an error", {
  path <- xlkit_example("template.xlsx")
  expect_true("Chart" %in% xlsx_sheets(path))
  expect_error(
    read_xlsx(path, sheet = "Chart"),
    "Sheet \"Chart\" of template.xlsx is a chart sheet, and xlkit reads only worksheets.",
    fixed = TRUE
  )
  expect_error(read_xlsx(path, sheet = 2), "Its worksheets are \"Cover\" and \"Data\"", fixed = TRUE)
})

test_that("a range is read as Excel shows it, and header = 5 reads the same table", {
  t1 <- read_xlsx(sales(), sheet = "Sales 2024", range = "B5:F40")
  expect_identical(dim(t1), c(35L, 5L))
  expect_identical(names(t1), c("region", "product", "units", "amount", "share"))
  expect_type(t1$units, "integer")
  expect_type(t1$amount, "double")
  expect_identical(t1, read_xlsx(sales(), sheet = "Sales 2024", header = 5))
  expect_identical(t1, read_xlsx(sales(), sheet = 3, range = "B5:F40"))
  expect_identical(t1, read_xlsx(sales(), range = "'Sales 2024'!B5:F40"))
  expect_identical(t1, read_xlsx(sales(), sheet = "Sales 2024", range = "B5"))
  expect_identical(t1, read_xlsx(sales(), sheet = "Sales 2024", range = "B5:F"))
  expect_identical(t1, read_xlsx(sales(), sheet = "Sales 2024", range = "$B$5:$F$40"))
  expect_identical(t1, read_xlsx(sales(), sheet = "Sales 2024", range = "F40:B5"))
  # An Excel table by name, from any sheet.
  expect_identical(t1, read_xlsx(sales(), range = "SalesTable"))
  expect_identical(t1, read_xlsx(sales(), sheet = "Notes", range = "salestable"))
})

test_that("a defined name reads its range", {
  regions <- read_xlsx(sales(), range = "RegionList")
  expect_identical(regions, read_xlsx(sales(), sheet = "Regions"))
  expect_identical(
    read_xlsx(edge(), range = "Block"),
    read_xlsx(edge(), sheet = "Ranges", range = "B3:D8")
  )
  expect_error(read_xlsx(sales(), range = "SalesTabel"), "has no Excel table or defined name \"SalesTabel\"")
  expect_error(read_xlsx(sales(), range = "SalesTabel"), "Did you mean \"SalesTable\"")
})

test_that("each form of range covers the cells the docs say", {
  # Ranges: a header in B3:D3, numbers B4:B8, text C4:C8, D4:D8 but D6,
  # and a stray "stray" in F10.
  read <- function(...) quietly(read_xlsx(edge(), sheet = "Ranges", ...))
  exact <- read(range = "B3:D12")
  expect_identical(dim(exact), c(9L, 3L))
  expect_identical(exact$a, c(4:8, NA, NA, NA, NA))
  corner <- read(range = "B3")
  expect_identical(names(corner), c("a", "b", "c", "E", "F"))
  expect_identical(nrow(corner), 7L)
  expect_identical(corner$F[[7]], "stray")
  open_bottom <- read(range = "B3:D")
  expect_identical(dim(open_bottom), c(5L, 3L))
  columns <- read(range = "B:D")
  expect_identical(columns, open_bottom)
  rows <- read(range = "3:8")
  expect_identical(rows, open_bottom)
  rows_with_stray <- read(range = "3:10")
  expect_identical(names(rows_with_stray), c("a", "b", "c", "E", "F"))
  expect_identical(read(range = "C5:C6", header = FALSE)$C, c("r5", "r6"))
})

test_that("ranges outside the sheet or past Excel's limits stop and say which", {
  ranges <- function(r) read_xlsx(edge(), sheet = "Ranges", range = r)
  expect_error(ranges("H1:K4"), "`range = \"H1:K4\"` lies outside the cells of sheet \"Ranges\", which hold data in B3:F10.", fixed = TRUE)
  expect_error(ranges("A1:B1048577"), "goes past Excel's last row, 1,048,576.", fixed = TRUE)
  expect_error(ranges("A1:XFE2"), "goes past Excel's last column, XFD.", fixed = TRUE)
  expect_error(ranges("XFE1"), "goes past Excel's last column, XFD.", fixed = TRUE)
  expect_error(ranges("A0:B2"), "has row 0", fixed = TRUE)
  expect_error(ranges("B5:F40:G"), "is not a range xlkit knows", fixed = TRUE)
  expect_error(ranges("B-5"), "is not a range xlkit knows", fixed = TRUE)
  expect_error(read_xlsx(edge(), sheet = "Empty", range = "A1:B2"), "sheet \"Empty\", which is empty", fixed = TRUE)
  expect_error(ranges(c("A1", "B2")), "`range` must be one string")
})

test_that("header rows must lie in the range", {
  expect_error(
    read_xlsx(sales(), sheet = "Sales 2024", range = "B5:F40", header = 3),
    "`header = 3` is outside `range = \"B5:F40\"`, which covers rows 5 to 40.", fixed = TRUE
  )
  t <- read_xlsx(sales(), sheet = "Sales 2024", range = "B4:F40", header = 5)
  expect_identical(names(t), c("region", "product", "units", "amount", "share"))
  expect_identical(nrow(t), 35L)
})

test_that("a header row below the data stops and names the last row with data", {
  expect_error(
    read_xlsx(sales(), sheet = "Sales 2024", header = 50),
    "`header = 50`, but the last row with data in sheet \"Sales 2024\" is 40.", fixed = TRUE
  )
  expect_error(read_xlsx(sales(), sheet = "Sales 2024", header = 50), "Its data is in B1:F40.", fixed = TRUE)
  expect_error(
    read_xlsx(sales(), sheet = "Sales 2024", range = "B:F", header = 41:42),
    "`header = 41:42`, but the last row with data in `range = \"B:F\"` is 40.", fixed = TRUE
  )
  # The last row with data is still a header, with no rows below it.
  last <- read_xlsx(sales(), sheet = "Sales 2024", header = 40)
  expect_identical(nrow(last), 0L)
  expect_identical(ncol(last), 5L)
})

test_that("a title in row 1 is read as the header, with a warning that says what to do", {
  w <- expect_warning(t <- read_xlsx(sales(), sheet = "Sales 2024"), class = "rlang_warning")
  expect_identical(
    first_line(w),
    "Row 1 has text only in B1 (\"Sales by region, 2024\"), but the rows below have up to 5 columns."
  )
  expect_match(
    conditionMessage(w),
    "If the header is lower down, give its row: `header = 5`, or the range: `range = \"B5:F40\"`.",
    fixed = TRUE
  )
  expect_identical(names(t)[[1]], "Sales by region, 2024")
  # No warning when the header or range is given, or the sheet has no title.
  expect_no_warning(read_xlsx(sales(), sheet = "Sales 2024", header = 5))
  expect_no_warning(read_xlsx(sales(), sheet = "Regions"))
  expect_no_warning(read_xlsx(sales(), sheet = "Notes"))
})
