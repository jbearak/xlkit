# Column types (ADR 0004): guessed from every cell, or chosen with
# `types`. A conversion that does not fit a cell makes it NA and records
# a problem; xlsx_problems() lists them.

type_aliases <- c(
  guess = "guess", text = "text", character = "text", number = "number",
  numeric = "number", double = "number", integer = "integer", logical = "logical",
  date = "date", datetime = "datetime", time = "time", skip = "skip"
)

# What a type reads as, in messages: "could not be read as ...", and
# "... is not ..." for one cell.
type_noun <- c(
  number = "numbers", integer = "whole numbers", logical = "TRUE or FALSE",
  date = "dates", datetime = "date-times", time = "times"
)
type_noun1 <- c(
  number = "a number", integer = "a whole number", logical = "TRUE or FALSE",
  date = "a date", datetime = "a date-time", time = "a time"
)

# One type per column, from `types` (NULL, one type, one per column, or
# named by column).
column_types <- function(types, col_names, call) {
  n <- length(col_names)
  if (is.null(types)) return(rep("guess", n))
  if (!is.character(types) || anyNA(types)) {
    rlang::abort("`types` must be a character vector of types, such as c(zip = \"text\").", call = call)
  }
  bad <- setdiff(unique(types), names(type_aliases))
  if (length(bad)) {
    msg <- paste0("`types` has ", dquote(bad[[1]]), ", which is not a type.")
    guess <- closest(bad[[1]], names(type_aliases))
    if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", dquote(guess), "?"))
    msg <- c(msg, i = paste0("The types are ", and_list(dquote(c(
      "guess", "text", "number", "integer", "logical", "date", "datetime", "time", "skip"
    ))), "."))
    rlang::abort(msg, call = call)
  }
  given <- names(types)
  types <- unname(type_aliases[types])
  if (is.null(given) || all(!nzchar(given))) {
    if (length(types) == 1) return(rep(types, n))
    if (length(types) == n) return(types)
    rlang::abort(c(
      paste0("`types` has ", length(types), " types, but the sheet has ", n, " columns."),
      i = "Give one type for all, one per column, or name the columns: `types = c(zip = \"text\")`."
    ), call = call)
  }
  if (any(!nzchar(given))) {
    rlang::abort("`types` must name every type or none.", call = call)
  }
  unknown <- setdiff(given, col_names)
  if (length(unknown)) {
    msg <- paste0("`types` names `", unknown[[1]], "`, which is not a column.")
    guess <- closest(unknown[[1]], col_names)
    if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean `", guess, "`?"))
    msg <- c(msg, i = paste0("The columns are ", and_list_first(paste0("`", col_names, "`"), 20), "."))
    rlang::abort(msg, call = call)
  }
  out <- rep("guess", n)
  out[match(given, col_names)] <- types
  out
}

# The type a column guesses from its cells' kinds.
guess_type <- function(kind, num) {
  k <- kind[kind != K_EMPTY & kind != K_ERROR]
  if (!length(k)) return("logical")
  u <- unique(k)
  if (all(u == K_LOGICAL)) return("logical")
  if (all(u == K_NUMBER)) {
    x <- num[kind == K_NUMBER]
    whole <- all(x == round(x)) && all(abs(x) <= 2147483647)
    return(if (whole) "integer" else "number")
  }
  if (all(u == K_DATE)) return("date")
  if (all(u %in% c(K_DATE, K_DATETIME))) return("datetime")
  if (all(u %in% c(K_TIME, K_DURATION))) return("time")
  "text"
}

# For a column guessed as text: the type it would have but for a few
# text cells, or NULL. A few is 10 or fewer, and fewer than 1 in 10 of
# its values.
text_because <- function(kind, num) {
  values <- kind != K_EMPTY & kind != K_ERROR
  text <- kind == K_TEXT
  n_text <- sum(text)
  if (n_text == 0 || n_text > 10 || n_text * 10 >= sum(values)) return(NULL)
  rest <- kind
  rest[text] <- K_EMPTY
  type <- guess_type(rest, num)
  if (!type %in% c("integer", "number", "date", "datetime", "time")) return(NULL)
  if (type == "integer") type <- "number"
  list(type = type, cells = which(text), values = sum(values))
}

parse_number <- function(x) {
  x <- trimws(x)
  ok <- grepl("^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?$", x)
  out <- rep(NA_real_, length(x))
  out[ok] <- as.numeric(x[ok])
  out
}

