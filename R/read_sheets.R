#' Read several sheets
#'
#' Reads each sheet of a workbook into a tibble, with the same
#' [read_xlsx()] arguments for every sheet.
#'
#' Chart sheets are skipped unless named. Each tibble keeps its own
#' [xlsx_problems()]. To stack sheets with the same columns into one
#' table, use `dplyr::bind_rows(all, .id = "sheet")`.
#'
#' @param path An `.xlsx` or `.xlsm` file.
#' @param sheets `NULL` for every worksheet; a vector of sheet names or
#'   positions; or one regular expression matched against the names, such
#'   as `"^Sales"`.
#' @param ... Arguments for [read_xlsx()], except `sheet`.
#' @return A list of tibbles named by sheet, in tab order.
#' @export
#' @examples
#' all <- read_sheets(xlkit_example("sales.xlsx"))
#' names(all)
#' read_sheets(xlkit_example("sales.xlsx"), sheets = "^Sales", header = 5)
read_sheets <- function(path, sheets = NULL, ...) {
  call <- rlang::current_env()
  args <- list(...)
  # R would match `sheet =` to `sheets` by partial matching.
  if ("sheet" %in% names(args) || "sheet" %in% names(sys.call())) {
    rlang::abort(c(
      "`read_sheets()` takes `sheets`, not `sheet`.",
      i = "Give the sheets to read as `sheets = c(\"Sales 2023\", \"Sales 2024\")`, or a regular expression."
    ), call = call)
  }
  args <- utils_modify(list(range = NULL, header = TRUE, names = "unique", types = NULL, na = "", dates = TRUE), args)
  full <- check_xlsx(path, call)
  info <- workbook_info(full, call)
  chosen <- choose_sheets(sheets, info, basename(path), call)
  out <- lapply(chosen, function(s) {
    read_one(path, s, args$range, args$header, args$names, args$types, args$na, args$dates,
             call = call, context = if (length(chosen) > 1) s else NULL)
  })
  names(out) <- chosen
  out
}

utils_modify <- function(defaults, args) {
  unknown <- setdiff(names(args), names(defaults))
  if (length(unknown) || (length(args) && is.null(names(args))) || any(!nzchar(names(args)))) {
    rlang::abort(c(
      "`...` must be named arguments of `read_xlsx()`.",
      i = "They are `range`, `header`, `names`, `types`, `na` and `dates`."
    ), call = rlang::caller_env())
  }
  defaults[names(args)] <- args
  defaults
}

choose_sheets <- function(sheets, info, file, call) {
  worksheets <- info$names[info$types == "worksheet"]
  if (is.null(sheets)) return(worksheets)
  if (is.numeric(sheets)) {
    return(vapply(sheets, resolve_sheet, character(1), info = info, file = file, call = call))
  }
  if (!is.character(sheets) || anyNA(sheets) || !length(sheets)) {
    rlang::abort("`sheets` must be NULL, sheet names or positions, or a regular expression.", call = call)
  }
  if (length(sheets) > 1 || sheets %in% info$names) {
    return(vapply(sheets, resolve_sheet, character(1), info = info, file = file, call = call, USE.NAMES = FALSE))
  }
  hit <- tryCatch(suppressWarnings(grepl(sheets, worksheets, perl = TRUE)), error = function(e) NULL)
  if (is.null(hit)) {
    rlang::abort(paste0("`sheets = ", dquote(sheets), "` is neither a sheet of ", file, " nor a regular expression."), call = call)
  }
  if (!any(hit)) {
    rlang::abort(c(
      paste0("No sheet of ", file, " is named ", dquote(sheets), " or matches it as a regular expression."),
      i = paste0("Its sheets are ", and_list(dquote(info$names)), ".")
    ), call = call)
  }
  worksheets[hit]
}
