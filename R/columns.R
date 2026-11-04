# R columns as Excel cells, for write_xlsx() (docs/r.md, "Write a
# table"). Each column becomes a cell kind, a number or a text for each
# row, the number format its type needs, and how wide it shows. NA
# becomes a blank cell (or the `na` text) here, in R, so no NA or NaN is
# handed to the writer: rust_xlsxwriter would write NaN as "NAN".

W_BLANK <- 0L
W_NUMBER <- 1L
W_TEXT <- 2L
W_BOOL <- 3L
W_FORMULA <- 4L

excel_text_max <- 32767

# A text's length as Excel counts it, in UTF-16 units, so a character
# beyond U+FFFF (most emoji) counts as two. Only text longer than half
# the limit can be too long, so only that is measured.
text_units <- function(x) {
  x <- enc2utf8(x)
  n <- nchar(x, allowNA = TRUE)
  long <- which(!is.na(n) & n > excel_text_max %/% 2)
  if (length(long)) n[long] <- lengths(iconv(x[long], "UTF-8", "UTF-16LE", toRaw = TRUE)) %/% 2
  n
}

# Excel serial numbers for R dates (days since 1970-01-01). Excel counts
# a 29 February 1900 that did not exist, so dates before 1 March 1900 are
# one less than the count from 1970 gives.
excel_days <- function(days) {
  s <- days + 25569
  early <- !is.na(days) & days < -25508
  s[early] <- s[early] - 1
  s
}

# The first and last days Excel can show: 1900-01-01 and 9999-12-31.
excel_first_day <- -25567
excel_last_day <- 2932896

# The wall clock of a date-time in its own time zone, as Excel's serial
# number. A POSIXct without a zone shows in the session's zone, so that
# is the clock it is written in, as R prints it.
excel_datetime <- function(x) {
  tz <- attr(x, "tzone", exact = TRUE)
  tz <- if (is.null(tz) || !length(tz)) "" else tz[[1]]
  lt <- as.POSIXlt(x, tz = tz)
  days <- as.numeric(as.Date(lt))
  secs <- lt$hour * 3600 + lt$min * 60 + lt$sec
  list(days = days, serial = excel_days(days) + secs / 86400)
}

# How the cells of one column are written: list(kind, num, str, format,
# width, nonfinite, unlabelled, too_early). `format` is the number format
# the type needs (NULL for none); `width` the widest cell in characters.
# `nonfinite` are the rows holding NaN or Inf, `unlabelled` the rows
# whose code has no value label, with their codes, and `too_early` the
# rows with dates Excel cannot hold.
column_cells_out <- function(x, values, na) {
  n <- length(x)
  out <- list(
    kind = rep(W_BLANK, n), num = rep(NA_real_, n), str = rep(NA_character_, n),
    format = NULL, width = 0, nonfinite = integer(), unlabelled = NULL, too_early = integer()
  )
  # NA is blank; NaN and Inf are blank too, and named in a warning.
  numbers <- function(out, v, keep = rep(TRUE, length(v))) {
    bad <- which(keep & (is.nan(v) | is.infinite(v)))
    if (length(bad)) {
      out$nonfinite <- bad
      out$str[bad] <- ifelse(is.nan(v[bad]), "NaN", ifelse(v[bad] > 0, "Inf", "-Inf"))
    }
    keep <- keep & is.finite(v)
    out$kind[keep] <- W_NUMBER
    out$num[keep] <- v[keep]
    out
  }
  texts <- function(out, s, keep = !is.na(s)) {
    out$kind[keep] <- W_TEXT
    out$str[keep] <- s[keep]
    out
  }
  if (inherits(x, "xl_formula")) {
    s <- sub("^=", "", vctrs::vec_data(x))
    keep <- !is.na(s) & nzchar(s)
    out$kind[keep] <- W_FORMULA
    out$str[keep] <- s[keep]
  } else if (is_labelled(x)) {
    out <- labelled_cells(out, x, values, numbers, texts)
  } else if (is.factor(x)) {
    out <- texts(out, as.character(x))
  } else if (inherits(x, "Date")) {
    days <- floor(as.numeric(unclass(x)))
    out <- dated(out, days, excel_days(days), numbers)
    out$format <- "yyyy-mm-dd"
  } else if (inherits(x, "POSIXt")) {
    dt <- excel_datetime(as.POSIXct(x))
    out <- dated(out, dt$days, dt$serial, numbers)
    out$format <- "yyyy-mm-dd hh:mm:ss"
  } else if (inherits(x, "difftime")) {
    secs <- as.numeric(x, units = "secs")
    out <- numbers(out, secs / 86400)
    long <- any(abs(secs[is.finite(secs)]) >= 86400)
    out$format <- if (long) "[h]:mm:ss" else "hh:mm:ss"
  } else if (is.logical(x) && !is.object(x)) {
    keep <- !is.na(x)
    out$kind[keep] <- W_BOOL
    out$num[keep] <- as.numeric(x[keep])
  } else if (is.numeric(x)) {
    out <- numbers(out, as.double(x))
  } else if (is.character(x)) {
    out <- texts(out, as.character(x))
  } else {
    s <- as.character(x)
    out <- texts(out, s)
  }
  if (nzchar(na)) {
    missing <- out$kind == W_BLANK & seq_len(n) %in% setdiff(which(is_missing(x)), out$nonfinite)
    out$kind[missing] <- W_TEXT
    out$str[missing] <- na
  }
  out
}

