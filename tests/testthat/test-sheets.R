# docs/r.md, "Read every sheet", and xlsx_sheets().

births <- function() xlkit_example("births.xlsx")

test_that("xlsx_sheets() lists sheets in tab order, chart sheets included", {
  expect_identical(
    xlsx_sheets(edge()),
    c("Early", "Errors", "Mixed", "Formats", "Ranges", "Names", "Empty", "Plot", "Text")
  )
  expect_error(xlsx_sheets("missing.xlsx"), "missing.xlsx does not exist.", fixed = TRUE)
})

test_that("read_sheets() reads every worksheet into a named list", {
  all <- suppressWarnings(read_sheets(births()))
  expect_type(all, "list")
  expect_identical(names(all), c("Summary", "Births 2023", "Births 2024", "Regions", "Notes"))
  expect_identical(all[["Regions"]], read_xlsx(births(), sheet = "Regions"))
  expect_true(all(vapply(all, tibble::is_tibble, logical(1))))
})

test_that("read_sheets() passes read_xlsx()'s arguments to every sheet", {
  two <- read_sheets(births(), sheets = c("Births 2023", "Births 2024"), header = 5)
  expect_identical(names(two), c("Births 2023", "Births 2024"))
  expect_identical(two[["Births 2024"]], read_xlsx(births(), sheet = "Births 2024", header = 5))
  expect_identical(read_sheets(births(), sheets = "^Births", header = 5), two)
  expect_identical(names(read_sheets(births(), sheets = c(4, 1))), c("Regions", "Summary"))
  expect_identical(names(read_sheets(births(), sheets = "Notes")), "Notes")
})

test_that("read_sheets() skips chart sheets unless named, and reads empty sheets as empty tibbles", {
  all <- quietly(read_sheets(edge()))
  expect_false("Plot" %in% names(all))
  expect_identical(dim(all[["Empty"]]), c(0L, 0L))
  expect_error(read_sheets(edge(), sheets = "Plot"), "is a chart sheet")
})

test_that("each tibble keeps its own problems, and messages name the sheet", {
  expect_warning(
    all <- read_sheets(xlkit_example("messy.xlsx"), sheets = c("Missing", "Headers"), na = c("NA", ".", "-")),
    "Sheet \"Missing\": 2 cells hold Excel errors", fixed = TRUE
  ) |> suppressMessages()
  expect_identical(xlsx_problems(all[["Missing"]])$cell, c("D4", "D9"))
  expect_identical(nrow(xlsx_problems(all[["Headers"]])), 0L)
  expect_message(
    read_sheets(xlkit_example("messy.xlsx"), sheets = c("Headers", "Types")),
    "Sheet \"Headers\": New names:", fixed = TRUE
  ) |> suppressMessages()
})

test_that("read_sheets() checks its arguments", {
  expect_error(read_sheets(births(), sheet = "Notes"), "takes `sheets`, not `sheet`")
  expect_error(read_sheets(births(), skip = 4), "`...` must be named arguments of `read_xlsx()`", fixed = TRUE)
  expect_error(read_sheets(births(), sheets = "^Nope"), "No sheet of births.xlsx is named \"^Nope\" or matches it", fixed = TRUE)
  expect_error(read_sheets(births(), sheets = c("Notes", "Nope")), "has no sheet \"Nope\"")
  expect_error(read_sheets(births(), sheets = "(["), "neither a sheet of births.xlsx nor a regular expression")
  expect_error(read_sheets(births(), sheets = TRUE), "`sheets` must be")
})
