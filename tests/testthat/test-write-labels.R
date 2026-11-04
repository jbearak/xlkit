# docs/r.md, "Variable labels and value labels", the writing half (ADR
# 0007). Labelled columns are made here in dtaparser's and haven's forms
# from their attributes, as xlkit reads them, without either package.

dta_labelled <- function(x, labels, label = NULL) {
  structure(x, labels = labels, label = label, class = c("dtaparser_labelled", "vctrs_vctr"))
}

survey <- function() {
  sex <- c(1, 2, 1, 9, 2, 1, 2, 1, 1, 2, 9)
  sex[29] <- 9
  sex[is.na(sex)] <- 1
  tibble::tibble(
    sex = dta_labelled(sex, c(Male = 1, Female = 2), "Sex of respondent"),
    agefb = structure(seq_along(sex) + 15, label = "Age at first birth"),
    id = seq_along(sex)
  )
}

test_that("value labels are written as text, codes without one as codes, with a message", {
  path <- temp_xlsx()
  msg <- expect_message(write_xlsx(survey(), path), class = "rlang_message")
  expect_identical(plain_message(msg), paste0(
    "`sex` has 3 cells whose code has no value label: 9 in A5, A12 and A30.\n",
    "They are written as codes.\n",
    "i Add a label with `dtaparser::with_labels()`, or write the column's codes with `values = \"codes\"`."
  ))
  back <- read_xlsx(path)
  expect_identical(back$sex[1:4], c("Male", "Female", "Male", "9"))
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(xl_cell(seen, "A2")$type, "s")
  expect_identical(xl_cell(seen, "A5")$type, "n")
})

test_that("the message names each code and one cell in the singular", {
  x <- dta_labelled(c(1, 7, 8, 8), c(One = 1))
  msg <- expect_message(write_xlsx(tibble::tibble(x = x), temp_xlsx()), class = "rlang_message")
  expect_identical(first_line(msg), "`x` has 3 cells whose code has no value label: 7 in A3; 8 in A4 and A5.\nThey are written as codes.")
  y <- dta_labelled(c(1, 7), c(One = 1))
  msg <- expect_message(write_xlsx(tibble::tibble(y = y), temp_xlsx()), class = "rlang_message")
  expect_identical(first_line(msg), "`y` has 1 cell whose code has no value label: 7 in A3.\nIt is written as a code.")
})

test_that("values = \"codes\" writes the codes, without a message", {
  path <- temp_xlsx()
  expect_no_message(write_xlsx(survey(), path, values = "codes"))
  back <- read_xlsx(path)
  expect_identical(back$sex[1:4], c(1L, 2L, 1L, 9L))
})

test_that("header = \"labels\" writes variable labels, the name where there is none", {
  path <- temp_xlsx()
  suppressMessages(write_xlsx(survey(), path, header = "labels"))
  expect_identical(names(read_xlsx(path)), c("Sex of respondent", "Age at first birth", "id"))
  # Read back with short names, the headers are the variable labels again.
  back <- read_xlsx(path, names = "snake")
  expect_identical(names(back), c("sex_of_respondent", "age_at_first_birth", "id"))
  expect_identical(attr(back$age_at_first_birth, "label"), "Age at first birth")
  expect_null(attr(back$id, "label"))
})

test_that("header = \"both\" writes names, then labels; FALSE writes none", {
  path <- temp_xlsx()
  write_xlsx(survey(), path, header = "both", values = "codes")
  grid <- read_xlsx(path, header = FALSE, types = "text")
  expect_identical(unname(unlist(grid[1, ])), c("sex", "agefb", "id"))
  expect_identical(unname(unlist(grid[2, ])), c("Sex of respondent", "Age at first birth", NA))
  expect_identical(grid$A[[3]], "1")
  expect_identical(read_xlsx(path, header = 1:2) |> names(), c("sex Sex of respondent", "agefb Age at first birth", "id"))

  path2 <- temp_xlsx()
  write_xlsx(data.frame(a = 1:2, b = c("x", "y")), path2, header = FALSE)
  grid <- read_xlsx(path2, header = FALSE)
  expect_identical(grid$A, 1:2)
  expect_identical(grid$B, c("x", "y"))
  skip_if_no_openpyxl()
  expect_identical(openpyxl(path2)$sheets$freeze, "")
})

test_that("tagged missing values write their own labels, other NA is blank", {
  # .a in dtaparser and haven: a NaN whose payload holds the letter.
  tagged <- function(tag) {
    bytes <- as.raw(c(0xa2, 0x07, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x7f))
    bytes[5] <- charToRaw(tag)
    readBin(bytes, "double", size = 8, endian = "little")
  }
  x <- dta_labelled(c(1, tagged("a"), NA, tagged("b"), 1), c(Yes = 1, Refused = tagged("a")))
  path <- temp_xlsx()
  write_xlsx(tibble::tibble(x = x), path)
  expect_identical(read_xlsx(path)$x, c("Yes", "Refused", NA, NA, "Yes"))
})

test_that("haven's labelled columns work the same way", {
  skip_if_not_installed("haven")
  x <- haven::labelled(c(1, 2, 3), c(Low = 1, High = 2), label = "Level")
  path <- temp_xlsx()
  expect_message(write_xlsx(tibble::tibble(level = x), path, header = "labels"), "3 in A4")
  back <- read_xlsx(path)
  expect_identical(names(back), "Level")
  expect_identical(back$Level, c("Low", "High", "3"))
  chr <- haven::labelled(c("M", "F", "X"), c(Male = "M", Female = "F"))
  path2 <- temp_xlsx()
  msg <- expect_message(write_xlsx(tibble::tibble(g = chr), path2), class = "rlang_message")
  expect_match(conditionMessage(msg), "\"X\" in A4", fixed = TRUE)
  expect_identical(read_xlsx(path2)$g, c("Male", "Female", "X"))
})

test_that("labels in a workbook of several sheets name the sheet", {
  x <- dta_labelled(c(1, 5), c(One = 1))
  msg <- expect_message(write_xlsx(list(A = data.frame(n = 1), B = tibble::tibble(x = x)), temp_xlsx()),
                        class = "rlang_message")
  expect_match(first_line(msg), "^Sheet \"B\": `x` has 1 cell")
})

test_that("a read_dta() and write_xlsx() round trip keeps labels as text", {
  skip_if_not_installed("dtaparser")
  skip_if_not(exists("save_dta", envir = asNamespace("dtaparser")))
  dta <- tempfile(fileext = ".dta")
  df <- survey()
  getExportedValue("dtaparser", "save_dta")(df, dta)
  back_dta <- getExportedValue("dtaparser", "read_dta")(dta)
  path <- temp_xlsx()
  suppressMessages(write_xlsx(back_dta, path, header = "labels"))
  back <- read_xlsx(path, names = "snake")
  expect_identical(back$sex_of_respondent[1:2], c("Male", "Female"))
  expect_identical(attr(back$age_at_first_birth, "label"), "Age at first birth")
})
