# Writing into an existing workbook (ADR 0006): the checks, the plan of
# cells R hands to Rust (src/rust/src/edit.rs), and the messages for what
# Rust reports. Rows and columns are counted from 0 in the plan and from 1
# (as Excel shows them) everywhere else.

# Where the workbook is: list(full, exists, ext). Stops for formats xlkit
# cannot edit, before anything is written.
check_edit_path <- function(path, call) {
  if (!rlang::is_string(path) || !nzchar(path)) {
    rlang::abort("`path` must be the path of an .xlsx file, as one string.", call = call)
  }
  file <- basename(path)
  ext <- tolower(sub("^.*[.]", "", file))
  if (!grepl(".", file, fixed = TRUE)) ext <- ""
  if (ext %in% c("xls", "xlsb")) {
    rlang::abort(c(
      paste0(file, " is an .", ext, " workbook, and xlkit edits only .xlsx and .xlsm workbooks."),
      i = "Open it in Excel and save it as an Excel Workbook (.xlsx), then write to that file."
    ), call = call)
  }
  if (!ext %in% c("xlsx", "xlsm")) {
    rlang::abort(c(
      paste0("`path` must end in .xlsx or .xlsm, and ", file, " does not."),
      i = "xlkit edits .xlsx and .xlsm workbooks."
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
  exists <- file.exists(full)
  if (exists) {
    head <- readBin(full, "raw", 512)
    zip <- as.raw(c(0x50, 0x4b, 0x03, 0x04))
    if (!(length(head) >= 4 && identical(head[1:4], zip))) {
      if (length(head) >= 4 && identical(head[1:4], as.raw(c(0xd0, 0xcf, 0x11, 0xe0)))) {
        rlang::abort(c(
          paste0(file, " is password-protected (or an .xls workbook named .", ext,
                 "), and xlkit cannot edit it. Nothing was written."),
          i = "Save a copy without a password in Excel (File > Info > Protect Workbook), and write to that."
        ), call = call)
      }
      rlang::abort(paste0(file, " is not an .xlsx workbook (", what_file(head), "). Nothing was written."),
                   call = call)
    }
  } else if (ext == "xlsm") {
    rlang::abort(c(
      paste0(path, " does not exist, and xlkit makes new workbooks only as .xlsx."),
      i = "Give a path ending in .xlsx."
    ), call = call)
  }
  list(full = full, exists = exists)
}

# The sheet to write: its name, and whether the workbook has it. A number
# picks an existing sheet by position.
check_edit_sheet <- function(sheet, info, path, call) {
  names <- if (is.null(info)) character() else info$names
  if (is.numeric(sheet) && length(sheet) == 1 && !is.na(sheet) && sheet == round(sheet)) {
    if (sheet < 1 || sheet > length(names)) {
      rlang::abort(paste0("`sheet = ", sheet, "`, but ", basename(path), " has ",
                          length(names), if (length(names) == 1) " sheet." else " sheets."), call = call)
    }
    sheet <- names[[sheet]]
  }
  if (!rlang::is_string(sheet) || !nzchar(sheet)) {
    rlang::abort("`sheet` must be a sheet name, as one string.", call = call)
  }
  hit <- match(tolower(sheet), tolower(names))
  if (!is.na(hit)) {
    if (info$types[[hit]] != "worksheet") {
      rlang::abort(c(
        paste0("Sheet ", dquote(names[[hit]]), " of ", basename(path), " is a chart sheet, and xlkit writes only worksheets."),
        i = "Write to another sheet, or give a new name to add one."
      ), call = call)
    }
    return(list(name = names[[hit]], new = FALSE))
  }
  check_sheet_names(c(sheet), call)
  list(name = sheet, new = TRUE)
}

check_after <- function(after, info, path, call) {
  if (is.null(after)) return(NA_character_)
  names <- if (is.null(info)) character() else info$names
  if (is.numeric(after) && length(after) == 1 && !is.na(after) && after >= 1 && after <= length(names)) {
    return(names[[after]])
  }
  if (!rlang::is_string(after)) rlang::abort("`after` must be a sheet name, as one string, or NULL.", call = call)
  hit <- match(tolower(after), tolower(names))
  if (is.na(hit)) {
    msg <- paste0(basename(path), " has no sheet ", dquote(after), " to put the new sheet after.")
    guess <- closest(after, names)
    if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", dquote(guess), "?"))
    if (length(names)) msg <- c(msg, i = paste0("Its sheets are ", and_list(dquote(names)), "."))
    rlang::abort(msg, call = call)
  }
  names[[hit]]
}

# Excel's date class of a column: 2 date, 3 date-time, 4 time, 5 a
# duration of 24 hours or more, 0 none. A cell whose format does not show
# its class gets a format that does (see edit.rs).
date_class <- function(x) {
  if (inherits(x, "Date")) return(2L)
  if (inherits(x, "POSIXt")) return(3L)
  if (inherits(x, "difftime")) {
    secs <- as.numeric(x, units = "secs")
    return(if (any(abs(secs[is.finite(secs)]) >= 86400)) 5L else 4L)
  }
  0L
}

# A new plan of cells to write into one sheet.
new_cell_plan <- function(sheet) {
  p <- new.env(parent = emptyenv())
  p$sheet <- sheet
  p$reg <- new_registry()
  p$blocks <- list()
  p$pieces <- integer()
  p$messages <- list()
  p$nonfinite <- character()
  p
}

# Add a column of cells from `cells` (column_cells_out()) at Excel's
# (row, col), with one format id and date class per cell.
add_cells <- function(p, row, col, kind, num, str, fmt, dclass) {
  p$blocks[[length(p$blocks) + 1]] <- list(row = row, col = col, kind = kind, num = num, str = str,
                                          fmt = fmt, dclass = dclass)
}

# The checks write_xlsx() makes on a column's cells, naming cells as
# Excel shows them.
check_cells <- function(p, cells, x, what, rows, col, call) {
  if (length(cells$too_early)) {
    bad <- cells$too_early
    rlang::abort(c(
      paste0(what, " has dates Excel cannot hold, which shows only 1900-01-01 to 9999-12-31: ",
             and_list_first(paste0(cell_ref(rows[bad], col), " (", format(x[bad]), ")")), "."),
      i = "Write them as text instead, with `format()`, or leave them out."
    ), call = call)
  }
  is_text <- cells$kind == W_TEXT | cells$kind == W_FORMULA
  cells$str[is_text] <- enc2utf8(cells$str[is_text])
  invalid <- which(is_text & !validUTF8(cells$str))
  if (length(invalid)) {
    rlang::abort(c(
      paste0(what, " has text that is not valid in its encoding: ", and_list_first(cell_ref(rows[invalid], col)), "."),
      i = "Fix its encoding first, such as with `iconv(x, from = \"latin1\", to = \"UTF-8\")`."
    ), call = call)
  }
  units <- text_units(cells$str)
  long <- which(cells$kind == W_TEXT & units > excel_text_max)
  if (length(long)) {
    rlang::abort(c(
      paste0(what, " has text longer than the 32,767 characters a cell holds: ",
             and_list_first(paste0(cell_ref(rows[long], col), " (", fmt_count(units[long]), " characters)")), "."),
      i = "Shorten it, such as with `substr(x, 1, 32767)`, or split it across cells."
    ), call = call)
  }
  if (length(cells$nonfinite)) {
    bad <- cells$nonfinite
    p$nonfinite <- c(p$nonfinite, paste0(cell_ref(rows[bad], col), " (", cells$str[bad], ")"))
  }
  cells
}

check_fits <- function(row, col, nrow, ncol, what, call) {
  if (row + nrow - 1 > max_row) {
    rlang::abort(c(
      paste0(what, " has ", fmt_count(nrow), " rows, which from row ", fmt_count(row),
             " would go past Excel's last row, 1,048,576."),
      i = "Split it across sheets, or start it higher up."
    ), call = call)
  }
  if (col + ncol - 1 > max_col) {
    rlang::abort(c(
      paste0(what, " has ", fmt_count(ncol), " columns, which from column ", col_letters(col),
             " would go past Excel's last column, XFD."),
      i = "Split it across sheets, or start it further left."
    ), call = call)
  }
}

# One vector down a column from (row, col). `overlay` is a style for every
# cell (or NULL), `keep_dates` whether cells keep their formats (giving
# dates a date format only where theirs shows none).
add_vector <- function(p, x, row, col, values, na, overlay, keep_dates, what, call) {
  if ((is.list(x) && !inherits(x, "POSIXlt")) || is.data.frame(x)) {
    rlang::abort(c(
      paste0(what, " is ", what_it_is(x), ", and a cell holds one value."),
      i = "Turn it into numbers or text first, or leave it out."
    ), call = call)
  }
  cells <- column_cells_out(x, values, na)
  rows <- row + seq_along(x) - 1
  cells <- check_cells(p, cells, x, what, rows, col, call)
  if (!is.null(cells$unlabelled)) {
    p$messages[[length(p$messages) + 1]] <- unlabelled_message(
      sub("^`|`$", "", what), cells$unlabelled, cell_ref(rows[cells$unlabelled$rows], col), identity
    )
  }
  style <- if (keep_dates) overlay else style_merge(if (!is.null(cells$format)) xl_style(format = cells$format), overlay)
  id <- format_id(p$reg, style)
  dc <- if (keep_dates) date_class(x) else 0L
  add_cells(p, row, col, cells$kind, cells$num, cells$str, rep(id, length(x)), rep(dc, length(x)))
  cells
}

# A data frame from (row, col) with its header rows. Returns the piece.
add_table <- function(p, df, row, col, header, values, na, formats, styles, header_style, keep_dates,
                      what, call) {
  n_header <- switch(if (isFALSE(header)) "none" else header, none = 0L, names = 1L, labels = 1L, both = 2L)
  check_fits(row, col, n_header + nrow(df), length(df), what, call)
  header_id <- format_id(p$reg, header_style)
  nm <- names(df)
  widths <- numeric(length(df))
  for (j in seq_along(df)) {
    x <- df[[j]]
    name <- nm[[j]]
    if (is.matrix(x)) {
      rlang::abort(c(
        paste0("`", name, "` is a matrix column, and a cell holds one value."),
        i = "Turn it into numbers or text first, or leave it out."
      ), call = call)
    }
    c0 <- col + j - 1
    header_text <- switch(if (n_header == 0) "none" else header,
      none = character(),
      names = name,
      labels = var_label(x, name),
      both = c(name, var_label(x, NA_character_))
    )
    for (h in header_text) {
      if (!is.na(h)) check_text_length(h, paste0("The header of `", name, "`"), cell_ref(row, c0), call)
    }
    if (length(header_text)) {
      kind <- ifelse(is.na(header_text) | !nzchar(header_text), W_BLANK, W_TEXT)
      add_cells(p, row, c0, kind, rep(NA_real_, length(header_text)), header_text,
                rep(header_id, length(header_text)), rep(0L, length(header_text)))
    }
    numfmt <- formats[[name]]
    overlay <- style_merge(if (!is.null(numfmt)) xl_style(format = numfmt), styles$columns[[name]])
    cells <- add_vector(p, x, row + n_header, c0, values, na, overlay, keep_dates, paste0("`", name, "`"), call)
    hw <- if (length(header_text)) max(nchar(header_text, type = "width"), 0, na.rm = TRUE) else 0
    if (isTRUE(header_style$bold)) hw <- hw * 1.1
    shown <- if (!is.null(styles$columns[[name]]$format)) styles$columns[[name]]$format else
      if (!is.null(numfmt)) numfmt else cells$format
    widths[[j]] <- max(hw, cells_width(cells, shown))
  }
  p$pieces <- c(p$pieces, row - 1L, col - 1L, n_header + nrow(df), length(df), n_header)
  widths
}

# A matrix from (row, col): its column names as a header row and its row
# names as a first column, when it has them.
add_matrix <- function(p, m, row, col, what, call) {
  rn <- rownames(m)
  cn <- colnames(m)
  r0 <- row + !is.null(cn)
  c0 <- col + !is.null(rn)
  check_fits(row, col, nrow(m) + !is.null(cn), ncol(m) + !is.null(rn), what, call)
  if (!is.null(cn)) {
    for (j in seq_along(cn)) {
      add_cells(p, row, c0 + j - 1, if (nzchar(cn[[j]])) W_TEXT else W_BLANK, NA_real_, cn[[j]], -1L, 0L)
    }
  }
  if (!is.null(rn)) add_vector(p, rn, r0, col, "labels", "", NULL, TRUE, what, call)
  for (j in seq_len(ncol(m))) {
    x <- m[, j]
    attributes(x) <- NULL
    if (is.factor(m)) x <- as.character(m[, j])
    add_vector(p, x, r0, c0 + j - 1, "labels", "", NULL, TRUE, what, call)
  }
  p$pieces <- c(p$pieces, row - 1L, col - 1L, nrow(m) + !is.null(cn), ncol(m) + !is.null(rn), as.integer(!is.null(cn)))
}

# Styles by range (and merged ranges' styles): over the cells written in
# them, and given to the other cells of the range as a style only.
apply_edit_styles <- function(p, ranges) {
  for (rs in ranges) {
    cl <- rs$cells
    covered <- vector("list", cl[[4]] - cl[[2]] + 1)
    for (b in seq_along(p$blocks)) {
      blk <- p$blocks[[b]]
      if (blk$col < cl[[2]] || blk$col > cl[[4]] || !length(blk$kind)) next
      rows <- blk$row + seq_along(blk$kind) - 1
      hit <- which(rows >= cl[[1]] & rows <= cl[[3]])
      if (!length(hit)) next
      old <- blk$fmt[hit]
      u <- unique(old)
      new <- vapply(u, function(id) format_id(p$reg, style_merge(format_style(p$reg, id), rs$style)), integer(1))
      p$blocks[[b]]$fmt[hit] <- new[match(old, u)]
      k <- blk$col - cl[[2]] + 1
      covered[[k]] <- c(covered[[k]], rows[hit])
    }
    id <- format_id(p$reg, rs$style)
    for (k in seq_along(covered)) {
      missing <- setdiff(seq(cl[[1]], cl[[3]]), covered[[k]])
      if (!length(missing)) next
      runs <- split(missing, cumsum(c(1, diff(missing) != 1)))
      for (r in runs) {
        n <- length(r)
        add_cells(p, r[[1]], cl[[2]] + k - 1, rep(W_STYLE, n), rep(NA_real_, n), rep(NA_character_, n),
                  rep(id, n), rep(0L, n))
      }
    }
  }
}

W_STYLE <- 5L

# The plan's parts, in the order src/init.c reads them (`E_*`).
edit_parts <- function(p, mode, after = NA_character_, freeze = c(-1L, -1L), widths = NULL,
                       merges = list()) {
  blocks <- Filter(function(b) length(b$kind) > 0, p$blocks)
  kinds <- unlist(lapply(blocks, `[[`, "kind"), use.names = FALSE)
  nums <- unlist(lapply(blocks, function(b) b$num[b$kind == W_NUMBER | b$kind == W_BOOL]), use.names = FALSE)
  strs <- unlist(lapply(blocks, function(b) b$str[b$kind == W_TEXT | b$kind == W_FORMULA]), use.names = FALSE)
  c(format_parts(p$reg), list(
    enc2utf8(c(p$sheet, after)),
    as.integer(c(mode, freeze)),
    as.integer(if (is.null(widths)) integer() else seq_along(widths) - 1L),
    as.double(if (is.null(widths)) numeric() else widths),
    as.integer(unlist(lapply(merges, function(m) m$cells - 1L))),
    as.integer(unlist(lapply(blocks, function(b) c(b$row - 1L, b$col - 1L, length(b$kind))), use.names = FALSE)),
    as.integer(if (is.null(kinds)) integer() else kinds),
    as.integer(unlist(lapply(blocks, `[[`, "fmt"), use.names = FALSE)),
    as.integer(unlist(lapply(blocks, `[[`, "dclass"), use.names = FALSE)),
    as.double(if (is.null(nums)) numeric() else nums),
    as.character(if (is.null(strs)) character() else strs),
    as.integer(p$pieces)
  ))
}

# Say what the plan found, then write it into the workbook `src` (`full`,
# or an empty workbook when `full` does not exist yet) through a temporary
# file beside `full`, which then replaces it. Raises the error for a
# failure, and says which charts no longer match.
run_edit <- function(p, parts, path, full, call, src = full) {
  if (length(p$nonfinite)) {
    n <- length(p$nonfinite)
    rlang::warn(c(
      paste0(fmt_count(n), if (n == 1) " cell holds" else " cells hold",
             " NaN or Inf, which Excel cannot store, and ", if (n == 1) "is" else "are", " blank: ",
             and_list_first(p$nonfinite), "."),
      i = "Replace them with numbers or NA first if they mean something else."
    ))
  }
  for (m in p$messages) rlang::inform(m)
  tmp <- tempfile(paste0(".", basename(full), "-"), tmpdir = dirname(full), fileext = ".tmp")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  res <- .Call(C_xl_edit, enc2utf8(src), enc2utf8(tmp), parts)
  if (!is.null(res$status)) edit_failed(res, path, p$sheet, call)
  move_over(tmp, full, path, call)
  s <- res$strings
  for (k in seq_len(length(s) %/% 3)) {
    chart <- s[[3 * k - 2]]
    rows <- as.integer(s[[3 * k]])
    rlang::inform(c(
      paste0("A chart plots ", chart, ", which no longer matches the ", fmt_count(rows),
             if (rows == 1) " row" else " rows", " written to ", s[[3 * k - 1]], "."),
      i = "To have the chart follow the data, make it plot an Excel table, and write into the table at its top-left cell with `at =`."
    ))
  }
  invisible()
}

refusal_reasons <- c(
  "namespace-prefixed-worksheet-element" = "its cells use a namespace prefix that is not bound to SpreadsheetML",
  "markup-compatibility-alternate-content" = "its cells are inside markup-compatibility alternatives (mc:AlternateContent), and which one applies is the reading program's choice",
  "foreign-worksheet-namespace" = "its XML is not in a SpreadsheetML namespace",
  "missing-cell-reference" = "a cell has no reference (r), so only the order of the cells says where it is",
  "invalid-cell-reference" = "a cell's reference (r) is not one Excel writes, such as A01 or a1"
)

grouped_what <- c(shared = "a shared formula", array = "an array formula", dataTable = "a data table")

# Raise the error for a failed edit. Nothing was written: the workbook is
# replaced only after the edit succeeds.
edit_failed <- function(res, path, sheet, call) {
  file <- basename(path)
  part <- strsplit(res$message, "\t", fixed = TRUE)[[1]]
  where <- paste0("Sheet ", dquote(sheet), " of ", file)
  nothing <- "Nothing was written."
  msg <- switch(as.character(res$status),
    "1" = paste0(file, " could not be opened: ", res$message, "."),
    "2" = paste0(file, " is not an .xlsx workbook (it is not a zip archive that can be read: ", res$message, ")."),
    "3" = paste0(file, " is not an .xlsx workbook (", res$message, ")."),
    "5" = paste0(file, " could not be read: ", res$message, "."),
    "7" = c(paste0("Sheet ", dquote(res$message), " of ", file, " is a chart sheet, and xlkit writes only worksheets."),
            i = "Write to another sheet, or give a new name to add one."),
    "11" = paste0(file, " could not be written: ", res$message, "."),
    "21" = c(paste0(where, ": cannot edit this worksheet: ", refusal_reasons[[res$message]], ". ", nothing),
             i = "Open the file in Excel and save it, then try again."),
    "29" = c(paste0(where, ": cannot edit this worksheet: it has no cell data (sheetData). ", nothing),
             i = "Open the file in Excel and save it, then try again."),
    "22" = c(paste0(part[[1]], " is inside the merged range ", part[[2]], ", which shows only its top-left cell, ",
                    sub(":.*", "", part[[2]]), ". ", nothing),
             i = paste0("Write to ", sub(":.*", "", part[[2]]), ", or unmerge the range in Excel first.")),
    "23" = c(paste0(part[[1]], " is part of ", grouped_what[[part[[2]]]], " over ", part[[3]],
                    ", and writing there would break the formulas of its other cells. ", nothing),
             i = "Write to other cells, or turn the formulas into values or plain formulas in Excel first."),
    "24" = c(paste0(part[[1]], " is in the header row of Excel table ", dquote(part[[2]]), " (", part[[3]],
                    "), and writing it would leave the table's column names wrong. ", nothing),
             i = paste0("To replace the table, write a data frame at its top-left cell: `write_sheet(x, path, sheet, at = \"",
                        sub(":.*", "", part[[3]]), "\")`.")),
    "25" = if (identical(part[[3]], "totals")) {
      c(paste0("Excel table ", dquote(part[[1]]), " (", part[[2]], ") has a totals row, which xlkit cannot move. ", nothing),
        i = "Turn off the totals row in Excel (Table Design > Total Row), or write elsewhere.")
    } else {
      c(paste0("Excel table ", dquote(part[[1]]), " (", part[[2]], ") would get other than one header row, so its columns could not be named. ", nothing),
        i = "Write a data frame with one header row (`header = \"names\"`) at the table's top-left cell.")
    },
    "26" = c(paste0("`merge = ", dquote(part[[1]]), "` overlaps the merged range ", part[[2]], " that sheet ",
                    dquote(sheet), " has. ", nothing),
             i = "Merge a range that does not overlap it, or unmerge that range in Excel first."),
    "27" = c(paste0("Sheet ", dquote(sheet), " has Excel table ", dquote(part[[1]]), " in ", part[[2]],
                    ", which `write_sheet()` would clear. ", nothing),
             i = paste0("To write into the table, use `at = \"", sub(":.*", "", part[[2]]),
                        "\"`; to keep it, write elsewhere with `at =`.")),
    "28" = c(paste0(file, " has no styles part, so xlkit cannot give cells a format. ", nothing),
             i = "Open the file in Excel and save it, then try again."),
    "30" = c(paste0("Excel table ", dquote(part[[1]]), " would grow over Excel table ", dquote(part[[2]]), ". ", nothing),
             i = "Write fewer rows or columns, or move one of the tables in Excel."),
    "31" = c(paste0("The column names of Excel table ", dquote(part[[1]]), " would repeat ", dquote(part[[2]]),
                    " (Excel compares them ignoring case). ", nothing),
             i = "Give the data frame's columns names that differ."),
    "33" = c(paste0(res$message, " would hold a date before 1904-01-01, which ", file,
                    " cannot hold: it counts dates from 1904. ", nothing),
             i = "Write the date as text instead, with `format()`."),
    "32" = c(paste0("`merge = ", dquote(part[[1]]), "` would hide the value in ", part[[2]],
                    ", since Excel keeps only a merged range's top-left value. ", nothing),
             i = "Merge cells that are empty apart from the top-left one."),
    c(paste0("xlkit's editor failed on ", file, ": ", res$message, "."),
      i = "Please report this at <https://github.com/jbearak/xlkit/issues>.")
  )
  rlang::abort(msg, call = call)
}

# Write an empty workbook with one sheet to a temporary file beside
# `full`, for writing into a file that does not exist yet. Returns its path.
empty_workbook <- function(sheet, full, call) {
  args <- check_write_args(FALSE, "labels", FALSE, FALSE, NULL, 1, "", FALSE, call)
  plan <- plan_workbook(list(list(name = sheet, tables = list(list(df = data.frame(), title = NULL)))),
                        args, list(), list(all = NA_real_, by = list()), list(columns = list(), ranges = list()),
                        list(), call)
  tmp <- tempfile(paste0(".", basename(full), "-"), tmpdir = dirname(full), fileext = ".xlsx")
  res <- .Call(C_xl_write, enc2utf8(tmp), plan$parts)
  if (!is.null(res$status)) {
    unlink(tmp)
    rlang::abort(paste0(basename(full), " could not be written: ", res$message, "."), call = call)
  }
  tmp
}
