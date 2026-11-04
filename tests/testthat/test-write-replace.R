# docs/r.md, "When the file exists" (ADR 0005): write_xlsx() never
# replaces a file without replace = TRUE, and replaces it through a
# temporary file beside it, so a failure leaves the old file.

test_that("an existing file stops, naming its sheets", {
  path <- temp_xlsx("results.xlsx")
  file.copy(xlkit_example("template.xlsx"), path)
  before <- unname(tools::md5sum(path))
  err <- expect_error(write_xlsx(data.frame(a = 1), path), class = "rlang_error")
  expect_identical(plain_message(err), paste0(
    "results.xlsx already exists, with sheets \"Cover\", \"Chart\" and \"Data\".\n",
    "i To replace the whole workbook, use `replace = TRUE`.\n",
    "i To change one sheet and keep the rest, use `write_sheet()` or `write_cells()`."
  ))
  expect_identical(unname(tools::md5sum(path)), before)
})

test_that("one sheet is named in the singular, and a file that is not a workbook too", {
  path <- temp_xlsx()
  write_xlsx(data.frame(a = 1), path, sheet = "Scores")
  err <- expect_error(write_xlsx(data.frame(a = 1), path), class = "rlang_error")
  expect_identical(first_line(err), "out.xlsx already exists, with sheet \"Scores\".")
  text <- temp_xlsx("notes.xlsx")
  writeLines("a,b", text)
  err <- expect_error(write_xlsx(data.frame(a = 1), text), class = "rlang_error")
  expect_identical(first_line(err), "notes.xlsx already exists.")
})

test_that("replace = TRUE replaces the file and leaves no temporary file", {
  path <- temp_xlsx("results.xlsx")
  file.copy(xlkit_example("template.xlsx"), path)
  write_xlsx(data.frame(a = 1:2), path, replace = TRUE)
  expect_identical(xlsx_sheets(path), "Sheet1")
  expect_identical(read_xlsx(path)$a, 1:2)
  expect_identical(list.files(dirname(path), all.files = TRUE, no.. = TRUE), "results.xlsx")
})

test_that("a failed write leaves the old file as it was", {
  skip_on_os("windows")
  skip_if(Sys.info()[["user"]] == "root", "root can write to read-only folders")
  path <- temp_xlsx("results.xlsx")
  file.copy(xlkit_example("template.xlsx"), path)
  before <- unname(tools::md5sum(path))
  Sys.chmod(dirname(path), "0555")
  on.exit(Sys.chmod(dirname(path), "0755"), add = TRUE)
  err <- expect_error(write_xlsx(data.frame(a = 1), path, replace = TRUE), class = "rlang_error")
  expect_match(conditionMessage(err), "^results.xlsx could not be written: ")
  Sys.chmod(dirname(path), "0755")
  expect_identical(unname(tools::md5sum(path)), before)
  expect_identical(list.files(dirname(path), all.files = TRUE, no.. = TRUE), "results.xlsx")
})

test_that("an error in the arguments leaves the old file, even with replace = TRUE", {
  path <- temp_xlsx("results.xlsx")
  file.copy(xlkit_example("template.xlsx"), path)
  before <- unname(tools::md5sum(path))
  expect_error(write_xlsx(data.frame(a = 1), path, formats = c(b = "0"), replace = TRUE), "`formats` names `b`")
  expect_error(write_xlsx(data.frame(a = strrep("x", 40000)), path, replace = TRUE), "32,767")
  expect_identical(unname(tools::md5sum(path)), before)
})

test_that("argument errors come before the file's own", {
  path <- temp_xlsx()
  write_xlsx(data.frame(share = 1), path)
  expect_error(write_xlsx(data.frame(share = 1), path, formats = c(shar = "0.0%")), "Did you mean `share`?", fixed = TRUE)
})
