# Judge response: Julia round (Library A vs Library B)

Score order: [ergonomics, failure, findability, correctness, completeness, clarity].
Only scores below 3 get a reason.

---

## Library A (R)

### 1 Install
Code:
```r
install.packages("remotes")
remotes::install_github("Library A")
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls (install `remotes`, then install the package), and a Rust toolchain must be installed first.

### 2 Read a sheet
Code:
```r
scores <- read_xlsx("report.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

### 3 Choose what to read
Code:
```r
read_xlsx(path, sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets(path)
```
Scores: [3, 3, 3, 3, 3, 3]

### 4 Header and names
Code:
```r
read_xlsx(path, sheet = "Headers")                           # New names: message lists each repair
read_xlsx(path, sheet = "Two-row header", header = 4:5)      # "Income 2020", ...
```
Scores: [3, 3, 3, 3, 3, 3]

### 5 Column types
Code:
```r
df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]

### 6 Dates and times
Code:
```r
read_xlsx("dates.xlsx")                       # Date, POSIXct, hms; 1904 file read automatically
read_xlsx("dates.xlsx", dates = FALSE)        # stored numbers
```
Scores: [3, 3, 3, 3, 3, 3]

### 7 Missing values and errors
Code:
```r
df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]

### 8 Every sheet
Code:
```r
all <- read_sheets("book.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

### 9 Write a table
Code:
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

### 10 Write several tables
Code:
```r
write_xlsx(list(A = a, B = b, C = c), "out.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "out.xlsx", gap = 2)
```
Scores: [3, 3, 3, 3, 3, 3]

### 11 Format the output
Code:
```r
write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3, 3, 3, 3, 3, 3]

### 12 Fill an existing workbook
Code:
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls, one for the sheet and one for the cells.

### 13 Labels
Code:
```r
write_xlsx(df, "survey.xlsx", header = "labels")      # values = "labels" is the default
df <- read_xlsx("survey.xlsx", names = "snake")       # long header kept as `label` attribute
```
Scores: [3, 3, 3, 3, 2, 3]
- Completeness 2: `names = "snake"` does not shorten long headers, and the docs do not point to `names = "stata"` (32-character limit) or a function for this case.

---

## Library B (XLSX.jl)

### 1 Install
Code:
```julia
using Pkg; Pkg.add("XLSX")
```
Scores: [3, 1, 3, 3, 2, 3]
- Failure 1: the docs say nothing about install failures or system requirements.
- Completeness 2: Julia version and platforms are given, but there is no word on system requirements or what to do when installation fails.

### 2 Read a sheet
Code:
```julia
df = XLSX.readto("report.xlsx", DataFrame)
```
Scores: [3, 1, 3, 3, 2, 2]
- Failure 1: the docs do not say what happens for a missing file.
- Completeness 2: there is no table of how each cell type becomes a column type (logical, date, text, mixed), only example outputs.
- Clarity 2: the column types have to be inferred from the examples, and `infer_eltypes` is described confusingly ("Vector{Any} of typed vectors").

### 3 Choose what to read
Code:
```julia
df = XLSX.readto("f.xlsx", "Sales 2024", "B:F", DataFrame; first_row = 5)
xf = XLSX.readxlsx("f.xlsx"); XLSX.sheetnames(xf)
```
Scores: [2, 1, 2, 3, 2, 2]
- Ergonomics 2: listing the sheet names takes two calls, and the range is given as columns plus `first_row` rather than `B5:F40`.
- Failure 1: the docs do not say what a misspelled sheet name does.
- Findability 2: `first_row` and the column range live in the docstrings, and `sheetnames` is in the tutorial, so the reader follows several links.
- Completeness 2: `B5:F40` as a single range for a table is not documented.
- Clarity 2: the reader has to piece it together from docstrings.

### 4 Header and names
Code:
```julia
df = DataFrame(XLSX.readtable("f.xlsx", "S"; normalizenames = true))
# two-row header: read the two rows with getdata, build labels by hand, then
XLSX.readtable("f.xlsx", "S"; first_row = 3, column_labels = labels)
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: a two-row header needs several manual calls, and nothing records which header text a name came from.
- Failure 1: the docs do not say what happens with duplicate or blank header cells.
- Findability 1: `normalizenames` and `column_labels` appear only in docstrings, with no guide section on headers.
- Correctness 2: what is stated is true, but the duplicate, blank and merged cases are not covered.
- Completeness 1: only the option names are given.
- Clarity 2: the docstrings are readable but give no example for this scenario.

### 5 Column types
Code:
```julia
df = DataFrame(XLSX.readtable("f.xlsx", "Types"))
df.zip = string.(df.zip)
df.amount = tryparse.(Float64, string.(df.amount))   # then find the nothings by hand
```
Scores: [1, 1, 1, 2, 1, 1]
- Ergonomics 1: there is no per-column type option, so conversion and finding the failed cells are manual.
- Failure 1: nothing is documented about unconvertible cells; the column just becomes mixed.
- Findability 1: only the `Any` columns in the FileIO example hint at it.
- Correctness 2: nothing false, but the scenario is not addressed.
- Completeness 1: there is no way to force a type, and leading zeros are not discussed.
- Clarity 1: no example.

### 6 Dates and times
Code:
```julia
df = DataFrame(XLSX.readtable("dates.xlsx", "Sheet1"))      # Date / Time / DateTime by cell style
# stored numbers: loop over XLSX.getcell(...).value by hand
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: the typed read is one call, but getting stored numbers means working cell by cell with `getcell`.
- Failure 1: the docs do not say what a text `unknown` cell does to a date column.
- Findability 1: the date behaviour is only implied by the write and round-trip examples and the `getdata` docstring.
- Correctness 2: the 1904 date system is not mentioned.
- Completeness 1: no 1904 handling and no stored-number read.
- Clarity 2: the examples show the types but do not explain the rule.

