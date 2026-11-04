#' The sheets of a workbook
#'
#' @param path An `.xlsx` or `.xlsm` file.
#' @return The sheet names, in tab order, as a character vector. Chart
#'   sheets are included; reading one is an error.
#' @export
#' @examples
#' xlsx_sheets(xlkit_example("sales.xlsx"))
xlsx_sheets <- function(path) {
  call <- rlang::current_env()
  full <- check_xlsx(path, call)
  workbook_info(full, call)$names
}
