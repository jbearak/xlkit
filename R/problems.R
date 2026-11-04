#' Cells that did not convert, and Excel errors
#'
#' Lists the cells of a tibble read by [read_xlsx()] that became `NA`
#' because they did not fit their column's type, and the cells that held
#' Excel errors such as `#N/A`. `cell` and `row` are as Excel shows them,
#' so you can find each cell in the workbook.
#'
#' @param x A tibble from [read_xlsx()] or [read_sheets()].
#' @return A tibble with columns `cell`, `column`, `row`, `value` (the
#'   cell's text as Excel shows it) and `problem`, with zero rows when
#'   there were none.
#' @export
#' @examples
#' path <- xlkit_example("messy.xlsx")
#' df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-"))
#' xlsx_problems(df)
xlsx_problems <- function(x) {
  if (!is.data.frame(x)) {
    rlang::abort("`x` must be a tibble read by `read_xlsx()`.")
  }
  p <- attr(x, "xlkit_problems", exact = TRUE)
  if (is.null(p)) empty_problems() else p
}

empty_problems <- function() {
  tibble::tibble(
    cell = character(), column = character(), row = integer(),
    value = character(), problem = character()
  )
}

with_problems <- function(df, problems) {
  problems$.type <- NULL
  attr(df, "xlkit_problems") <- problems
  df
}

# One tibble from the problems of each column, in column order.
problems_tibble <- function(problems) {
  if (!length(problems)) return(empty_problems())
  parts <- lapply(problems, function(p) {
    tibble::tibble(
      cell = p$cell, column = p$column, row = p$row, value = p$value, problem = p$problem,
      .type = p$type
    )
  })
  vctrs::vec_rbind(!!!parts)
}

# One warning for every problem of a read: a line per column for cells
# that did not convert, and one line for Excel errors.
warn_problems <- function(problems, label) {
  if (!nrow(problems)) return(invisible())
  lines <- character()
  conv <- problems[problems$problem != "Excel error", ]
  for (col in unique(conv$column)) {
    p <- conv[conv$column == col, ]
    n <- nrow(p)
    lines <- c(lines, paste0(
      fmt_count(n), if (n == 1) " cell" else " cells", " in `", col, "` could not be read as ",
      type_noun[[p$.type[[1]]]], if (n == 1) " and is NA:\n" else " and are NA:\n",
      and_list_first(paste0(p$cell, " (", dquote(p$value), ")")), "."
    ))
  }
  errs <- problems[problems$problem == "Excel error", ]
  n <- nrow(errs)
  if (n) {
    lines <- c(lines, paste0(
      if (n == 1) "1 cell holds an Excel error and is NA: " else paste0(fmt_count(n), " cells hold Excel errors and are NA: "),
      and_list_first(paste0(errs$cell, " (", errs$value, ")")), "."
    ))
  }
  rlang::warn(c(label(paste(lines, collapse = "\n")), i = "See them all with `xlsx_problems(df)`."))
}
