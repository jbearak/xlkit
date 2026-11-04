#' A cell style
#'
#' Makes a style for [write_xlsx()]'s `header_style`, `styles` and
#' `merge`. Arguments left `NULL` keep what the cell has, so styles
#' combine: a column's style, then a range's, each changing only what it
#' sets.
#'
#' @param bold,italic,underline,wrap `TRUE` or `FALSE`. `wrap` wraps long
#'   text onto several lines within the cell.
#' @param size The font size in points, such as `14`.
#' @param font The font's name, such as `"Arial"`.
#' @param color,fill The text color and the cell's fill color, as
#'   `"#RRGGBB"` or an R color name such as `"lightyellow"`
#'   (see [grDevices::colors()]).
#' @param border `"thin"`, `"medium"`, `"thick"` or `"double"` for all four
#'   sides; four of them for the top, right, bottom and left; or some
#'   sides by name, such as `c(top = "thin")`.
#' @param align `"left"`, `"center"` or `"right"`.
#' @param valign `"top"`, `"center"` or `"bottom"`.
#' @param indent The text's indent, in steps of about one character.
#' @param format A number format, such as `"0.0%"` or `"yyyy-mm-dd"`.
#' @return An `xl_style` object.
#' @seealso [write_xlsx()]
#' @export
#' @examples
#' xl_style(bold = TRUE, fill = "#FFF2CC")
#' xl_style(border = c(top = "thin"), format = "#,##0")
xl_style <- function(bold = NULL, italic = NULL, underline = NULL, size = NULL, font = NULL,
                     color = NULL, fill = NULL, border = NULL, align = NULL, valign = NULL,
                     wrap = NULL, indent = NULL, format = NULL) {
  call <- rlang::current_env()
  flag <- function(x, what) {
    if (is.null(x) || rlang::is_bool(x)) return(x)
    rlang::abort(paste0("`", what, "` must be TRUE, FALSE or NULL."), call = call)
  }
  string <- function(x, what) {
    if (is.null(x) || (rlang::is_string(x) && nzchar(x))) return(x)
    rlang::abort(paste0("`", what, "` must be one string, or NULL."), call = call)
  }
  choice <- function(x, what, choices) {
    if (is.null(x)) return(x)
    if (rlang::is_string(x) && x %in% choices) return(x)
    rlang::abort(c(
      paste0("`", what, "` must be ", and_or(dquote(choices)), ", or NULL."),
      x = paste0("It is ", paste(deparse(x), collapse = " "), ".")
    ), call = call)
  }
  if (!is.null(size) && !(is.numeric(size) && length(size) == 1 && !is.na(size) && size >= 1 && size <= 409)) {
    rlang::abort("`size` must be a font size in points, from 1 to 409, or NULL.", call = call)
  }
  if (!is.null(indent) && !(is.numeric(indent) && length(indent) == 1 && !is.na(indent) &&
                            indent == round(indent) && indent >= 0 && indent <= 250)) {
    rlang::abort("`indent` must be a whole number from 0 to 250, or NULL.", call = call)
  }
  style <- list(
    bold = flag(bold, "bold"),
    italic = flag(italic, "italic"),
    underline = flag(underline, "underline"),
    size = if (!is.null(size)) as.numeric(size),
    font = string(font, "font"),
    color = style_color(color, "color", call),
    fill = style_color(fill, "fill", call),
    border = style_border(border, call),
    align = choice(align, "align", c("left", "center", "right")),
    valign = choice(valign, "valign", c("top", "center", "bottom")),
    wrap = flag(wrap, "wrap"),
    indent = if (!is.null(indent)) as.integer(indent),
    format = string(format, "format")
  )
  structure(style[!vapply(style, is.null, logical(1))], class = "xl_style")
}

# "a or b", "a, b or c"
and_or <- function(x) {
  n <- length(x)
  if (n <= 1) return(paste(x, collapse = ""))
  paste0(paste(x[-n], collapse = ", "), " or ", x[n])
}

