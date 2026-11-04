#' Write data frames to a new .xlsx workbook
#'
#' Writes one data frame to a sheet, several to one sheet each, or
#' several stacked on one sheet with titles. The defaults are for a table
#' someone will read: a bold header row that stays in view when
#' scrolling, and each column as wide as its contents, up to 60
#' characters. `write_xlsx()` never replaces a file unless
#' `replace = TRUE`.
#'
#' Each column type becomes:
#'
#' | R type | in Excel |
#' |---|---|
#' | integer, double | a number; `NaN` and `Inf` are blank with a warning |
#' | character | text |
#' | logical | `TRUE` or `FALSE` |
#' | `Date` | a date, shown `yyyy-mm-dd` |
#' | `POSIXct` | a date-time on the clock of its time zone, shown `yyyy-mm-dd hh:mm:ss` |
#' | `hms`, `difftime` | a time, shown `hh:mm:ss` (`[h]:mm:ss` when one is 24 hours or more) |
#' | factor | its labels, as text |
#' | dtaparser or haven labelled | its value labels, as text; a code without a label is written as the code, with a message |
#' | [xl_formula()] | formulas |
#' | list | an error naming the column |
#'
#' `NA` is a blank cell. Text is always written as text: `"=A1+1"` is not
#' a formula and `"https://..."` is not a link unless marked with
#' [xl_formula()].
#'
#' Excel's limits are errors that say which value broke them: more than
#' 1,048,576 rows or 16,384 columns on a sheet, text longer than 32,767
#' characters, dates before 1900, and sheet names longer than 31
#' characters, holding `[ ] : * ? / \`, or the same as another apart
#' from case. Every argument is checked before anything is written.
#'
#' The guide, with every message and what to do about it, is
#' <https://github.com/jbearak/xlkit/blob/main/docs/r.md>.
#'
#' @param x A data frame; a named list of data frames, one sheet each; or
#'   a named list whose elements are lists of data frames, stacked on one
#'   sheet with their names as titles above them (an unnamed one gets no
#'   title). Sheets in one call can mix both forms.
#' @param path The `.xlsx` file to write.
#' @param sheet The sheet's name when `x` is one data frame.
#' @param header `"names"` for the column names, `"labels"` for the
#'   variable labels (the `label` attribute, or the name where a column
#'   has none), `"both"` for two header rows (names, then labels), or
#'   `FALSE` for no header row.
#' @param values For labelled columns: `"labels"` writes the value labels
#'   as text, `"codes"` the codes.
#' @param formats Excel number formats by column name, such as
#'   `c(share = "0.0%", amount = "#,##0")`. The values are unchanged;
#'   only how Excel shows them.
#' @param widths `"auto"` fits each column to its contents, up to 60
#'   characters; one number sets every column; numbers named by column,
#'   such as `c(notes = 80)`, set those and fit the rest.
#' @param freeze `TRUE` keeps the header row in view (on a sheet with one
#'   table); `FALSE` does not; a cell such as `"B2"` freezes the rows above
#'   it and the columns left of it.
#' @param filter `TRUE` adds filter buttons to the header row. Excel
#'   allows one filter per sheet, so it needs one table on each sheet.
#' @param header_style The header cells' style, from [xl_style()]; `NULL`
#'   for plain.
#' @param styles A list of styles from [xl_style()], named by column (the
#'   column's body) or by a cell or range such as `"A12:F12"`.
#' @param merge Ranges to merge, such as `"A1:F1"`, or a list of styles
#'   named by the ranges to merge, `list("A1:F1" = xl_style(align =
#'   "center"))`. Excel keeps only a merged range's top-left value, so
#'   the other cells must be empty.
#' @param gap Blank rows between tables on one sheet.
#' @param na Text to write for `NA`; `""` leaves the cell empty.
#' @param replace `TRUE` replaces `path` if it exists; `FALSE` stops
#'   instead. The new file is written beside the old one and moved over
#'   it, so an error leaves the old file as it was.
#' @return `path`, invisibly.
#' @seealso [xl_style()], [xl_formula()], [read_xlsx()]
#' @export
#' @examples
#' scores <- read_xlsx(xlkit_example("report.xlsx"))
#' path <- file.path(tempdir(), "scores.xlsx")
#' write_xlsx(scores, path, sheet = "Scores", replace = TRUE)
#' read_xlsx(path)
#'
#' sales <- read_xlsx(xlkit_example("sales.xlsx"), sheet = "Sales 2024", header = 5)
#' write_xlsx(
#'   list(Sales = sales, Tables = list("Units" = sales[1:3, 1:3], "Amounts" = sales[1:3, c(1, 4)])),
#'   file.path(tempdir(), "sales.xlsx"),
#'   formats = c(share = "0.0%", amount = "#,##0"),
#'   styles = list(region = xl_style(bold = TRUE)),
#'   replace = TRUE
#' )
write_xlsx <- function(x, path, sheet = "Sheet1", header = "names", values = "labels",
                       formats = NULL, widths = "auto", freeze = TRUE, filter = FALSE,
                       header_style = xl_style(bold = TRUE), styles = NULL, merge = NULL,
                       gap = 1, na = "", replace = FALSE) {
  call <- rlang::current_env()
  x_name <- rlang::caller_arg(x)
  full <- check_write_path(path, call)
  args <- check_write_args(header, values, freeze, filter, header_style, gap, na, replace, call)
  sheets <- collect_sheets(x, sheet, !missing(sheet), call)
  check_sheet_names(vapply(sheets, `[[`, "", "name"), call)

  columns <- unique(unlist(lapply(sheets, function(s) lapply(s$tables, function(t) names(t$df)))))
  of_x <- if (is.data.frame(x) && grepl("^[[:alnum:]._]+$", x_name)) paste0("of `", x_name, "`") else "of any table in `x`"
  formats <- check_formats(formats, columns, of_x, call)
  widths <- check_widths(widths, columns, of_x, call)
  styles <- check_styles(styles, columns, of_x, call)
  merges <- check_merge(merge, call)
  if (isTRUE(args$filter)) {
    if (isFALSE(args$header)) {
      rlang::abort("`filter = TRUE` needs a header row for its buttons, and `header = FALSE` writes none.", call = call)
    }
    for (s in sheets) {
      if (length(s$tables) > 1) {
        rlang::abort(c(
          paste0("`filter = TRUE` needs one table per sheet, and sheet ", dquote(s$name), " has ",
                 length(s$tables), "."),
          i = "Excel allows one filter per sheet. Write the tables to sheets of their own, or leave `filter = FALSE`."
        ), call = call)
      }
    }
  }

  if (file.exists(full) && !replace) existing_file(path, full, call)

  plan <- plan_workbook(sheets, args, formats, widths, styles, merges, call)
  write_plan(plan, path, full, call)
  for (m in plan$messages) rlang::inform(m)
  if (!is.null(plan$warning)) rlang::warn(plan$warning)
  invisible(path)
}

