# Cases from the first review of the writing code.

new_dir <- function() {
  dir <- tempfile("xlkit-")
  dir.create(dir)
  dir
}

test_that("without replace, a file made after the check is not overwritten", {
  dir <- new_dir()
  path <- file.path(dir, "race.xlsx")
  other <- file.path(dir, "other.xlsx")
  write_xlsx(data.frame(a = 1), other)
  # Another program makes `path` after write_xlsx() checked for it: the
  # tracer runs as the commit step starts.
  trace("write_plan", where = asNamespace("xlkit"), print = FALSE,
        tracer = bquote(file.copy(.(other), .(path))))
  on.exit(untrace("write_plan", where = asNamespace("xlkit")), add = TRUE)
  expect_error(write_xlsx(data.frame(b = 2), path), "already exists")
  expect_identical(unname(tools::md5sum(path)), unname(tools::md5sum(other)))
  expect_length(list.files(dir, pattern = "[.]tmp$", all.files = TRUE), 0)
})

test_that("a warning made an error leaves the existing file as it was", {
  path <- file.path(new_dir(), "warn.xlsx")
  write_xlsx(data.frame(a = 1), path)
  before <- unname(tools::md5sum(path))
  old <- options(warn = 2)
  on.exit(options(old), add = TRUE)
  expect_error(write_xlsx(data.frame(a = NaN), path, replace = TRUE))
  expect_identical(unname(tools::md5sum(path)), before)
})

test_that("formats whose first section has no digits are written", {
  path <- file.path(new_dir(), "formats.xlsx")
  expect_no_error(write_xlsx(data.frame(a = 1, b = 2), path, formats = c(a = ";;;", b = '"text"')))
})

test_that("widths follow a column style's number format", {
  skip_if_no_openpyxl()
  path <- file.path(new_dir(), "styled.xlsx")
  write_xlsx(data.frame(x = 0.1), path, styles = list(x = xl_style(format = "0.00000000000000000000")))
  w <- openpyxl(path)$widths
  expect_gt(w$width[w$col == "A"], 20)
})

test_that("text length counts characters beyond U+FFFF twice, as Excel does", {
  path <- file.path(new_dir(), "emoji.xlsx")
  long <- strrep("\U0001F600", 20000)
  err <- expect_error(write_xlsx(data.frame(t = long), path), class = "rlang_error")
  expect_match(conditionMessage(err), "A2 \\(40,000 characters\\)")
  expect_false(file.exists(path))
})
