# Judgement: Library A (Julia) and Library B (R), round 1

Score order: [ergonomics, failure, findability, correctness, completeness, clarity].

Notes on method:
- I used only the text in julia.md.
- Library A has no pointer from the front page (README/index) to its tutorial, so I scored findability 2 where a tutorial heading names the task. I scored 1 where the answer is only in a docstring or implied, and 3 only for install.
- Library B's README has a task-to-section table, so most of its findability scores are 3.
- Where a Library A docstring does not say what happens, I scored the failure probe 1.
- Library B's `install_github("Library B")` and `library(Library B)` contain the placeholder name. I treated that as an anonymisation artifact, not a doc error.

---

# LIBRARY A (Julia)

## Task 1 Install
Code:
```julia
using Pkg; Pkg.add("XLSX")
```
Scores: [3, 1, 3, 3, 2, 3]
- Failure 1: the docs say nothing about a failed install or a missing system requirement.
- Completeness 2: the command, Julia version (1.10+) and platforms are given. System requirements and what to do when install fails are missing.

## Task 2 Read a sheet
Code:
```julia
using DataFrames; df = XLSX.readto("report.xlsx", DataFrame)   # first sheet by default
```
Scores: [3, 1, 2, 3, 2, 3]
- Failure 1: the docs do not say what happens when the file does not exist.
- Findability 2: "Read Tabular Data" is a tutorial heading, but the front page does not point to it and the tutorial page is long.
- Completeness 2: the example shows Int64 and String columns, and `getdata` says dates become `Date`. There is no per-type table covering Bool, Float64, Date and missing.

## Task 3 Choose what to read
Code:
```julia
df = XLSX.readto("sales.xlsx", "Sales 2024", "B:F", DataFrame; first_row=5)
XLSX.sheetnames(XLSX.readxlsx("sales.xlsx"))
```
Scores: [2, 1, 2, 3, 2, 2]
- Ergonomics 2: the table read is one call (`first_row=5` is an Excel row number, columns `B:F`). Listing sheet names takes two calls (`readxlsx`, then `sheetnames`). I did not find a way to give `B5:F40` as a single range for a table read.
- Failure 1: nothing says what a misspelled sheet name does.
- Findability 2: the answer is spread across the long tutorial and the `readtable` docstring.
- Completeness 2: a title above the table and a fixed end row are not shown as a recipe. The table ends at the first empty row (`stop_in_empty_row`).
- Clarity 2: `first_row` and `columns` are explained only in a docstring, and no example combines them.

## Task 4 Header and names
Code:
```julia
df = DataFrame(XLSX.readtable("f.xlsx", "Headers"; normalizenames=true))
# two-row header: read from the second header row with column_labels built by hand,
# or use getMergedCells / getMergedBaseCell to find the group names
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: nothing handles a two-row or merged header. The user must build the labels from several calls. Blank and duplicate header cells have no documented default.
- Failure 1: the docs do not say what happens with two `Total` cells or a blank cell.
- Findability 1: `header`, `column_labels` and `normalizenames` appear only in docstrings.
- Correctness 2: what is said is right, but `column_labels` is "Vector{Symbol}" in one docstring and "Symbols or strings" in another. Nothing covers `%` or duplicates.
- Completeness 1: normalizing is described, but duplicates, blanks, merged group headers and which header text each name came from are not.
- Clarity 2: the options are described in plain words, with no example of the result.

## Task 5 Column types
Code (manual):
```julia
dt = XLSX.readtable("f.xlsx", "Types"; missing_strings=["n/a"])
# no `types` argument: convert zip and amount by hand (string.(), tryparse.()) and collect the failures yourself
```
Scores: [1, 1, 1, 1, 1, 1]
- Ergonomics 1: there is no way to force a column to text or number. A numeric `zip` loses its leading zero. A mixed `amount` column comes back mixed.
- Failure 1: the docs do not say what happens to cells that cannot convert, and give no way to list them.
- Findability 1: only `infer_eltypes` and `missing_strings` in docstrings.
- Correctness 1: the statements are true, but they barely cover the task and could lead a user to expect a text column.
- Completeness 1: only automatic inference is covered.
- Clarity 1: "typed vectors" is not explained for mixed columns, and no example is given.

## Task 6 Dates and times
Code:
```julia
df = XLSX.readto("d.xlsx", DataFrame)                    # Date / DateTime / Time chosen from the cell style
c  = XLSX.getcell(XLSX.readxlsx("d.xlsx")[1], "A2")      # raw stored value via c.value, parsed by hand
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: reading as dates is one call. Reading the stored numbers has no option and needs `getcell` plus manual parsing.
- Failure 1: nothing is said about a text cell such as `unknown` in a date column.
- Findability 1: only the `getdata` docstring says dates are picked by cell style.
- Correctness 2: what is said is right, but the 1904 date system is not mentioned.
- Completeness 1: 1904 workbooks and reading the stored numbers are not covered.
- Clarity 2: the `getdata` explanation is plain, with no example.

