# Run the R examples in docs/r.md's reading sections ("Install" to "Read
# every sheet") and check their output against the `#>` lines the docs
# show.
#
#   Rscript tools/check-docs.R [library]
#
# The examples run in one interactive R session, as a user would type
# them, in a temporary folder holding a copy of report.xlsx (for the
# "Did you mean report.xlsx?" example). The console's width is 80.
# `library` is where xlkit is installed, if not on the default path.
# Exits with status 1 when an output differs or an example without
# output fails.

args <- commandArgs(trailingOnly = TRUE)
lib <- if (length(args)) normalizePath(args[[1]]) else NULL
root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
doc <- readLines(file.path(root, "docs", "r.md"), encoding = "UTF-8")

from <- grep("^## Install$", doc)
to <- grep("^## Write a table$", doc) - 1
doc <- doc[from:to]

# Code blocks: list(code, expected, line).
starts <- grep("^```r$", doc)
blocks <- lapply(starts, function(s) {
  e <- s + which(doc[(s + 1):length(doc)] == "```")[[1]]
  body <- doc[(s + 1):(e - 1)]
  out <- startsWith(body, "#>")
  list(code = body[!out], expected = sub("^#> ?", "", body[out]), line = from + s)
})
blocks <- Filter(function(b) !any(grepl("install.packages|remotes::", b$code)), blocks)

dir <- tempfile("xlkit-docs-")
dir.create(dir)
script <- file.path(dir, "examples.R")
setup <- c(
  if (!is.null(lib)) sprintf(".libPaths(c(%s, .libPaths()))", deparse(lib)),
  "options(width = 80)",
  "file.copy(system.file('extdata', 'report.xlsx', package = 'xlkit'), 'report.xlsx')",
  "cat('@@START\\n')"
)
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

failed <- 0
for (k in seq_along(blocks)) {
  span <- if (marks[[k]] + 1 <= marks[[k + 1]] - 1) (marks[[k]] + 1):(marks[[k + 1]] - 1) else integer()
  got <- transcript[span][is_output[span]]
  got <- sub("\\s+$", "", got)
  b <- blocks[[k]]
  want <- sub("\\s+$", "", b$expected)
  if (length(want)) {
    if (!identical(got, want)) {
      failed <- failed + 1
      cat(sprintf("docs/r.md:%d differs.\n--- docs\n%s\n--- R\n%s\n\n", b$line,
                  paste(want, collapse = "\n"), paste(got, collapse = "\n")))
    }
  } else if (any(grepl("^Error", got))) {
    failed <- failed + 1
    cat(sprintf("docs/r.md:%d failed:\n%s\n\n", b$line, paste(got, collapse = "\n")))
  }
}
cat(sprintf("%d examples run, %d with output checked, %d failed.\n",
            length(blocks), sum(lengths(lapply(blocks, `[[`, "expected")) > 0), failed))
quit(status = if (failed) 1 else 0)
