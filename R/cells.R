# Cells of a grid (see read_grid()) and their text as Excel shows them.

K_EMPTY <- 0L
K_NUMBER <- 1L
K_DATE <- 2L
K_DATETIME <- 3L
K_TIME <- 4L
K_DURATION <- 5L
K_LOGICAL <- 6L
K_TEXT <- 7L
K_ERROR <- 8L
K_NUMERIC <- 1:5

# The cells of `g` in Excel rows `rows` of column `col`, padding with
# empty cells outside the sheet's data: list(kind, num, text, pad).
column_cells <- function(g, rows, col) {
  n <- length(rows)
  out <- list(kind = integer(n), num = rep(NA_real_, n), text = character(n), pad = integer(n))
  j <- col - g$c0
  if (g$nrow > 0 && j >= 0 && j < g$ncol) {
    i <- rows - g$r0
    inside <- i >= 0 & i < g$nrow
    idx <- j * g$nrow + i[inside] + 1
    out$kind[inside] <- g$kind[idx]
    out$num[inside] <- g$num[idx]
    out$text[inside] <- g$text[idx]
    out$pad[inside] <- g$pad[idx]
  }
  out
}

# Days since 1970-01-01 for Excel serial numbers. In the 1900 system,
# Excel counts a 29 February 1900 that did not exist (day 60): days
# before it are one off from days after it, and day 60 itself is NA.
serial_days <- function(serial, is_1904) {
  if (is_1904) return(serial - 24107)
  out <- ifelse(serial < 60, serial - 25568, serial - 25569)
  out[!is.na(serial) & serial >= 60 & serial < 61] <- NA
  out
}

is_leap_day <- function(serial, is_1904) {
  !is_1904 & !is.na(serial) & serial >= 60 & serial < 61
}

# Seconds since 1970-01-01 UTC, to the millisecond.
serial_seconds <- function(serial, is_1904) round(serial_days(serial, is_1904) * 86400, 3)

# Seconds into the day, to the millisecond.
day_seconds <- function(serial) round((serial - floor(serial)) * 86400, 3) %% 86400

# A number written in full, up to 15 significant digits, or padded with
# zeros when its format is a run of zeros such as 00000.
number_text <- function(x, pad = integer(length(x))) {
  out <- trimws(formatC(x, digits = 15, format = "fg"))
  # Beyond what 15 digits can write in full, use an exponent.
  far <- !is.na(x) & x != 0 & (abs(x) >= 1e15 | abs(x) < 1e-9)
  if (any(far)) out[far] <- sprintf("%.15g", x[far])
  padded <- pad > 0 & !is.na(x) & x == round(x) & abs(x) < 1e15
  # Pad the digits, not the sign: -42 formatted 00000 shows as -00042.
  if (any(padded)) {
    out[padded] <- paste0(ifelse(x[padded] < 0, "-", ""), sprintf("%0*.0f", pad[padded], abs(x[padded])))
  }
  out
}

# Whole milliseconds as h:mm:ss, with .mmm when they are not whole seconds.
hms_text <- function(ms, hours_over_24 = FALSE) {
  ms <- round(ms)
  secs <- ms %/% 1000
  frac <- ms %% 1000
  h <- secs %/% 3600
  m <- (secs %% 3600) %/% 60
  s <- secs %% 60
  out <- sprintf(if (hours_over_24) "%d:%02d:%02d" else "%02d:%02d:%02d", h, m, s)
  out[frac > 0] <- paste0(out[frac > 0], sprintf(".%03d", frac[frac > 0]))
  out
}

# Each cell as text, as Excel shows it (NA for an empty cell): numbers
# in full or zero-padded, dates as 2024-03-01, logicals as TRUE/FALSE,
# errors as #N/A.
cell_text <- function(cells, is_1904) {
  kind <- cells$kind
  num <- cells$num
  out <- rep(NA_character_, length(kind))
  t <- kind == K_TEXT | kind == K_ERROR
  out[t] <- cells$text[t]
  b <- kind == K_LOGICAL
  out[b] <- ifelse(num[b] != 0, "TRUE", "FALSE")
  n <- kind == K_NUMBER
  if (any(n)) out[n] <- number_text(num[n], cells$pad[n])
  d <- kind == K_DATE
  if (any(d)) {
    days <- serial_days(num[d], is_1904)
    txt <- format(new_date(floor(days)), "%Y-%m-%d")
    txt[is_leap_day(num[d], is_1904)] <- "1900-02-29"
    out[d] <- txt
  }
  dt <- kind == K_DATETIME
  if (any(dt)) {
    # Split into days and milliseconds after rounding, so 23:59:59.9996
    # becomes the next day's 00:00:00 rather than this day's.
    ms <- round(num[dt] * 86400000)
    day <- ms %/% 86400000
    txt <- format(new_date(floor(serial_days(day, is_1904))), "%Y-%m-%d")
    txt[is_leap_day(day, is_1904)] <- "1900-02-29"
    out[dt] <- paste(txt, hms_text(ms %% 86400000))
  }
  tm <- kind == K_TIME
  if (any(tm)) out[tm] <- hms_text(round((num[tm] - floor(num[tm])) * 86400000) %% 86400000)
  du <- kind == K_DURATION
  if (any(du)) out[du] <- hms_text(round(num[du] * 86400000), hours_over_24 = TRUE)
  out
}

new_date <- function(days) structure(as.double(days), class = "Date")
