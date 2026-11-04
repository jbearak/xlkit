# Judging: Library A (xlkit, R) and Stata

Scores are [ergonomics, failure, findability, correctness, completeness, clarity] for Library A, and [ergonomics, failure] for Stata.

## Library A

**1 Install**
```r
install.packages("remotes"); remotes::install_github("jbearak/xlkit")
```
Scores: [2,3,3,3,2,3]
- Ergonomics 2: two calls, and a Rust toolchain is needed first (Rtools on Windows).
- Failure 3: the `xlkit: building needs cargo` message says R cannot find Rust and what to do (restart R, check `Sys.which("cargo")`).
- Completeness 2: no minimum Rust version, no Linux system libraries, and no word on whether prebuilt binaries exist.

**2 Read a sheet**
```r
scores <- read_xlsx("report.xlsx")
```
Scores: [3,3,3,3,3,3]. A type table is given, and a missing file gives `Did you mean report.xlsx?`.

**3 Choose what to read**
```r
read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets("sales.xlsx")
```
Scores: [3,3,3,3,3,3]. A wrong sheet name lists the sheets and suggests the closest one.

**4 Header and names**
```r
read_xlsx(p, sheet = "Headers", names = "snake")
read_xlsx(p, sheet = "Two-row header", header = 4:5)
```
Scores: [3,3,3,3,3,3]. The `New names:` message says where each repaired name came from. The `label` attribute keeps the original header text.

**5 Column types**
```r
df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))
```
Scores: [3,3,3,3,3,3]. The warning names C2003 and C2004 and points to `xlsx_problems(df)`. The docs are honest that leading zeros typed away cannot be restored, and give a `formatC` workaround.

**6 Dates and times**
```r
read_xlsx("dates.xlsx"); read_xlsx("dates1904.xlsx"); read_xlsx("dates.xlsx", dates = FALSE)
```
Scores: [3,3,3,3,2,3]
- Completeness 2: the 1904 workbook is covered for date reading, but the docs do not say what the stored numbers look like in that system.
- The `unknown` text cell is covered by the Column types message, and `types = c(day = "date")` is offered as the fix.

**7 Missing values and errors**
```r
df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-")); xlsx_problems(df)
```
Scores: [3,3,3,3,3,3]. The warning names D4 (#N/A) and D9 (#DIV/0!). `xlsx_problems()` separates errors from blanks.

**8 Every sheet**
```r
read_sheets("book.xlsx")
```
Scores: [3,3,3,3,3,3]. An empty sheet gives a 0x0 tibble, and the docs say so.

**9 Write a table**
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3,3,3,3,3,3]. A column-type table is given. An existing file stops with an error that lists its sheets and offers `replace = TRUE` or `write_sheet()`.

**10 Write several tables**
```r
write_xlsx(list(A = a, B = b, C = c), "w.xlsx")
write_xlsx(list(S = list("Table 1" = t1, "Table 2" = t2)), "w2.xlsx", gap = 2)
```
Scores: [3,3,3,3,3,3]. A `Q1/Q2` sheet name stops before writing and suggests `Q1-Q2`.

