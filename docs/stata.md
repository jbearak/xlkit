# From a do-file to R: Excel lines

Each `import excel`, `export excel` and `putexcel` line of a do-file has
one line of xlkit. A translated script starts:

```r
library(dtaparser)
library(datakit)
library(xlkit)
```

Stata keeps one dataset in memory, and R keeps as many as you name, so
`import excel ..., clear` becomes `df <- read_xlsx(...)`, and the
`export excel` and `putexcel` lines say which data frame they write.

## import excel

| Stata | xlkit |
|---|---|
| `import excel using "f.xlsx", clear` | `df <- read_xlsx("f.xlsx", header = FALSE)` |
| `import excel using "f.xlsx", firstrow clear` | `df <- read_xlsx("f.xlsx", names = "stata")` |
| `..., sheet("Sales 2024")` | `sheet = "Sales 2024"` |
| `..., cellrange(B5:F40)` | `range = "B5:F40"` |
| `..., cellrange(B5)` | `range = "B5"` (from B5 to the last row and column with data) |
| `..., firstrow case(lower)` | `names = c("stata", "lower")` |
| `..., allstring` | `types = "text"` |
| `import excel using "f.xlsx", describe` | `xlsx_sheets("f.xlsx")` |
| a loop that imports each sheet and appends | `dplyr::bind_rows(read_sheets("f.xlsx"), .id = "sheet")` |

Without `firstrow`, Stata names the variables by their column letters,
`A`, `B`, ..., and `header = FALSE` does the same. With `firstrow`,
Stata makes each header into a valid name and keeps the header text as
the variable label; `names = "stata"` does both.

Two things differ:

- Stata picks a numeric or string type for each column from its cells,
  as xlkit does, but puts dates in numeric variables with a `%td`
  format. xlkit gives `Date` and `POSIXct` columns; dtaparser's
  `save_dta()` writes them as `%td` and `%tc`.
- `import excel` reads an Excel error as missing without saying so.
  xlkit warns and lists the cells: `xlsx_problems(df)`.

## export excel

| Stata | xlkit |
|---|---|
| `export excel using "f.xlsx", firstrow(variables) replace` | `write_xlsx(df, "f.xlsx", replace = TRUE)` |
| `export excel using "f.xlsx", replace` (no header row) | `write_xlsx(df, "f.xlsx", header = FALSE, replace = TRUE)` |
| `..., firstrow(varlabels)` | `header = "labels"` |
| `..., nolabel` | `values = "codes"` |
| `..., sheet("Data")` on a new file | `sheet = "Data"` |
| `..., sheet("Data", replace)` on an existing file | `write_sheet(df, "f.xlsx", sheet = "Data")` |
| `..., sheet("Data", modify) cell(B3)` | `write_sheet(df, "f.xlsx", sheet = "Data", at = "B3")` |
| `..., keepcellfmt` | nothing: `write_sheet(..., at =)` keeps cell formats |
| `..., missing("NA")` | `na = "NA"` |
| `..., datestring("%tdCCYY-NN-DD")` | write the dates as text first: `df$date <- format(df$date, "%Y-%m-%d")`; to keep them as Excel dates shown that way, `formats = c(date = "yyyy-mm-dd")` |
| `export excel x y using "f.xlsx" if g == 1, ...` | `write_xlsx(df[which(df$g == 1), c("x", "y")], "f.xlsx", ...)` (`which()` drops rows where `g` is `NA`, as `if` does) |

`replace = TRUE` matches Stata's `replace`: without it, `write_xlsx()`
stops when the file exists, and says which sheets it has and how to
keep them.

## putexcel

`putexcel set` names the file and sheet for the lines after it.
`write_cells()` takes them in each call, so a run of `putexcel` lines
becomes one call:

```stata
putexcel set "results.xlsx", sheet("Cover") modify
putexcel C4 = 1250
putexcel C5 = (date("2024-12-31", "YMD") - td(30dec1899)), nformat("yyyy-mm-dd")
putexcel B2 = "Results for 2024", bold font("Calibri", 14)
putexcel B2:F2, merge hcenter
```

```r
write_cells(
  "results.xlsx", sheet = "Cover",
  C4 = 1250,
  C5 = as.Date("2024-12-31"),
  B2 = "Results for 2024",
  styles = list(B2 = xl_style(bold = TRUE, font = "Calibri", size = 14),
                "B2:F2" = xl_style(align = "center")),
  merge = "B2:F2"
)
```

| Stata | xlkit, inside `write_cells(path, sheet, ...)` |
|---|---|
| `putexcel set "f.xlsx", sheet("S") modify` | `write_cells("f.xlsx", sheet = "S", ...)` |
| `putexcel set "f.xlsx", sheet("S") replace` | `write_xlsx()` first, or `write_sheet()` to start the sheet over |
| `putexcel C4 = 1250` | `C4 = 1250` |
| `putexcel C4 = (r(mean))` | `C4 = mean(df$x)` |
| `putexcel C4 = "text"` | `C4 = "text"` |
| `putexcel B2 = matrix(M)` | `B2 = unname(M)` (values only) |
| `putexcel B2 = matrix(M), names` | `B2 = M`: a matrix with row or column names writes them too |
| `putexcel B2 = formula(SUM(A1:A5))` | `B2 = xl_formula("SUM(A1:A5)")` |
| `putexcel C4, nformat("0.0%")` | `styles = list(C4 = xl_style(format = "0.0%"))` |
| `putexcel A1:F1, bold` | `styles = list("A1:F1" = xl_style(bold = TRUE))` |
| `putexcel A1:F1, border(bottom)` | `styles = list("A1:F1" = xl_style(border = c(bottom = "thin")))` |
| `putexcel A1:F1, fpattern(solid, "220 230 241")` | `styles = list("A1:F1" = xl_style(fill = "#DCE6F1"))` |
| `putexcel A1:F1, merge` | `merge = "A1:F1"` |
| `putexcel A1:F1, hcenter` | `styles = list("A1:F1" = xl_style(align = "center"))` |
| `putexcel save`, `putexcel clear` | nothing: each `write_cells()` call saves |

Not translated: `putexcel ... = picture()` and `= etable`/`collect`
tables. Write the table as a data frame first, then put it at a cell:
`write_cells(path, sheet, B2 = tab)`.

Stata counts dates in days from 1 January 1960 and Excel from
30 December 1899, so a do-file that puts a date into a cell subtracts
`td(30dec1899)`. An R `Date` needs nothing: `write_cells()` converts it.

## Files that Excel has open

On Windows, Excel locks a workbook it has open, and both Stata and
xlkit stop with an error until you close it. On macOS nothing locks the
file; close it in Excel before writing anyway, because Excel will not
see the change and may save over it.
