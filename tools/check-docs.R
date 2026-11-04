# Run the R examples in docs/r.md and README.md, and check their output
# against the `#>` lines the docs show.
#
#   Rscript tools/check-docs.R [library]
#
# The examples run in one interactive R session, as a user would type
# them, with the console 80 wide:
#
# - docs/r.md's reading sections ("Install" to "Read every sheet") in a
#   temporary folder holding a copy of report.xlsx (for the "Did you
#   mean report.xlsx?" example);
# - its writing sections ("Write a table" to "Fill in an existing
#   workbook", and "Variable labels and value labels") in a folder of
#   their own. The docs write about the reader's own data and files, so
#   that folder holds them: `summary`, `detail`, `notes`, `means`,
#   `counts`, `q` and `q3` (made from sales.xlsx), `new_data` (twelve
#   months of values, as many rows as the template's Data sheet) and
#   `model_table` (a small table of estimates), results.xlsx (a copy of
#   template.xlsx, with sheets Cover, Chart and Data), and survey.dta
#   (written with dtaparser, whose `sex` has the unlabelled code 9 in
#   rows 5, 12 and 30 of the sheet and whose `agefb` is labelled "Age at
#   first birth");
# - README.md's first example, in a folder holding sales.xlsx and
#   template.xlsx, where `summary` is the Summary sheet.
#
# A block of output with no code, such as a message shown on its own, is
# checked against what the code block above it prints.
#
# `library` is where xlkit (and dtaparser) are installed, if not on the
# default path. Exits with status 1 when an output differs or an example
# without output fails.

args <- commandArgs(trailingOnly = TRUE)
lib <- if (length(args)) normalizePath(args[[1]]) else NULL
root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
doc <- readLines(file.path(root, "docs", "r.md"), encoding = "UTF-8")
readme <- readLines(file.path(root, "README.md"), encoding = "UTF-8")

# Code blocks of `lines[from:to]`: list(code, expected, where).
blocks_of <- function(lines, from, to, file) {
  part <- lines[from:to]
  starts <- grep("^```r$", part)
  out <- lapply(starts, function(s) {
    e <- s + which(part[(s + 1):length(part)] == "```")[[1]]
    body <- part[(s + 1):(e - 1)]
    is_out <- startsWith(body, "#>")
    code <- body[!is_out]
    list(code = code, expected = sub("^#> ?", "", body[is_out]), where = sprintf("%s:%d", file, from + s - 1))
  })
  out <- Filter(function(b) !any(grepl("install.packages|remotes::", b$code)), out)
  # A block of output alone shows what the code block above it prints.
  keep <- rep(TRUE, length(out))
  for (k in seq_along(out)) {
    if (k > 1 && !any(nzchar(trimws(out[[k]]$code))) && !length(out[[k - 1]]$expected)) {
      out[[k - 1]]$expected <- out[[k]]$expected
      out[[k - 1]]$where <- out[[k]]$where
      keep[k] <- FALSE
    }
  }
  Filter(function(b) any(nzchar(trimws(b$code))), out[keep])
}
section <- function(title) {
  from <- grep(paste0("^## ", title, "$"), doc)
  to <- grep("^## ", doc)
  list(from = from, to = to[to > from][[1]] - 1)
}
range_of <- function(first, last) c(section(first)$from, section(last)$to)

reading <- range_of("Install", "Read every sheet")
writing <- range_of("Write a table", "Fill in an existing workbook")
labels <- section("Variable labels and value labels")
setup_block <- function(code) list(list(code = code, expected = character(), where = "tools/check-docs.R's setup", setup = TRUE))
blocks <- c(
  blocks_of(doc, reading[[1]], reading[[2]], "docs/r.md"),
  "write-setup",
  blocks_of(doc, writing[[1]], writing[[2]], "docs/r.md"),
  blocks_of(doc, labels$from, labels$to, "docs/r.md"),
  "readme-setup",
  blocks_of(readme, 1, grep("^## ", readme)[[1]] - 1, "README.md")
)

