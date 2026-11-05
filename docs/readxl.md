# From readxl and writexl to xlkit

This page gives the xlkit line for each readxl and writexl line.
[docs/r.md](r.md) covers each task in full.

readxl and writexl have functions named `read_xlsx()` and
`write_xlsx()`, as xlkit does. Attach only xlkit, or write `xlkit::`.

```r
library(xlkit)
```

## readxl

| readxl | xlkit |
|---|---|
| `read_excel(p)` or `read_xlsx(p)` | `read_xlsx(p)` |
| `read_excel(p, sheet = "Births 2024")` | `read_xlsx(p, sheet = "Births 2024")` |
| `excel_sheets(p)` | `xlsx_sheets(p)` |
| `read_excel(p, range = "B5:F40")` | `read_xlsx(p, range = "B5:F40")` |
| `read_excel(p, range = "Births 2024!B5:F40")` | `read_xlsx(p, sheet = "Births 2024", range = "B5:F40")` |
| `read_excel(p, skip = 4)` | `read_xlsx(p, header = 5)`: the header's row as Excel numbers it |
| `read_excel(p, range = cell_cols("B:F"))` | `read_xlsx(p, range = "B:F")` |
| `read_excel(p, range = cell_rows(5:40))` | `read_xlsx(p, range = "5:40")` |
| `read_excel(p, range = cell_limits(c(5, 2), c(NA, NA)))` | `read_xlsx(p, range = "B5")` |
| `read_excel(p, col_names = FALSE)` | `read_xlsx(p, header = FALSE)`: columns are named by their letters, `A`, `B`, ..., not `...1`, `...2` |
| `read_excel(p, .name_repair = janitor::make_clean_names)` | `read_xlsx(p, names = "snake")`, or `names = janitor::make_clean_names` |
| `read_excel(p, col_types = c("text", "guess", "guess", "numeric", "guess"))` | `read_xlsx(p, types = c(id = "text", amount = "number"))`: name the columns to fix, and the rest are guessed |
| `read_excel(p, col_types = "text")` | `read_xlsx(p, types = "text")` |
| `read_excel(p, guess_max = Inf)` | nothing: every cell is used |
| `read_excel(p, na = c("", "NA", "."))` | `read_xlsx(p, na = c("NA", "."))`: blank cells are always `NA` |
| `lapply(set_names(excel_sheets(p)), read_excel, path = p)` | `read_sheets(p)` |

## writexl

| writexl | xlkit |
|---|---|
| `write_xlsx(df, p)` | `write_xlsx(df, p)`, and `replace = TRUE` if the file exists |
| `write_xlsx(list(Summary = a, Detail = b), p)` | the same |
| `write_xlsx(df, p, col_names = FALSE)` | `write_xlsx(df, p, header = FALSE)` |
| `write_xlsx(df, p, format_headers = FALSE)` | `write_xlsx(df, p, header_style = NULL)` |
| `write_xlsx(df, p, na = "NA")` | `write_xlsx(df, p, na = "NA")` |
| `xl_sheet(df, cols = list(xl_col_spec("share", format = xl_num_format("0.0%"))))` | `formats = c(share = "0.0%")` |
| `xl_col_spec("notes", width = 80)` | `widths = c(notes = 80)` |
| `xl_sheet(df, auto_colwidth = TRUE)` | nothing: columns are as wide as their contents |
| `xl_sheet(df, freeze = "A2")` | nothing: `freeze = TRUE` is the default; `freeze = "B2"` for another cell |
| `xl_sheet(df, autofilter = TRUE)` | `filter = TRUE` |
| several tables on one sheet: not possible | `write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), p)` |
| change a workbook that exists: not possible | `write_sheet(df, p, sheet = "Data")` replaces one sheet; `write_cells(p, sheet = "Cover", C4 = 1250)` fills cells |

## What differs

- **Types from every cell.** readxl guesses from the first 1,000 rows
  (`guess_max`), so a text cell further down becomes `NA` with a
  warning. xlkit uses every cell, and says which cells made a column
  text.
- **Dates are `Date`.** readxl gives `POSIXct` for every date cell, and
  a time of day as a `POSIXct` on 1899-12-31. xlkit gives `Date` for
  dates, `POSIXct` for date-times and `hms` for times.
- **Excel errors are reported.** readxl reads `#N/A` and `#DIV/0!` as
  `NA` without a word. xlkit warns and lists them in
  `xlsx_problems(df)`.
- **Rows are Excel's.** readxl's `skip` is the least number of rows to
  skip: blank rows after them are skipped too, so the header can be a
  lower row than you meant. xlkit's `header = 5` is row 5, and `range`
  uses the row numbers Excel shows.
- **Files are not replaced unasked.** writexl replaces a file that
  exists. `write_xlsx()` stops; give `replace = TRUE`, or use
  `write_sheet()` or `write_cells()` to keep the other sheets.
- **Labels are written.** writexl writes a haven or dtaparser labelled
  column as its codes and ignores variable labels. xlkit writes the
  value labels, and the variable labels with `header = "labels"`.
