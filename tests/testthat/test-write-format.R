# docs/r.md, "Format the output": number formats, widths, frozen panes,
# filters, header style, styles by column and by range, merged ranges,
# and the checks on their names. openpyxl is the oracle for all of it.

sales <- function() {
  data.frame(
    region = c("North", "South", "East"),
    amount = c(1234.5678, 250, 99999),
    share = c(0.256, 0.5, 0.244),
    stringsAsFactors = FALSE
  )
}

test_that("formats give number formats by column, without changing values", {
  path <- temp_xlsx()
  write_xlsx(sales(), path, formats = c(share = "0.0%", amount = "#,##0"))
  expect_identical(bare(read_xlsx(path)), tibble::as_tibble(sales()))
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(xl_cell(seen, "B2")$format, "#,##0")
  expect_identical(xl_cell(seen, "C4")$format, "0.0%")
  expect_identical(xl_cell(seen, "A2")$format, "General")
  # The header keeps its own (General) format.
  expect_identical(xl_cell(seen, "C1")$format, "General")
})

test_that("formats replace a date column's default format", {
  path <- temp_xlsx()
  write_xlsx(data.frame(d = as.Date("2024-03-01")), path, formats = c(d = "d mmm yyyy"))
  expect_identical(read_xlsx(path)$d, as.Date("2024-03-01"))
  skip_if_no_openpyxl()
  expect_identical(xl_cell(openpyxl(path), "A2")$format, "d mmm yyyy")
})

test_that("a percent format on numbers that look already multiplied by 100 gets a message", {
  path <- temp_xlsx()
  scaled <- data.frame(share = c(25.6, 40, -3), small = c(0.256, 25, 3))
  msg <- expect_message(
    write_xlsx(scaled, path, formats = c(share = "0.0%", small = "0%")),
    class = "rlang_message"
  )
  expect_identical(
    first_line(msg),
    "`share` has values such as 25.6 and the format \"0.0%\", which shows them as 2560.0%."
  )
  expect_match(conditionMessage(msg), "A percent format multiplies by 100. To show 25.6%, divide by 100 first.",
               fixed = TRUE)
  # Not for a fraction anywhere in the column, nor a quoted "%".
  expect_no_message(write_xlsx(scaled, path, formats = c(small = "0%"), replace = TRUE))
  expect_no_message(write_xlsx(scaled, path, formats = c(share = '0.0"%"'), replace = TRUE))
  expect_message(write_sheet(scaled, path, sheet = "Sheet1", formats = c(share = "0%")),
                 "`share` has values such as 25.6 and the format \"0%\", which shows them as 2560%.", fixed = TRUE)
  expect_message(write_sheet(scaled, path, sheet = "Sheet1", at = "E1", styles = list(share = xl_style(format = "0%"))),
                 "`share` has values such as 25.6", fixed = TRUE)
  msg <- expect_message(
    write_cells(path, sheet = "Sheet1", J2 = c(12.5, 30), styles = list("J2:J3" = xl_style(format = "0.0%"))),
    class = "rlang_message"
  )
  expect_match(conditionMessage(msg), "J2 and J3 have values such as 12.5 and the format \"0.0%\", which shows them as 1250.0%.",
               fixed = TRUE)
  expect_no_message(write_cells(path, sheet = "Sheet1", J2 = 0.125, styles = list(J2 = xl_style(format = "0.0%"))))
})

test_that("a percent format given by range gets the message in write_xlsx() and write_sheet()", {
  path <- temp_xlsx()
  scaled <- data.frame(share = c(25, 40))
  by_range <- list("A2:A3" = xl_style(format = "0%"))
  expect_message(write_xlsx(scaled, path, styles = by_range),
                 "`share` has values such as 25 and the format \"0%\", which shows them as 2500%.", fixed = TRUE)
  expect_message(write_sheet(scaled, path, sheet = "Sheet1", styles = by_range),
                 "`share` has values such as 25", fixed = TRUE)
  expect_message(write_xlsx(data.frame(share = c(25, 40, 50)), path, styles = by_range, replace = TRUE),
                 "A2 and A3 have values such as 25", fixed = TRUE)
})