dir <- tempfile("xlkit-docs-")
dir.create(dir)
script <- file.path(dir, "examples.R")
setup <- c(
  if (!is.null(lib)) sprintf(".libPaths(c(%s, .libPaths()))", deparse(lib)),
  "options(width = 80)",
  "file.copy(system.file('extdata', 'report.xlsx', package = 'xlkit'), 'report.xlsx')",
  "cat('@@START\\n')"
)
# The reader's own data and files, for the writing sections.
write_setup <- c(
  "invisible(suppressMessages({",
  "  dir.create('write'); setwd('write')",
  "  .sales <- xlkit::xlkit_example('sales.xlsx')",
  "  summary <- xlkit::read_xlsx(.sales, sheet = 'Summary')",
  "  detail <- xlkit::read_xlsx(.sales, sheet = 'Sales 2024', range = 'B5:F40')",
  "  notes <- xlkit::read_xlsx(.sales, sheet = 'Notes')",
  "  means <- aggregate(cbind(units, amount) ~ region, detail, mean)",
  "  counts <- as.data.frame(table(region = detail$region), responseName = 'n')",
  "  q <- detail[1:7, ]; q3 <- detail[8:14, ]",
  "  new_data <- data.frame(month = month.abb, value = c(120, 135, 128, 140, 152, 149, 160, 171, 158, 166, 175, 190))",
  "  model_table <- data.frame(term = c('(Intercept)', 'price'), estimate = c(12.4, -0.8), std_error = c(1.1, 0.2))",
  "  file.copy(xlkit::xlkit_example('template.xlsx'), 'results.xlsx')",
  "  .sex <- rep(c(1, 2), length.out = 40); .sex[c(4, 11, 29)] <- 9",
  "  dtaparser::save_dta(data.frame(",
  "    sex = dtaparser::with_labels(.sex, c(Male = 1, Female = 2), label = 'Sex'),",
  "    agefb = structure(seq(16, by = 0.5, length.out = 40), label = 'Age at first birth')",
  "  ), 'survey.dta')",
  "}))"
)
readme_setup <- c(
  "invisible(suppressMessages({",
  "  dir.create('../readme'); setwd('../readme')",
  "  file.copy(c(xlkit::xlkit_example('sales.xlsx'), xlkit::xlkit_example('template.xlsx')), '.')",
  "  summary <- xlkit::read_xlsx('sales.xlsx', sheet = 'Summary')",
  "}))"
)
blocks <- lapply(blocks, function(b) {
  if (identical(b, "write-setup")) return(setup_block(write_setup)[[1]])
  if (identical(b, "readme-setup")) return(setup_block(readme_setup)[[1]])
  b
})
code <- setup
for (k in seq_along(blocks)) code <- c(code, sprintf("cat('@@BLOCK %d\\n')", k), blocks[[k]]$code)
code <- c(code, "cat('@@END\\n')")
writeLines(code, script, useBytes = TRUE)

r <- file.path(R.home("bin"), "R")
old <- setwd(dir)
transcript <- system2(r, c("--interactive", "--no-save", "-q"), stdin = script, stdout = TRUE, stderr = TRUE)
setwd(old)
transcript <- transcript[!grepl("^OMP: ", transcript)]

# Output lines: neither prompts nor rlang's hint about last_trace().
transcript <- transcript[(grep("^@@START$", transcript)[[1]] + 1):length(transcript)]
is_output <- !grepl("^[>+] |^[>+]$", transcript) & !grepl("^Run `rlang::last_trace\\(\\)`", transcript)
marks <- grep("^@@(BLOCK [0-9]+|END)$", transcript)
mark_of <- sub("^@@BLOCK ", "", transcript[marks])

failed <- 0
n_run <- 0
n_checked <- 0
for (k in seq_along(blocks)) {
  b <- blocks[[k]]
  if (is.null(b$setup)) n_run <- n_run + 1
  m <- match(as.character(k), mark_of)
  span <- if (marks[[m]] + 1 <= marks[[m + 1]] - 1) (marks[[m]] + 1):(marks[[m + 1]] - 1) else integer()
  got <- transcript[span][is_output[span]]
  got <- sub("\\s+$", "", got)
  want <- sub("\\s+$", "", b$expected)
  if (length(want)) {
    n_checked <- n_checked + 1
    if (!identical(got, want)) {
      failed <- failed + 1
      cat(sprintf("%s differs.\n--- docs\n%s\n--- R\n%s\n\n", b$where,
                  paste(want, collapse = "\n"), paste(got, collapse = "\n")))
    }
  } else if (any(grepl("^Error", got))) {
    failed <- failed + 1
    cat(sprintf("%s failed:\n%s\n\n", b$where, paste(got, collapse = "\n")))
  }
}
cat(sprintf("%d examples run, %d with output checked, %d failed.\n", n_run, n_checked, failed))
quit(status = if (failed) 1 else 0)
