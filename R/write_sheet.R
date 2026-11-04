#' Write a table to one sheet of a workbook, keeping the rest of it
#'
#' Changes one sheet of an existing workbook and copies everything else in
#' the file as it was: other sheets, charts, images, comments, conditional
#' formats, data validation, defined names, pivot tables and macros. The
#' workbook is never rebuilt from what xlkit understands.
#'
#' Without `at`, the sheet's cells (with their values, formulas, formats
#' and merged ranges) are replaced by `x` from `A1`, with a bold header,
#' as [write_xlsx()] writes it. The sheet keeps its place among the tabs,
#' its column widths, frozen panes, tab color and print settings, and a
#' chart that plots it plots the new data.
#'
#' With `at`, only the cells `x` covers are written, and they keep their
#' formats unless `formats` or `styles` say otherwise (a date written into
#' a cell whose format does not show dates gets `yyyy-mm-dd`). If `at` is
#' the top-left cell of an Excel table, the table is resized to fit `x`
#' and takes its column names, and charts that plot the table's columns
#' follow it. Writing below an Excel table's body grows the table.
#'
#' A chart plots a fixed range; xlkit says when one plots a range that no
#' longer matches the rows written.
#'
#' A sheet the workbook does not have is added after the last tab, or
#' after `after`. A file that does not exist becomes a new workbook, as
#' [write_xlsx()] makes it. The workbook is marked so Excel recalculates
#' every formula when it opens the file.
#'
#' Nothing is written, and the file is left as it was, for `.xls`, `.xlsb`
#' and password-protected files, for worksheets whose XML xlkit cannot edit
#' safely, and for writes into part of an Excel table's header or inside a
#' merged range other than its top-left cell.
#'
#' The guide is <https://github.com/jbearak/xlkit/blob/main/docs/r.md>.
#'
#' @param x A data frame.
#' @param path An `.xlsx` or `.xlsm` file.
#' @param sheet The sheet's name (or the position of an existing sheet).
#' @param at `NULL` to replace the sheet's cells with `x` from `A1`; a cell
#'   such as `"H2"` to write `x` there and keep the other cells.
#' @param after For a new sheet, the sheet it goes after; `NULL` for after
#'   the last tab.
#' @param header,values,na As in [write_xlsx()].
#' @param formats Excel number formats by column name, such as
#'   `c(share = "0.0%")`.
#' @param styles A list of styles from [xl_style()], named by column (the
#'   column's body) or by a cell or range.
#' @return `path`, invisibly.
#' @seealso [write_cells()] to put values into cells, [write_xlsx()] for a
#'   new workbook.
#' @export
#' @examples
#' path <- file.path(tempdir(), "template.xlsx")
#' file.copy(xlkit_example("template.xlsx"), path, overwrite = TRUE)
#' new_data <- data.frame(month = month.abb, value = round(100 + 50 * sin(1:12)))
#' write_sheet(new_data, path, sheet = "Data")
#' write_sheet(head(mtcars[, 1:3]), path, sheet = "Data", at = "E2")
#' write_sheet(new_data, path, sheet = "Notes", after = "Cover")
#' xlsx_sheets(path)
write_sheet <- function(x, path, sheet, at = NULL, after = NULL, header = "names", values = "labels",
                        formats = NULL, styles = NULL, na = "") {
  call <- rlang::current_env()
  x_name <- rlang::caller_arg(x)
  if (!is.data.frame(x)) {
    rlang::abort(c(
      "`x` must be a data frame.",
      x = paste0("It is ", what_it_is(x), "."),
      i = "To put single values into cells, use `write_cells()`."
    ), call = call)
  }
  where <- check_edit_path(path, call)
  if (missing(sheet)) rlang::abort("`sheet` must be a sheet name, as one string.", call = call)
  args <- check_write_args(header, values, TRUE, FALSE, xl_style(bold = TRUE), 1, na, FALSE, call)
  of_x <- if (grepl("^[[:alnum:]._]+$", x_name)) paste0("of `", x_name, "`") else "of `x`"
  formats <- check_formats(formats, names(x), of_x, call)
  styles <- check_styles(styles, names(x), of_x, call)
  at_cell <- NULL
  if (!is.null(at)) {
    at_cell <- if (rlang::is_string(at)) parse_cells(at)
    if (is.null(at_cell) || at_cell[[1]] != at_cell[[3]] || at_cell[[2]] != at_cell[[4]]) {
      rlang::abort(c(
        "`at` must be the cell where the table starts, such as \"H2\", or NULL.",
        x = paste0("It is ", paste(deparse(at), collapse = " "), ".")
      ), call = call)
    }
  }
  sheets <- function(name) list(list(name = name, tables = list(list(df = x, title = NULL))))
  widths <- list(all = NA_real_, by = list())

  if (!where$exists && is.null(at)) {
    if (!rlang::is_string(sheet)) rlang::abort("`sheet` must be a sheet name, as one string.", call = call)
    check_sheet_names(sheet, call)
    plan <- plan_workbook(sheets(sheet), args, formats, widths, styles, list(), call)
    for (m in plan$messages) rlang::inform(m)
    if (!is.null(plan$warning)) rlang::warn(plan$warning)
    write_plan(plan, path, where$full, FALSE, call)
    return(invisible(path))
  }
  info <- if (where$exists) workbook_info(where$full, call) else NULL
  sh <- check_edit_sheet(sheet, info, path, call)
  after <- if (sh$new) check_after(after, info, path, call) else NA_character_

  if (is.null(at)) {
    plan <- plan_workbook(sheets(sh$name), args, formats, widths, styles, list(), call)
    for (m in plan$messages) rlang::inform(m)
    if (!is.null(plan$warning)) rlang::warn(plan$warning)
    parts <- plan$parts
    blocks <- matrix(parts[[10]], nrow = 4)
    n_cells <- length(parts[[11]])
    n_header <- switch(if (isFALSE(args$header)) "none" else args$header, none = 0L, names = 1L, labels = 1L, both = 2L)
    # Each column's date class, so Rust counts its dates in the workbook's
    # date system. The first blocks are the columns, header cells first.
    dclass <- integer(n_cells)
    starts <- cumsum(c(0L, blocks[4, ]))
    for (j in seq_along(x)) {
      dclass[starts[[j]] + n_header + seq_len(nrow(x))] <- date_class(x[[j]])
    }
    p <- new_cell_plan(sh$name)
    p$added <- sh$note
    edit <- c(parts[1:4], list(
      enc2utf8(c(sh$name, after)),
      as.integer(c(1L, parts[[6]][1:2])),
      as.integer(parts[[7]][c(FALSE, TRUE)]),
      parts[[8]],
      integer(),
      as.integer(blocks[-1, , drop = FALSE]),
      parts[[11]],
      parts[[12]],
      dclass,
      parts[[13]],
      parts[[14]],
      as.integer(c(0L, 0L, n_header + nrow(x), length(x), n_header))
    ))
    run_edit(p, edit, path, where$full, call)
    return(invisible(path))
  }

  p <- new_cell_plan(sh$name)
  p$added <- sh$note
  add_table(p, x, at_cell[[1]], at_cell[[2]], args$header, args$values, args$na, formats, styles, NULL,
            TRUE, "`x`", call)
  apply_edit_styles(p, styles$ranges)
  parts <- edit_parts(p, 0L, after)
  src <- where$full
  if (!where$exists) {
    src <- empty_workbook(sh$name, where$full, call)
    on.exit(unlink(src), add = TRUE)
  }
  run_edit(p, parts, path, where$full, call, src)
  invisible(path)
}
