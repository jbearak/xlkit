# From openxlsx to xlkit

This page gives the xlkit line for each openxlsx line.
[docs/r.md](r.md) covers each task in full.

```r
library(xlkit)
```

openxlsx counts rows and columns as numbers (`startRow = 4,
startCol = 3`); xlkit names cells as Excel shows them (`C4`).

## Read

| openxlsx | xlkit |
|---|---|
| `read.xlsx(p)` | `read_xlsx(p)`: a tibble, not a `data.frame` |
| `read.xlsx(p, sheet = "Births 2024")` | `read_xlsx(p, sheet = "Births 2024")` |
| `getSheetNames(p)` | `xlsx_sheets(p)` |
| `read.xlsx(p, startRow = 5)` | `read_xlsx(p, header = 5)` |
| `read.xlsx(p, rows = 5:40, cols = 2:6)` | `read_xlsx(p, range = "B5:F40")` |
| `read.xlsx(p, namedRegion = "Totals")` (a defined name) | `read_xlsx(p, range = "Totals")`; the name of an Excel table works too |
| `read.xlsx(p, colNames = FALSE)` | `read_xlsx(p, header = FALSE)` |
| `read.xlsx(p, detectDates = TRUE)` | nothing: dates are read as dates by default |
| `read.xlsx(p, na.strings = c("NA", "."))` | `read_xlsx(p, na = c("NA", "."))` |
| `read.xlsx(p, check.names = TRUE)` | `read_xlsx(p, names = "snake")` |
| a loop over `getSheetNames()` | `read_sheets(p)` |

## Write

| openxlsx | xlkit |
|---|---|
| `write.xlsx(df, p)` | `write_xlsx(df, p)`, and `replace = TRUE` if the file exists |
| `write.xlsx(df, p, overwrite = TRUE)` | `write_xlsx(df, p, replace = TRUE)` |
| `write.xlsx(list(Summary = a, Detail = b), p)` | `write_xlsx(list(Summary = a, Detail = b), p)` |
| `write.xlsx(df, p, sheetName = "Data")` | `write_xlsx(df, p, sheet = "Data")` |
| `write.xlsx(df, p, colNames = FALSE)` | `write_xlsx(df, p, header = FALSE)` |
| `write.xlsx(df, p, firstRow = TRUE, colWidths = "auto", withFilter = TRUE)` | `write_xlsx(df, p, filter = TRUE)`: a frozen header and fitted widths are the default |
| `write.xlsx(df, p, headerStyle = createStyle(textDecoration = "bold"))` | nothing: the header is bold by default |
| `addStyle(wb, "Data", createStyle(numFmt = "0.0%"), rows = 2:41, cols = 4)` | `formats = c(share = "0.0%")` |
| `setColWidths(wb, "Data", cols = 3, widths = 80)` | `widths = c(notes = 80)` |
| `freezePane(wb, "Data", firstActiveRow = 2, firstActiveCol = 2)` | `freeze = "B2"` |
| `mergeCells(wb, "Data", cols = 1:6, rows = 1)` | `merge = "A1:F1"` |
| `writeData(wb, "Results", b, startRow = nrow(a) + 4)` for a second table | `write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), p)` |

## Fill in a template

```r
# openxlsx
wb <- loadWorkbook("results.xlsx")
writeData(wb, "Cover", 1250, startCol = 3, startRow = 4)
writeFormula(wb, "Cover", "SUM(C8:C12)", startCol = 3, startRow = 13)
saveWorkbook(wb, "results.xlsx", overwrite = TRUE)
```

```r
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C13 = xl_formula("SUM(C8:C12)"))
```

| openxlsx | xlkit |
|---|---|
| `writeData(wb, "Cover", 1250, startCol = 3, startRow = 4)` | `C4 = 1250` |
| `writeFormula(wb, "Cover", "SUM(C8:C12)", startCol = 3, startRow = 13)` | `C13 = xl_formula("SUM(C8:C12)")` |
| `addStyle(wb, "Cover", createStyle(numFmt = "0.0%"), rows = 4, cols = 3, stack = TRUE)` | `styles = list(C4 = xl_style(format = "0.0%"))` |
| `writeData(wb, "Data", df, startCol = 8, startRow = 2)` | `write_sheet(df, p, sheet = "Data", at = "H2")` |
| `removeWorksheet(wb, "Data")`, `addWorksheet(wb, "Data")`, `writeData(wb, "Data", df)` | `write_sheet(df, p, sheet = "Data")`: the sheet keeps its place among the tabs |

## What differs

- **Dates are dates.** `read.xlsx()` reads date cells as numbers unless
  given `detectDates = TRUE`. `read_xlsx()` gives `Date`, `POSIXct` or
  `hms`; `dates = FALSE` gives the numbers.
- **Headers keep their spaces.** `read.xlsx()` turns spaces in headers
  into dots, so `Share %` becomes `Share.%`. xlkit keeps the header text
  as the name by default; `names = "snake"` gives `share_percent`.
- **Text `"NA"` is text.** `read.xlsx()` reads the text `NA` as
  missing by default. xlkit reads only blank cells as `NA`, unless `na`
  says otherwise.
- **One default for replacing files.** `write.xlsx()` replaces a file
  that exists by default and `saveWorkbook()` does not. Every xlkit
  writer keeps the file: `write_xlsx()` stops unless `replace = TRUE`,
  and `write_sheet()` and `write_cells()` change only what they write.
- **Templates are copied, not rebuilt.** `loadWorkbook()` and
  `saveWorkbook()` rebuild the file from what openxlsx understands.
  `write_sheet()` and `write_cells()` copy every part they do not
  write, byte for byte.
- **Labels are written.** openxlsx ignores value labels and variable
  labels. xlkit writes value labels as text, and variable labels as the
  header with `header = "labels"`.
- **Excel errors are reported.** xlkit reads `#N/A` and `#DIV/0!` as
  `NA`, warns, and lists them in `xlsx_problems(df)`.