check_write_path <- function(path, call) {
  if (!rlang::is_string(path) || !nzchar(path)) {
    rlang::abort("`path` must be the path of an .xlsx file, as one string.", call = call)
  }
  if (!grepl("[.]xlsx$", path, ignore.case = TRUE)) {
    rlang::abort(c(
      paste0("`path` must end in .xlsx, and ", basename(path), " does not."),
      i = "xlkit writes .xlsx workbooks; Excel will not open one with another extension."
    ), call = call)
  }
  full <- path.expand(path)
  if (dir.exists(full)) rlang::abort(paste0(path, " is a folder, not an .xlsx file."), call = call)
  if (!dir.exists(dirname(full))) {
    rlang::abort(c(
      paste0(path, " cannot be written: its folder, ", dirname(path), ", does not exist."),
      i = "Make the folder first, with `dir.create()`."
    ), call = call)
  }
  full
}

check_write_args <- function(header, values, freeze, filter, header_style, gap, na, replace, call) {
  if (!(isFALSE(header) || (rlang::is_string(header) && header %in% c("names", "labels", "both")))) {
    rlang::abort(c(
      "`header` must be \"names\", \"labels\", \"both\" or FALSE.",
      x = paste0("It is ", paste(deparse(header), collapse = " "), ".")
    ), call = call)
  }
  if (!(rlang::is_string(values) && values %in% c("labels", "codes"))) {
    rlang::abort("`values` must be \"labels\" or \"codes\".", call = call)
  }
  freeze_at <- NULL
  if (rlang::is_string(freeze)) {
    r <- tryCatch(parse_range(freeze, call = NULL), error = function(e) NULL)
    if (is.null(r) || is.null(r$form) || is.na(r$form) || r$form != "corner" || !is.null(r$sheet)) {
      rlang::abort(c(
        "`freeze` must be TRUE, FALSE or a cell such as \"B2\".",
        x = paste0("It is ", dquote(freeze), ".")
      ), call = call)
    }
    freeze_at <- c(r$r1, r$c1)
  } else if (!rlang::is_bool(freeze)) {
    rlang::abort("`freeze` must be TRUE, FALSE or a cell such as \"B2\".", call = call)
  }
  if (!rlang::is_bool(filter)) rlang::abort("`filter` must be TRUE or FALSE.", call = call)
  if (!is.null(header_style) && !is_style(header_style)) {
    rlang::abort("`header_style` must be a style from `xl_style()`, or NULL for plain.", call = call)
  }
  if (!(is.numeric(gap) && length(gap) == 1 && !is.na(gap) && gap >= 0 && gap == round(gap))) {
    rlang::abort("`gap` must be a number of blank rows: 0, 1, 2, ...", call = call)
  }
  if (!(is.character(na) && length(na) == 1 && !is.na(na))) {
    rlang::abort("`na` must be one string: \"\" for blank cells, or text such as \"NA\".", call = call)
  }
  if (!rlang::is_bool(replace)) rlang::abort("`replace` must be TRUE or FALSE.", call = call)
  list(header = header, values = values, freeze = freeze, freeze_at = freeze_at, filter = filter,
       header_style = header_style, gap = as.integer(gap), na = na)
}

