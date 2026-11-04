# Judgement: Library A (Julia) and Library B (R)

Score order is [ergonomics, failure, findability, correctness, completeness, clarity].

Library A's front page (README and docs index) has no links into the guide. For Library A I gave findability 3 when a guide heading names the task, 2 when the answer sits in a long page or in docstring options, and 1 when it is only implied.

---

## Library A (Julia)

### 1 Install
Code: `using Pkg; Pkg.add("LibraryA")`
Scores: 3, 1, 3, 3, 2, 3
- Failure 1: the docs do not say what to do if installation fails, or whether any system requirement exists.
- Completeness 2: the command, Julia 1.10+ and Linux/macOS/Windows are given. System requirements and install troubleshooting are not.

### 2 Read a sheet
Code: `df = XLSX.readto("report.xlsx", DataFrame)` (or `DataFrame(XLSX.readtable("report.xlsx", "Sheet1"))`)
Scores: 3, 1, 3, 3, 2, 3
- Failure 1: a missing file is not covered.
- Completeness 2: `infer_eltypes=true` gives typed columns, and the tutorial output shows Int64, String, Float64 and Date. There is no table saying which type each kind of column gets. `CellConcreteType` is only an unrendered `@docs` reference.

### 3 Choose what to read
Code:
```julia
df = XLSX.readto("sales.xlsx", "Sales 2024", "B:F", DataFrame; first_row=5)
XLSX.sheetnames(XLSX.readxlsx("sales.xlsx"))
```
Scores: 2, 1, 2, 3, 2, 2
- Ergonomics 2: reading is one call with `first_row=5`. Listing the names takes two calls (`readxlsx`, then `sheetnames`), and the task takes the lowest part.
- Failure 1: a misspelled sheet name is not covered.
- Findability 2: `first_row` and `columns` are in docstrings. There is no guide example for a title above the table.
- Completeness 2: no sheet-not-found behavior.
- Clarity 2: the options are scattered across docstrings.

### 4 Header and names
Code: `XLSX.readtable("f.xlsx", "S"; columns="A:E", column_labels=[...], normalizenames=true)`. For the two-row header: read the header cells with `getdata` and `getMergedBaseCell`, build the names, then `readtable(...; first_row=3, column_labels=...)`.
Scores: 1, 1, 1, 2, 1, 1
- Ergonomics 1: the header is inferred from contiguous non-empty cells, so a blank header cell cuts the table short. No handling of duplicates is documented, and the two-row header takes several manual calls.
- Failure 1: duplicate and blank headers are not covered.
- Findability 1: only docstring options (`column_labels`, `normalizenames`) and the merged-cells page.
- Correctness 2: nothing wrong, but it says nothing about `%` or duplicates.
- Completeness 1 and clarity 1: the task is largely not covered.

### 5 Column types
Code: `XLSX.readtable("f.xlsx", "S"; infer_eltypes=false)`, then convert `zip` and parse `amount` by hand.
Scores: 1, 1, 1, 2, 1, 1
- Ergonomics 1: there is no `types=` argument. Mixed columns come back as `Any`, so the user converts them manually.
- Failure 1: nothing says what happens to `n/a` or `12,5`. There is no report of unconverted cells.
- Findability 1, completeness 1 and clarity 1: the task is not covered. Only `infer_eltypes` and `missing_strings` exist, and the `infer_eltypes` docstring is muddled.
- Correctness 2: nothing false, little said.

### 6 Dates and times
Code: `XLSX.readto("f.xlsx", DataFrame)` gives Date, DateTime and Time. For stored numbers, read raw cells with `getcell(...).value` through `readxlsx`.
Scores: 1, 1, 1, 2, 1, 2
- Ergonomics 1: raw numbers need `getcell` loops.
- Failure 1: a stray `unknown` text cell is not covered.
- Findability 1: only the `getdata` docstring and the write/read round-trip example.
- Correctness 2: what is said is true.
- Completeness 1: the 1904 system and reading stored numbers are not covered.
- Clarity 2: the `getdata` explanation (style decides Date) is clear.

