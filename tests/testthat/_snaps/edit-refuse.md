# other formats and password-protected files are refused

    Code
      write_cells(xls, "Sheet1", A1 = 1)
    Condition
      Error in `write_cells()`:
      ! old.xls is an .xls workbook, and xlkit edits only .xlsx and .xlsm workbooks.
      i Open it in Excel and save it as an Excel Workbook (.xlsx), then write to that file.
    Code
      write_sheet(data.frame(a = 1), sub("xls$", "xlsb", xls), "Sheet1")
    Condition
      Error in `write_sheet()`:
      ! old.xlsb is an .xlsb workbook, and xlkit edits only .xlsx and .xlsm workbooks.
      i Open it in Excel and save it as an Excel Workbook (.xlsx), then write to that file.
    Code
      write_cells(locked, "Sheet1", A1 = 1)
    Condition
      Error in `write_cells()`:
      ! locked.xlsx is password-protected (or an .xls workbook named .xlsx), and xlkit cannot edit it. Nothing was written.
      i Save a copy without a password in Excel (File > Info > Protect Workbook), and write to that.
    Code
      write_cells(sub("locked", "notes", sub("xlsx$", "txt", locked)), "Sheet1", A1 = 1)
    Condition
      Error in `write_cells()`:
      ! `path` must end in .xlsx or .xlsm, and notes.txt does not.
      i xlkit edits .xlsx and .xlsm workbooks.

# worksheet XML that cannot be edited safely is refused

    Code
      write_cells(path, "Sheet1", A1 = 2)
    Condition
      Error in `write_cells()`:
      ! Sheet "Sheet1" of unsafe.xlsx: cannot edit this worksheet: a cell has no reference (r), so only the order of the cells says where it is. Nothing was written.
      i Open the file in Excel and save it, then try again.

# a merged range's other cells and a table's header are refused

    Code
      write_cells(path, "Report", B1 = "x")
    Condition
      Error in `write_cells()`:
      ! B1 is inside the merged range A1:D1, which shows only its top-left cell, A1. Nothing was written.
      i Write to A1, or unmerge the range in Excel first.
    Code
      write_cells(path, "Data", B1 = "Amount")
    Condition
      Error in `write_cells()`:
      ! B1 is in the header row of Excel table "Sales" (A1:B13), and writing it would leave the table's column names wrong. Nothing was written.
      i To replace the table, write a data frame at its top-left cell: `write_sheet(x, path, sheet, at = "A1")`.
    Code
      write_sheet(data.frame(a = 1), path, sheet = "Data", at = "B1")
    Condition
      Error in `write_sheet()`:
      ! B1 is in the header row of Excel table "Sales" (A1:B13), and writing it would leave the table's column names wrong. Nothing was written.
      i To replace the table, write a data frame at its top-left cell: `write_sheet(x, path, sheet, at = "A1")`.
    Code
      write_cells(path, "Report", merge = "A3:B3")
    Condition
      Error in `write_cells()`:
      ! `merge = "A3:B3"` would hide the value in B3, since Excel keeps only a merged range's top-left value. Nothing was written.
      i Merge cells that are empty apart from the top-left one.
    Code
      write_cells(path, "Report", merge = "C1:E1")
    Condition
      Error in `write_cells()`:
      ! `merge = "C1:E1"` overlaps the merged range A1:D1 that sheet "Report" has. Nothing was written.
      i Merge a range that does not overlap it, or unmerge that range in Excel first.

# write_sheet() without `at` will not clear a table that is not at A1

    Code
      write_sheet(data.frame(a = 1), path, sheet = "Tables")
    Condition
      Error in `write_sheet()`:
      ! Sheet "Tables" has Excel table "NoHeader" in A2:B3, which `write_sheet()` would clear. Nothing was written.
      i To write into the table, use `at = "A2"`; to keep it, write elsewhere with `at =`.

# chart sheets are not written

    Code
      write_cells(path, "Chart", A1 = 1)
    Condition
      Error in `write_cells()`:
      ! Sheet "Chart" of template.xlsx is a chart sheet, and xlkit writes only worksheets.
      i Write to another sheet, or give a new name to add one.

# a sheet name Excel does not allow stops before anything is written

    Code
      write_sheet(data.frame(a = 1), path, sheet = "Q1/Q2")
    Condition
      Error in `write_sheet()`:
      ! Sheet name "Q1/Q2" has "/", which Excel does not allow in sheet names.
      i Use another name, such as "Q1-Q2".

