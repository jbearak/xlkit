# dates follow the workbook's 1904 date system in every edit mode

    Code
      write_cells(path, "Early", C1 = as.Date("1903-12-31"))
    Condition
      Error in `write_cells()`:
      ! C1 would hold a date before 1904-01-01, which edge1904.xlsx cannot hold: it counts dates from 1904. Nothing was written.
      i Write the date as text instead, with `format()`.