what_it_is <- function(x) {
  if (is.null(x)) return("NULL")
  if (is.function(x)) return("a function")
  if (is.data.frame(x)) return("a data frame")
  if (is.list(x)) return("a list")
  cls <- class(x)[[1]]
  paste0(if (grepl("^[aeiouAEIOU]", cls)) "an " else "a ", cls, " vector")
}

# The sheets to write: list(name, tables = list(list(df, title))).
collect_sheets <- function(x, sheet, sheet_given, call) {
  if (is.data.frame(x)) {
    if (!rlang::is_string(sheet)) rlang::abort("`sheet` must be a sheet name, as one string.", call = call)
    return(list(list(name = sheet, tables = list(list(df = x, title = NULL)))))
  }
  if (!is.list(x) || is.object(x)) {
    rlang::abort(c(
      "`x` must be a data frame, or a named list of data frames.",
      x = paste0("It is ", what_it_is(x), ".")
    ), call = call)
  }
  if (sheet_given) {
    rlang::abort(c(
      "`sheet` names the sheet only when `x` is one data frame.",
      i = "The names of a list name its sheets: `list(Summary = summary, Detail = detail)`."
    ), call = call)
  }
  if (!length(x)) rlang::abort("`x` is an empty list; give a data frame, or a named list of them.", call = call)
  nm <- names(x)
  if (is.null(nm)) nm <- rep("", length(x))
  missing_name <- which(is.na(nm) | !nzchar(nm))
  if (length(missing_name)) {
    rlang::abort(c(
      paste0("Every sheet of `x` needs a name, and element ", missing_name[[1]], " has none."),
      i = "Name each sheet: `list(Summary = summary, Detail = detail)`.",
      i = "To stack tables on one sheet, put them in a list named by the sheet: `list(Results = list(means, counts))`."
    ), call = call)
  }
  lapply(seq_along(x), function(i) {
    e <- x[[i]]
    where <- paste0("`x$", code_name(nm[[i]]), "`")
    if (is.data.frame(e)) return(list(name = nm[[i]], tables = list(list(df = e, title = NULL))))
    ok <- is.list(e) && !is.object(e) && length(e) > 0 && all(vapply(e, is.data.frame, logical(1)))
    if (!ok) {
      what <- if (is.list(e) && !is.object(e) && length(e) == 0) "an empty list" else what_it_is(e)
      if (is.list(e) && !is.object(e) && length(e) > 0) {
        k <- which(!vapply(e, is.data.frame, logical(1)))[[1]]
        what <- paste0("a list whose element ", k, " is ", what_it_is(e[[k]]))
      }
      rlang::abort(c(
        paste0(where, " must be a data frame, or a list of data frames to stack on one sheet."),
        x = paste0("It is ", what, ".")
      ), call = call)
    }
    titles <- names(e)
    if (is.null(titles)) titles <- rep("", length(e))
    titles[is.na(titles)] <- ""
    list(name = nm[[i]], tables = lapply(seq_along(e), function(k) {
      list(df = e[[k]], title = if (nzchar(titles[[k]])) titles[[k]])
    }))
  })
}