# "#RRGGBB" from "#rrggbb" or an R color name.
style_color <- function(x, what, call) {
  if (is.null(x)) return(NULL)
  bad <- function(extra = NULL) {
    rlang::abort(c(
      paste0("`", what, "` must be a color as \"#RRGGBB\" or an R color name such as \"lightyellow\"."),
      extra
    ), call = call)
  }
  if (!rlang::is_string(x)) bad()
  if (grepl("^#[0-9A-Fa-f]{6}$", x)) return(toupper(x))
  if (startsWith(x, "#")) bad(c(x = paste0(dquote(x), " is not in the form \"#RRGGBB\".")))
  if (!tolower(x) %in% grDevices::colors()) {
    guess <- closest(tolower(x), grDevices::colors())
    bad(c(x = paste0(dquote(x), " is not an R color name."),
          if (!is.null(guess)) c(i = paste0("Did you mean ", dquote(guess), "?"))))
  }
  rgb <- grDevices::col2rgb(x)
  sprintf("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
}

border_sides <- c("top", "right", "bottom", "left")
border_kinds <- c("thin", "medium", "thick", "double")

# A border as c(top =, right =, bottom =, left =), NA for a side left as
# it is.
style_border <- function(x, call) {
  if (is.null(x)) return(NULL)
  bad <- function() {
    rlang::abort(c(
      "`border` must be \"thin\", \"medium\", \"thick\" or \"double\"; four of them for top, right, bottom and left; or sides by name, such as c(top = \"thin\").",
      x = paste0("It is ", paste(deparse(x), collapse = " "), ".")
    ), call = call)
  }
  if (!is.character(x) || anyNA(x) || !all(x %in% border_kinds)) bad()
  out <- rlang::set_names(rep(NA_character_, 4), border_sides)
  sides <- names(x)
  if (is.null(sides)) {
    if (length(x) == 1) out[] <- x else if (length(x) == 4) out[] <- x else bad()
  } else {
    if (!all(sides %in% border_sides) || anyDuplicated(sides)) bad()
    out[sides] <- x
  }
  out
}

#' @export
format.xl_style <- function(x, ...) {
  parts <- vapply(names(x), function(f) {
    v <- x[[f]]
    if (f == "border") {
      set <- !is.na(v)
      if (all(set) && length(unique(v)) == 1) return(paste("border", v[[1]]))
      return(paste0("border ", paste(names(v)[set], v[set], collapse = ", ")))
    }
    if (is.logical(v)) return(if (v) f else paste0("no ", f))
    if (is.character(v)) return(paste0(f, " ", dquote(v)))
    paste(f, v)
  }, character(1))
  paste0("<xl_style> ", if (length(parts)) paste(parts, collapse = ", ") else "(keeps the cell's style)")
}

#' @export
print.xl_style <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

# `b` on top of `a`: what `b` sets replaces what `a` has.
style_merge <- function(a, b) {
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  out <- unclass(a)
  for (f in names(b)) {
    if (f == "border" && !is.null(out$border)) {
      set <- !is.na(b$border)
      out$border[set] <- b$border[set]
    } else {
      out[[f]] <- b[[f]]
    }
  }
  structure(out, class = "xl_style")
}

is_style <- function(x) inherits(x, "xl_style")

#' Excel formulas
#'
#' Marks text as Excel formulas, for [write_xlsx()]: a column of class
#' `xl_formula` is written as formulas, one per cell, and Excel calculates
#' them when it opens the file. Text that is not marked is always written
#' as text, even when it starts with `=`.
#'
#' The file stores no result for a formula until Excel calculates it, so
#' [read_xlsx()] reads a formula's cell as `NA` until the workbook has been
#' opened and saved in Excel.
#'
#' @param x A character vector of formulas, with or without the leading
#'   `=`, such as `"SUM(C2:C9)"`. `NA` is an empty cell.
#' @return An `xl_formula` vector.
#' @seealso [write_xlsx()]
#' @export
#' @examples
#' df <- data.frame(x = 1:3)
#' df$double <- xl_formula(paste0("A", 2:4, "*2"))
#' write_xlsx(df, file.path(tempdir(), "formulas.xlsx"), replace = TRUE)
xl_formula <- function(x) {
  if (inherits(x, "xl_formula")) return(x)
  if (!is.character(x) && !(is.logical(x) && all(is.na(x)))) {
    rlang::abort(c(
      "`x` must be a character vector of formulas, such as \"SUM(C2:C9)\".",
      x = paste0("It is ", vctrs::vec_ptype_full(x), ".")
    ))
  }
  vctrs::new_vctr(as.character(x), class = "xl_formula", inherit_base_type = TRUE)
}

#' @export
format.xl_formula <- function(x, ...) {
  out <- vctrs::vec_data(x)
  out <- ifelse(is.na(out) | startsWith(out, "="), out, paste0("=", out))
  out
}

#' @exportS3Method vctrs::vec_ptype_abbr
vec_ptype_abbr.xl_formula <- function(x, ...) "fmla"