## Task 7 Missing values and errors
Code:
```julia
df = DataFrame(XLSX.readtable("m.xlsx", "Missing"; missing_strings=["NA", ".", "-"]))
sh = XLSX.readxlsx("m.xlsx")["Missing"]; XLSX.iserror(sh, "D2:D20"); XLSX.geterror(sh, "D2:D20")
```
Scores: [1, 1, 1, 3, 2, 2]
- Ergonomics 1: `missing_strings` is one call. Telling errors from blanks needs the workbook, the sheet and `iserror` or `geterror`. The docs do not say whether `readtable` turns error cells into `missing`.
- Failure 1: nothing is said about what `readtable` does with `#N/A` and `#DIV/0!` in a numeric column.
- Findability 1: `missing_strings`, `iserror` and `geterror` appear only in function reference entries.
- Completeness 2: both halves exist, but the link between error cells and a table read is missing.
- Clarity 2: the `iserror` and `geterror` examples are good, but there is no end-to-end example.

## Task 8 Every sheet
Code:
```julia
xf = XLSX.readxlsx("w.xlsx")
tabs = Dict(n => DataFrame(XLSX.gettable(xf[n])) for n in XLSX.sheetnames(xf))
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: there is no read-all function, so the user loops, with several calls per sheet.
- Failure 1: the docs do not say what an empty sheet gives. The example workbook lists an `empty` sheet, but not how `gettable` treats it.
- Findability 1: only implied by the `sheetnames` and `gettable` examples.
- Correctness 2: the pieces are right, but nothing assembles them.
- Completeness 1: main pieces only, with no empty-sheet or chartsheet handling.
- Clarity 2: each piece has an example, but not the whole task.

## Task 9 Write a table
Code:
```julia
XLSX.writetable("out.xlsx", df)       # fails if out.xlsx exists, unless overwrite=true
```
Scores: [3, 2, 2, 3, 2, 3]
- Failure 2: the docs say writing fails unless `overwrite=true`. The error text is not shown, so I cannot confirm it says what to do.
- Findability 2: the heading "Export Tabular Data from any Tables.jl compatible source" is there, but it is not reachable from the front page.
- Completeness 2: the types written natively are listed, and anything else becomes a string, which covers categorical. What each column looks like in Excel (date formats, logicals) is not spelled out.

## Task 10 Write several tables
Code:
```julia
XLSX.writetable("report.xlsx", "Sheet A" => df1, "Sheet B" => df2, "Sheet C" => df3)
XLSX.openxlsx("r.xlsx", mode="w") do xf
    s = xf[1]
    s["A1"] = "Table 1"; XLSX.writetable!(s, df1; anchor_cell=XLSX.CellRef("A2"))
    s["A" * string(r2)] = "Table 2"; XLSX.writetable!(s, df2; anchor_cell=XLSX.CellRef("A" * string(r2 + 1)))
