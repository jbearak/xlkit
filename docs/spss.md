# From SPSS to R: Excel lines

This page gives the xlkit line for each SPSS command that reads or
writes a workbook: `GET DATA /TYPE=XLSX` and `SAVE TRANSLATE`.
[docs/r.md](r.md) covers each task in full.

```r
library(xlkit)
```

SPSS has one active dataset; R keeps as many data frames as you name,
so `GET DATA` becomes `df <- read_xlsx(...)`, and the writing lines name
the data frame they write.

## GET DATA

```spss
GET DATA
  /TYPE=XLSX
  /FILE='sales.xlsx'
  /SHEET=NAME 'Sales 2024'
  /CELLRANGE=RANGE 'B5:F40'
  /READNAMES=ON.
```

```r
sales <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
```

| SPSS | xlkit |
|---|---|
| `GET DATA /TYPE=XLSX /FILE='f.xlsx' /READNAMES=ON.` | `df <- read_xlsx("f.xlsx")` |
| `/SHEET=NAME 'Sales 2024'` | `sheet = "Sales 2024"` |
| `/SHEET=INDEX 3` | `sheet = 3` |
| `/CELLRANGE=RANGE 'B5:F40'` | `range = "B5:F40"` |
| `/CELLRANGE=FULL` | nothing: the default reads the sheet's data |
| `/READNAMES=OFF` | `header = FALSE`: columns are named by their letters, `A`, `B`, ... |
| `/ASSUMEDSTRWIDTH=255` | nothing: R's text has no width, so nothing is cut |
| `DATASET NAME sales.` | the variable `sales` |

SPSS makes each header into a valid variable name. `names = "snake"`
does the same in R's style, `Share %` becoming `share_percent`, and
keeps the header text as the `label` of each column whose name
changed, which `haven::write_sav()` writes as the variable label.

To read every sheet at once, `read_sheets("f.xlsx")` gives a named list
of tibbles; `xlsx_sheets("f.xlsx")` lists the sheet names.

## SAVE TRANSLATE

```spss
SAVE TRANSLATE OUTFILE='survey.xlsx'
  /TYPE=XLS
  /VERSION=12
  /FIELDNAMES
  /CELLS=LABELS
  /REPLACE.
```

```r
write_xlsx(survey, "survey.xlsx", replace = TRUE)
```

| SPSS | xlkit |
|---|---|
| `SAVE TRANSLATE OUTFILE='f.xlsx' /TYPE=XLS /VERSION=12 /FIELDNAMES /REPLACE.` | `write_xlsx(df, "f.xlsx", values = "codes", replace = TRUE)`: SPSS writes codes unless told `/CELLS=LABELS` |
| without `/FIELDNAMES` | `header = FALSE` |
| `/FIELDNAMES VALUE=LABELS` | `header = "labels"`: variable labels as the header |
| `/CELLS=LABELS` | nothing: `values = "labels"` is the default |
| `/CELLS=VALUES` | `values = "codes"` |
| `/EXCELOPTIONS SHEET='Data'` | `sheet = "Data"` |
| `/KEEP=id age sex` | `write_xlsx(df[c("id", "age", "sex")], ...)` |
| `/MISSING=RECODE` (user-missing values as blank) | nothing, if the data came through `haven::read_sav()`: it reads user-missing values as `NA`, and `NA` is a blank cell |

Without `replace = TRUE`, `write_xlsx()` stops when the file exists, and
says which sheets it has and how to keep them. To write one sheet of a
workbook that exists and keep the others, use
`write_sheet(df, "f.xlsx", sheet = "Data")`.

A labelled column read with `haven::read_sav()` is written as its value
labels, as `/CELLS=LABELS` does. A code without a label is written as
the code, with a message that names the cells. See
[Variable labels and value labels](r.md#variable-labels-and-value-labels).

## Output tables

`OUTPUT EXPORT /XLSX` writes Viewer tables to a workbook. In R, make the
table a data frame and write it; several tables can share one sheet,
each titled by its name:

```r
write_xlsx(list(Results = list("Table 1. Means" = means, "Table 2. Counts" = counts)),
           "tables.xlsx")
```

To put values into the cells of a formatted template instead, keeping
the rest of the workbook as it was, use `write_cells()`:

```r
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```

## What differs

- **Dates.** SPSS counts seconds from 14 October 1582. A date cell
  reads as an R `Date`, and an R `Date` writes as an Excel date;
  nothing to convert.
- **Types from every cell.** A column with one text cell among numbers
  is text, and xlkit says which cells made it so. `types =
  c(amount = "number")` reads it as numbers, and the cells that are not
  become `NA` with a warning.
- **Excel errors are reported.** A cell holding `#N/A` or `#DIV/0!` is
  `NA` with a warning that names it, and `xlsx_problems(df)` lists them
  all.
