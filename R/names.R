# Column names from header text (docs/r.md, "Header rows and column
# names"). Every rule gives unique names. Blank and repeated headers are
# repaired with the column letter, as are names a rule (or Stata's
# 32-character cut) makes equal, and those repairs get a message.

name_rules <- c("unique", "snake", "stata")
name_cases <- c("lower", "upper")

check_names_arg <- function(names, call) {
  if (is.function(names)) return(names)
  ok <- is.character(names) && length(names) %in% 1:2 && !anyNA(names) &&
    all(names %in% c(name_rules, name_cases)) &&
    sum(names %in% name_rules) <= 1 && sum(names %in% name_cases) <= 1
  if (!ok) {
    rlang::abort(c(
      "`names` must be \"unique\", \"snake\", \"stata\", \"lower\" or \"upper\", a rule and a case such as c(\"stata\", \"lower\"), or a function.",
      x = paste0("It is ", paste(deparse(names), collapse = " "), ".")
    ), call = call)
  }
  names
}

# Names for columns with header `text` (NA or "" for blank) and Excel
# column letters `letters`. Returns list(names, repairs), where repairs
# is a data frame of the columns renamed because their header was blank
# or repeated, or the rule made it repeat an earlier name: index, why
# ("blank", "repeat", "rule" or "cut"), and the earlier column it repeats.
make_col_names <- function(text, letters, rule) {
  text[is.na(text)] <- ""
  if (is.function(rule)) {
    out <- rule(text)
    if (!is.character(out) || length(out) != length(text)) {
      rlang::abort(c(
        "The function given as `names` must return a character vector as long as its input.",
        x = paste0("Given ", length(text), " headers, it returned ", class(out)[[1]], " of length ", length(out), ".")
      ))
    }
    out[is.na(out)] <- ""
    u <- uniquify(out, letters)
    return(list(names = finish_unique(u$names, letters, identity)$names, repairs = u$repairs))
  }
  u <- uniquify(text, letters)
  case <- function(x) {
    if ("lower" %in% rule) x <- tolower(x)
    if ("upper" %in% rule) x <- toupper(x)
    x
  }
  # Stata's checks come after the case, so c("stata", "lower") cannot
  # turn IF into the reserved word if.
  convert <- function(x) {
    if ("snake" %in% rule) case(snake_name(x)) else if ("stata" %in% rule) stata_name(case(x)) else case(x)
  }
  out <- convert(u$names)
  # A rule can make a name empty ("%" under "stata"); use the letter.
  empty <- !nzchar(out)
  out[empty] <- convert(letters[empty])
  limit <- if ("stata" %in% rule) 32 else Inf
  # The names before Stata's cut, to tell a repeat the cut made.
  uncut <- if ("stata" %in% rule) stata_name(case(u$names), cut = FALSE) else out
  uncut[empty] <- out[empty]
  f <- finish_unique(out, letters, convert, base = u$names, limit = limit, uncut = uncut)
  more <- f$repairs[!f$repairs$index %in% u$repairs$index, , drop = FALSE]
  repairs <- rbind(u$repairs, more)
  list(names = f$names, repairs = repairs[order(repairs$index), , drop = FALSE])
}

# Blank headers become their column letter; a header that repeats an
# earlier name gets "_" and its letter.
uniquify <- function(text, letters) {
  out <- text
  blank <- !nzchar(trimws(text))
  out[blank] <- letters[blank]
  why <- ifelse(blank, "blank", NA_character_)
  of <- rep(NA_integer_, length(text))
  for (i in seq_along(out)) {
    if (blank[i] || i == 1) next
    earlier <- match(out[i], out[seq_len(i - 1)])
    if (!is.na(earlier)) {
      out[i] <- paste0(text[i], "_", letters[i])
      why[i] <- "repeat"
      of[i] <- earlier
    }
  }
  repaired <- which(!is.na(why))
  list(names = out, repairs = data.frame(index = repaired, why = why[repaired], of = of[repaired]))
}

# Make names unique that a rule made equal: the later one gets "_" and
# its letter, then a number if that is not enough. Under a length limit
# (Stata's 32), the stem is cut to keep the suffix. Returns list(names,
# repairs), with why "cut" when the names differed before the cut.
finish_unique <- function(out, letters, convert, base = out, limit = Inf, uncut = out) {
  index <- integer()
  why <- character()
  of <- integer()
  for (i in seq_along(out)) {
    k <- 1
    earlier <- match(out[i], out[seq_len(i - 1)])
    if (!is.na(earlier)) {
      index <- c(index, i)
      why <- c(why, if (uncut[i] != uncut[earlier]) "cut" else "rule")
      of <- c(of, earlier)
    }
    while (out[i] %in% out[seq_len(i - 1)]) {
      suffix <- convert(paste0("x_", letters[i], if (k > 1) paste0("_", k)))
      suffix <- substr(suffix, 2, nchar(suffix))
      stem <- convert(base[i])
      if (is.finite(limit)) stem <- substr(stem, 1, limit - nchar(suffix))
      out[i] <- paste0(stem, suffix)
      k <- k + 1
    }
  }
  list(names = out, repairs = data.frame(index = index, why = why, of = of))
}

snake_name <- function(x) {
  x <- gsub("%", " percent ", x, fixed = TRUE)
  x <- gsub("#", " number ", x, fixed = TRUE)
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  x <- tolower(x)
  x <- gsub("[^[:alnum:]]+", "_", x)
  gsub("^_+|_+$", "", x)
}

stata_reserved <- c(
  "_all", "_b", "byte", "_coef", "_cons", "double", "float", "if", "in", "int", "long",
  "_n", "_N", "_pi", "_pred", "_rc", "_skip", "strL", "using", "with"
)

# Valid Stata names: letters, digits and underscores, at most 32
# characters (unless `cut = FALSE`), not starting with a digit, and not a
# reserved word.
stata_name <- function(x, cut = TRUE) {
  x <- iconv(x, "UTF-8", "ASCII", sub = "_")
  x[is.na(x)] <- ""
  x <- gsub("[^A-Za-z0-9_]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x <- ifelse(grepl("^[0-9]", x) | x %in% stata_reserved, paste0("_", x), x)
  if (!cut) return(x)
  # The cut can end on a run of other characters; drop its "_" there too.
  out <- sub("_+$", "", substr(x, 1, 32))
  ifelse(nzchar(out), out, substr(x, 1, 32))
}

# The message for repairs, naming the header cells and the new names.
names_message <- function(repairs, names, text, header_cells, title = "New names:") {
  lines <- character()
  for (k in seq_len(nrow(repairs))) {
    i <- repairs$index[[k]]
    lines[[k]] <- if (repairs$why[[k]] == "blank") {
      paste0(header_cells[[i]], " (blank) is `", names[[i]], "`")
    } else {
      of <- header_cells[[repairs$of[[k]]]]
      why <- switch(repairs$why[[k]],
        "repeat" = paste0("it repeats ", of),
        "rule" = paste0("it would repeat ", of, " after the rule"),
        "cut" = paste0("cut to 32 characters, it would repeat ", of)
      )
      shown <- if (nzchar(text[[i]])) paste0(" ", dquote(text[[i]])) else " (blank)"
      paste0(header_cells[[i]], shown, " is `", names[[i]], "` (", why, ")")
    }
  }
  rlang::inform(c(
    title,
    rlang::set_names(lines, rep("*", length(lines))),
    i = "Choose another rule with `names =`, or set your own with `names(df) <- ...`."
  ))
}
