# The plan of a new workbook: every cell, format, column width, merged
# range, frozen pane and filter, as the plain vectors src/init.c hands to
# Rust (src/rust/src/write.rs). Rows and columns are counted from 0 in
# the plan and from 1 (as Excel shows them) everywhere else.

# Formats, kept once each: the styles, and a key for each to find it.
new_registry <- function() {
  reg <- new.env(parent = emptyenv())
  reg$styles <- list()
  reg$keys <- character()
  reg
}

style_key <- function(style) {
  paste(names(style), vapply(style, function(v) paste(v, collapse = "/"), ""), sep = "=", collapse = ";")
}

# The format index of a style, -1 for none.
format_id <- function(reg, style) {
  if (is.null(style) || !length(style)) return(-1L)
  key <- style_key(style)
  i <- match(key, reg$keys)
  if (is.na(i)) {
    reg$keys <- c(reg$keys, key)
    reg$styles[[length(reg$styles) + 1]] <- style
    i <- length(reg$keys)
  }
  as.integer(i - 1L)
}

format_style <- function(reg, id) if (id < 0) NULL else reg$styles[[id + 1]]

# Cell references with the sheet's name, when the workbook has several.
sheet_cells <- function(sheet, rows, cols, several) {
  refs <- cell_ref(rows, cols)
  if (!several) return(refs)
  prefix <- if (grepl("^[A-Za-z_][A-Za-z0-9_.]*$", sheet)) sheet else paste0("'", gsub("'", "''", sheet), "'")
  paste0(prefix, "!", refs)
}