test_that("the percent message judges each cell's final format, so a later format without % clears it", {
  path <- temp_xlsx()
  scaled <- data.frame(share = c(25, 40))
  expect_no_message(write_xlsx(scaled, path, formats = c(share = "0%"),
                               styles = list("A2:A3" = xl_style(format = "0"))))
  overlap <- list("C2:C3" = xl_style(format = "0%"), "C1:C3" = xl_style(format = "0"))
  expect_no_message(write_cells(path, sheet = "Sheet1", C2 = c(25, 40), styles = overlap))
  expect_no_message(write_sheet(scaled, path, sheet = "Sheet1", at = "C1", styles = overlap))
})

test_that("a % after _ or * (space or fill) is not a percent format", {
  path <- temp_xlsx()
  expect_no_message(write_xlsx(data.frame(share = c(25, 40)), path, formats = c(share = "0_%")))
  expect_no_message(write_xlsx(data.frame(share = c(25, 40)), path, formats = c(share = "0*%"), replace = TRUE))
})

test_that("a name that is not a column stops, suggesting one that is", {
  path <- temp_xlsx()
  s <- sales()
  err <- expect_error(write_xlsx(s, path, formats = c(shar = "0.0%")), class = "rlang_error")
  expect_identical(plain_message(err),
                   "`formats` names `shar`, which is not a column of `s`.\ni Did you mean `share`?")
  err <- expect_error(write_xlsx(list(A = s), path, widths = c(nots = 80)), class = "rlang_error")
  expect_identical(first_line(err), "`widths` names `nots`, which is not a column of any table in `x`.")
  err <- expect_error(write_xlsx(s, path, styles = list(regoin = xl_style(bold = TRUE))), class = "rlang_error")
  expect_identical(plain_message(err), paste0(
    "`styles` names `regoin`, which is neither a column of `s` nor a cell or range such as \"A2:F2\".\n",
    "i Did you mean `region`?"
  ))
  err <- expect_error(write_xlsx(s, path, formats = c(a = "0", b = "0")), class = "rlang_error")
  expect_identical(first_line(err), "`formats` names `a` and `b`, which are not columns of `s`.")
  expect_error(write_xlsx(s, path, formats = "0.0%"), "`formats` must be number formats named by column")
  expect_false(file.exists(path))
})

test_that("widths: auto, one number, or by name with the rest fitted", {
  skip_if_no_openpyxl()
  w <- function(path) {
    x <- openpyxl(path)$widths
    setNames(round(x$width), x$col)
  }
  p1 <- temp_xlsx()
  write_xlsx(sales(), p1, widths = 20)
  # openpyxl joins columns of one width into one range, A:C.
  expect_identical(unname(w(p1)), 21)
  p2 <- temp_xlsx()
  write_xlsx(sales(), p2, widths = c(region = 30))
  expect_identical(w(p2)[["A"]], 31)
  expect_lt(w(p2)[["C"]], 12)
  p3 <- temp_xlsx()
  write_xlsx(sales(), p3)
  # "1,234.57"-wide numbers and "North" fit; nothing is Excel's default 8.43.
  expect_true(all(w(p3) >= 6 & w(p3) <= 14))
  expect_error(write_xlsx(sales(), temp_xlsx(), widths = c(10, 20)), "`widths` must be \"auto\"", fixed = TRUE)
  expect_error(write_xlsx(sales(), temp_xlsx(), widths = 300), "from 0 to 255")
})

test_that("freeze: FALSE, or a cell freezing rows above and columns left", {
  skip_if_no_openpyxl()
  p1 <- temp_xlsx()
  write_xlsx(sales(), p1, freeze = FALSE)
  expect_identical(openpyxl(p1)$sheets$freeze, "")
  p2 <- temp_xlsx()
  write_xlsx(sales(), p2, freeze = "B2")
  expect_identical(openpyxl(p2)$sheets$freeze, "'B2'")
  p3 <- temp_xlsx()
  write_xlsx(sales(), p3, header = "both")
  expect_identical(openpyxl(p3)$sheets$freeze, "'A3'")
})

