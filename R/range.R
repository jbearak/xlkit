# Ranges as Excel shows them (ADR 0003): "B5:F40", "B5", "B5:F", "B:F",
# "5:40", an optional "Sheet!" in front, or the name of an Excel table or
# defined name.

cell_pattern <- "^\\$?([A-Za-z]{1,3})\\$?([0-9]+)$"
col_pattern <- "^\\$?([A-Za-z]{1,3})$"
row_pattern <- "^\\$?([0-9]+)$"

# Parse `range` into list(sheet, r1, c1, r2, c2, form), with NA for an
# open edge, or list(name = ) for a table or defined name.
parse_range <- function(range, call) {
  if (!is.character(range) || length(range) != 1 || is.na(range) || !nzchar(trimws(range))) {
    rlang::abort("`range` must be one string, such as \"B5:F40\", or NULL.", call = call)
  }
  text <- trimws(range)
  sheet <- NULL
  bang <- regexpr("![^!]*$", text)
  if (bang > 0) {
    sheet <- substr(text, 1, bang - 1)
    if (grepl("^'.*'$", sheet)) sheet <- gsub("''", "'", substr(sheet, 2, nchar(sheet) - 1))
    text <- substr(text, bang + 1, nchar(text))
  }
  parts <- strsplit(text, ":", fixed = TRUE)[[1]]
  bad <- function() {
    rlang::abort(c(
      paste0("`range = ", dquote(range), "` is not a range xlkit knows."),
      i = "Give cells as Excel shows them: \"B5:F40\", \"B5\", \"B5:F\", \"B:F\" or \"5:40\", or the name of an Excel table."
    ), call = call)
  }
  out <- list(sheet = sheet, r1 = NA, c1 = NA, r2 = NA, c2 = NA, form = NA, text = range)
  if (length(parts) == 1) {
    # Excel does not allow a name that looks like a cell, so "B5" is a cell.
    if (grepl(cell_pattern, parts)) {
      out$r1 <- as.numeric(sub(cell_pattern, "\\2", parts))
      out$c1 <- col_number(sub(cell_pattern, "\\1", parts))
      out$form <- "corner"
    } else if (grepl("^[\\p{L}_\\\\][\\p{L}\\p{N}_.\\\\]*$", parts, perl = TRUE) && is.null(sheet)) {
      return(list(name = parts, text = range))
    } else {
      bad()
    }
  } else if (length(parts) == 2) {
    a <- parts[[1]]
    b <- parts[[2]]
    if (grepl(cell_pattern, a) && grepl(cell_pattern, b)) {
      out$r1 <- as.numeric(sub(cell_pattern, "\\2", a))
      out$c1 <- col_number(sub(cell_pattern, "\\1", a))
      out$r2 <- as.numeric(sub(cell_pattern, "\\2", b))
      out$c2 <- col_number(sub(cell_pattern, "\\1", b))
      out$form <- "cells"
    } else if (grepl(cell_pattern, a) && grepl(col_pattern, b)) {
      out$r1 <- as.numeric(sub(cell_pattern, "\\2", a))
      out$c1 <- col_number(sub(cell_pattern, "\\1", a))
      out$c2 <- col_number(sub(col_pattern, "\\1", b))
      out$form <- "open_bottom"
    } else if (grepl(col_pattern, a) && grepl(col_pattern, b)) {
      out$c1 <- col_number(sub(col_pattern, "\\1", a))
      out$c2 <- col_number(sub(col_pattern, "\\1", b))
      out$form <- "columns"
    } else if (grepl(row_pattern, a) && grepl(row_pattern, b)) {
      out$r1 <- as.numeric(sub(row_pattern, "\\1", a))
      out$r2 <- as.numeric(sub(row_pattern, "\\1", b))
      out$form <- "rows"
    } else {
      bad()
    }
  } else {
    bad()
  }
  check_limits(out, range, call)
  # Excel reads "F40:B5" as B5:F40.
  if (!is.na(out$r1) && !is.na(out$r2) && out$r1 > out$r2) out[c("r1", "r2")] <- out[c("r2", "r1")]
  if (!is.na(out$c1) && !is.na(out$c2) && out$c1 > out$c2) out[c("c1", "c2")] <- out[c("c2", "c1")]
  out
}

check_limits <- function(r, range, call) {
  rows <- c(r$r1, r$r2)
  rows <- rows[!is.na(rows)]
  cols <- c(r$c1, r$c2)
  cols <- cols[!is.na(cols)]
  if (any(rows < 1)) {
    rlang::abort(c(
      paste0("`range = ", dquote(range), "` has row 0."),
      i = "Rows are numbered from 1, as Excel shows them."
    ), call = call)
  }
  if (any(rows > max_row)) {
    rlang::abort(paste0(
      "`range = ", dquote(range), "` goes past Excel's last row, 1,048,576."
    ), call = call)
  }
  if (any(cols > max_col)) {
    rlang::abort(paste0(
      "`range = ", dquote(range), "` goes past Excel's last column, XFD."
    ), call = call)
  }
}

