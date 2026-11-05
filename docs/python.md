# From Python to R: Excel lines

This page gives the xlkit line for each pandas, openpyxl and polars
line that reads or writes a workbook. [docs/r.md](r.md) covers each
task in full.

```r
library(xlkit)
```

pandas counts rows, columns and sheets from 0, and polars counts rows
from 0 and sheets from 1. xlkit uses the numbers Excel shows: row 5 is
`5`, the third tab is `3`, and a block of cells is `"B5:F40"`.

## pandas: read

| pandas | xlkit |
|---|---|
| `df = pd.read_excel("f.xlsx")` | `df <- read_xlsx("f.xlsx")` |
| `pd.read_excel(p, sheet_name="Births 2024")` | `read_xlsx(p, sheet = "Births 2024")` |
| `pd.read_excel(p, sheet_name=2)` | `read_xlsx(p, sheet = 3)` |
| `pd.ExcelFile(p).sheet_names` | `xlsx_sheets(p)` |
| `pd.read_excel(p, header=4)` | `read_xlsx(p, header = 5)` |
| `pd.read_excel(p, header=4, usecols="B:F", nrows=35)` | `read_xlsx(p, range = "B5:F40")` |
| `pd.read_excel(p, header=None)` | `read_xlsx(p, header = FALSE)`: columns are named `A`, `B`, ..., not `0`, `1`, ... |
| `pd.read_excel(p, header=[3, 4])` | `read_xlsx(p, header = 4:5)`: one name per column, such as `Income 2020`, not a MultiIndex |
| `pd.read_excel(p, dtype={"zip": str})` | `read_xlsx(p, types = c(zip = "text"))` |
| `pd.read_excel(p, dtype=str)` | `read_xlsx(p, types = "text")` |
| `pd.read_excel(p, na_values=["."])` | `read_xlsx(p, na = ".")` |
| `pd.read_excel(p, sheet_name=None)` | `read_sheets(p)`: a named list of tibbles |

## pandas: write

| pandas | xlkit |
|---|---|
| `df.to_excel("f.xlsx", index=False)` | `write_xlsx(df, "f.xlsx")`, and `replace = TRUE` if the file exists |
| `df.to_excel(p, sheet_name="Data", index=False)` | `write_xlsx(df, p, sheet = "Data")` |
| `df.to_excel(p, index=False, header=False)` | `write_xlsx(df, p, header = FALSE)` |
| `df.to_excel(p, index=False, na_rep="NA")` | `write_xlsx(df, p, na = "NA")` |
| `df.to_excel(p, index=False, freeze_panes=(1, 0))` | nothing: `write_xlsx()` keeps the header in view |
| `df.to_excel(p, index=False, autofilter=True)` | `write_xlsx(df, p, filter = TRUE)` |
| `df.to_excel(p, index=False, float_format="%.2f")` | `write_xlsx(df, p, formats = c(x = "0.00"))`: Excel shows two decimals and keeps the full value |
| `xw.sheets["Data"].autofit()` | nothing: columns are as wide as their contents |
| one `to_excel(xw, sheet_name=...)` per frame inside `with pd.ExcelWriter(p) as xw:` | `write_xlsx(list(Summary = a, Detail = b), p)` |
| `startrow=` to stack frames on one sheet | `write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), p)` |
| `pd.ExcelWriter(p, mode="a", engine="openpyxl", if_sheet_exists="replace")`, then `df.to_excel(xw, sheet_name="Data", index=False)` | `write_sheet(df, p, sheet = "Data")` |
| `if_sheet_exists="overlay"`, then `df.to_excel(xw, sheet_name="Report", startrow=4, startcol=1, header=False, index=False)` | `write_sheet(df, p, sheet = "Report", at = "B5", header = FALSE)` |

## openpyxl

openpyxl works cell by cell; xlkit reads and writes tables, and fills
in cells with `write_cells()`.

