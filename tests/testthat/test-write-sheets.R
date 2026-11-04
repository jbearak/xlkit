# docs/r.md, "Write several tables": one sheet per data frame, tables
# stacked on one sheet with titles, and the rules for sheet names.

test_that("a named list writes one sheet each, in order", {
  path <- temp_xlsx()
  a <- data.frame(x = 1:2)
  b <- data.frame(y = c("p", "q"))
  write_xlsx(list(Summary = a, Detail = b, Notes = a), path)
  expect_identical(xlsx_sheets(path), c("Summary", "Detail", "Notes"))
  expect_identical(read_xlsx(path, sheet = "Detail")$y, c("p", "q"))
  all <- read_sheets(path)
  expect_identical(all$Notes$x, 1:2)
  skip_if_no_openpyxl()
  expect_identical(openpyxl(path)$sheets$name, c("Summary", "Detail", "Notes"))
})

test_that("tables on one sheet are stacked under bold titles, gap rows apart", {
  path <- temp_xlsx()
  means <- data.frame(group = c("a", "b"), mean = c(1.5, 2.5))
  counts <- data.frame(group = c("a", "b", "c"), n = c(10L, 20L, 30L))
  write_xlsx(list(Results = list("Table 1. Means" = means, "Table 2. Counts" = counts)), path, gap = 2)
  grid <- read_xlsx(path, header = FALSE, types = "text")
  expect_identical(grid$A, c("Table 1. Means", "group", "a", "b", NA, NA,
                             "Table 2. Counts", "group", "a", "b", "c"))
  expect_identical(grid$B, c(NA, "mean", "1.5", "2.5", NA, NA, NA, "n", "10", "20", "30"))
  # Each table reads back by its range.
  expect_identical(bare(read_xlsx(path, range = "A2:B4")), tibble::as_tibble(means))
  expect_identical(bare(read_xlsx(path, range = "A8:B11")), tibble::as_tibble(counts))
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_true(xl_cell(seen, "A1")$bold)
  expect_true(xl_cell(seen, "A7")$bold)
  expect_true(xl_cell(seen, "A8")$bold)
  # No one header row belongs to every table, so nothing is frozen.
  expect_identical(seen$sheets$freeze, "")
})

test_that("the default gap is one row, and unnamed tables get no title", {
  path <- temp_xlsx()
  write_xlsx(list(S = list(data.frame(a = 1), data.frame(b = 2))), path)
  grid <- read_xlsx(path, header = FALSE, types = "text")
  expect_identical(grid$A, c("a", "1", NA, "b", "2"))
  path2 <- temp_xlsx()
  write_xlsx(list(S = list(First = data.frame(a = 1), data.frame(b = 2))), path2)
  expect_identical(read_xlsx(path2, header = FALSE, types = "text")$A, c("First", "a", "1", NA, "b", "2"))
})

test_that("one titled table freezes through its header", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  write_xlsx(list(S = list("Title" = data.frame(a = 1:3))), path)
  expect_identical(openpyxl(path)$sheets$freeze, "'A3'")
})

test_that("sheets in one call mix both forms", {
  path <- temp_xlsx()
  write_xlsx(list(One = data.frame(a = 1), Two = list(T = data.frame(b = 2))), path)
  expect_identical(xlsx_sheets(path), c("One", "Two"))
  expect_identical(read_xlsx(path, sheet = "Two", header = FALSE, types = "text")$A, c("T", "b", "2"))
})

test_that("a sheet name Excel does not allow stops, suggesting one it does", {
  q <- data.frame(a = 1)
  path <- temp_xlsx()
  err <- expect_error(write_xlsx(list("Q1/Q2" = q, Q3 = q), path), class = "rlang_error")
  expect_identical(
    conditionMessage(err),
    "Sheet name \"Q1/Q2\" has \"/\", which Excel does not allow in sheet names.\ni Use another name, such as \"Q1-Q2\"."
  )
  err <- expect_error(write_xlsx(list("a[1]:b*?\\" = q), path), class = "rlang_error")
  expect_identical(
    first_line(err),
    "Sheet name \"a[1]:b*?\\\" has \"[\", \"]\", \":\", \"*\", \"?\" and \"\\\", which Excel does not allow in sheet names."
  )
  expect_match(conditionMessage(err), "such as \"a-1--b---\"", fixed = TRUE)

  long <- strrep("x", 32)
  err <- expect_error(write_xlsx(q, path, sheet = long), class = "rlang_error")
  expect_identical(first_line(err), paste0("Sheet name \"", long, "\" has 32 characters, which is more than the 31 Excel allows in sheet names."))
  expect_match(conditionMessage(err), paste0("such as \"", strrep("x", 31), "\""), fixed = TRUE)

  err <- expect_error(write_xlsx(list(Summary = q, summary = q), path), class = "rlang_error")
  expect_identical(first_line(err), "Sheet name \"summary\" is the same as \"Summary\" apart from case, which Excel does not allow in sheet names.")
  expect_match(conditionMessage(err), "such as \"summary 2\"", fixed = TRUE)

  err <- expect_error(write_xlsx(list(A = q, A = q), path), class = "rlang_error")
  expect_identical(first_line(err), "Sheet name \"A\" is used twice, and Excel does not allow two sheets with one name.")
  expect_match(conditionMessage(err), "such as \"A 2\"", fixed = TRUE)

  err <- expect_error(write_xlsx(q, path, sheet = "'Q1"), class = "rlang_error")
  expect_identical(first_line(err), "Sheet name \"'Q1\" starts with \"'\", which Excel does not allow in sheet names.")
  expect_error(write_xlsx(q, path, sheet = "History"), "one Excel keeps for itself")
  expect_error(write_xlsx(q, path, sheet = ""), "A sheet name must not be empty.")
  expect_false(file.exists(path))
})

test_that("31 characters and every other character are allowed", {
  path <- temp_xlsx()
  name <- "Sales 2024 (été) - Q1 & Q2, #1"
  write_xlsx(list(x = data.frame(a = 1), y = data.frame(a = 2)) |> setNames(c(strrep("y", 31), name)), path)
  expect_identical(xlsx_sheets(path), c(strrep("y", 31), name))
})

test_that("a list needs sheet names, and data frames in it", {
  path <- temp_xlsx()
  a <- data.frame(x = 1)
  err <- expect_error(write_xlsx(list(a, a), path), class = "rlang_error")
  expect_identical(first_line(err), "Every sheet of `x` needs a name, and element 1 has none.")
  expect_match(conditionMessage(err), "list(Results = list(means, counts))", fixed = TRUE)
  err <- expect_error(write_xlsx(list(Summary = summary, Detail = a), path), class = "rlang_error")
  expect_identical(plain_message(err),
                   "`x$Summary` must be a data frame, or a list of data frames to stack on one sheet.\nx It is a function.")
  expect_error(write_xlsx(list(S = list(a, 1:3)), path), "It is a list whose element 2 is an integer vector.", fixed = TRUE)
  expect_error(write_xlsx(list(), path), "`x` is an empty list")
  expect_error(write_xlsx(list(S = a), path, sheet = "S"), "`sheet` names the sheet only when `x` is one data frame.", fixed = TRUE)
  expect_false(file.exists(path))
})