# Excel's rules for sheet names: 1 to 31 characters, none of [ ] : * ? /
# \, not starting or ending with an apostrophe, not "History", and no two
# the same apart from case.
check_sheet_names <- function(names, call) {
  bad <- function(msg, name) {
    rlang::abort(c(msg, i = paste0("Use another name, such as ", dquote(valid_sheet_name(name, names)), ".")),
                 call = call)
  }
  for (k in seq_along(names)) {
    name <- names[[k]]
    if (is.na(name) || !nzchar(name)) rlang::abort("A sheet name must not be empty.", call = call)
    chars <- strsplit(name, "")[[1]]
    forbidden <- unique(chars[chars %in% c("[", "]", ":", "*", "?", "/", "\\")])
    if (length(forbidden)) {
      bad(paste0("Sheet name ", dquote(name), " has ", and_list(dquote(forbidden)),
                 ", which Excel does not allow in sheet names."), name)
    }
    if (nchar(name) > 31) {
      bad(paste0("Sheet name ", dquote(name), " has ", nchar(name),
                 " characters, which is more than the 31 Excel allows in sheet names."), name)
    }
    if (startsWith(name, "'") || endsWith(name, "'")) {
      bad(paste0("Sheet name ", dquote(name), " ", if (startsWith(name, "'")) "starts" else "ends",
                 " with \"'\", which Excel does not allow in sheet names."), name)
    }
    if (tolower(name) == "history") {
      bad(paste0("Sheet name ", dquote(name), " is one Excel keeps for itself, and does not allow."), name)
    }
    same <- which(tolower(names[seq_len(k - 1)]) == tolower(name))
    if (length(same)) {
      other <- names[[same[[1]]]]
      msg <- if (identical(other, name)) {
        paste0("Sheet name ", dquote(name), " is used twice, and Excel does not allow two sheets with one name.")
      } else {
        paste0("Sheet name ", dquote(name), " is the same as ", dquote(other),
               " apart from case, which Excel does not allow in sheet names.")
      }
      bad(msg, name)
    }
  }
}

# A name Excel allows, close to `name` and unlike the other names.
valid_sheet_name <- function(name, names) {
  s <- gsub("[\\[\\]:*?/\\\\]", "-", name, perl = TRUE)
  s <- gsub("^'+|'+$", "", s)
  s <- substr(s, 1, 31)
  if (!nzchar(s) || tolower(s) == "history") s <- paste0(substr(s, 1, 29), " 1")
  taken <- tolower(setdiff(names, name))
  if (tolower(name) %in% tolower(names[duplicated(tolower(names))])) taken <- c(taken, tolower(name))
  k <- 2
  base <- s
  while (tolower(s) %in% taken) {
    suffix <- paste0(" ", k)
    s <- paste0(substr(base, 1, 31 - nchar(suffix)), suffix)
    k <- k + 1
  }
  s
}

