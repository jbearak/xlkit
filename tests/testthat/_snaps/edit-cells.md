# a vector's values are checked as write_xlsx() checks them

    Code
      write_cells(path, "Cover", C4 = as.Date("1850-01-01"))
    Condition
      Error in `write_cells()`:
      ! `C4` has dates Excel cannot hold, which shows only 1900-01-01 to 9999-12-31: C4 (1850-01-01).
      i Write them as text instead, with `format()`, or leave them out.
    Code
      write_cells(path, "Cover", 1250)
    Condition
      Error in `write_cells()`:
      ! Each value in `...` needs the cell it goes in, such as `C4 = 1250`.
      x Value 1 has none.
    Code
      write_cells(path, "Cover", `C4:C5` = 1)
    Condition
      Error in `write_cells()`:
      ! `C4:C5` is not a cell; each value in `...` goes in one cell, such as `C4 = 1250`.
      i A vector, matrix or data frame starts there and fills the cells below and to the right.
    Code
      write_cells(path, "Cover", C4 = list(1, 2))
    Condition
      Error in `write_cells()`:
      ! `C4` must be a value, a vector, a matrix or a data frame.
      x It is a list.
    Code
      write_cells(path, "Cover", styles = list(region = xl_style(bold = TRUE)))
    Condition
      Error in `write_cells()`:
      ! `styles` names "region", which is not a cell or range.
      i Name styles by cell or range, such as "B2" or "A12:F12".

