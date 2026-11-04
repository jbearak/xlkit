# Small helpers for messages.

# "a", "a and b", "a, b and c"
and_list <- function(x) {
  n <- length(x)
  if (n <= 1) return(paste(x, collapse = ""))
  paste0(paste(x[-n], collapse = ", "), " and ", x[n])
}

# The first `max` items of `x` joined with "and", then "and N more".
and_list_first <- function(x, max = 5) {
  if (length(x) <= max) return(and_list(x))
  paste0(paste(x[seq_len(max)], collapse = ", "), " and ", fmt_count(length(x) - max), " more")
}

fmt_count <- function(n) formatC(n, big.mark = ",", format = "d")

dquote <- function(x) paste0("\"", x, "\"")

# A column name as it is written in R code: `x` in backticks when it is
# not syntactic.
code_name <- function(x) {
  ifelse(make.names(x) == x, x, paste0("`", gsub("`", "\\\\`", x), "`"))
}

# Optimal string alignment distance, ignoring case: an edit is an
# insertion, deletion, substitution or swap of two neighbours.
edit_distance <- function(a, b) {
  a <- utf8ToInt(tolower(a))
  b <- utf8ToInt(tolower(b))
  m <- length(a)
  n <- length(b)
  if (m == 0) return(n)
  if (n == 0) return(m)
  d <- matrix(0L, m + 1, n + 1)
  d[, 1] <- 0:m
  d[1, ] <- 0:n
  for (i in seq_len(m)) {
    for (j in seq_len(n)) {
      cost <- if (a[i] == b[j]) 0L else 1L
      d[i + 1, j + 1] <- min(d[i, j + 1] + 1L, d[i + 1, j] + 1L, d[i, j] + cost)
      if (i > 1 && j > 1 && a[i] == b[j - 1] && a[i - 1] == b[j]) {
        d[i + 1, j + 1] <- min(d[i + 1, j + 1], d[i - 1, j - 1] + 1L)
      }
    }
  }
  d[m + 1, n + 1]
}

# The choice closest to `x`, if it is close enough to be a likely typo.
closest <- function(x, choices) {
  choices <- choices[choices != x]
  if (length(choices) == 0 || is.na(x) || !nzchar(x)) return(NULL)
  same_case <- choices[tolower(choices) == tolower(x)]
  if (length(same_case)) return(same_case[[1]])
  d <- vapply(choices, edit_distance, numeric(1), b = x, USE.NAMES = FALSE)
  limit <- max(1, min(3, floor(nchar(x) / 3)))
  if (min(d) > limit) return(NULL)
  choices[[which.min(d)]]
}

# Excel column letters for column numbers, and back.
col_letters <- function(n) {
  vapply(n, function(k) {
    out <- character()
    while (k > 0) {
      r <- (k - 1) %% 26
      out <- c(LETTERS[r + 1], out)
      k <- (k - 1) %/% 26
    }
    paste(out, collapse = "")
  }, character(1), USE.NAMES = FALSE)
}

col_number <- function(letters) {
  vapply(toupper(letters), function(s) {
    k <- 0
    for (ch in strsplit(s, "")[[1]]) k <- k * 26 + match(ch, LETTERS)
    k
  }, numeric(1), USE.NAMES = FALSE)
}

cell_ref <- function(row, col) paste0(col_letters(col), row)

# Rows and columns Excel allows.
max_row <- 1048576
max_col <- 16384