test_that("filter = TRUE adds filter buttons to the header row", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  write_xlsx(sales(), path, filter = TRUE)
  expect_identical(openpyxl(path)$sheets$filter, "'A1:C4'")
  path2 <- temp_xlsx()
  write_xlsx(list(S = list(T = sales())), path2, filter = TRUE)
  expect_identical(openpyxl(path2)$sheets$filter, "'A2:C5'")
})

test_that("filter = TRUE needs one table per sheet and a header", {
  path <- temp_xlsx()
  err <- expect_error(write_xlsx(list(S = list(sales(), sales())), path, filter = TRUE), class = "rlang_error")
  expect_identical(first_line(err), "`filter = TRUE` needs one table per sheet, and sheet \"S\" has 2.")
  expect_error(write_xlsx(sales(), path, filter = TRUE, header = FALSE), "needs a header row")
})

test_that("header_style styles the header; NULL is plain", {
  skip_if_no_openpyxl()
  p1 <- temp_xlsx()
  write_xlsx(sales(), p1, header_style = NULL)
  expect_false(xl_cell(openpyxl(p1), "A1")$bold)
  p2 <- temp_xlsx()
  write_xlsx(sales(), p2, header_style = xl_style(italic = TRUE, fill = "#FFF2CC", border = c(bottom = "thin")))
  h <- xl_cell(openpyxl(p2), "B1")
  expect_false(h$bold)
  expect_true(h$italic)
  expect_identical(h$fill, "FFF2CC")
  expect_identical(h$bottom, "'thin'")
  expect_identical(h$top, "")
})

test_that("styles by column style the body; by range, any cells", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  write_xlsx(
    sales(), path,
    formats = c(share = "0.0%"),
    styles = list(
      region = xl_style(bold = TRUE, color = "red"),
      share = xl_style(fill = "lightyellow"),
      "A4:C4" = xl_style(border = c(top = "thin")),
      "E2" = xl_style(fill = "#00FF00")
    )
  )
  seen <- openpyxl(path)
  a2 <- xl_cell(seen, "A2")
  expect_true(a2$bold)
  expect_identical(a2$color, "FF0000")
  # A column's style leaves its number format, and the header, alone.
  c2 <- xl_cell(seen, "C2")
  expect_identical(c2$fill, "FFFFE0")
  expect_identical(c2$format, "0.0%")
  expect_identical(xl_cell(seen, "C1")$fill, "")
  # The range adds a border on top of what the cells have.
  c4 <- xl_cell(seen, "C4")
  expect_identical(c4$top, "'thin'")
  expect_identical(c4$fill, "FFFFE0")
  expect_identical(c4$format, "0.0%")
  expect_true(xl_cell(seen, "A4")$bold)
  expect_identical(xl_cell(seen, "B3")$top, "")
  # A styled cell with nothing in it is a blank cell with the style.
  e2 <- xl_cell(seen, "E2")
  expect_identical(e2$fill, "00FF00")
  expect_identical(e2$value, "")
  expect_identical(read_xlsx(path)$amount, sales()$amount)
})

test_that("every xl_style() property reaches the cell", {
  skip_if_no_openpyxl()
  path <- temp_xlsx()
  st <- xl_style(bold = TRUE, italic = TRUE, underline = TRUE, size = 14, font = "Arial",
                 color = "#1F4E79", fill = "gray90", border = c("thin", "medium", "thick", "double"),
                 align = "center", valign = "top", wrap = TRUE, indent = 2, format = "0.00")
  write_xlsx(data.frame(x = 1.5), path, styles = list(x = st))
  c <- xl_cell(openpyxl(path), "A2")
  expect_true(c$bold)
  expect_true(c$italic)
  expect_identical(c$underline, "'single'")
  expect_identical(c$size, "14.0")
  expect_identical(c$font, "'Arial'")
  expect_identical(c$color, "1F4E79")
  expect_identical(c$fill, "E5E5E5")
  expect_identical(c(c$top, c$right, c$bottom, c$left), c("'thin'", "'medium'", "'thick'", "'double'"))
  expect_identical(c$align, "'center'")
  expect_identical(c$valign, "'top'")
  expect_true(c$wrap)
  expect_identical(c$indent, "2.0")
  expect_identical(c$format, "0.00")
})