plan_workbook <- function(sheets, args, formats, widths, styles, merges, call) {
  reg <- new_registry()
  several <- length(sheets) > 1
  title_id <- format_id(reg, xl_style(bold = TRUE))
  header_id <- format_id(reg, args$header_style)
  n_header <- switch(if (isFALSE(args$header)) "none" else args$header, none = 0L, names = 1L, labels = 1L, both = 2L)

  blocks <- list()
  add_block <- function(sheet, row, col, kind, num, str, fmt) {
    blocks[[length(blocks) + 1]] <<- list(sheet = sheet, row = row, col = col, kind = kind, num = num,
                                          str = str, fmt = fmt)
  }
  sheet_ints <- integer()
  width_cols <- integer()
  width_vals <- numeric()
  merge_ints <- integer()
  messages <- list()
  nonfinite <- character()

  for (s in seq_along(sheets)) {
    sh <- sheets[[s]]
    label <- function(msg) if (several) paste0("Sheet ", dquote(sh$name), ": ", msg) else msg
    first_block <- length(blocks) + 1
    row <- 0L
    tables <- list()
    col_width <- numeric()
    ncols <- max(vapply(sh$tables, function(t) length(t$df), integer(1)))
    if (ncols > max_col) {
      rlang::abort(c(
        label(paste0("The table has ", fmt_count(ncols), " columns, and a sheet holds at most 16,384.")),
        i = "Split the columns across sheets: a named list of data frames writes one sheet each."
      ), call = call)
    }
    rows_needed <- sum(vapply(sh$tables, function(t) {
      as.numeric(!is.null(t$title)) + n_header + nrow(t$df)
    }, numeric(1))) + args$gap * (length(sh$tables) - 1)
    if (rows_needed > max_row) {
      rlang::abort(c(
        label(paste0("The sheet would have ", fmt_count(rows_needed), " rows, and a sheet holds at most 1,048,576.")),
        i = "Split the table across sheets: a named list of data frames writes one sheet each."
      ), call = call)
    }
    for (t in sh$tables) {
      df <- t$df
      if (!is.null(t$title)) {
        check_text_length(t$title, label("The title"), cell_ref(row + 1, 1), call)
        add_block(s - 1L, row, 0L, W_TEXT, NA_real_, t$title, title_id)
        row <- row + 1L
      }
      header_top <- row
      body_top <- row + n_header
      nm <- names(df)
      for (j in seq_along(df)) {
        x <- df[[j]]
        name <- nm[[j]]
        if ((is.list(x) && !inherits(x, "POSIXlt")) || is.data.frame(x) || is.matrix(x)) {
          what <- if (is.data.frame(x)) "a data frame column" else if (is.matrix(x)) "a matrix column" else "a list column"
          rlang::abort(c(
            label(paste0("`", name, "` is ", what, ", and a cell holds one value.")),
            i = "Turn it into numbers or text first, or leave it out."
          ), call = call)
        }
        cells <- column_cells_out(x, args$values, args$na)
        col <- j - 1L
        body_rows <- body_top + seq_along(x)
        if (length(cells$too_early)) {
          bad <- cells$too_early
          rlang::abort(c(
            label(paste0("`", name, "` has dates Excel cannot hold, which shows only 1900-01-01 to 9999-12-31: ",
                         and_list_first(paste0(cell_ref(body_rows[bad], j), " (", format(x[bad]), ")")), ".")),
            i = "Write them as text instead, with `format()`, or leave them out."
          ), call = call)
        }
        is_text <- cells$kind == W_TEXT | cells$kind == W_FORMULA
        cells$str[is_text] <- enc2utf8(cells$str[is_text])
        invalid <- which(is_text & !validUTF8(cells$str))
        if (length(invalid)) {
          rlang::abort(c(
            label(paste0("`", name, "` has text that is not valid in its encoding: ",
                         and_list_first(cell_ref(body_rows[invalid], j)), ".")),
            i = "Fix its encoding first, such as with `iconv(x, from = \"latin1\", to = \"UTF-8\")`."
          ), call = call)
        }
        units <- text_units(cells$str)
        long <- which(cells$kind == W_TEXT & units > excel_text_max)
        if (length(long)) {
          rlang::abort(c(
            label(paste0("`", name, "` has text longer than the 32,767 characters a cell holds: ",
                         and_list_first(paste0(cell_ref(body_rows[long], j), " (",
                                               fmt_count(units[long]), " characters)")), ".")),
            i = "Shorten it, such as with `substr(x, 1, 32767)`, or split it across cells."
          ), call = call)
        }
        if (length(cells$nonfinite)) {
          bad <- cells$nonfinite
          nonfinite <- c(nonfinite, paste0(sheet_cells(sh$name, body_rows[bad], j, several),
                                           " (", cells$str[bad], ")"))
        }
        if (!is.null(cells$unlabelled)) {
          messages[[length(messages) + 1]] <- unlabelled_message(
            name, cells$unlabelled, cell_ref(body_rows[cells$unlabelled$rows], j), label
          )
        }
        numfmt <- if (!is.null(formats[[name]])) formats[[name]] else cells$format
        body_style <- style_merge(if (!is.null(numfmt)) xl_style(format = numfmt), styles$columns[[name]])
        body_id <- format_id(reg, body_style)
        header_text <- switch(if (n_header == 0) "none" else args$header,
          none = character(),
          names = name,
          labels = var_label(x, name),
          both = c(name, var_label(x, NA_character_))
        )
        for (h in header_text) {
          if (!is.na(h)) check_text_length(h, label(paste0("The header of `", name, "`")), cell_ref(header_top + 1, j), call)
        }
        h_kind <- ifelse(is.na(header_text) | !nzchar(header_text), W_BLANK, W_TEXT)
        add_block(s - 1L, header_top, col,
                  c(h_kind, cells$kind),
                  c(rep(NA_real_, length(header_text)), cells$num),
                  c(header_text, cells$str),
                  c(rep(header_id, length(header_text)), rep(body_id, length(x))))
        hw <- if (length(header_text)) max(nchar(header_text, type = "width"), 0, na.rm = TRUE) else 0
        if (!is.null(args$header_style$bold) && isTRUE(args$header_style$bold)) hw <- hw * 1.1
        if (isTRUE(args$filter)) hw <- hw + 2
        # Size the column for the format its cells will show, which a
        # column style's `format` overrides.
        shown_fmt <- if (!is.null(styles$columns[[name]]$format)) styles$columns[[name]]$format else numfmt
        if (is.numeric(x) && !is_labelled(x)) {
          pm <- percent_message(label(paste0("`", name, "`")), cells$num[cells$kind == W_NUMBER], shown_fmt)
          if (!is.null(pm)) messages[[length(messages) + 1]] <- pm
        }
        w <- max(hw, cells_width(cells, shown_fmt))
        col_width[j] <- max(if (j <= length(col_width) && !is.na(col_width[j])) col_width[j] else 0, w)
      }
      tables[[length(tables) + 1]] <- list(top = if (is.null(t$title)) header_top else header_top - 1L,
                                           header_top = header_top, body_top = body_top,
                                           last = body_top + nrow(df) - 1L, ncol = length(df))
      row <- body_top + nrow(df) + args$gap
    }

    # Styles by range, over whatever the cells already have.
    sheet_blocks <- if (length(blocks) >= first_block) seq(first_block, length(blocks)) else integer()
    for (rs in c(styles$ranges, Filter(function(m) !is.null(m$style), merges))) {
      sheet_blocks <- apply_range_style(sheet_blocks, rs$cells, rs$style, reg, s - 1L, add_block)
    }

    # Merged ranges: Excel keeps only the top-left value.
    for (m in merges) {
      cl <- m$cells
      hidden_rows <- numeric()
      hidden_cols <- numeric()
      for (b in sheet_blocks) {
        blk <- blocks[[b]]
        if (blk$col + 1 < cl[[2]] || blk$col + 1 > cl[[4]]) next
        rows <- blk$row + seq_along(blk$kind)
        inside <- rows >= cl[[1]] & rows <= cl[[3]] & blk$kind != W_BLANK &
          !(rows == cl[[1]] & blk$col + 1 == cl[[2]])
        hidden_rows <- c(hidden_rows, rows[inside])
        hidden_cols <- c(hidden_cols, rep(blk$col + 1, sum(inside)))
      }
      if (length(hidden_rows)) {
        o <- order(hidden_rows, hidden_cols)
        hidden <- cell_ref(hidden_rows[o], hidden_cols[o])
        rlang::abort(c(
          label(paste0("`merge = ", dquote(m$text), "` would hide the values in ", and_list_first(hidden),
                       ", since Excel keeps only a merged range's top-left value.")),
          i = "Merge cells that are empty apart from the top-left one, such as a title's row."
        ), call = call)
      }
      merge_ints <- c(merge_ints, s - 1L, cl - 1L)
    }

    # Frozen panes and the filter.
    freeze <- c(-1L, -1L)
    if (!is.null(args$freeze_at)) {
      freeze <- as.integer(args$freeze_at - 1)
    } else if (isTRUE(args$freeze) && length(tables) == 1 && n_header > 0) {
      freeze <- c(tables[[1]]$body_top, 0L)
    }
    filter <- rep(-1L, 4)
    if (isTRUE(args$filter) && length(tables) == 1 && tables[[1]]$ncol > 0) {
      tb <- tables[[1]]
      filter <- as.integer(c(tb$body_top - 1L, 0L, max(tb$last, tb$body_top - 1L), tb$ncol - 1L))
    }
    sheet_ints <- c(sheet_ints, freeze, filter)

    # Column widths: fitted up to 60 characters, or as `widths` says.
    for (j in seq_len(ncols)) {
      w <- if (!is.na(widths$all)) widths$all else min(60, (if (is.na(col_width[j])) 0 else col_width[j]) + 2)
      named <- unlist(lapply(sh$tables, function(t) {
        k <- names(t$df)[j]
        if (!is.na(k) && !is.null(widths$by[[k]])) widths$by[[k]]
      }))
      if (length(named)) w <- max(named)
      width_cols <- c(width_cols, s - 1L, j - 1L)
      width_vals <- c(width_vals, w)
    }
  }

  kinds <- unlist(lapply(blocks, `[[`, "kind"), use.names = FALSE)
  if (is.null(kinds)) kinds <- integer()
  nums <- unlist(lapply(blocks, function(b) b$num[b$kind == W_NUMBER | b$kind == W_BOOL]), use.names = FALSE)
  strs <- unlist(lapply(blocks, function(b) b$str[b$kind == W_TEXT | b$kind == W_FORMULA]), use.names = FALSE)
  fmts <- unlist(lapply(blocks, `[[`, "fmt"), use.names = FALSE)
  block_ints <- unlist(lapply(blocks, function(b) c(b$sheet, b$row, b$col, length(b$kind))), use.names = FALSE)

  warning <- NULL
  if (length(nonfinite)) {
    n <- length(nonfinite)
    warning <- c(
      paste0(fmt_count(n), if (n == 1) " cell holds" else " cells hold",
             " NaN or Inf, which Excel cannot store, and ", if (n == 1) "is" else "are", " blank: ",
             and_list_first(nonfinite), "."),
      i = "Replace them with numbers or NA first if they mean something else."
    )
  }

  list(
    parts = c(format_parts(reg), list(
      vapply(sheets, `[[`, "", "name"),
      as.integer(sheet_ints),
      as.integer(width_cols),
      as.double(width_vals),
      as.integer(merge_ints),
      as.integer(block_ints),
      as.integer(kinds),
      as.integer(if (is.null(fmts)) integer() else fmts),
      as.double(if (is.null(nums)) numeric() else nums),
      as.character(if (is.null(strs)) character() else strs)
    )),
    messages = messages,
    warning = warning
  )
}

