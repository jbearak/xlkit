#' Example workbooks
#'
#' The workbooks that ship with xlkit, so that every example runs as
#' written: `report.xlsx` (one sheet, `Scores`), `sales.xlsx` (five
#' sheets; `Sales 2024` has a title in B1, a note in B2 and its table in
#' B5:F40), `messy.xlsx` (sheets `Headers`, `Two-row header`, `Types` and
#' `Missing`), `dates.xlsx` and its copy in the 1904 date system,
#' `dates1904.xlsx`, and `template.xlsx` (a formatted `Cover` sheet, a
#' chart on `Chart`, and a `Data` sheet the chart plots). Copy one before
#' writing to it.
#'
#' @param name A workbook's file name, or `NULL` to list them.
#' @return The path of the workbook, or the names of all of them.
#' @export
#' @examples
#' xlkit_example()
#' xlkit_example("report.xlsx")
xlkit_example <- function(name = NULL) {
  dir <- system.file("extdata", package = "xlkit", mustWork = TRUE)
  files <- sort(list.files(dir, pattern = "[.]xlsx$"), method = "radix")
  if (is.null(name)) return(files)
  if (!is.character(name) || length(name) != 1 || is.na(name) || !name %in% files) {
    shown <- if (is.character(name) && length(name) == 1) dquote(name) else paste(deparse(name), collapse = " ")
    msg <- paste0("xlkit has no example workbook ", shown, ".")
    guess <- if (is.character(name) && length(name) == 1) closest(name, files)
    if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", dquote(guess), "?"))
    rlang::abort(c(msg, i = paste0("The examples are ", and_list(dquote(files)), ".")))
  }
  file.path(dir, name)
}
