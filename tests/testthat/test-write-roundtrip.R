# Every example workbook, read by read_xlsx() and written by
# write_xlsx(), reads back with the same values and types; and readxl
# reads what write_xlsx() wrote as it reads the original.

example_tables <- function() {
  births <- xlkit_example("births.xlsx")
  messy <- xlkit_example("messy.xlsx")
  quiet <- function(...) suppressMessages(suppressWarnings(read_xlsx(...)))
  list(
    report = quiet(xlkit_example("report.xlsx")),
    summary = quiet(births, sheet = "Summary"),
    births_2023 = quiet(births, sheet = "Births 2023", header = 5),
    births_2024 = quiet(births, sheet = "Births 2024", range = "B5:F40"),
    regions = quiet(births, sheet = "Regions"),
    notes = quiet(births, sheet = "Notes"),
    headers = quiet(messy, sheet = "Headers"),
    headers_snake = quiet(messy, sheet = "Headers", names = "snake"),
    two_row = quiet(messy, sheet = "Two-row header", header = 4:5),
    types = quiet(messy, sheet = "Types"),
    types_number = quiet(messy, sheet = "Types", types = c(zip = "text", amount = "number")),
    missing = quiet(messy, sheet = "Missing", na = c("NA", ".", "-")),
    dates = quiet(xlkit_example("dates.xlsx")),
    dates1904 = quiet(xlkit_example("dates1904.xlsx")),
    template_data = quiet(xlkit_example("template.xlsx"), sheet = "Data")
  )
}

test_that("every example table reads back with the same values and types", {
  tables <- example_tables()
  path <- temp_xlsx()
  names(tables) <- substr(names(tables), 1, 31)
  write_xlsx(tables, path)
  expect_identical(xlsx_sheets(path), names(tables))
  for (name in names(tables)) {
    back <- read_xlsx(path, sheet = name)
    expect_identical(bare(back), bare(tables[[name]]), label = name)
  }
})

test_that("each example table round-trips on a sheet of its own, too", {
  tables <- example_tables()
  for (name in names(tables)) {
    path <- temp_xlsx()
    write_xlsx(tables[[name]], path)
    expect_identical(bare(read_xlsx(path)), bare(tables[[name]]), label = name)
  }
})

test_that("variable labels round-trip through header = \"labels\"", {
  df <- suppressMessages(read_xlsx(xlkit_example("messy.xlsx"), sheet = "Headers", names = "snake"))
  path <- temp_xlsx()
  write_xlsx(df, path, header = "labels")
  back <- suppressMessages(read_xlsx(path, names = "snake"))
  expect_identical(names(back), names(df))
  expect_identical(attr(back$share_percent, "label"), "Share %")
  expect_identical(bare(back), bare(df))
})

test_that("stacked tables read back by their ranges", {
  tables <- example_tables()
  path <- temp_xlsx()
  write_xlsx(list(Both = list("Regions" = tables$regions, "Dates" = tables$dates)), path)
  n <- nrow(tables$regions)
  expect_identical(bare(read_xlsx(path, range = paste0("A2:C", n + 2))), bare(tables$regions))
  top <- n + 5
  expect_identical(bare(read_xlsx(path, range = paste0("A", top, ":C", top + nrow(tables$dates)))), bare(tables$dates))
})

test_that("readxl reads the written tables as it reads the originals", {
  skip_if_not_installed("readxl")
  rx <- function(...) suppressWarnings(suppressMessages(readxl::read_excel(...)))
  check <- function(original, written) {
    expect_identical(names(written), names(original))
    for (col in names(original)) {
      expect_equal(written[[col]], original[[col]], label = col, ignore_attr = TRUE)
    }
  }
  for (name in c("report.xlsx", "dates.xlsx")) {
    df <- read_xlsx(xlkit_example(name))
    path <- temp_xlsx()
    write_xlsx(df, path)
    check(rx(xlkit_example(name)), rx(path))
  }
  births <- xlkit_example("births.xlsx")
  df <- read_xlsx(births, sheet = "Births 2024", range = "B5:F40")
  path <- temp_xlsx()
  write_xlsx(df, path, formats = c(women = "#,##0", births = "#,##0", asfr = "0.0"))
  check(rx(births, sheet = "Births 2024", range = "B5:F40"), rx(path))
})