# A column's variable label, or `otherwise` where it has none.
var_label <- function(x, otherwise) {
  l <- attr(x, "label", exact = TRUE)
  if (rlang::is_string(l) && nzchar(l)) l else otherwise
}

check_text_length <- function(text, what, cell, call) {
  if (text_units(text) > excel_text_max) {
    rlang::abort(c(
      paste0(what, " in ", cell, " has ", fmt_count(text_units(text)),
             " characters, more than the 32,767 a cell holds."),
      i = "Shorten it, such as with `substr(x, 1, 32767)`."
    ), call = call)
  }
}

# Put `style` over the cells of `cells` (Excel's rows and columns) on
# sheet `sheet`, combining it with the format each cell has, and add
# blank cells with the style where nothing is written. Returns the
# sheet's block indices.
apply_range_style <- function(sheet_blocks, cells, style, reg, sheet, add_block) {
  env <- environment(add_block)
  covered <- vector("list", cells[[4]] - cells[[2]] + 1)
  for (b in sheet_blocks) {
    blk <- env$blocks[[b]]
    c1 <- blk$col + 1
    if (c1 < cells[[2]] || c1 > cells[[4]]) next
    rows <- blk$row + seq_along(blk$kind)
    hit <- which(rows >= cells[[1]] & rows <= cells[[3]])
    if (!length(hit)) next
    old <- blk$fmt[hit]
    u <- unique(old)
    new <- vapply(u, function(id) format_id(reg, style_merge(format_style(reg, id), style)), integer(1))
    env$blocks[[b]]$fmt[hit] <- new[match(old, u)]
    k <- c1 - cells[[2]] + 1
    covered[[k]] <- c(covered[[k]], rows[hit])
  }
  id <- format_id(reg, style)
  for (k in seq_along(covered)) {
    missing <- setdiff(seq(cells[[1]], cells[[3]]), covered[[k]])
    if (!length(missing)) next
    # One block per run of rows.
    runs <- split(missing, cumsum(c(1, diff(missing) != 1)))
    for (r in runs) {
      add_block(sheet, as.integer(r[[1]] - 1), as.integer(cells[[2]] + k - 2),
                rep(W_BLANK, length(r)), rep(NA_real_, length(r)), rep(NA_character_, length(r)),
                rep(id, length(r)))
      sheet_blocks <- c(sheet_blocks, length(env$blocks))
    }
  }
  sheet_blocks
}

