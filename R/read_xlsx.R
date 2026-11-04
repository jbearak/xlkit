#' Read a sheet of an .xlsx workbook
#'
#' Reads one sheet into a tibble. Cells are named as Excel shows them: a
#' sheet by its tab name, a range as `"B5:F40"`, a header by its row
#' number. Each column's type comes from every cell in it.
#'
#' Column types, when guessed:
#'
#' | the column's cells hold | the column becomes |
#' |---|---|
#' | whole numbers only, each between -2,147,483,647 and 2,147,483,647 | integer |
#' | numbers, some not whole or larger | double |
#' | `TRUE` and `FALSE` only | logical |
#' | numbers formatted as dates without a time | `Date` |
#' | numbers formatted as dates, some with a time | `POSIXct` in UTC |
#' | numbers formatted as times of day or durations | `hms` |
#' | any text | character |
#' | nothing | logical, all `NA` |
#'
#' Blank cells, and text that is only spaces, are `NA` in every type.
#' Excel errors such as `#N/A` are `NA` with a warning, except in
#' `"text"` columns, which keep the error's text.
#'
#' Ranges: `"B5:F40"` reads exactly those cells; `"B5"` from B5 to the
#' last row and column with data; `"B5:F"` columns B to F from row 5 down
#' to the last row with a value; `"B:F"` columns B to F from their first
#' row with a value; `"5:40"` rows 5 to 40, every column with a value;
#' and a name reads that Excel table or defined name, from any sheet.
#'
#' Types for `types`: `"guess"`, `"text"` (or `"character"`), `"number"`
#' (or `"numeric"`, `"double"`), `"integer"`, `"logical"`, `"date"`,
#' `"datetime"`, `"time"` and `"skip"`.
#'
#' The guide, with every message and what to do about it, is
#' <https://github.com/jbearak/xlkit/blob/main/docs/r.md>.
#'
#' @param path An `.xlsx` or `.xlsm` file.
#' @param sheet A sheet name, or a position counting tabs from 1.
#' @param range `NULL` for the sheet's data, or a range as Excel shows
#'   it: `"B5:F40"`, `"B5"`, `"B5:F"`, `"B:F"`, `"5:40"`, or the name of
#'   an Excel table or defined name.
#' @param header `TRUE` for the first row of the range or of the sheet's
#'   data; `FALSE` for none (columns are named by their letters); a row
#'   number as Excel shows it, such as `5`; or consecutive rows, such as
#'   `4:5`, whose text is joined with a space.
#' @param names How header text becomes column names: `"unique"` (a
#'   blank header is named by its column letter and a repeat gets `_` and
#'   its letter), `"snake"`, `"stata"`, `"lower"`, `"upper"`, a rule and
#'   a case such as `c("stata", "lower")`, or a function of a character
#'   vector. Every choice gives unique names.
#' @param types `NULL` to guess every column; one type for every column;
#'   one per column in order; or types named by column, such as
#'   `c(zip = "text")`, with the rest guessed.
#' @param na Text that means missing. It matches the whole cell after
#'   trimming spaces, and only text cells.
#' @param dates `FALSE` reads date-formatted numbers as numbers.
#' @return A tibble. Columns whose name differs from their header text
#'   have a `label` attribute holding the text. Cells that did not convert
#'   and Excel errors are listed by [xlsx_problems()].
#' @seealso [read_sheets()] to read several sheets, [xlsx_sheets()] to
#'   list them.
#' @export
#' @examples
#' read_xlsx(xlkit_example("report.xlsx"))
#'
#' path <- xlkit_example("sales.xlsx")
#' read_xlsx(path, sheet = "Sales 2024", range = "B5:F40")
#' read_xlsx(path, sheet = "Sales 2024", header = 5)
#'
#' path <- xlkit_example("messy.xlsx")
#' read_xlsx(path, sheet = "Two-row header", header = 4:5)
#' read_xlsx(path, sheet = "Headers", names = "snake")
#' df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-"))
#' xlsx_problems(df)
read_xlsx <- function(path, sheet = 1, range = NULL, header = TRUE, names = "unique",
                      types = NULL, na = "", dates = TRUE) {
  read_one(path, sheet, range, header, names, types, na, dates, call = rlang::current_env())
}

