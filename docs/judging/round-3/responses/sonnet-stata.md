# Judging: Library A (xlkit, R) and Stata (`import excel`, `export excel`, `putexcel`)

Order of scores for A: Ergonomics, Failure, Findability, Correctness, Completeness, Clarity. Stata gets Ergonomics and Failure only.

Stata scoring note: `import excel` needs `firstrow` to take names from row 1, and `export excel` needs `firstrow(variables)` to write a header. Without them the default gives a wrong result for these scenarios. I score that as 2 (one command, one required option whose meaning is clear), not 1.

---

## Library A

### 1 Install
```r
install.packages("remotes")
remotes::install_github("jbearak/xlkit")
```
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: two calls, not on CRAN, and the user must install Rust first (plus Rtools on Windows).
- Failure 3: `xlkit: building needs cargo` names the problem, and the next lines say to restart R and check `Sys.which("cargo")`.
- Findability, correctness, completeness and clarity are all 3. The README has an Install section and the guide has per-platform steps, the R version, system requirements, a check command and an issue-report route.

### 2 Read a sheet
```r
read_xlsx("report.xlsx")
```
Scores: 3, 3, 3, 3, 3, 3. One call, and the type table gives each column's type (int, chr, dbl, lgl, Date). A missing file stops with "reprot.xlsx does not exist. Did you mean report.xlsx?".

### 3 Choose what to read
```r
read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets("sales.xlsx")
```
Scores: 3, 3, 3, 3, 3, 3. Each part is one call with direct arguments. A misspelled sheet stops, suggests "Sales 2024" and lists all sheet names.

### 4 Header and names
```r
read_xlsx(p, sheet = "Headers", names = "snake")
read_xlsx(p, sheet = "Two-row header", header = 4:5)
```
Scores: 3, 3, 3, 3, 3, 3. A blank or repeated header is repaired and reported ("New names: C1 "Total" is `Total_C` (it repeats B1)..."). Header text is kept as the `label` attribute. A merged group cell names each column it covers.

### 5 Column types
```r
df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: the read is one call with a named `types`. Listing the unconverted cells takes a second call, `xlsx_problems()`. Zip numbers with no zero-padding format also need `formatC` afterwards, which the docs say.
- Failure 3: the warning gives "2 cells in `amount` could not be read as numbers and are NA: C2003 ("n/a") and C2004 ("12,5")", and "See them all with `xlsx_problems(df)`".

### 6 Dates and times
```r
read_xlsx("dates.xlsx")
read_xlsx("dates1904.xlsx")
read_xlsx("dates.xlsx", dates = FALSE)
```
Scores: 3, 3, 3, 3, 3, 3. Dates, date-times and times come as Date, POSIXct (UTC) and hms, and the 1904 system is read from the workbook. `dates = FALSE`, or `types = ... "number"`, gives the stored numbers. The guide's number examples check out (45306, 0.354). A stray `unknown` makes the column text, and the message names the cell and points to `types = c(day = "date")`.

### 7 Missing values and errors
```r
df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: the read is one call, but telling errors from blanks needs `xlsx_problems()`, a second call.
- Failure 3: "2 cells hold Excel errors and are NA: D4 (#N/A) and D9 (#DIV/0!). See them all with `xlsx_problems(df)`", and the numeric column stays numeric.

### 8 Every sheet
```r
all <- read_sheets("book.xlsx")
```
Scores: 3, 3, 3, 3, 3, 3. One call returns a named list. An empty sheet gives a 0×0 tibble, and the docs say so, which is the right result with no message needed.

### 9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores: 3, 3, 3, 3, 3, 3. The type table says what each column becomes: factor to its labels as text, NA to a blank, Date and POSIXct to formatted dates. An existing file stops with "already exists, with sheets ..." and says to use `replace = TRUE` or `write_sheet()`.

### 10 Write several tables
```r
write_xlsx(list(Summary = a, Detail = b, Notes = c), "r.xlsx")
write_xlsx(list(Results = list("Table 1" = a, "Table 2" = b)), "t.xlsx", gap = 2)
```
Scores: 3, 3, 3, 3, 3, 3. Both parts are one call. `Q1/Q2` stops before anything is written, names the `/` and suggests "Q1-Q2".

### 11 Format the output
```r
write_xlsx(df, "o.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: 3, 3, 3, 3, 3, 3. Bold header, fitted widths and frozen header are defaults. An unknown column in `formats` stops, names it and suggests `share`. The format examples in the table are numerically right.

### 12 Fill an existing workbook
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: two calls.
- Failure 3: the docs say the chart is kept and plots the new data. They also say a chart on a fixed range is flagged when the table size changes, and they list what is kept, what is cleared and what is refused.

### 13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")
df <- read_xlsx("survey.xlsx", names = "snake")
```
Scores: 3, 3, 3, 3, 3, 3. Value labels are written by default, and the long header comes back as the `label` attribute that `save_dta()` uses. A code with no value label is written as the code, with a message naming the cells and the fix (`with_labels()` or `values = "codes"`).

---

## Stata

### 2 Read a sheet
```stata
import excel using "report.xlsx", firstrow clear
```
Scores: 2, 2
- Ergonomics 2: one command, but `firstrow` is required, or row 1 becomes data and the columns turn into strings. Types are chosen by Stata, and dates arrive as numerics with `%td` formats.
- Failure 2: `file reprot.xlsx not found` (r(601)) names the problem but gives no suggestion.

### 3 Choose what to read
```stata
import excel using "f.xlsx", describe
import excel using "f.xlsx", sheet("Sales 2024") cellrange(B5:F40) firstrow clear
```
Scores: 2, 2
- Ergonomics 2: arguments are in Excel terms, but `firstrow` is again required, and listing the sheets is a separate command.
- Failure 2: a sheet that is not found stops with an error naming the sheet. It does not list the available sheets.

