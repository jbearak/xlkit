# Round 1 judging: Library A (R) and Stata

Order of scores: Library A = [ergonomics, failure, findability, correctness, completeness, clarity]. Stata = [ergonomics, failure].
A score of 3 gets no reason. Reasons are given only for scores below 3.

## Library A

### 1 Install
```r
install.packages("remotes")
remotes::install_github("Library A")
```
Scores: [2, 2, 3, 2, 3, 3]
- Ergonomics 2: two calls, because `remotes` has to be installed first.
- Failure 2: the quoted message `Library A: building needs cargo` names the problem. The fix (restart R, check `Sys.which("cargo")`) is in the docs, not in the message.
- Correctness 2: the issue link is an unfilled placeholder, `<[link]>`.

### 2 Read a sheet
```r
read_xlsx("report.xlsx")
```
The columns become integer, character, double, logical and Date.
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs do not say what a missing file does.

### 3 Choose what to read
```r
read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets("sales.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]. A misspelled sheet stops with a "Did you mean" hint and the list of sheets.

### 4 Header and names
```r
read_xlsx("messy.xlsx", sheet = "Headers", names = "snake")
read_xlsx("messy.xlsx", sheet = "Two-row header", header = 4:5)
```
Scores: [3, 3, 3, 3, 3, 3]
- Duplicate and blank names are made unique (`Total_C`, `D`). The original header text is kept as the `label` attribute.
- The docs say every `names` choice gives unique names, so I treat the result as right without a message.

### 5 Column types
```r
df <- read_xlsx("messy.xlsx", sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]. The warning names C2003 and C2004 and points to `xlsx_problems()`.

### 6 Dates and times
```r
read_xlsx("dates.xlsx")
read_xlsx("dates1904.xlsx")
read_xlsx("dates.xlsx", dates = FALSE)
```
Scores: [3, 2, 3, 3, 2, 3]
- Failure 2: with `types = "date"` a text cell warns, but the docs show no date-specific message. By default the column quietly becomes character.
- Completeness 2: the docs do not say what stored numbers a 1904 workbook gives. They also do not say what happens to the one text cell (`unknown`) when `dates = FALSE`.

### 7 Missing values and errors
```r
df <- read_xlsx("messy.xlsx", sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: a second call, `xlsx_problems()`, is needed to tell errors from blanks. The warning already names the error cells.

### 8 Every sheet
```r
read_sheets("workbook.xlsx")
```
Scores: [3, 1, 3, 3, 2, 3]
- Failure 1: the docs do not say what an empty sheet gives.
- Completeness 2: the same missing edge case.

### 9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]. The docs give a type table (factor becomes text, NA becomes a blank). A workbook saved by another program is refused with a message that offers `write_sheet()` or `replace = TRUE`.

### 10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "wb.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "r.xlsx", gap = 2)
```
Scores: [3, 2, 3, 3, 3, 3]
- Failure 2: the docs say a sheet name holding `/` is an error that says which value broke the limit, but not what to do.

### 11 Format the output
```r
write_xlsx(df, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3, 1, 3, 3, 2, 3]
- Failure 1: the docs do not say what an unknown name in `formats` does. They say so only for `styles`.
- Completeness 2: the same missing edge case.

### 12 Fill an existing workbook
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [2, 3, 3, 3, 2, 3]
- Ergonomics 2: two calls, one for each sheet.
- Completeness 2: the docs do not say what happens to the formatting of the cells `write_sheet()` clears. They also do not say what happens when the new table is a different size from the chart's range.

### 13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")
read_xlsx("survey.xlsx", names = "snake")
```
Scores: [3, 3, 3, 3, 3, 3]. A code with no label is written as the code, and the docs say so.

## Stata

### 2 Read a sheet
```stata
import excel using "report.xlsx", firstrow clear
```
Scores: [2, 2]
- Ergonomics 2: one command, but without `firstrow` the header becomes data and every column is a string.
- Failure 2: `file reprot.xlsx not found`, r(601). The message names the problem and not the fix.

### 3 Choose what to read
```stata
import excel using "sales.xlsx", sheet("Sales 2024") cellrange(B5:F40) firstrow clear
import excel using "sales.xlsx", describe
```
Scores: [2, 2]
- Ergonomics 2: two commands.
- Failure 2: `worksheet Sales 2042 not found`. It does not list the sheets.

### 4 Header and names
```stata
import excel using "messy.xlsx", sheet("Headers") firstrow clear
import excel using "messy.xlsx", sheet("Two-row header") cellrange(A4) allstring clear
* then a loop to join rows 4 and 5 into names, rename, drop row 1 and 2
```
Scores: [1, 3]
- Ergonomics 1: the one-row header works, but the two-row header needs several commands and a loop to build the names.
- Failure: `firstrow` makes valid names and keeps the original text as the variable label, so I score it 3 with no message needed. I am not sure of the exact rule Stata uses for duplicates.

