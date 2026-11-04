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
  if (any(padded)) out[padded] <- sprintf("%0*.0f", pad[padded], x[padded])
  out
}

hms_text <- function(secs, hours_over_24 = FALSE) {
  secs <- round(secs)
  h <- secs %/% 3600
  m <- (secs %% 3600) %/% 60
  s <- secs %% 60
  sprintf(if (hours_over_24) "%d:%02d:%02d" else "%02d:%02d:%02d", h, m, s)
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
    secs <- round(serial_seconds(num[dt], is_1904))
    txt <- format(.POSIXct(secs, tz = "UTC"), "%Y-%m-%d %H:%M:%S")
    leap <- is_leap_day(num[dt], is_1904)
    txt[leap] <- paste("1900-02-29", hms_text(day_seconds(num[dt][leap])))
    out[dt] <- txt
  }
  tm <- kind == K_TIME
  if (any(tm)) out[tm] <- hms_text(day_seconds(num[tm]))
  du <- kind == K_DURATION
  if (any(du)) out[du] <- hms_text(round(num[du] * 86400, 3), hours_over_24 = TRUE)
  out
}

new_date <- function(days) structure(as.double(days), class = "Date")