# Rows of `x` that are NA (and so blank, or the `na` text).
is_missing <- function(x) {
  if (inherits(x, "xl_formula")) return(is.na(vctrs::vec_data(x)))
  if (is_labelled(x)) return(is.na(vctrs::vec_data(x)))
  if (is.double(x) && !is.object(x)) return(is.na(x) & !is.nan(x))
  is.na(x)
}

# Dates as numbers, except those before 1900 or after 9999, which Excel
# cannot hold.
dated <- function(out, days, serial, numbers) {
  early <- which(!is.na(days) & is.finite(days) & (days < excel_first_day | days > excel_last_day))
  out$too_early <- early
  keep <- rep(TRUE, length(serial))
  keep[early] <- FALSE
  numbers(out, serial, keep)
}

is_labelled <- function(x) inherits(x, c("dtaparser_labelled", "haven_labelled"))

# The tag of each tagged NA ("a" to "z"), or "" (dtaparser and haven keep
# Stata's .a to .z in a NaN's payload).
na_tags <- function(x) {
  out <- rep("", length(x))
  if (!is.double(x)) return(out)
  na <- which(is.na(x))
  if (!length(na)) return(out)
  bytes <- writeBin(as.double(x[na]), raw(), size = 8, endian = "little")
  tag <- bytes[seq(5, by = 8, length.out = length(na))]
  ok <- tag != as.raw(0)
  out[na[ok]] <- vapply(tag[ok], rawToChar, character(1))
  out
}

# A labelled column: its value labels as text with `values = "labels"`,
# with the codes that have none written as numbers; or its codes.
labelled_cells <- function(out, x, values, numbers, texts) {
  codes <- vctrs::vec_data(x)
  write_codes <- function(out) if (is.character(codes)) texts(out, codes) else numbers(out, as.double(codes))
  labels <- attr(x, "labels", exact = TRUE)
  if (values == "codes" || is.null(labels) || !length(labels)) return(write_codes(out))
  text <- rep(NA_character_, length(codes))
  known <- !is.na(labels)
  hit <- match(codes, labels[known])
  hit[is.na(codes)] <- NA
  text[!is.na(hit)] <- names(labels)[known][hit[!is.na(hit)]]
  # Tagged missing values (.a to .z) with labels of their own.
  if (any(!known) && is.double(codes)) {
    code_tags <- na_tags(codes)
    label_tags <- na_tags(as.double(labels[!known]))
    t <- match(code_tags, label_tags[nzchar(label_tags)])
    t[!nzchar(code_tags)] <- NA
    text[!is.na(t)] <- names(labels)[!known][nzchar(label_tags)][t[!is.na(t)]]
  }
  out <- write_codes(out)
  labelled_text <- !is.na(text)
  out <- texts(out, text, labelled_text)
  out$num[labelled_text] <- NA_real_
  rows <- which(!labelled_text & !is.na(codes))
  if (length(rows)) out$unlabelled <- list(rows = rows, codes = codes[rows])
  out
}

# How many characters wide a column's cells show, the widest of them,
# given the number format they are written with.
cells_width <- function(cells, format) {
  w <- 0
  s <- cells$str[cells$kind == W_TEXT]
  if (length(s)) {
    lines <- if (any(grepl("\n", s, fixed = TRUE))) unlist(strsplit(s, "\n", fixed = TRUE)) else s
    w <- max(w, nchar(lines, type = "width", allowNA = TRUE), na.rm = TRUE)
  }
  b <- cells$num[cells$kind == W_BOOL]
  if (length(b)) w <- max(w, if (any(b == 0)) 5 else 4)
  v <- cells$num[cells$kind == W_NUMBER]
  if (length(v)) w <- max(w, number_width(v, format))
  w
}