test_that("merge merges ranges, keeping the top-left value, with an optional style", {
  path <- temp_xlsx()
  write_xlsx(list(S = list("A long title" = sales())), path, merge = list("A1:C1" = xl_style(align = "center")))
  expect_identical(read_xlsx(path, range = "A1:A1", header = FALSE)$A, "A long title")
  skip_if_no_openpyxl()
  seen <- openpyxl(path)
  expect_identical(seen$merged$range, "A1:C1")
  expect_identical(xl_cell(seen, "A1")$align, "'center'")
  expect_true(xl_cell(seen, "A1")$bold)
  path2 <- temp_xlsx()
  write_xlsx(list(A = sales(), B = sales()), path2, merge = c("E1:F2", "E4:E5"))
  seen <- openpyxl(path2)
  expect_identical(seen$merged$sheet, c("A", "A", "B", "B"))
  expect_setequal(seen$merged$range[seen$merged$sheet == "B"], c("E1:F2", "E4:E5"))
})

test_that("merge stops when it would hide values, overlaps, or is one cell", {
  path <- temp_xlsx()
  err <- expect_error(write_xlsx(sales(), path, merge = "A1:B2"), class = "rlang_error")
  expect_identical(first_line(err), paste0(
    "`merge = \"A1:B2\"` would hide the values in B1, A2 and B2, ",
    "since Excel keeps only a merged range's top-left value."
  ))
  expect_error(write_xlsx(sales(), path, merge = c("E1:F2", "F2:G3")), "overlap, which Excel does not allow")
  expect_error(write_xlsx(sales(), path, merge = "E1"), "which is one cell")
  expect_error(write_xlsx(sales(), path, merge = "Sheet!E1:F1"), "is not a range of cells")
  expect_false(file.exists(path))
})

test_that("xl_style() checks its arguments", {
  expect_error(xl_style(bold = "yes"), "`bold` must be TRUE, FALSE or NULL.")
  expect_error(xl_style(size = 0), "`size` must be a font size")
  expect_error(xl_style(color = "#12345"), "is not in the form \"#RRGGBB\"", fixed = TRUE)
  err <- expect_error(xl_style(fill = "lightyelow"), class = "rlang_error")
  expect_match(conditionMessage(err), "Did you mean \"lightyellow\"?", fixed = TRUE)
  expect_error(xl_style(border = "dotted"), "`border` must be")
  expect_error(xl_style(border = c(top = "thin", middle = "thin")), "`border` must be")
  expect_error(xl_style(border = c("thin", "thin")), "`border` must be")
  expect_error(xl_style(align = "middle"), "`align` must be \"left\", \"center\" or \"right\"", fixed = TRUE)
  expect_error(xl_style(valign = "middle"), "`valign` must be \"top\", \"center\" or \"bottom\"", fixed = TRUE)
  expect_error(xl_style(indent = 1.5), "`indent` must be a whole number")
  expect_error(xl_style(format = ""), "`format` must be one string")
  expect_error(write_xlsx(sales(), temp_xlsx(), styles = list(region = list(bold = TRUE))),
               "`styles$region` must be a style from `xl_style()`.", fixed = TRUE)
})

test_that("xl_style() keeps only what is set, and prints it", {
  expect_identical(length(xl_style()), 0L)
  s <- xl_style(bold = TRUE, fill = "white", border = c(top = "thin"))
  expect_identical(names(s), c("bold", "fill", "border"))
  expect_identical(s$fill, "#FFFFFF")
  expect_identical(format(s), "<xl_style> bold, fill \"#FFFFFF\", border top thin")
  expect_identical(format(xl_style(border = "thin")), "<xl_style> border thin")
  expect_identical(format(xl_style()), "<xl_style> (keeps the cell's style)")
  expect_output(print(s), "<xl_style> bold", fixed = TRUE)
})

test_that("fractions in one column do not hide a percent mistake in another", {
  path <- temp_copy(xlkit_example("template.xlsx"))
  expect_message(
    write_cells(path, "Cover", H1 = c(25, 40), I1 = c(0.25, 0.4),
                styles = list("H1:H2" = xl_style(format = "0%"), "I1:I2" = xl_style(format = "0%"))),
    "H1 and H2 have values such as 25"
  )
})