**11 Format the output**
```r
write_xlsx(df, "o.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3,3,3,3,3,3]. Bold header, frozen header and auto widths are defaults. A misspelled column in `formats` stops with `Did you mean share?`.

**12 Fill an existing workbook**
```r
write_sheet(new, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [3,3,3,3,3,3]. The docs say what is kept and what is cleared, say the chart is kept and follows the data, and warn when its fixed range no longer matches.

**13 Labels**
```r
write_xlsx(df, "s.xlsx", header = "labels")
df <- read_xlsx("s.xlsx", names = "snake")
```
Scores: [3,3,3,3,3,3]. A code with no value label is written as the code, with a message naming the cells and the fix.

## Stata (`import excel`, `export excel`, `putexcel`)

**2** `import excel "report.xlsx", firstrow clear`
Scores: [2,2]
- Ergonomics 2: without `firstrow` the header row becomes data and every column is a string.
- Failure 2: `file reprot.xlsx not found`, r(601). It names the problem only and does not suggest a similar file.

**3** `import excel "sales.xlsx", sheet("Sales 2024") cellrange(B5:F40) firstrow clear` and `import excel "sales.xlsx", describe`
Scores: [2,2]
- Ergonomics 2: needs `firstrow`.
- Failure 2: a bad sheet name gives an error naming the worksheet but does not list the sheets.

**4** `import excel f.xlsx, sheet("Headers") firstrow clear` for the first sheet. The two-row header needs `cellrange` from the names row, then manual `rename` or concatenation.
Scores: [1,1]
- Ergonomics 1: the single-row case is handled (valid names, header kept as label), but a two-row header has no support and takes several commands.
- Failure 1: duplicate and blank headers are repaired silently; no message.

**5** `import excel f.xlsx, sheet("Types") firstrow clear`, then `destring amount, replace force`, then `list if missing(amount)`
Scores: [1,2]
- Ergonomics 1: mixed columns come in as strings, so a destring step is needed. Number cells in `zip` lose leading zeros.
- Failure 2: `destring ..., force` reports how many values became missing but does not name the cells. `12,5` can silently become 125 under `ignore(",")`.

**6** `import excel f.xlsx, firstrow clear` for dates. For stored numbers, convert from Stata dates back to Excel serials (`gen x = day + 21916`).
Scores: [1,1]
- Ergonomics 1: dates import natively as `%td` and `%tc`. Excel's stored numbers are not available directly, because Stata's epoch differs.
- Failure 1: a text cell makes the column a string with no message, and the docs do not say what is shown.

**7** `import excel f.xlsx, sheet("Missing") firstrow clear`, then `destring rate, replace force`, plus `replace x = "" if inlist(x, "NA", ".", "-")`
Scores: [1,1]
- Ergonomics 1: there is no `na()` option, and a text code turns the column into a string.
- Failure 1: Excel errors become missing silently, and errors cannot be told from blanks.

**8** `import excel f.xlsx, describe`, then a `forvalues` loop over `r(worksheet_`i')` with `import excel f.xlsx, sheet("`s'") firstrow clear` and a save or frame per sheet
Scores: [1,1]
- Ergonomics 1: one dataset in memory, so there is no collection of tables.
- Failure 1: how an empty sheet behaves is not documented in a way that is clear.

**9** `export excel using "out.xlsx", firstrow(variables)`
Scores: [2,2]
- Ergonomics 2: the header needs `firstrow`. Value labels are written as text by default. Stata has no logical type.
- Failure 2: `file out.xlsx already exists`, r(602). It names the problem only and does not say to use `replace`.

**10**
```stata
export excel using w.xlsx, sheet("A") firstrow(variables) replace
export excel using w.xlsx, sheet("B", modify) firstrow(variables)
// ... repeat for C, reloading each table each time
// two tables on one sheet:
putexcel set w.xlsx, sheet("S") modify
putexcel A1 = "Table 1"
export excel using w.xlsx, sheet("S", modify) cell(A2)
putexcel A`=_N+4' = "Table 2"
export excel using w.xlsx, sheet("S", modify) cell(A`=_N+5')
```
Scores: [1,2]
- Ergonomics 1: several commands, with each dataset loaded in turn and row arithmetic done by hand.
- Failure 2: an invalid sheet name gives an error naming the problem, with no suggested fix.

**11** `export excel` then `putexcel set ..., modify`, `putexcel A1:F1, bold`, `putexcel C2:C40, nformat(0.0%)`, `putexcel D2:D40, nformat(#,##0)`, `colwidth()` on Stata 17 and later
Scores: [0,2]
- Ergonomics 0: no auto-fit, no freeze panes and no filter buttons. Formats go by cell range, not by variable.
- Failure 2: a misspelled variable gives `variable shar not found` and stops.

**12**
```stata
putexcel set results.xlsx, sheet("Cover") modify
putexcel C4 = 1250
putexcel C5 = date("2024-12-31","YMD"), nformat(yyyy-mm-dd)
export excel using results.xlsx, sheet("Data", replace) firstrow(variables)
```
Scores: [1,1]
- Ergonomics 1: several commands, and the date needs an `nformat`.
- Failure 1: it is not documented clearly whether the chart survives.

**13** `export excel using "f.xlsx", firstrow(varlabels)` (value labels are the default; `nolabel` writes codes). Then `import excel f.xlsx, firstrow clear`.
Scores: [3,1]
- Failure 1: a code with no label is written as the number, with no message.

```json
{"A": {"1": [2,3,3,3,2,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,2,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [3,3,3,3,3,3], "13": [3,3,3,3,3,3]},
 "Stata": {"2": [2,2], "3": [2,2], "4": [1,1], "5": [1,2], "6": [1,1], "7": [1,1], "8": [1,1], "9": [2,2], "10": [1,2], "11": [0,2], "12": [1,1], "13": [3,1]}}
```