# The formats as the plan's first four parts.
format_parts <- function(reg) {
  n <- length(reg$styles)
  ints <- matrix(-1L, nrow = 13, ncol = n)
  size <- rep(NA_real_, n)
  font <- rep(NA_character_, n)
  numfmt <- rep(NA_character_, n)
  rgb <- function(x) if (is.null(x)) -1L else strtoi(substr(x, 2, 7), 16L)
  flag <- function(x) if (is.null(x)) -1L else as.integer(x)
  side <- function(b, k) if (is.null(b) || is.na(b[[k]])) -1L else match(b[[k]], border_kinds)
  for (i in seq_len(n)) {
    s <- reg$styles[[i]]
    ints[, i] <- c(
      flag(s$bold), flag(s$italic), flag(s$underline), rgb(s$color), rgb(s$fill),
      side(s$border, 1), side(s$border, 2), side(s$border, 3), side(s$border, 4),
      if (is.null(s$align)) -1L else match(s$align, c("left", "center", "right")),
      if (is.null(s$valign)) -1L else match(s$valign, c("top", "center", "bottom")),
      flag(s$wrap), if (is.null(s$indent)) -1L else s$indent
    )
    if (!is.null(s$size)) size[i] <- s$size
    if (!is.null(s$font)) font[i] <- s$font
    if (!is.null(s$format)) numfmt[i] <- s$format
  }
  list(as.integer(ints), size, font, numfmt)
}

# The message for codes without a value label, naming their cells.
unlabelled_message <- function(name, unlabelled, cells, label) {
  codes <- unlabelled$codes
  shown_codes <- if (is.character(codes)) dquote(codes) else format(codes, trim = TRUE, digits = 15)
  groups <- split(cells, factor(shown_codes, levels = unique(shown_codes)))
  parts <- vapply(names(groups), function(code) paste0(code, " in ", and_list_first(groups[[code]])), "")
  if (length(parts) > 5) parts <- c(parts[1:5], paste0("and ", length(parts) - 5, " more codes"))
  n <- length(cells)
  c(
    label(paste0(
      "`", name, "` has ", fmt_count(n), if (n == 1) " cell" else " cells",
      " whose code has no value label: ", paste(parts, collapse = "; "), ".\n",
      if (n == 1) "It is written as a code." else "They are written as codes."
    )),
    i = "Add a label with `dtaparser::with_labels()`, or write the column's codes with `values = \"codes\"`."
  )
}