# read_xlsx() for one sheet; `context` names the sheet in messages when
# read_sheets() reads several.
read_one <- function(path, sheet, range, header, names, types, na, dates, call, context = NULL) {
  full <- check_xlsx(path, call)
  header <- check_header(header, call)
  names <- check_names_arg(names, call)
  if (!is.character(na) || anyNA(na)) {
    rlang::abort("`na` must be a character vector, such as c(\"NA\", \".\").", call = call)
  }
  if (!rlang::is_bool(dates)) rlang::abort("`dates` must be TRUE or FALSE.", call = call)
  file <- basename(path)
  info <- workbook_info(full, call)

  r <- NULL
  if (!is.null(range)) {
    r <- parse_range(range, call)
    if (!is.null(r$name)) r <- resolve_name(r$name, full, call)
    if (!is.null(r$sheet)) sheet <- r$sheet
  }
  sheet_name <- resolve_sheet(sheet, info, file, call)
  g <- read_grid(full, sheet_name, call)
  rect <- resolve_rect(g, r, header, sheet_name, call)
  if (is.null(rect)) return(with_problems(tibble::tibble(), empty_problems()))

  cols <- seq(rect[[2]], rect[[4]])
  letters <- col_letters(cols)
  header_rows <- if (isTRUE(header)) rect[[1]] else if (isFALSE(header)) integer() else header
  first_body <- if (length(header_rows)) max(header_rows) + 1 else rect[[1]]
  body_rows <- if (first_body <= rect[[3]]) seq(first_body, rect[[3]]) else numeric()
  label <- function(msg) if (is.null(context)) msg else paste0("Sheet ", dquote(context), ": ", msg)

  # Header text and names.
  title <- NULL
  if (length(header_rows)) {
    text <- header_text(g, header_rows, cols)
    if (is.null(r) && isTRUE(header)) title <- title_row(g, rect, cols)
    made <- make_col_names(text, letters, names)
    col_names <- made$names
    if (nrow(made$repairs) && is.null(title)) {
      cells <- if (length(header_rows) == 1) {
        cell_ref(header_rows, cols)
      } else {
        paste0(cell_ref(min(header_rows), cols), ":", cell_ref(max(header_rows), cols))
      }
      names_message(made$repairs, col_names, text, cells, label("New names:"))
    }
  } else {
    text <- rep("", length(cols))
    col_names <- letters
  }
  if (!is.null(title)) {
    rlang::warn(c(
      label(paste0(
        "Row ", rect[[1]], " has text only in ", title$cell, " (", dquote(title$text),
        "), but the rows below have up to ", title$width, " columns."
      )),
      i = paste0("If the header is lower down, give its row: `header = ", title$header,
                 "`, or the range: `range = ", dquote(title$range), "`.")
    ))
  }

  col_types <- column_types(types, col_names, call)
  out <- list()
  problems <- list()
  notes <- list()
  for (j in seq_along(cols)) {
    type <- col_types[[j]]
    if (type == "skip") next
    cells <- column_cells(g, body_rows, cols[[j]])
    if (length(na) && any(nzchar(na))) {
      missing <- cells$kind == K_TEXT & trimws(cells$text) %in% na
      cells$kind[missing] <- K_EMPTY
    }
    if (!dates) cells$kind[cells$kind %in% c(K_DATE, K_DATETIME, K_TIME, K_DURATION)] <- K_NUMBER
    if (type == "guess") {
      type <- guess_type(cells$kind, cells$num)
      if (type == "text") {
        because <- text_because(cells$kind, cells$num)
        if (!is.null(because)) {
          because$name <- col_names[[j]]
          because$cells <- cell_ref(body_rows[because$cells], cols[[j]])
          because$values_text <- cells$text[cells$kind == K_TEXT]
          notes[[length(notes) + 1]] <- because
        }
      }
    }
    conv <- convert_cells(cells, type, g$is_1904)
    value <- conv$value
    if (nzchar(text[[j]]) && !identical(text[[j]], col_names[[j]])) attr(value, "label") <- text[[j]]
    out[[col_names[[j]]]] <- value
    bad <- which(!is.na(conv$problem))
    if (length(bad)) {
      problems[[length(problems) + 1]] <- list(
        cell = cell_ref(body_rows[bad], cols[[j]]),
        column = col_names[[j]],
        row = as.integer(body_rows[bad]),
        value = cell_text(lapply(cells, `[`, bad), g$is_1904),
        problem = conv$problem[bad],
        type = type
      )
    }
  }

  # Under a title row, the warning above says what is wrong.
  if (is.null(title)) for (note in notes) text_message(note, label)
  problems <- problems_tibble(problems)
  warn_problems(problems, label)
  df <- tibble::new_tibble(out, nrow = length(body_rows))
  with_problems(df, problems)
}

check_header <- function(header, call) {
  if (rlang::is_bool(header)) return(header)
  ok <- is.numeric(header) && length(header) >= 1 && !anyNA(header) &&
    all(header == round(header)) && all(header >= 1) &&
    (length(header) == 1 || all(diff(header) == 1))
  if (!ok) {
    rlang::abort(c(
      "`header` must be TRUE, FALSE, a row number such as 5, or consecutive rows such as 4:5.",
      x = paste0("It is ", paste(deparse(header), collapse = " "), ".")
    ), call = call)
  }
  if (any(header > max_row)) {
    rlang::abort("`header` goes past Excel's last row, 1,048,576.", call = call)
  }
  as.numeric(header)
}

