# Calls into the Rust core (src/init.c, src/rust) and the checks before
# them. The C side returns list(status, message) when Rust failed; the
# errors are raised here, after Rust has freed its memory (ADR 0002).

# Stop unless `path` is a readable .xlsx file. Returns the expanded path.
check_xlsx <- function(path, call) {
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    rlang::abort("`path` must be the path of an .xlsx file, as one string.", call = call)
  }
  full <- path.expand(path)
  if (!file.exists(full)) {
    msg <- c(paste0(path, " does not exist."))
    folder <- dirname(full)
    if (!dir.exists(folder)) {
      msg <- c(msg, i = paste0("Its folder, ", dirname(path), ", does not exist either."))
    } else {
      files <- list.files(folder)
      guess <- closest(basename(full), files)
      if (!is.null(guess)) msg <- c(msg, i = paste0("Did you mean ", guess, "?"))
    }
    rlang::abort(msg, call = call)
  }
  if (dir.exists(full)) {
    rlang::abort(paste0(path, " is a folder, not an .xlsx file."), call = call)
  }
  head <- readBin(full, "raw", 512)
  zip <- as.raw(c(0x50, 0x4b, 0x03, 0x04))
  if (length(head) >= 4 && identical(head[1:4], zip)) return(full)
  rlang::abort(paste0(basename(path), " is not an .xlsx workbook (", what_file(head), ")."), call = call)
}

# What a file that is not a zip archive looks like, from its first bytes.
what_file <- function(head) {
  starts <- function(bytes) length(head) >= length(bytes) && identical(head[seq_along(bytes)], as.raw(bytes))
  if (length(head) == 0) return("it is empty")
  if (starts(c(0xd0, 0xcf, 0x11, 0xe0))) {
    return("it looks like an .xls workbook, or an .xlsx encrypted with a password")
  }
  if (starts(utf8ToInt("%PDF"))) return("it looks like a PDF")
  if (starts(c(0x3c)) || starts(c(0xef, 0xbb, 0xbf, 0x3c))) {
    return("it looks like HTML or XML")
  }
  bytes <- as.integer(head)
  text <- all(bytes %in% c(9L, 10L, 13L) | (bytes >= 32L & bytes != 127L))
  if (text) return("it looks like text")
  "it is not a zip archive, which every .xlsx file is"
}

# Raise the error for a failed call into Rust.
rust_failed <- function(res, path, call, sheet = NULL) {
  file <- basename(path)
  msg <- switch(as.character(res$status),
    "1" = paste0(file, " could not be opened: ", res$message, "."),
    "2" = paste0(file, " is not an .xlsx workbook (it is not a zip archive that can be read: ", res$message, ")."),
    "3" = paste0(file, " is not an .xlsx workbook (", res$message, ")."),
    "4" = paste0(file, " is password-protected, and xlkit cannot read it."),
    "5" = paste0(file, " could not be read: ", res$message, "."),
    "6" = paste0(file, " has no sheet ", dquote(res$message), "."),
    "7" = paste0("Sheet ", dquote(res$message), " of ", file, " is not a worksheet."),
    c(paste0("xlkit's reader failed on ", file, ": ", res$message, "."),
      i = "Please report this at <https://github.com/jbearak/xlkit/issues>.")
  )
  rlang::abort(msg, call = call)
}

# The sheets of a workbook: list(names, types, is_1904), where a type is
# "worksheet", "chart" or "other".
workbook_info <- function(path, call) {
  res <- .Call(C_xl_info, enc2utf8(path))
  if (!is.null(res$status)) rust_failed(res, path, call)
  types <- c("worksheet", "chart", "other")[res$ints[-1] + 1L]
  list(names = res$strings, types = types, is_1904 = res$ints[[1]] == 1L)
}

# Defined names and Excel tables: a data frame of name, sheet, formula,
# and for tables the rows and columns they cover.
workbook_names <- function(path, call) {
  res <- .Call(C_xl_names, enc2utf8(path))
  if (!is.null(res$status)) rust_failed(res, path, call)
  n <- length(res$strings) %/% 3
  s <- matrix(res$strings, nrow = 3)
  d <- matrix(res$ints, nrow = 5)
  data.frame(
    name = s[1, seq_len(n)], sheet = s[2, seq_len(n)], formula = s[3, seq_len(n)],
    r1 = d[1, seq_len(n)], c1 = d[2, seq_len(n)], r2 = d[3, seq_len(n)], c2 = d[4, seq_len(n)],
    header_rows = d[5, seq_len(n)],
    stringsAsFactors = FALSE
  )
}

# One sheet's used cells. Cells are column-major from (r0, c0); `kind`
# is 0 empty, 1 number, 2 date, 3 date-time, 4 time, 5 duration,
# 6 logical, 7 text, 8 Excel error.
read_grid <- function(path, sheet, call) {
  res <- .Call(C_xl_read, enc2utf8(path), enc2utf8(sheet))
  if (!is.null(res$status)) rust_failed(res, path, call, sheet)
  ints <- res$ints
  nrow <- ints[[3]]
  ncol <- ints[[4]]
  n <- nrow * ncol
  n_merged <- ints[[6]]
  merged <- matrix(ints[6 + seq_len(4 * n_merged)], ncol = 4, byrow = TRUE,
                   dimnames = list(NULL, c("r1", "c1", "r2", "c2")))
  bytes <- as.integer(res$bytes)
  list(
    r0 = ints[[1]], c0 = ints[[2]], nrow = nrow, ncol = ncol,
    is_1904 = ints[[5]] == 1L,
    kind = bytes[seq_len(n)],
    pad = bytes[n + seq_len(n)],
    num = res$doubles,
    text = res$strings,
    merged = merged
  )
}