| openpyxl | xlkit |
|---|---|
| `wb = load_workbook(p, data_only=True)`, then `list(wb["Data"].values)` | `read_xlsx(p, sheet = "Data")` |
| `wb.sheetnames` | `xlsx_sheets(p)` |
| `wb["Data"]["B5:F40"]` | `read_xlsx(p, sheet = "Data", range = "B5:F40")` |
| `wb["Data"].tables["Births"].ref`, then slice the cells | `read_xlsx(p, range = "Births")` |
| `ws["C4"] = 1250`, then `wb.save(p)` | `write_cells(p, sheet = "Cover", C4 = 1250)` |
| `ws["B2"] = "=SUM(A1:A5)"` | `write_cells(p, sheet = "Cover", B2 = xl_formula("SUM(A1:A5)"))` |
| `ws["C4"].number_format = "0.0%"` | `styles = list(C4 = xl_style(format = "0.0%"))` |
| `ws["A1"].font = Font(bold=True)` | `styles = list(A1 = xl_style(bold = TRUE))` |
| `ws["A1"].fill = PatternFill("solid", fgColor="DCE6F1")` | `styles = list(A1 = xl_style(fill = "#DCE6F1"))` |
| `ws["A1"].alignment = Alignment(horizontal="center")` | `styles = list(A1 = xl_style(align = "center"))` |
| `ws.merge_cells("A1:F1")` | `merge = "A1:F1"` |
| `ws.column_dimensions["E"].width = 80` | `write_xlsx(df, p, widths = c(notes = 80))` |
| `ws.freeze_panes = "B2"` | `write_xlsx(df, p, freeze = "B2")` |
| `del wb["Data"]` and `wb.create_sheet("Data", 1)`, then write each cell | `write_sheet(df, p, sheet = "Data")` |

Several cells go in one call:

```r
write_cells(
  "results.xlsx", sheet = "Cover",
  C4 = 1250,
  C5 = as.Date("2024-12-31"),
  B2 = "Results for 2024",
  styles = list(B2 = xl_style(bold = TRUE, size = 14)),
  merge = "B2:F2"
)
```

## polars

| polars | xlkit |
|---|---|
| `pl.read_excel(p, sheet_name="Data")` | `read_xlsx(p, sheet = "Data")` |
| `pl.read_excel(p, sheet_id=3)` | `read_xlsx(p, sheet = 3)` |
| `pl.read_excel(p, sheet_id=0)` | `read_sheets(p)` |
| `pl.read_excel(p, table_name="Births")` | `read_xlsx(p, range = "Births")` |
| `pl.read_excel(p, read_options={"header_row": 4, "use_columns": "B:F", "n_rows": 35})` | `read_xlsx(p, range = "B5:F40")` |
| `pl.read_excel(p, has_header=False)` | `read_xlsx(p, header = FALSE)` |
| `pl.read_excel(p, schema_overrides={"zip": pl.String})` | `read_xlsx(p, types = c(zip = "text"))` |
| `df.write_excel(p, worksheet="Data")` | `write_xlsx(df, p, sheet = "Data")` |
| `df.write_excel(p, column_formats={"share": "0.0%"})` | `write_xlsx(df, p, formats = c(share = "0.0%"))` |

## What differs

- **Text stays text.** pandas parses a text cell that looks like a
  number, so `02139` becomes `2139`. xlkit keeps it as `"02139"`.
- **Fewer missing values.** pandas reads the text `NA`, `N/A`, `None`,
  `null` and `nan` as missing by default, so Namibia's code `NA` is
  lost. xlkit reads only blank cells as `NA`; give `na` for the
  markers your file uses, such as `na = c("NA", "N/A", "NULL", "None")`.
- **Excel errors are reported.** pandas reads `#N/A` and `#DIV/0!` as
  `NaN` without a word. xlkit reads them as `NA` too, warns, and lists
  the cells in `xlsx_problems(df)`.
- **Files are not replaced unasked.** `to_excel()` and openpyxl's
  `save()` overwrite a file without asking. `write_xlsx()` stops when
  the file exists; give `replace = TRUE`, or use `write_sheet()` or
  `write_cells()` to keep the other sheets.
- **Templates keep everything.** pandas' append mode and openpyxl load
  the workbook into their model and save the model, so whatever the
  model lacks is dropped: shapes, slicers, sparklines, newer
  conditional formats. `write_sheet()` and `write_cells()` copy every
  part they do not write, byte for byte.
- **Readable output.** pandas 3 writes no header style, and neither
  pandas nor openpyxl fits column widths. `write_xlsx()` makes the
  header bold, keeps it in view and fits the widths.
- **Text is not a formula.** openpyxl and XlsxWriter turn text that
  starts with `=` into a formula. xlkit writes it as text unless it is
  wrapped in `xl_formula()`.
- **No index column.** An R data frame has no index to write, so there
  is no `index=False` to remember.
- **Sheet positions count every tab.** pandas skips chart sheets when
  it counts `sheet_name=2`; xlkit's `sheet = 3` is the third tab, and
  reading a chart sheet is an error.