### 7 Missing values and errors
Code:
```julia
df = XLSX.readto("f.xlsx", "S", DataFrame; missing_strings=["NA", ".", "-"])
sh = XLSX.readxlsx("f.xlsx")["S"]
XLSX.iserror(sh, "C2:C100")
```
Scores: 1, 1, 1, 2, 2, 2
- Ergonomics 1: `missing_strings` is one call. Telling errors from blanks needs `readxlsx`, indexing and `iserror`.
- Failure 1: how `#N/A` and `#DIV/0!` read in a numeric column is not said.
- Findability 1: only in function reference entries (`iserror`, `geterror`, `missing_strings`).
- Correctness 2: nothing false, but whether error cells become missing is not stated.
- Completeness 2: the main tools exist, but `readtable`'s handling of errors is missing.
- Clarity 2: `iserror` and `geterror` examples are good. The link to the read step is missing.

### 8 Every sheet
Code:
```julia
xf = XLSX.readxlsx(f)
Dict(n => DataFrame(XLSX.readtable(f, n)) for n in XLSX.sheetnames(xf))
```
Scores: 1, 1, 1, 2, 1, 1
- Ergonomics 1: a manual loop of twelve `readtable` calls.
- Failure 1: an empty sheet is not covered.
- Findability 1 and completeness 1: there is no read-all-sheets recipe, only `sheetnames` and `readtable`.
- Correctness 2: nothing false.
- Clarity 1: not covered.

### 9 Write a table
Code: `XLSX.writetable("out.xlsx", df)`
Scores: 3, 2, 3, 3, 2, 3
- Failure 2: the docs say writing fails unless `overwrite=true`, but they do not show the message.
- Completeness 2: types outside the supported list become strings, and the list is given. How each column appears in Excel (date formats, categorical, missing) is not described.

### 10 Write several tables
Code:
```julia
XLSX.writetable("report.xlsx", "Summary" => a, "Detail" => b, "Notes" => c)
XLSX.openxlsx("t.xlsx", mode="w") do xf
    s = xf[1]; s["A1"] = "Table 1"
    XLSX.writetable!(s, t1; anchor_cell=XLSX.CellRef("A2"))
    s["A9"] = "Table 2"
    XLSX.writetable!(s, t2; anchor_cell=XLSX.CellRef("A10"))
end
```
Scores: 1, 1, 2, 3, 2, 2
- Ergonomics 1: three sheets take one call. Two titled tables on one sheet take several calls and manual row arithmetic.
- Failure 1: a `/` in a sheet name is not covered.
- Findability 2: the multi-sheet part is easy to find, but stacking tables is not named.
- Completeness 2: titles and spacing are not shown, only `anchor_cell`.
- Clarity 2: the multi-sheet forms are dense, and the examples do not show their results.

### 11 Format the output
Code:
```julia
XLSX.openxlsx("o.xlsx", mode="w") do xf
    s = xf[1]; XLSX.writetable!(s, df)
    XLSX.setFont(s, "A1:G1"; bold=true)
    XLSX.setFormat(s, "C2:C101"; format="0.0%")
    XLSX.setFormat(s, "D2:D101"; format="#,##0")
    XLSX.setColumnWidth(s, "A:G"; width=15)
    XLSX.freezePanes(s)
end
```
Scores: 1, 1, 2, 2, 2, 3
- Ergonomics 1: many calls on cell ranges, and no auto-fit.
- Failure 1: formats go by cell range, not column name. A bad range is not covered.
- Findability 2: the formatting pages exist. Auto-fit and filter buttons are not found.
- Correctness 2: small errors, such as the `seColumnWidth` typo and `setRowHeight(sh, "I")`.
- Completeness 2: no auto-fit width and no filter buttons (apart from the Excel Table `as_table` option).
- Clarity 3: the examples are good.