# Pick a sheet by name or position; stop with the names when it is not
# there, and for chart sheets.
resolve_sheet <- function(sheet, info, file, call) {
  sheets <- info$names
  listing <- function(x) paste0("Its sheets are ", and_list(dquote(x)), ".")
  if (is.numeric(sheet)) {
    if (length(sheet) != 1 || is.na(sheet) || sheet != round(sheet) || sheet < 1) {
      rlang::abort("`sheet` must be a sheet name, or a position counting tabs from 1.", call = call)
    }
    if (sheet > length(sheets)) {
      rlang::abort(c(
        paste0(file, " has ", length(sheets), if (length(sheets) == 1) " sheet" else " sheets",
               ", so there is no sheet ", sheet, "."),
        i = listing(sheets)
      ), call = call)
    }
    i <- sheet
  } else if (is.character(sheet) && length(sheet) == 1 && !is.na(sheet)) {
    i <- match(sheet, sheets)
    if (is.na(i)) {
      msg <- paste0(file, " has no sheet ", dquote(sheet), ".")
      guess <- closest(sheet, sheets)
      if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", dquote(guess), "?"))
      rlang::abort(c(msg, i = listing(sheets)), call = call)
    }
  } else {
    rlang::abort("`sheet` must be a sheet name, or a position counting tabs from 1.", call = call)
  }
  if (info$types[[i]] != "worksheet") {
    what <- if (info$types[[i]] == "chart") "a chart sheet" else "not a worksheet"
    worksheets <- sheets[info$types == "worksheet"]
    rlang::abort(c(
      paste0("Sheet ", dquote(sheets[[i]]), " of ", file, " is ", what, ", and xlkit reads only worksheets."),
      i = paste0("Its worksheets are ", and_list(dquote(worksheets)), ".")
    ), call = call)
  }
  sheets[[i]]
}

# The header text of each column: the text of the header rows, joined
# with a space. A cell merged across columns names each of them.
header_text <- function(g, rows, cols) {
  parts <- vapply(rows, function(row) {
    t <- vapply(cols, function(col) {
      cell_text(column_cells(g, row, col), g$is_1904)
    }, character(1))
    t[is.na(t)] <- ""
    for (k in seq_len(nrow(g$merged))) {
      m <- g$merged[k, ]
      if (m[["r1"]] != row || m[["c2"]] == m[["c1"]]) next
      top_left <- cell_text(column_cells(g, row, m[["c1"]]), g$is_1904)
      if (is.na(top_left)) next
      fill <- cols > m[["c1"]] & cols <= m[["c2"]]
      t[fill] <- top_left
    }
    gsub("\\s+", " ", trimws(t))
  }, character(length(cols)))
  parts <- matrix(parts, nrow = length(cols))
  apply(parts, 1, function(p) paste(p[nzchar(p)], collapse = " "))
}

# A first row that looks like a title: text in one cell, while the rows
# below are wider and one of them looks like a header (text in as many
# cells as the widest row). Returns what the warning needs, or NULL.
title_row <- function(g, rect, cols) {
  r1 <- rect[[1]]
  if (rect[[3]] <= r1) return(NULL)
  rows <- seq(r1, rect[[3]])
  kinds <- vapply(cols, function(col) column_cells(g, rows, col)$kind, integer(length(rows)))
  kinds <- matrix(kinds, nrow = length(rows))
  first <- which(kinds[1, ] != K_EMPTY)
  if (length(first) != 1 || kinds[1, first] != K_TEXT) return(NULL)
  below <- kinds[-1, , drop = FALSE]
  width <- rowSums(below != K_EMPTY)
  if (max(width) < 2) return(NULL)
  all_text <- rowSums(below == K_TEXT) == width
  candidate <- which(width == max(width) & all_text)
  if (!length(candidate)) return(NULL)
  header_row <- rows[-1][candidate[[1]]]
  b <- bounds_in(g, ra = header_row, ca = rect[[2]], cb = rect[[4]])
  list(
    cell = cell_ref(r1, cols[[first]]),
    text = cell_text(column_cells(g, r1, cols[[first]]), g$is_1904),
    width = max(width),
    header = header_row,
    range = range_text(b[[1]], b[[2]], b[[3]], b[[4]])
  )
}

# The message for a column that is text only because of a few cells.
text_message <- function(note, label) {
  noun <- type_noun[[note$type]]
  t <- length(note$cells)
  shown <- paste0(note$cells, " (", dquote(note$values_text), ")")
  rlang::inform(c(
    label(paste0(
      "`", note$name, "` is text because ", t, " of its ", fmt_count(note$values), " values ",
      if (t == 1) paste0("is not ", type_noun1[[note$type]]) else paste0("are not ", noun),
      ":\n", and_list(shown), "."
    )),
    i = paste0("To read it as ", noun, ", use `types = c(", code_name(note$name), " = ",
               dquote(note$type), ")`; ", if (t == 1) "that cell becomes NA." else "those cells become NA.")
  ))
}
