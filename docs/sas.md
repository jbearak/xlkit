# From SAS to R: Excel lines

This page gives the xlkit line for each SAS step that reads or writes a
workbook: `PROC IMPORT`, `PROC EXPORT`, the `XLSX` engine of `LIBNAME`
and `ODS EXCEL`. [docs/r.md](r.md) covers each task in full.

```r
library(xlkit)
```

SAS keeps data sets in a library; R keeps data frames in variables, so
`out=df` becomes `df <- read_xlsx(...)`, and the writing lines name the
data frame they write.

## PROC IMPORT

```sas
proc import datafile="sales.xlsx" out=sales dbms=xlsx replace;
  range="Sales$B5:F40";
  getnames=yes;
run;
```

```r
sales <- read_xlsx("sales.xlsx", sheet = "Sales", range = "B5:F40")
```

| SAS | xlkit |
|---|---|
| `proc import datafile="f.xlsx" out=df dbms=xlsx replace; run;` | `df <- read_xlsx("f.xlsx")` |
| `sheet="Sales 2024";` | `sheet = "Sales 2024"` |
| `range="Sales$B5:F40";` | `sheet = "Sales", range = "B5:F40"` |
| `range="SalesTable";` (a named range) | `range = "SalesTable"`; an Excel table's name works too |
| `getnames=no;` | `header = FALSE`: columns are named by their letters, `A`, `B`, ... |
| `options validvarname=v7;` (the default) | `names = "stata"`: letters, digits and `_`, at most 32 characters, as V7 allows; a header that had to change is kept as the column's `label` |
| `options validvarname=any;` | `names = "unique"` (the default): the header text as it is, such as `` df$`Share %` `` |

Reading through the `XLSX` engine:

| SAS | xlkit |
|---|---|
| `libname x xlsx "f.xlsx";` then `data df; set x."Sales 2024"n; run;` | `df <- read_xlsx("f.xlsx", sheet = "Sales 2024")` |
| `proc datasets lib=x; quit;` to list the sheets | `xlsx_sheets("f.xlsx")` |
| a macro loop over the sheets of `x` | `read_sheets("f.xlsx")`: a named list of tibbles |

## PROC EXPORT

| SAS | xlkit |
|---|---|
| `proc export data=df outfile="f.xlsx" dbms=xlsx replace; run;` | `write_xlsx(df, "f.xlsx", replace = TRUE)` |
| `sheet="Data";` | `sheet = "Data"` |
| `putnames=no;` | `header = FALSE` |
| `proc export data=df label ...;` (labels as the header) | `header = "labels"` |
| `sheet="Data";` on a workbook that exists | `write_sheet(df, "f.xlsx", sheet = "Data")`: the other sheets stay as they were |
| `data=df(where=(g = 1) keep=x y)` | `write_xlsx(df[which(df$g == 1), c("x", "y")], ...)`: `which()` drops rows where `g` is `NA`, as `where` drops missing `g` |

Without `replace = TRUE`, `write_xlsx()` stops when the file exists, and
says which sheets it has and how to keep them.

## ODS EXCEL

`ODS EXCEL` writes procedure output to a new workbook, one sheet per
table unless told otherwise. `write_xlsx()` writes data frames the same
way, and makes the header bold and keeps it in view by default.

```sas
ods excel file="report.xlsx" options(sheet_name="Summary" autofilter="all");
proc print data=summary noobs label; run;
ods excel options(sheet_name="Detail");
proc print data=detail noobs label; run;
ods excel close;
```

```r
write_xlsx(list(Summary = summary, Detail = detail), "report.xlsx",
           header = "labels", filter = TRUE, replace = TRUE)
```

| SAS | xlkit |
|---|---|
| `options(sheet_name="Data")` | `sheet = "Data"`, or a named list of data frames |
| `options(sheet_interval="none")` (tables stacked on one sheet) | `write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), ...)` |
| `options(frozen_headers="on")` | nothing: `freeze = TRUE` is the default |
| `options(autofilter="all")` | `filter = TRUE` |
| `options(absolute_column_width="20,12")` | `widths = c(region = 20, amount = 12)`, or `widths = 20` for every column; the default fits each column to its contents |
| `proc print ... label` | `header = "labels"` |
| `format share percent8.1 amount comma12.;` | `formats = c(share = "0.0%", amount = "#,##0")` |
| `style(header)=[font_weight=bold]` | nothing: `header_style = xl_style(bold = TRUE)` is the default |

A percent format multiplies by 100 in Excel as in SAS, so a share
stored as 0.256 shows as 25.6% in both.

## Filling in a template

SAS fills single cells of a template through DDE, with Excel running on
Windows. `write_cells()` writes the cells without Excel, on any system,
and keeps the rest of the workbook byte for byte. Cells are named as
Excel shows them, so `R4C3` is `C4`:

```r
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```

## What differs

- **Dates.** SAS counts days from 1 January 1960. A date cell reads as
  an R `Date`, and an R `Date` writes as an Excel date; nothing to
  convert.
- **Text has no length.** `PROC IMPORT` gives each character variable
  a fixed length; R's text has none, so nothing is cut.
- **Excel errors are reported.** A cell holding `#N/A` or `#DIV/0!` is
  `NA` with a warning that names it, and `xlsx_problems(df)` lists them
  all.
- **Formats and value labels.** A SAS user-defined format that maps
  codes to text arrives in R, through `haven::read_sas()` with its
  catalog, as a labelled column. `write_xlsx()` writes the labels by
  default and the codes with `values = "codes"`. See
  [Variable labels and value labels](r.md#variable-labels-and-value-labels).