### 4 Header and names
```stata
import excel using "f.xlsx", sheet("Headers") firstrow clear
import excel using "f.xlsx", sheet("Two-row") cellrange(A5) firstrow clear   // group row lost; rebuild names by hand
```
Scores: 1, 2
- Ergonomics 1: the blank and duplicate cells get valid names, and the original header text goes into the variable label, in one command. The two-row header has no merge or join, so the user imports once, builds names with `rename` or a loop, and sets labels.
- Failure 2: names are repaired silently. The label keeps the header text, but there is no message.

### 5 Column types
```stata
import excel using "f.xlsx", sheet("Types") firstrow allstring clear
destring amount, gen(amount_n) force
list amount if missing(amount_n) & amount != ""
```
Scores: 1, 2
- Ergonomics 1: there is no per-column type option, only `allstring`. The user then converts column by column and lists the failures by hand.
- Failure 2: `destring, force` reports a count of values it could not convert but not which cells.

### 6 Dates and times
```stata
import excel using "dates.xlsx", firstrow clear      // %td / %tc variables
gen double stamp_xl = stamp / 86400000 + 21916       // stored number, by hand
```
Scores: 1, 1
- Ergonomics 1: date, date-time and time cells arrive as Stata date variables. Getting Excel's stored numbers has no option, so the user converts by hand and must know the 1960 versus 1899/1904 offsets.
- Failure 1: a column with `unknown` becomes a string column and no message names the cell.

### 7 Missing values and errors
```stata
import excel using "f.xlsx", sheet("Missing") firstrow allstring clear
foreach v of varlist * { replace `v' = "" if inlist(`v',"NA",".","-") }
destring rate, replace force
```
Scores: 1, 0
- Ergonomics 1: there is no `na()` option, so it is several commands. Excel errors come in as missing, and there is no way to tell them from blanks.
- Failure 0: `#N/A` and `#DIV/0!` become missing without any message, which is the behaviour Library A's docs describe for Stata.

### 8 Every sheet
```stata
import excel using "f.xlsx", describe
forvalues i = 1/`r(N_worksheet)' {
    local s `r(worksheet_`i')'
    frame create f`i'
    frame f`i': import excel using "f.xlsx", sheet("`s'") firstrow clear
}
```
Scores: 1, 2
- Ergonomics 1: this is a loop with frames or tempfiles, and there is no collection of tables.
- Failure 2: an empty sheet errors rather than giving an empty table, which stops the loop unless it is wrapped in `capture`.

### 9 Write a table
```stata
export excel using "out.xlsx", firstrow(variables)
```
Scores: 2, 2
- Ergonomics 2: one command. `firstrow(variables)` is needed for a header row. Value labels are written as text by default and missing values come out blank. Stata has no logical or factor types, so those are numeric or labelled numerics.
- Failure 2: an existing file stops with `file out.xlsx already exists` (r(602)), which names the problem but does not point to `replace` or `modify`.

### 10 Write several tables
```stata
export excel using "r.xlsx", sheet("A") firstrow(variables) replace   // one dataset in memory at a time
export excel using "r.xlsx", sheet("B", modify) firstrow(variables)
putexcel set "r.xlsx", sheet("S") modify
putexcel A1 = "Table 1"
export excel using "r.xlsx", sheet("S", modify) cell(A2) firstrow(variables)
// compute the next row from _N, then repeat for table 2
```
Scores: 1, 2
- Ergonomics 1: one command per table, with the right dataset loaded each time, and titles and start rows are worked out by hand.
- Failure 2: an invalid sheet name is rejected with an error. As I remember it, the message names the problem without suggesting a replacement.

### 11 Format the output
```stata
export excel using "o.xlsx", firstrow(variables) replace
putexcel set "o.xlsx", modify
putexcel A1:E1, bold
putexcel C2:C`=_N+1', nformat("0.0%")
putexcel D2:D`=_N+1', nformat("#,##0")
```
Scores: 0, 1
- Ergonomics 0: formats go by cell range, and the last row has to be computed. `putexcel` has no autofit, no freeze panes and no filter buttons, so the scenario is not fully possible.
- Failure 1: formats are applied by cell reference, so a misspelled column name is never checked and the wrong cells are formatted without a message.

### 12 Fill an existing workbook
```stata
export excel using "results.xlsx", sheet("Data", replace) firstrow(variables)
putexcel set "results.xlsx", sheet("Cover") modify
putexcel C4 = 1250
putexcel C5 = (date("2024-12-31","YMD") - td(30dec1899)), nformat("yyyy-mm-dd")
```
Scores: 1, 1
- Ergonomics 1: several commands, and the date has to be converted to an Excel serial by hand.
- Failure 1: I do not recall the manual saying what happens to the template's chart, so it is unknown, and charts may not survive a rewrite.

### 13 Labels
```stata
export excel using "survey.xlsx", firstrow(varlabels)
import excel using "survey.xlsx", firstrow clear
```
Scores: 3, 1
- Ergonomics 3: `firstrow(varlabels)` gives the variable labels as the header and value labels are written by default. On import, `firstrow` makes valid short names and keeps the header text as the variable label.
- Failure 1: a code with no value label is written as the number with no message.

---

```json
{"A": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [2,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [2,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,3,3,3,3,3]},
 "Stata": {"2": [2,2], "3": [2,2], "4": [1,2], "5": [1,2], "6": [1,1], "7": [1,0], "8": [1,2], "9": [2,2], "10": [1,2], "11": [0,1], "12": [1,1], "13": [3,1]}}
```