### 7 Missing values and errors
Code:
```julia
df = DataFrame(XLSX.readtable("f.xlsx", "Missing"; missing_strings = ["NA", ".", "-"]))
XLSX.iserror(sh, "A1:A50")      # errors found separately
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: `missing_strings` covers the text codes, but nothing says error cells become missing; they must be handled with a second call.
- Failure 1: the docs do not say what happens to `#N/A` cells in a numeric column.
- Findability 1: `missing_strings` and `iserror` appear only in docstrings.
- Correctness 2: what is stated is accurate but incomplete.
- Completeness 1: `missing_strings` is covered, but how errors read in a table is not.
- Clarity 2: the docstrings are clear but the two features are not connected.

### 8 Every sheet
Code:
```julia
xf = XLSX.readxlsx("book.xlsx")
Dict(n => DataFrame(XLSX.readtable("book.xlsx", n)) for n in XLSX.sheetnames(xf))
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: this takes a loop of per-sheet calls.
- Failure 1: the docs do not say what an empty sheet reads as.
- Findability 1: there is no guide entry; the reader must combine `sheetnames` and `readtable`.
- Correctness 2: nothing false, but nothing covers the task directly.
- Completeness 1: the pieces exist but no recipe is given.
- Clarity 2: the pieces are clear, the combination is left to the reader.

### 9 Write a table
Code:
```julia
XLSX.writetable("out.xlsx", df)
```
Scores: [3, 2, 3, 3, 2, 3]
- Failure 2: the docs say writing fails unless `overwrite=true`, but not what the message says or how to proceed.
- Completeness 2: the Julia types written are listed, but what each becomes in Excel (date formats, categorical, missing) is not.

### 10 Write several tables
Code:
```julia
XLSX.writetable("out.xlsx", "A" => a, "B" => b, "C" => c)
XLSX.openxlsx("out.xlsx", mode = "w") do xf
    s = xf[1]; s["A1"] = "Table 1"; XLSX.writetable!(s, t1; anchor_cell = XLSX.CellRef("A2"))
    s["A8"] = "Table 2"; XLSX.writetable!(s, t2; anchor_cell = XLSX.CellRef("A9"))   # rows counted by hand
end
```
Scores: [1, 1, 2, 3, 2, 3]
- Ergonomics 1: three sheets in one call is good, but two titled tables on one sheet take several calls with hand-counted anchors (min over parts).
- Failure 1: the docs do not say what happens with `/` in a sheet name.
- Findability 2: the multi-sheet case has a heading; titled tables on one sheet are not named anywhere.
- Completeness 2: sheet-name rules and titles above tables are not covered.

### 11 Format the output
Code:
```julia
XLSX.setFont(s, "A1:F1"; bold = true)
XLSX.setFormat(s, "E2:E40"; format = "0.0%")
XLSX.setFormat(s, "D2:D40"; format = "#,##0")
XLSX.setColumnWidth(s, "A:F"; width = 14)   # no autofit
XLSX.freezePanes(s)
# filter buttons: XLSX.addtable!(...) / as_table=true
```
Scores: [1, 1, 2, 3, 2, 2]
- Ergonomics 1: several calls over cell ranges, not column names, and widths cannot be fitted to contents.
- Failure 1: the docs do not say what happens for a wrong column; there are no named columns.
- Findability 2: each piece has a heading, but filter buttons are only in the Excel Tables page.
- Completeness 2: no auto-fit, and no filter without a Table.
- Clarity 2: there are many setter variants and the reader has to choose among them.

### 12 Fill an existing workbook
Code:
```julia
XLSX.openxlsx("results.xlsx", mode = "rw") do xf
    XLSX.writetable!(xf["Data"], df)        # old cells below/right are not cleared
    xf["Cover"]["C4"] = 1250
    xf["Cover"]["C5"] = Date(2024, 12, 31)
end
```
Scores: [1, 1, 3, 2, 1, 2]
- Ergonomics 1: this is an open/edit/save sequence, with the old `Data` content cleared by hand.
- Failure 1: the warning says elements the library "cannot process (such as charts, pivot tables)" are at risk, but it is ambiguous that the chart is dropped.
- Correctness 2: "will preserve existing data and formatting" conflicts with the chart warning.
- Completeness 1: there is no list of what is kept and what is lost, and no word on replacing a sheet's contents.
- Clarity 2: the warning is confusingly worded.

### 13 Labels
Code (by hand, no label support):
```julia
XLSX.writetable("out.xlsx", columns_with_value_labels_applied_by_hand, variable_labels)
```
Scores: [1, 1, 0, 0, 0, 0]
- Ergonomics 1: there is no label concept, so the user maps labels manually.
- Failure 1: nothing is documented.
- Findability, correctness, completeness, clarity 0: the task is not covered.

---

```json
{"A": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,3,3,3,2,3]},
 "B": {"1": [3,1,3,3,2,3], "2": [3,1,3,3,2,2], "3": [2,1,2,3,2,2], "4": [1,1,1,2,1,2], "5": [1,1,1,2,1,1], "6": [1,1,1,2,1,2], "7": [1,1,1,2,1,2], "8": [1,1,1,2,1,2], "9": [3,2,3,3,2,3], "10": [1,1,2,3,2,3], "11": [1,1,2,3,2,2], "12": [1,1,3,2,1,2], "13": [1,1,0,0,0,0]}}
```