# The message for names in `formats`, `widths` or `styles` that are not
# columns.
not_columns <- function(arg, bad, columns, of_x, call, also = NULL) {
  shown <- paste0("`", bad, "`")
  which <- if (!is.null(also)) "is neither a column " else if (length(bad) == 1) "is not a column " else "are not columns "
  msg <- paste0("`", arg, "` names ", and_list(shown), ", which ", which, of_x, also, ".")
  guesses <- unlist(lapply(bad, function(b) closest(b, columns)))
  if (length(guesses)) msg <- c(msg, i = paste0("Did you mean ", and_list(paste0("`", guesses, "`")), "?"))
  rlang::abort(msg, call = call)
}

check_formats <- function(formats, columns, of_x, call) {
  if (is.null(formats)) return(list())
  if (is.list(formats)) {
    ok <- all(vapply(formats, rlang::is_string, logical(1)))
    if (ok) formats <- unlist(formats)
  }
  nm <- names(formats)
  if (!is.character(formats) || anyNA(formats) || is.null(nm) || any(is.na(nm) | !nzchar(nm)) ||
      any(!nzchar(formats))) {
    rlang::abort("`formats` must be number formats named by column, such as c(share = \"0.0%\", amount = \"#,##0\").",
                 call = call)
  }
  bad <- setdiff(nm, columns)
  if (length(bad)) not_columns("formats", bad, columns, of_x, call)
  as.list(formats)
}

check_widths <- function(widths, columns, of_x, call) {
  msg <- "`widths` must be \"auto\", one number for every column, or numbers named by column, such as c(notes = 80)."
  if (identical(widths, "auto")) return(list(all = NA_real_, by = list()))
  if (!is.numeric(widths) || anyNA(widths) || !length(widths)) rlang::abort(msg, call = call)
  if (any(widths <= 0 | widths > 255)) {
    rlang::abort(c(msg, x = "Excel's column widths run from 0 to 255 characters."), call = call)
  }
  nm <- names(widths)
  if (is.null(nm)) {
    if (length(widths) != 1) rlang::abort(msg, call = call)
    return(list(all = as.numeric(widths), by = list()))
  }
  if (any(is.na(nm) | !nzchar(nm))) rlang::abort(msg, call = call)
  bad <- setdiff(nm, columns)
  if (length(bad)) not_columns("widths", bad, columns, of_x, call)
  list(all = NA_real_, by = as.list(widths))
}

# Parse a cell or range for `styles` and `merge`: c(r1, c1, r2, c2), as
# Excel numbers them, or NULL.
parse_cells <- function(text) {
  r <- tryCatch(parse_range(text, call = NULL), error = function(e) NULL)
  if (is.null(r) || !is.null(r$name) || !is.null(r$sheet) || is.na(r$form)) return(NULL)
  if (r$form == "corner") return(c(r$r1, r$c1, r$r1, r$c1))
  if (r$form == "cells") return(c(r$r1, r$c1, r$r2, r$c2))
  NULL
}

check_styles <- function(styles, columns, of_x, call) {
  out <- list(columns = list(), ranges = list())
  if (is.null(styles)) return(out)
  nm <- names(styles)
  if (!is.list(styles) || is_style(styles) || is.null(nm) || any(is.na(nm) | !nzchar(nm))) {
    rlang::abort("`styles` must be a list of styles named by column or by range, such as list(region = xl_style(bold = TRUE)).",
                 call = call)
  }
  for (k in seq_along(styles)) {
    st <- styles[[k]]
    if (!is_style(st)) {
      rlang::abort(c(
        paste0("`styles$", code_name(nm[[k]]), "` must be a style from `xl_style()`."),
        x = paste0("It is ", what_it_is(st), ".")
      ), call = call)
    }
    key <- nm[[k]]
    if (key %in% columns) {
      out$columns[[key]] <- style_merge(out$columns[[key]], st)
      next
    }
    cells <- parse_cells(key)
    if (is.null(cells)) {
      not_columns("styles", key, columns, of_x, call, also = " nor a cell or range such as \"A2:F2\"")
    }
    out$ranges[[length(out$ranges) + 1]] <- list(cells = cells, style = st, text = key)
  }
  out
}