# Text as 2024-03-01, with an optional time 14:30 or 14:30:00(.5), as
# seconds since 1970-01-01 UTC; NA when it is not.
parse_datetime_text <- function(x, time = TRUE) {
  x <- trimws(x)
  pattern <- if (time) {
    "^([0-9]{4}-[0-9]{2}-[0-9]{2})(?:[T ]([0-9]{2}):([0-9]{2})(?::([0-9]{2}(?:[.][0-9]+)?))?)?$"
  } else {
    "^([0-9]{4}-[0-9]{2}-[0-9]{2})()()()$"
  }
  out <- rep(NA_real_, length(x))
  m <- regmatches(x, regexec(pattern, x, perl = TRUE))
  for (i in which(lengths(m) > 0)) {
    p <- m[[i]]
    d <- as.Date(p[[2]], format = "%Y-%m-%d")
    if (is.na(d) || format(d, "%Y-%m-%d") != p[[2]]) next
    h <- if (nzchar(p[[3]])) as.numeric(p[[3]]) else 0
    mi <- if (nzchar(p[[4]])) as.numeric(p[[4]]) else 0
    s <- if (nzchar(p[[5]])) as.numeric(p[[5]]) else 0
    if (h > 23 || mi > 59 || s >= 60) next
    out[[i]] <- as.numeric(d) * 86400 + h * 3600 + mi * 60 + s
  }
  out
}

# Text as 14:30 or 14:30:15(.5), as seconds; NA when it is not.
parse_time_text <- function(x) {
  x <- trimws(x)
  m <- regmatches(x, regexec("^([0-9]{1,3}):([0-9]{2})(?::([0-9]{2}(?:[.][0-9]+)?))?$", x, perl = TRUE))
  out <- rep(NA_real_, length(x))
  for (i in which(lengths(m) > 0)) {
    p <- m[[i]]
    mi <- as.numeric(p[[3]])
    s <- if (nzchar(p[[4]])) as.numeric(p[[4]]) else 0
    if (mi > 59 || s >= 60) next
    out[[i]] <- as.numeric(p[[2]]) * 3600 + mi * 60 + s
  }
  out
}

# Convert a column's cells to `type`. Returns list(value, problem), where
# problem is NA for cells that converted and says why for those that
# did not. Excel errors are problems in every type but "text".
convert_cells <- function(cells, type, is_1904) {
  kind <- cells$kind
  num <- cells$num
  n <- length(kind)
  problem <- rep(NA_character_, n)
  numeric_kind <- kind %in% K_NUMERIC
  text <- kind == K_TEXT
  if (type != "text") problem[kind == K_ERROR] <- "Excel error"

  value <- switch(type,
    text = cell_text(cells, is_1904),
    logical = {
      v <- rep(NA, n)
      ok <- numeric_kind | kind == K_LOGICAL
      v[ok] <- num[ok] != 0
      t <- toupper(trimws(cells$text[text]))
      v[text] <- ifelse(t == "TRUE", TRUE, ifelse(t == "FALSE", FALSE, NA))
      problem[text & is.na(v)] <- "not TRUE or FALSE"
      v
    },
    number = ,
    integer = {
      v <- rep(NA_real_, n)
      ok <- numeric_kind | kind == K_LOGICAL
      v[ok] <- num[ok]
      v[text] <- parse_number(cells$text[text])
      problem[text & is.na(v)] <- "not a number"
      if (type == "integer") {
        frac <- !is.na(v) & v != round(v)
        big <- !is.na(v) & !frac & abs(v) > 2147483647
        problem[frac] <- "not a whole number"
        problem[big] <- "too large for an integer"
        v[frac | big] <- NA
        v <- as.integer(v)
      }
      v
    },
    date = ,
    datetime = {
      secs <- rep(NA_real_, n)
      secs[numeric_kind] <- serial_seconds(num[numeric_kind], is_1904)
      leap <- numeric_kind & is_leap_day(num, is_1904)
      negative <- numeric_kind & !is.na(num) & num < 0
      problem[leap] <- "29 February 1900, a day that did not exist"
      problem[negative] <- "a negative number, which is not a date"
      secs[negative] <- NA
      secs[text] <- parse_datetime_text(cells$text[text], time = type == "datetime")
      problem[text & is.na(secs)] <- if (type == "date") "not a date" else "not a date-time"
      problem[kind == K_LOGICAL] <- if (type == "date") "not a date" else "not a date-time"
      if (type == "date") new_date(floor(secs / 86400)) else .POSIXct(secs, tz = "UTC")
    },
    time = {
      secs <- rep(NA_real_, n)
      clock <- numeric_kind & kind != K_DURATION
      secs[clock] <- day_seconds(num[clock])
      dur <- kind == K_DURATION
      secs[dur] <- round(num[dur] * 86400, 3)
      secs[text] <- parse_time_text(cells$text[text])
      problem[text & is.na(secs)] <- "not a time"
      problem[kind == K_LOGICAL] <- "not a time"
      hms::new_hms(secs)
    }
  )
  list(value = value, problem = problem)
}