### 12 Fill an existing workbook
Code:
```julia
XLSX.openxlsx("results.xlsx", mode="rw") do xf
    XLSX.writetable!(xf["Data"], df)
    xf["Cover"]["C4"] = 1250
    xf["Cover"]["C5"] = Date(2024,12,31)
end
```
Scores: 1, 1, 3, 2, 1, 2
- Ergonomics 1: many calls. Clearing the old Data cells first is not shown.
- Failure 1: the docs only warn that elements it cannot process (charts, pivot tables) may not survive an `rw` overwrite. They do not say definitively what happens to the chart.
- Correctness 2: the warning conflicts with the mentions of chart support elsewhere.
- Completeness 1: there is no clear list of what is kept and lost, and nothing on clearing a sheet or on date formats in a cell.
- Clarity 2: the warning is convoluted.

### 13 Labels
Code: not possible with the library's documented functions.
Scores: 0, 1, 0, 0, 0, 0
- Ergonomics 0: no variable or value label support.
- Failure 1: the docs do not say what happens.
- Docs 0: not covered.

---

## Library B (R)

### 1 Install
Code: `install.packages("remotes"); remotes::install_github("Library B")`
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: two calls, and a Rust toolchain is needed because the package is not on CRAN.

### 2 Read a sheet
Code: `read_xlsx("report.xlsx")`
Scores: 3, 3, 3, 3, 3, 3

### 3 Choose what to read
Code:
```r
read_xlsx(path, sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets(path)
```
Scores: 3, 3, 3, 3, 3, 3

### 4 Header and names
Code:
```r
read_xlsx(path, sheet = "Headers", names = "snake")
read_xlsx(path, sheet = "Two-row header", header = 4:5)
```
Scores: 3, 3, 3, 3, 3, 3

### 5 Column types
Code: `df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number"))`, then `xlsx_problems(df)`
Scores: 3, 3, 3, 3, 3, 3

### 6 Dates and times
Code:
```r
read_xlsx(xlkit_example("dates.xlsx"))
read_xlsx(path, dates = FALSE)
```
Scores: 3, 3, 3, 3, 3, 3

### 7 Missing values and errors
Code: `df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-")); xlsx_problems(df)`
Scores: 3, 3, 3, 3, 3, 3

### 8 Every sheet
Code: `read_sheets(path)`
Scores: 3, 3, 3, 3, 3, 3

### 9 Write a table
Code: `write_xlsx(df, "out.xlsx")`
Scores: 3, 3, 3, 3, 3, 3

### 10 Write several tables
Code:
```r
write_xlsx(list(A = a, B = b, C = c), "report.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "t.xlsx", gap = 2)
```
Scores: 3, 3, 3, 3, 3, 2
- Clarity 2: the guide says "one blank row between them (`gap = 2` for two)". "Second table two rows below" could mean two blank rows or a two-row offset, and the guide does not tie the wording to the scenario.

### 11 Format the output
Code: `write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)`
Scores: 3, 3, 3, 3, 3, 3

### 12 Fill an existing workbook
Code:
```r
write_sheet(new_data, path, sheet = "Data")
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: 2, 3, 3, 3, 3, 3
- Ergonomics 2: two calls.

### 13 Labels
Code:
```r
write_xlsx(df, "survey.xlsx", header = "labels")
read_xlsx("survey.xlsx", names = "snake")
```
Scores: 3, 3, 3, 3, 3, 3

---

```json
{"A": {"1": [3,1,3,3,2,3], "2": [3,1,3,3,2,3], "3": [2,1,2,3,2,2], "4": [1,1,1,2,1,1], "5": [1,1,1,2,1,1], "6": [1,1,1,2,1,2], "7": [1,1,1,2,2,2], "8": [1,1,1,2,1,1], "9": [3,2,3,3,2,3], "10": [1,1,2,3,2,2], "11": [1,1,2,2,2,3], "12": [1,1,3,2,1,2], "13": [0,1,0,0,0,0]},
 "B": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,2], "11": [3,3,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,3,3,3,3,3]}}
```