check_merge <- function(merge, call) {
  if (is.null(merge)) return(list())
  msg <- "`merge` must be ranges such as \"A1:F1\", or a list of styles named by range, such as list(\"A1:F1\" = xl_style(align = \"center\"))."
  if (is.character(merge) && !anyNA(merge) && is.null(names(merge))) {
    ranges <- merge
    merge_styles <- rep(list(NULL), length(merge))
  } else if (is.list(merge) && !is_style(merge) && !is.null(names(merge)) &&
             all(vapply(merge, function(s) is.null(s) || is_style(s), logical(1)))) {
    ranges <- names(merge)
    merge_styles <- unname(merge)
  } else {
    rlang::abort(msg, call = call)
  }
  out <- list()
  for (k in seq_along(ranges)) {
    cells <- parse_cells(ranges[[k]])
    if (is.null(cells)) {
      rlang::abort(c(msg, x = paste0(dquote(ranges[[k]]), " is not a range of cells.")), call = call)
    }
    if (cells[[1]] == cells[[3]] && cells[[2]] == cells[[4]]) {
      rlang::abort(c(
        paste0("`merge` has ", dquote(ranges[[k]]), ", which is one cell."),
        i = "Give the range to merge, such as \"A1:F1\"."
      ), call = call)
    }
    for (m in out) {
      overlap <- cells[[1]] <= m$cells[[3]] && m$cells[[1]] <= cells[[3]] &&
        cells[[2]] <= m$cells[[4]] && m$cells[[2]] <= cells[[4]]
      if (overlap) {
        rlang::abort(paste0("`merge` ranges ", dquote(m$text), " and ", dquote(ranges[[k]]),
                            " overlap, which Excel does not allow."), call = call)
      }
    }
    out[[length(out) + 1]] <- list(cells = cells, style = merge_styles[[k]], text = ranges[[k]])
  }
  out
}

# The error when `path` exists and `replace = FALSE`, naming its sheets.
existing_file <- function(path, full, call) {
  file <- basename(path)
  sheets <- tryCatch({
    head <- readBin(full, "raw", 4)
    if (identical(head, as.raw(c(0x50, 0x4b, 0x03, 0x04)))) workbook_info(full, call)$names
  }, error = function(e) NULL)
  first <- if (length(sheets)) {
    paste0(file, " already exists, with ", if (length(sheets) == 1) "sheet " else "sheets ",
           and_list(dquote(sheets)), ".")
  } else {
    paste0(file, " already exists.")
  }
  rlang::abort(c(
    first,
    i = "To replace the whole workbook, use `replace = TRUE`.",
    i = "To change one sheet and keep the rest, use `write_sheet()` or `write_cells()`."
  ), call = call)
}

# Write the plan to a temporary file beside `full`, then move it over
# `full`, so an error leaves an existing file as it was (ADR 0005).
write_plan <- function(plan, path, full, call) {
  tmp <- tempfile(paste0(".", basename(full), "-"), tmpdir = dirname(full), fileext = ".tmp")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  res <- .Call(C_xl_write, enc2utf8(tmp), plan$parts)
  if (!is.null(res$status)) {
    file <- basename(path)
    msg <- switch(as.character(res$status),
      "11" = paste0(file, " could not be written: ", res$message, "."),
      c(paste0("xlkit's writer failed on ", file, ": ", res$message, "."),
        i = "Please report this at <https://github.com/jbearak/xlkit/issues>.")
    )
    rlang::abort(msg, call = call)
  }
  why <- NULL
  ok <- withCallingHandlers(
    file.rename(tmp, full),
    warning = function(w) {
      why <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  if (!ok) {
    file <- basename(path)
    if (.Platform$OS.type == "windows") {
      rlang::abort(c(
        paste0(file, " is open in Excel, or another program is using it, so it cannot be replaced."),
        i = "Close it in Excel and run again."
      ), call = call)
    }
    rlang::abort(paste0(file, " could not be replaced", if (!is.null(why)) paste0(": ", why), "."), call = call)
  }
}