# The widest a number shows in a format. An approximation, as Excel's
# own autofit is: it counts characters, not the font's pixels.
number_width <- function(v, format) {
  if (is.null(format) || tolower(format) == "general") {
    return(max(pmin(nchar(trimws(formatC(v, digits = 10, format = "g"))), 11)))
  }
  code <- first_format_section(format)
  literal <- gsub('"[^"]*"|\\\\.|\\[[^]]*\\]|_.|\\*.', "", code)
  quoted <- sum(nchar(regmatches(code, gregexpr('"[^"]*"', code))[[1]]) - 2)
  if (grepl("[yYdDhHsS]", literal) || (grepl("[mM]", literal) && !grepl("[0#?]", literal))) {
    shown <- gsub("mmmm+", "September", literal, ignore.case = TRUE)
    shown <- gsub("dddd+", "Wednesday", shown, ignore.case = TRUE)
    shown <- gsub("AM/PM", "AM", shown, ignore.case = TRUE)
    return(nchar(shown) + quoted)
  }
  if (grepl("[eE][+-]", literal)) return(nchar(literal) + quoted)
  percent <- grepl("%", literal, fixed = TRUE)
  # A section of text only, or none (";;;" hides the value), shows no digits.
  if (!grepl("[0#?]", literal)) return(nchar(literal) + quoted)
  parts <- strsplit(literal, ".", fixed = TRUE)[[1]]
  decimals <- if (length(parts) > 1) nchar(gsub("[^0#?]", "", parts[[2]])) else 0
  int_digits <- nchar(gsub("[^0]", "", parts[[1]]))
  comma <- grepl("[0#?],[0#?]", literal)
  shown <- trimws(formatC(abs(v) * if (percent) 100 else 1, format = "f", digits = decimals,
                          big.mark = if (comma) "," else ""))
  width <- pmax(nchar(shown), int_digits) + (v < 0)
  others <- nchar(gsub("[0#?.,]", "", literal))
  max(width) + others + quoted
}

# A number format's first section, up to an unquoted ";".
first_format_section <- function(format) {
  chars <- strsplit(format, "")[[1]]
  quoted <- FALSE
  i <- 1
  while (i <= length(chars)) {
    ch <- chars[[i]]
    if (ch == "\"") quoted <- !quoted
    else if (ch == "\\" && !quoted) i <- i + 1
    else if (ch == ";" && !quoted) return(paste(chars[seq_len(i - 1)], collapse = ""))
    i <- i + 1
  }
  format
}

# A number format with an unquoted "%", which shows a number times 100.
is_percent_format <- function(format) {
  rlang::is_string(format) && grepl("%", gsub('"[^"]*"|\\\\.|\\[[^]]*\\]', "", format), fixed = TRUE)
}

# The message for numbers that look already multiplied by 100 (every
# finite one at least 1 in absolute value) given a percent format, or
# NULL. `what` names the column or cells, `verb` agrees with it.
percent_message <- function(what, v, format, verb = "has") {
  v <- v[is.finite(v)]
  if (!is_percent_format(format) || !length(v) || any(abs(v) < 1)) return(NULL)
  shown <- format(v[[1]], digits = 15, trim = TRUE)
  code <- gsub('"[^"]*"|\\\\.|\\[[^]]*\\]|_.|\\*.', "", first_format_section(format))
  parts <- strsplit(code, ".", fixed = TRUE)[[1]]
  decimals <- if (length(parts) > 1) nchar(gsub("[^0#?]", "", parts[[2]])) else 0
  comma <- grepl("[0#?],[0#?]", code)
  as_pct <- paste0(trimws(formatC(v[[1]] * 100, format = "f", digits = decimals,
                                  big.mark = if (comma) "," else "")), "%")
  one <- length(v) == 1
  c(
    paste0(what, " ", verb, if (one) " the value " else " values such as ", shown, " and the format ",
           dquote(format), ", which shows ", if (one) "it" else "them", " as ", as_pct, "."),
    i = paste0("A percent format multiplies by 100. To show ", shown, "%, divide by 100 first.")
  )
}

# Percent messages for the numbers written into each range in `ranges`
# whose style has a percent format, naming the cells.
percent_range_messages <- function(blocks, ranges) {
  out <- list()
  for (rs in ranges) {
    if (!is_percent_format(rs$style$format)) next
    cl <- rs$cells
    rows <- numeric()
    cols <- numeric()
    v <- numeric()
    for (blk in blocks) {
      if (blk$col < cl[[2]] || blk$col > cl[[4]]) next
      r <- blk$row + seq_along(blk$kind) - 1
      hit <- r >= cl[[1]] & r <= cl[[3]] & blk$kind == W_NUMBER & blk$dclass == 0L
      rows <- c(rows, r[hit])
      cols <- c(cols, rep(blk$col, sum(hit)))
      v <- c(v, blk$num[hit])
    }
    if (!length(v)) next
    o <- order(rows, cols)
    cells <- cell_ref(rows[o], cols[o])
    m <- percent_message(and_list_first(cells), v[o], rs$style$format,
                         verb = if (length(cells) == 1) "has" else "have")
    if (!is.null(m)) out[[length(out) + 1]] <- m
  }
  out
}