# Where a table or defined name points: list(sheet, r1, c1, r2, c2).
resolve_name <- function(name, path, call) {
  names <- workbook_names(path, call)
  hit <- which(tolower(names$name) == tolower(name))
  if (length(hit) == 0) {
    msg <- paste0(basename(path), " has no Excel table or defined name ", dquote(name), ".")
    guess <- closest(name, names$name)
    if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", dquote(guess), "?"))
    if (nrow(names)) {
      msg <- c(msg, i = paste0("Its tables and names are ", and_list(dquote(unique(names$name))), "."))
    }
    msg <- c(msg, i = "A range of cells is written as Excel shows it, such as \"B5:F40\".")
    rlang::abort(msg, call = call)
  }
  n <- names[hit[[1]], ]
  if (!nzchar(n$formula)) {
    return(list(sheet = n$sheet, r1 = n$r1, c1 = n$c1, r2 = n$r2, c2 = n$c2, form = "cells", text = name,
                table_header_rows = n$header_rows))
  }
  formula <- sub("^=", "", n$formula)
  r <- tryCatch(parse_range(formula, call = NULL), error = function(e) NULL)
  if (is.null(r) || !is.null(r$name) || is.null(r$sheet)) {
    rlang::abort(c(
      paste0("The defined name ", dquote(name), " is not a range of cells; it is ", formula, "."),
      i = "Give the range as Excel shows it, such as \"B5:F40\"."
    ), call = call)
  }
  r$text <- name
  r
}

# Bounds of the non-empty cells of `g` within rows [ra, rb] and columns
# [ca, cb] (NA for unbounded): c(r1, c1, r2, c2), or NULL if none.
bounds_in <- function(g, ra = NA, rb = NA, ca = NA, cb = NA) {
  if (g$nrow == 0) return(NULL)
  rows <- g$r0 + seq_len(g$nrow) - 1
  cols <- g$c0 + seq_len(g$ncol) - 1
  keep_r <- (is.na(ra) | rows >= ra) & (is.na(rb) | rows <= rb)
  keep_c <- (is.na(ca) | cols >= ca) & (is.na(cb) | cols <= cb)
  if (!any(keep_r) || !any(keep_c)) return(NULL)
  filled <- matrix(g$kind != 0L, nrow = g$nrow)[keep_r, keep_c, drop = FALSE]
  if (!any(filled)) return(NULL)
  rr <- which(rowSums(filled) > 0)
  cc <- which(colSums(filled) > 0)
  c(rows[keep_r][min(rr)], cols[keep_c][min(cc)], rows[keep_r][max(rr)], cols[keep_c][max(cc)])
}

range_text <- function(r1, c1, r2, c2) paste0(cell_ref(r1, c1), ":", cell_ref(r2, c2))

# The rectangle to read: c(r1, c1, r2, c2), from the parsed range, the
# header rows and the sheet's cells. Returns NULL for nothing to read.
resolve_rect <- function(g, r, header, sheet, call) {
  top <- if (is.numeric(header)) min(header) else NA
  where <- if (g$nrow == 0) {
    paste0("sheet ", dquote(sheet), ", which is empty")
  } else {
    paste0("the cells of sheet ", dquote(sheet), ", which hold data in ",
           range_text(g$r0, g$c0, g$r0 + g$nrow - 1, g$c0 + g$ncol - 1))
  }
  outside <- function() {
    rlang::abort(paste0("`range = ", dquote(r$text), "` lies outside ", where, "."), call = call)
  }
  if (is.null(r)) {
    b <- bounds_in(g, ra = top)
    if (is.null(b)) {
      if (!is.na(top)) past_data(header, bounds_in(g), paste0("sheet ", dquote(sheet)), call)
      return(NULL)
    }
    if (!is.na(top)) b[[1]] <- top
    return(b)
  }
  rect <- switch(r$form,
    cells = {
      if (is.null(bounds_in(g, r$r1, r$r2, r$c1, r$c2))) outside()
      c(r$r1, r$c1, r$r2, r$c2)
    },
    corner = {
      b <- bounds_in(g, ra = r$r1, ca = r$c1)
      if (is.null(b)) outside()
      c(r$r1, r$c1, b[[3]], b[[4]])
    },
    open_bottom = {
      b <- bounds_in(g, ra = r$r1, ca = r$c1, cb = r$c2)
      if (is.null(b)) outside()
      c(r$r1, r$c1, b[[3]], r$c2)
    },
    columns = {
      b <- bounds_in(g, ra = top, ca = r$c1, cb = r$c2)
      if (is.null(b) && !is.na(top)) {
        past_data(header, bounds_in(g, ca = r$c1, cb = r$c2), paste0("`range = ", dquote(r$text), "`"), call)
      }
      if (is.null(b)) outside()
      c(if (is.na(top)) b[[1]] else top, r$c1, b[[3]], r$c2)
    },
    rows = {
      b <- bounds_in(g, ra = r$r1, rb = r$r2)
      if (is.null(b)) outside()
      c(r$r1, b[[2]], r$r2, b[[4]])
    }
  )
  if (!is.na(top)) {
    if (top < rect[[1]] || max(header) > rect[[3]]) {
      rlang::abort(paste0(
        "`header = ", deparse_rows(header), "` is outside `range = ", dquote(r$text),
        "`, which covers rows ", rect[[1]], " to ", rect[[3]], "."
      ), call = call)
    }
    rect[[1]] <- top
  }
  rect
}

# The error for header rows below the last row with data in `where`,
# whose data is in `b` (nothing happens when `where` holds no data).
past_data <- function(header, b, where, call) {
  if (is.null(b)) return(invisible())
  rlang::abort(c(
    paste0("`header = ", deparse_rows(header), "`, but the last row with data in ", where, " is ", b[[3]], "."),
    i = paste0("Its data is in ", range_text(b[[1]], b[[2]], b[[3]], b[[4]]), ".")
  ), call = call)
}

deparse_rows <- function(x) if (length(x) == 1) as.character(x) else paste0(min(x), ":", max(x))
