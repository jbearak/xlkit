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

# A Python with openpyxl, for what R's readers cannot see (number formats,
# fonts, fills, borders, widths, frozen panes, filters, merged ranges), or
# "" when there is none. Tests that need it skip without it.
python_exe <- local({
  found <- NULL
  function() {
    if (!is.null(found)) return(found)
    found <<- ""
    for (p in c("python3", "python")) {
      exe <- Sys.which(p)
      if (!nzchar(exe)) next
      ok <- suppressWarnings(system2(exe, c("-I", "-c", shQuote("import openpyxl")), stdout = FALSE, stderr = FALSE))
      if (identical(as.integer(ok), 0L)) {
        found <<- unname(exe)
        break
      }
    }
    found
  }
})

skip_if_no_openpyxl <- function() {
  if (!nzchar(python_exe())) testthat::skip("python3 with openpyxl is not installed")
}

# What openpyxl sees in a workbook: list(sheets, widths, merged, cells),
# from openpyxl_dump.py.
openpyxl <- function(path) {
  script <- testthat::test_path("openpyxl_dump.py")
  out <- system2(python_exe(), c("-I", shQuote(script), shQuote(path)), stdout = TRUE)
  Encoding(out) <- "UTF-8"
  rows <- strsplit(out, "\t", fixed = TRUE)
  kind <- vapply(rows, `[[`, "", 1)
  table <- function(k, cols) {
    r <- rows[kind == k]
    m <- matrix(as.character(unlist(lapply(r, function(x) c(x[-1], rep("", length(cols) - length(x) + 1))))),
                ncol = length(cols), byrow = TRUE)
    df <- as.data.frame(m, stringsAsFactors = FALSE)
    names(df) <- cols
    df
  }
  cells <- table("cell", c("sheet", "cell", "type", "value", "format", "bold", "italic", "underline",
                           "size", "font", "color", "fill", "top", "right", "bottom", "left",
                           "align", "valign", "wrap", "indent"))
  cells$bold <- cells$bold == "True"
  cells$italic <- cells$italic == "True"
  cells$wrap <- cells$wrap == "True"
  widths <- table("width", c("sheet", "col", "width"))
  widths$width <- as.numeric(widths$width)
  list(sheets = table("sheet", c("name", "freeze", "filter")), widths = widths,
       merged = table("merged", c("sheet", "range")), cells = cells)
}

# One cell of openpyxl()'s cells, as a list.
xl_cell <- function(seen, cell, sheet = seen$sheets$name[[1]]) {
  hit <- seen$cells[seen$cells$sheet == sheet & seen$cells$cell == cell, , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  as.list(hit[1, ])
}

# A path in a new temporary folder.
temp_xlsx <- function(name = "out.xlsx") {
  dir <- tempfile("xlkit-w-")
  dir.create(dir)
  file.path(dir, name)
}

# A condition's message with rlang's bullets as plain letters ("i", "x",
# "*"), which they are when the console cannot show the symbols.
plain_message <- function(cnd) {
  lines <- strsplit(conditionMessage(cnd), "\n", fixed = TRUE)[[1]]
  lines <- sub("^ℹ ", "i ", lines)
  lines <- sub("^✖ ", "x ", lines)
  lines <- sub("^• ", "* ", lines)
  paste(lines, collapse = "\n")
}

# A tibble without variable labels or xlsx_problems(), to compare values
# and types.
bare <- function(df) {
  out <- lapply(df, function(x) {
    attr(x, "label") <- NULL
    x
  })
  tibble::as_tibble(out)
}
