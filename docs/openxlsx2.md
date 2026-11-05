# From openxlsx2 to xlkit

This page gives the xlkit line for each openxlsx2 line.
[docs/r.md](r.md) covers each task in full.

openxlsx2 has functions named `read_xlsx()` and `write_xlsx()`, as
xlkit does. Attach only xlkit, or write `xlkit::`.

```r
library(xlkit)
```

openxlsx2 builds a workbook object, changes it with `wb$...()` methods
and saves it. xlkit has no workbook object: each call reads the file or
writes it, and names cells as Excel shows them.

## Read

| openxlsx2 | xlkit |
|---|---|
| `wb_to_df(p)` or `read_xlsx(p)` | `read_xlsx(p)`: a tibble, not a `data.frame` |
| `wb_to_df(p, sheet = "Sales 2024")` | `read_xlsx(p, sheet = "Sales 2024")` |
| `wb_get_sheet_names(wb_load(p))` | `xlsx_sheets(p)` |
| `wb_to_df(p, dims = "B5:F40")` | `read_xlsx(p, range = "B5:F40")` |
| `wb_to_df(p, dims = "B5:F+")` | `read_xlsx(p, range = "B5:F")` |
| `wb_to_df(p, start_row = 5)` | `read_xlsx(p, header = 5)` |
| `wb_to_df(p, named_region = "SalesTable")` | `read_xlsx(p, range = "SalesTable")` |
| `wb_to_df(p, col_names = FALSE)` | `read_xlsx(p, header = FALSE)` |
| `wb_to_df(p, check_names = TRUE)` | `read_xlsx(p, names = "snake")`: syntactic names, in lower case with `_` |
| `wb_to_df(p, types = c(zip = "character"))` | `read_xlsx(p, types = c(zip = "text"))` |
| `wb_to_df(p, convert = FALSE)` | `read_xlsx(p, types = "text")` |
| `wb_to_df(p, detect_dates = FALSE)` | `read_xlsx(p, dates = FALSE)` |
| `wb_to_df(p, na = c("NA", "."))` | `read_xlsx(p, na = c("NA", "."))` |
| a loop over `wb_get_sheet_names()` | `read_sheets(p)` |

## Write

| openxlsx2 | xlkit |
|---|---|
| `write_xlsx(df, p)` | `write_xlsx(df, p)`, and `replace = TRUE` if the file exists |
| `write_xlsx(list(Summary = a, Detail = b), p)` | the same |
| `write_xlsx(df, p, col_widths = "auto", first_row = TRUE, with_filter = TRUE)` | `write_xlsx(df, p, filter = TRUE)`: fitted widths and a frozen header are the default |
| `wb$add_font(dims = wb_dims(x = df, select = "col_names"), bold = TRUE)` | nothing: the header is bold by default |
| `wb$add_numfmt(dims = wb_dims(x = df, cols = "share"), numfmt = "0.0%")` | `formats = c(share = "0.0%")` |
| `wb$set_col_widths(cols = 3, widths = 80)` | `widths = c(notes = 80)` |
| `wb$freeze_pane(first_active_row = 2, first_active_col = 2)` | `freeze = "B2"` |
| `wb$merge_cells(dims = "A1:F1")` | `merge = "A1:F1"` |
| `wb$add_data(x = b, dims = wb_dims(from_row = nrow(a) + 3))` for a second table | `write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), p)` |

## Fill in a template

| openxlsx2 | xlkit |
|---|---|
| `wb_load(p)$add_data(sheet = "Cover", x = 1250, dims = "C4")$save(p)` | `write_cells(p, sheet = "Cover", C4 = 1250)` |
| `wb$add_formula(sheet = "Cover", x = "SUM(C8:C12)", dims = "C13")` | `write_cells(p, sheet = "Cover", C13 = xl_formula("SUM(C8:C12)"))` |
| `wb$add_numfmt(sheet = "Cover", dims = "C4", numfmt = "0.0%")` | `styles = list(C4 = xl_style(format = "0.0%"))` |
| `wb$clean_sheet(sheet = "Data")`, then `wb$add_data(sheet = "Data", x = df)` and `wb$save(p)` | `write_sheet(df, p, sheet = "Data")` |
| `wb$add_data(sheet = "Data", x = df, dims = "H2")`, then `wb$save(p)` | `write_sheet(df, p, sheet = "Data", at = "H2")` |
| `wb$add_worksheet("New")`, then `wb$add_data(sheet = "New", x = df)` and `wb$save(p)` | `write_sheet(df, p, sheet = "New")` |

## What differs

- **`NA` is a blank cell.** openxlsx2 writes `NA` as the Excel error
  `#N/A` unless told otherwise, so `SUM()` over the column fails. xlkit
  writes a blank cell; `na = "NA"` writes text.
- **Excel errors are `NA`, with a warning.** openxlsx2 reads `#DIV/0!`
  as the text `"#DIV/0!"`, which makes a column of numbers character.
  xlkit reads every error as `NA`, warns, and lists them in
  `xlsx_problems(df)`.
- **Mixed columns say why.** In both, one text cell among numbers makes
  a column character. xlkit says which cells did it.
- **Templates are copied, not rebuilt.** openxlsx2 loads a template
  into its model and saves the model, which keeps what the model
  covers. `write_sheet()` and `write_cells()` copy every part they do
  not write, byte for byte.
- **Files are not replaced unasked.** `wb$save()` replaces a file that
  exists. `write_xlsx()` stops; give `replace = TRUE`.
- **Variable labels.** openxlsx2 writes labelled columns as their
  labels, as xlkit does, but ignores variable labels. xlkit writes them
  as the header with `header = "labels"`, and `values = "codes"` writes
  codes.