### 5 Column types
```stata
import excel using "messy.xlsx", sheet("Types") firstrow allstring clear
destring amount, generate(amount_n) force dpcomma
list row if missing(amount_n) & amount != ""
```
Scores: [1, 2]
- Ergonomics 1: there is no per-column type option. Several commands are needed, and the cells that failed have to be found by hand.
- Failure 2: without `force`, `destring` stops with "contains nonnumeric characters". It does not say which cells. With `force` it is silent.

### 6 Dates and times
```stata
import excel using "dates.xlsx", firstrow clear
import excel using "dates1904.xlsx", firstrow clear
gen double day_num = day - td(30dec1899)
```
Scores: [1, 1]
- Ergonomics 1: Stata dates are not Excel numbers, so the stored numbers need extra conversion code.
- Failure 1: one text cell makes the column a string silently, and Stata's own docs do not describe it.

### 7 Missing values and errors
```stata
import excel using "messy.xlsx", sheet("Missing") firstrow clear
destring rate, replace force
```
Scores: [1, 0]
- Ergonomics 1: the missing-value codes make the column a string, and `destring force` is needed. Errors cannot be told apart from blanks.
- Failure 0: `#N/A` and `#DIV/0!` become missing with no message (the Library A docs also state this).

### 8 Every sheet
```stata
import excel using "wb.xlsx", describe
forvalues i = 1/`r(N_worksheet)' { local s`i' = r(worksheet_`i') }
forvalues i = 1/12 {
    frame create f`i'
    frame f`i': import excel using "wb.xlsx", sheet("`s`i''") firstrow
}
```
Scores: [1, 1]
- Ergonomics 1: a loop and frames are needed.
- Failure 1: I do not know of a message for an empty sheet that names the problem.

### 9 Write a table
```stata
export excel using "out.xlsx", firstrow(variables)
```
Scores: [2, 2]
- Ergonomics 2: one command, but `firstrow` is needed for a header. Dates and value labels are written by default.
- Failure 2: `file out.xlsx already exists` stops the command, but the message does not mention `replace`.

### 10 Write several tables
```stata
export excel using "r.xlsx", sheet("A") firstrow(variables) replace
* load the second table, then:
export excel using "r.xlsx", sheet("B", modify) firstrow(variables)
* same again for the third table
putexcel set "r.xlsx", sheet("S") modify
putexcel A1 = "Table 1"
export excel using "r.xlsx", sheet("S", modify) cell(A2) firstrow(variables)
local r = _N + 5
putexcel A`r' = "Table 2"
* ... export the second table at cell(A`=`r'+1')
```
Scores: [1, 2]
- Ergonomics 1: there are several commands, and each table has to be loaded first. The row of the second table is worked out by hand.
- Failure 2: an invalid sheet name stops with a message naming the problem, as far as I recall.

### 11 Format the output
```stata
putexcel set "out.xlsx", sheet("Sheet1") modify
putexcel A1:E1, bold
putexcel D2:D100, nformat(0.0%)
putexcel E2:E100, nformat(#,##0)
* column widths need Mata; freeze panes and filter buttons are not available
```
Scores: [0, 1]
- Ergonomics 0: freeze panes and filter buttons are not possible in `putexcel`. Widths need Mata. Formats go by cell range, not by column name.
- Failure 1: Stata has no formats keyed by column name, so there is no matching message.

### 12 Fill an existing workbook
```stata
export excel using "results.xlsx", sheet("Data", replace) firstrow(variables)
putexcel set "results.xlsx", sheet("Cover") modify
putexcel C4 = 1250
putexcel C5 = date("2024-12-31", "YMD"), nformat("yyyy-mm-dd")
```
Scores: [1, 0]
- Ergonomics 1: several commands.
- Failure 0: as I recall, charts and other unsupported features can be lost in `modify` with no warning. I am not certain.

### 13 Labels
```stata
export excel using "survey.xlsx", firstrow(varlabels)
import excel using "survey.xlsx", firstrow clear
```
Scores: [2, 3]
- Ergonomics 2: one command each way, but `firstrow` is needed in both. On import, the long header is kept as the variable label and the name is made valid, up to 32 characters.
- Failure: value labels are used where they exist and the code is shown otherwise. I score it 3 as the right result without a message, the same as Library A.

```json
{"A": {"1": [2,2,3,2,3,3], "2": [3,1,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,2,3,3,2,3], "7": [2,3,3,3,3,3], "8": [3,1,3,3,2,3], "9": [3,3,3,3,3,3], "10": [3,2,3,3,3,3], "11": [3,1,3,3,2,3], "12": [2,3,3,3,2,3], "13": [3,3,3,3,3,3]},
 "Stata": {"2": [2,2], "3": [2,2], "4": [1,3], "5": [1,2], "6": [1,1], "7": [1,0], "8": [1,1], "9": [2,2], "10": [1,2], "11": [0,1], "12": [1,0], "13": [2,3]}}
```
