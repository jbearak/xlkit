#' Put values into cells of a workbook, keeping the rest of it
#'
#' Writes values into cells of a sheet, as Stata's `putexcel` does, and
#' copies everything else in the file as it was: other cells, other
#' sheets, charts, images, comments, conditional formats, data validation,
#' defined names, pivot tables and macros. The workbook is never rebuilt
#' from what xlkit understands.
#'
#' A cell keeps its own format, so a template's formatted cell shows the
#' new value as the template meant. A date written into a cell whose
#' format does not show dates gets the `yyyy-mm-dd` format and keeps its
#' font, fill and borders.
#'
#' What a value becomes:
#'
#' | value | written |
#' |---|---|
#' | a number, text, logical, date or date-time | that cell |
#' | a vector of length 2 or more | down the column from that cell |
#' | a matrix | a block, from that cell, with its column and row names when it has them |
#' | a data frame | a table with its header row, from that cell |
#' | [xl_formula()] | a formula; Excel calculates it when the file is opened |
#' | `NA` | an empty cell, keeping its format |
#'
#' Text is written as text, never as a formula. The workbook is marked so
#' Excel recalculates every formula when it opens the file; until then,
#' [read_xlsx()] reads the old results.
#'
#' Nothing is written, and the file is left as it was, when a cell is
#' inside a merged range other than its top-left cell, in an Excel
#' table's header row, or in an array formula's range; when the sheet's
#' XML uses a form xlkit cannot edit safely; and for `.xls`, `.xlsb` and
#' password-protected files. The new file is written beside the old one
#' and moved over it.
#'
#' The guide is <https://github.com/jbearak/xlkit/blob/main/docs/r.md>.
#'
#' @param path An `.xlsx` or `.xlsm` file. If it does not exist, a new
#'   workbook is made.
#' @param sheet The sheet's name (or its position). A sheet the workbook
#'   does not have is added after the last tab.
#' @param ... Cells and values, such as `C4 = 1250` or
#'   `B2 = "Results for 2024"`.
#' @param styles A list of styles from [xl_style()], named by cell or
#'   range, such as `list(B2 = xl_style(bold = TRUE, size = 14))`. A style
#'   changes only what it sets; the cell keeps the rest of its format. A
#'   percent format on cells whose numbers are all 1 or more (or -1 or
#'   less) gets a message naming them.
#' @param merge Ranges to merge, such as `"B2:F2"`, or a list of styles
#'   named by the ranges to merge. Excel keeps only a merged range's
#'   top-left value, so the other cells must be empty.
#' @return `path`, invisibly.
#' @seealso [write_sheet()] to write a table to a sheet, [write_xlsx()]
#'   for a new workbook.
#' @export
#' @examples
#' path <- file.path(tempdir(), "template.xlsx")
#' file.copy(xlkit_example("template.xlsx"), path, overwrite = TRUE)
#' write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
#' write_cells(
#'   path, sheet = "Cover",
#'   B2 = "Results for 2024",
#'   styles = list(B2 = xl_style(bold = TRUE, size = 14)),
#'   merge = "B2:F2"
#' )
#' read_xlsx(path, sheet = "Cover", header = FALSE)
write_cells <- function(path, sheet, ..., styles = NULL, merge = NULL) {
  call <- rlang::current_env()
  where <- check_edit_path(path, call)
  info <- if (where$exists) workbook_info(where$full, call) else NULL
  if (missing(sheet)) rlang::abort("`sheet` must be a sheet name, as one string.", call = call)
  sh <- check_edit_sheet(sheet, info, path, call)
  values <- rlang::list2(...)
  nm <- names(values)
  if (is.null(nm)) nm <- rep("", length(values))
  unnamed <- which(is.na(nm) | !nzchar(nm))
  if (length(unnamed)) {
    rlang::abort(c(
      "Each value in `...` needs the cell it goes in, such as `C4 = 1250`.",
      x = paste0("Value ", unnamed[[1]], " has none.")
    ), call = call)
  }
  if (!length(values) && is.null(styles) && is.null(merge)) {
    rlang::abort("Give cells and their values, such as `C4 = 1250`.", call = call)
  }
  ranges <- check_range_styles(styles, call)
  merges <- check_merge(merge, call)

  p <- new_cell_plan(sh$name)
  p$added <- sh$note
  for (k in seq_along(values)) {
    cl <- parse_cells(nm[[k]])
    if (is.null(cl) || cl[[1]] != cl[[3]] || cl[[2]] != cl[[4]]) {
      rlang::abort(c(
        paste0("`", nm[[k]], "` is not a cell; each value in `...` goes in one cell, such as `C4 = 1250`."),
        i = "A vector, matrix or data frame starts there and fills the cells below and to the right."
      ), call = call)
    }
    r <- cl[[1]]
    c <- cl[[2]]
    v <- values[[k]]
    what <- paste0("`", nm[[k]], "`")
    if (is.data.frame(v)) {
      add_table(p, v, r, c, "names", "labels", "", list(), list(columns = list()), NULL, TRUE, what, call)
    } else if (is.matrix(v)) {
      add_matrix(p, v, r, c, what, call)
    } else if (is.null(v) || (is.list(v) && !inherits(v, "POSIXlt")) || !vctrs::obj_is_vector(v)) {
      rlang::abort(c(
        paste0(what, " must be a value, a vector, a matrix or a data frame."),
        x = paste0("It is ", what_it_is(v), ".")
      ), call = call)
    } else if (!length(v)) {
      rlang::abort(paste0(what, " is empty; give it a value, or NA to empty the cell."), call = call)
    } else {
      check_fits(r, c, length(v), 1, what, call)
      add_vector(p, v, r, c, "labels", "", NULL, TRUE, what, call)
      p$pieces <- c(p$pieces, r - 1L, c - 1L, length(v), 1L, 0L)
    }
  }
  styled <- c(ranges, Filter(function(m) !is.null(m$style), merges))
  apply_edit_styles(p, styled)
  p$messages <- c(p$messages, percent_range_messages(p$blocks, styled))
  parts <- edit_parts(p, 0L, merges = merges)
  src <- where$full
  if (!where$exists) {
    src <- empty_workbook(sh$name, where$full, call)
    on.exit(unlink(src), add = TRUE)
  }
  run_edit(p, parts, path, where$full, call, src)
  invisible(path)
}

# `styles` for write_cells(): styles named by cell or range.
check_range_styles <- function(styles, call) {
  if (is.null(styles)) return(list())
  nm <- names(styles)
  if (!is.list(styles) || is_style(styles) || is.null(nm) || any(is.na(nm) | !nzchar(nm))) {
    rlang::abort("`styles` must be a list of styles named by cell or range, such as list(B2 = xl_style(bold = TRUE)).",
                 call = call)
  }
  lapply(seq_along(styles), function(k) {
    st <- styles[[k]]
    if (!is_style(st)) {
      rlang::abort(c(
        paste0("`styles$", code_name(nm[[k]]), "` must be a style from `xl_style()`."),
        x = paste0("It is ", what_it_is(st), ".")
      ), call = call)
    }
    cells <- parse_cells(nm[[k]])
    if (is.null(cells)) {
      rlang::abort(c(
        paste0("`styles` names ", dquote(nm[[k]]), ", which is not a cell or range."),
        i = "Name styles by cell or range, such as \"B2\" or \"A12:F12\"."
      ), call = call)
    }
    list(cells = cells, style = st, text = nm[[k]])
  })
}
