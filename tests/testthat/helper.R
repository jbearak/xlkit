# Workbooks made by tools/make-examples.py with openpyxl.
fixture <- function(name) testthat::test_path("fixtures", name)
edge <- function() fixture("edge.xlsx")

# A file in a temporary folder with the given bytes or lines.
temp_file <- function(name, lines = NULL, bytes = NULL) {
  dir <- tempfile("xlkit-")
  dir.create(dir)
  path <- file.path(dir, name)
  if (!is.null(bytes)) writeBin(bytes, path) else writeLines(lines, path)
  path
}

# read_xlsx() without its messages and warnings, for tests of values.
quietly <- function(expr) suppressMessages(suppressWarnings(expr))

# A condition's message up to its first bullet line ("i ...", "* ...").
first_line <- function(cnd) {
  lines <- strsplit(conditionMessage(cnd), "\n", fixed = TRUE)[[1]]
  bullet <- grepl("^(\u2139|i|\u2022|\\*|x|\u2716|!) ", lines)
  keep <- if (any(bullet)) seq_len(which(bullet)[[1]] - 1) else seq_along(lines)
  paste(lines[keep], collapse = "\n")
}