end
```
Scores: [1, 1, 2, 2, 2, 2]
- Ergonomics 1: the three-sheet part is one call (score 3). The titled tables on one sheet need an open file, hand-computed row numbers and several calls (score 1). The lowest applies.
- Failure 1: the docs do not mention a sheet name containing `/`.
- Findability 2: the multi-table text is inside the long export section, and nothing mentions stacking tables on one sheet.
- Correctness 2: one example uses `DataFrame` with no import, and a later one calls `writexlsx` without `XLSX.`.
- Completeness 2: separate sheets are well covered, but titled tables on one sheet are not covered beyond `anchor_cell`.
- Clarity 2: the many call forms (keywords, tuples, vector of tuples, pairs) need rereading.

## Task 11 Format the output
Code:
```julia
XLSX.openxlsx("s.xlsx", mode="w") do xf
    s = xf[1]; XLSX.writetable!(s, df; as_table=true)       # an Excel Table carries the filter buttons
    XLSX.setFont(s, "A1:F1"; bold=true)
    XLSX.setFormat(s, "C2:C100"; format="0.0%")
    XLSX.setFormat(s, "D2:D100"; format="#,##0")
    XLSX.setColumnWidth(s, "A:F"; width=15)                 # fixed width only
    XLSX.freezePanes(s)
end
```
Scores: [1, 1, 2, 2, 2, 3]
- Ergonomics 1: this takes many calls, formats go by cell range not column name, and there is no fit-to-contents.
- Failure 1: formats are not applied by column name. The docs do not say what `setFormat` does on an empty range, though the other `set*` functions skip empty cells quietly.
- Findability 2: separate pages for formats, widths and panes, with nothing linking them for this task. Filter buttons are only mentioned under Excel Tables.
- Correctness 2: small errors. `XLSX.seColumnWidth` is a typo in a docstring example, and the `setRowHeight` example uses `"I"` although the text says a row or cell reference is needed.
- Completeness 2: bold, number formats and freezing are covered. Auto-fit is not available and the docs do not say so.

## Task 12 Fill an existing workbook
Code:
```julia
xf = XLSX.opentemplate("results.xlsx")
XLSX.writetable!(xf["Data"], newdf)          # does not clear old cells beyond the new table
xf["Cover"]["C4"] = 1250; xf["Cover"]["C5"] = Date(2024,12,31)
XLSX.writexlsx("out.xlsx", xf; overwrite=true)
```
Scores: [1, 1, 2, 2, 1, 2]
- Ergonomics 1: several calls, and clearing the old Data cells is the user's job.
- Failure 1: the docs warn that charts are among the elements Library A "cannot process" and may be lost when a file is overwritten. They never say plainly what happens to the `Chart` sheet. Elsewhere the colour docs mention charts, which adds to the confusion.
- Findability 2: the "Edit Existing Files" heading and its warning sit in the long tutorial.
- Correctness 2: the statements are right, but the chart wording is contradictory.
- Completeness 1: "preserve existing data and formatting" is stated, but there is no list of what is kept or lost, and nothing on replacing a sheet's contents.
- Clarity 2: the warning is clear, but what is lost is left vague.

## Task 13 Labels
Code (manual):
```julia
df.sex = ifelse.(df.sex .== 1, "Male", "Female")
XLSX.writetable("o.xlsx", collect(eachcol(df)), varlabels)       # labels as header names
dt = XLSX.readtable("s.xlsx", "S"; column_labels=short)           # long headers kept only if you save them yourself
```
Scores: [1, 1, 0, 0, 0, 0]
- Ergonomics 1: no label concept, so the user recodes and maps by hand with several calls.
- Failure 1: nothing is said about a code with no value label.
- Findability 0, correctness 0, completeness 0 and clarity 0: the task is not covered.

---

# LIBRARY B (R)

## Task 1 Install
Code:
```r
install.packages("remotes"); remotes::install_github("Library B")
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls on a fresh machine, and Rust must be installed first.
- Failure 3: the docs name the `building needs cargo` message and say to restart R and check `Sys.which("cargo")`. Other build errors go to an issue with the output and `sessionInfo()`.

## Task 2 Read a sheet
Code:
```r
scores <- read_xlsx("report.xlsx")
```
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs do not say what happens when the file does not exist.

## Task 3 Choose what to read
Code:
```r
sales <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets("sales.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

## Task 4 Header and names
Code:
```r
read_xlsx(p, sheet = "Headers", names = "snake")
read_xlsx(p, sheet = "Two-row header", header = 4:5)
```
Scores: [3, 3, 3, 3, 3, 3]
- Failure 3: no message is given. Duplicates become `Total`, `Total_C` and a blank becomes `D`, and the original header text is kept as the `label` attribute. That is the right handling, and the docs state it.

## Task 5 Column types
Code:
```r
df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]
- The warning names the cells (`C2003 ("n/a")`, `C2004 ("12,5")`) and points to `xlsx_problems(df)`.

## Task 6 Dates and times
Code:
```r
read_xlsx("dates.xlsx")                                     # Date, POSIXct (UTC), hms; 1904 read from the workbook
read_xlsx("dates.xlsx", types = c(day = "number", clock = "number"))   # stored numbers
```
Scores: [3, 3, 3, 3, 3, 3]
- Failure 3: with `"date"`, other text becomes `NA` with a warning, and the Messages table gives `xlsx_problems()`. A guessed column with one text cell becomes character, and the docs say so.

## Task 7 Missing values and errors
Code:
```r
df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)      # lists the Excel errors (the warning already names them)
```
Scores: [3, 3, 3, 3, 3, 3]

## Task 8 Every sheet
Code:
```r
all <- read_sheets("w.xlsx")
```
Scores: [3, 1, 3, 3, 2, 3]
- Failure 1: the docs do not say what an empty sheet gives. Reading a chart sheet is an error, but the docs do not say whether `read_sheets` skips chart sheets.
- Completeness 2: the empty-sheet and chart-sheet cases are missing.

## Task 9 Write a table
Code:
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]
- Failure 3: the error names the other program, lists the sheets that would be lost, and offers `write_sheet()`, `write_cells()` or `replace = TRUE`.

## Task 10 Write several tables
Code:
```r
write_xlsx(list(A = a, B = b, C = c), "report.xlsx")
write_xlsx(list(Results = list("Table 1. Means" = means, "Table 2. Counts" = counts)), "results.xlsx", gap = 2)
```
Scores: [3, 2, 3, 3, 3, 3]
- Failure 2: the docs say Excel's limits "are errors that say which value broke them" and list `/` among the banned characters. The message text is not shown, so I cannot confirm it says what to do.

## Task 11 Format the output
Code:
```r
write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs say a bad key in `styles` stops with an error and a bad name in `types` stops with the column names. They say nothing about a `formats` name that is not in the table.

## Task 12 Fill an existing workbook
Code:
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls, one per part of the job. Each call is simple.
- Failure 3: the docs say charts and other untouched parts are copied as they were, and that the chart now plots the new data.

## Task 13 Labels
Code:
```r
write_xlsx(df, "survey.xlsx", header = "labels")          # values = "labels" is the default
df <- read_xlsx("survey.xlsx", names = "snake")           # long header kept in attr(, "label")
```
Scores: [3, 2, 3, 3, 3, 3]
- Failure 2: the docs say a code without a label is written as the code, with no warning naming the unlabelled codes.

---

```json
{"A": {"1": [3,1,3,3,2,3], "2": [3,1,2,3,2,3], "3": [2,1,2,3,2,2], "4": [1,1,1,2,1,2], "5": [1,1,1,1,1,1], "6": [1,1,1,2,1,2], "7": [1,1,1,3,2,2], "8": [1,1,1,2,1,2], "9": [3,2,2,3,2,3], "10": [1,1,2,2,2,2], "11": [1,1,2,2,2,3], "12": [1,1,2,2,1,2], "13": [1,1,0,0,0,0]},
 "B": {"1": [2,3,3,3,3,3], "2": [3,1,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,1,3,3,2,3], "9": [3,3,3,3,3,3], "10": [3,2,3,3,3,3], "11": [3,1,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,2,3,3,3,3]}}
```
