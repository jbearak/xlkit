# Review

Scores are in the order ergonomics, failure behavior, findability, correctness, completeness, clarity. Code assumes the relevant library and table packages are attached. The examples use the stated input files and tables; sheet names or column positions left unspecified by the scenario are illustrative.

## Library A

### 1. Install — [3, 1, 3, 3, 2, 2]

```julia
using Pkg
Pkg.add("LibraryA")
```

Failure 1: the documentation does not specify the missing-requirement failure message. Completeness 2: it gives Julia versions, platforms and an issue link, but no build-failure diagnosis. Clarity 2: the basic command is clear, but the failure path has no worked example.

### 2. Read a sheet — [3, 1, 2, 3, 2, 2]

```julia
df = XLSX.readto("report.xlsx", DataFrame)
```

The documented inference gives typed columns: integers, strings, floating-point numbers, booleans and dates according to the cells and their formats. Failure 1: the missing-path message is not documented. Findability 2: the tabular-read example is in the tutorial, beyond the front page. Completeness 2: type inference is described, but the missing-file case is not. Clarity 2: the example gives output, but the full type rules must be assembled from separate references.

### 3. Choose what to read — [1, 1, 2, 3, 2, 2]

```julia
names = XLSX.sheetnames(XLSX.readxlsx("report.xlsx"))
df = XLSX.readto("report.xlsx", "Sales 2024", "B:F", DataFrame;
                 first_row=5, stop_in_row_function=r -> XLSX.row_number(r) > 35)
```

The stop predicate is table-relative: with a header at row 5, data rows 6–40 are positions 1–35; verify the iterator's relative numbering when adapting it. Ergonomics 1: listing sheets takes multiple calls and limiting the end row requires an indirect predicate. Failure 1: no misspelled-sheet diagnostic is specified. Findability 2: sheet listing and table bounds are in separate tutorial/reference material. Completeness 2: the building blocks are described, but not this exact bounded range as a table. Clarity 2: the row-relative stopping rule requires interpretation.

### 4. Header and names — [1, 1, 2, 2, 1, 2]

```julia
f = XLSX.opentemplate("report.xlsx"); s = f["Headers"]
raw = s["A1:E1"]
df = XLSX.readto("report.xlsx", "Headers", "A:E", DataFrame;
                 column_labels=[:region, :total_b, :total_c, :d, :share])
t = f["Two-row header"]; group = XLSX.getMergedBaseCell(t, "C4"); subheaders = t["B5:D5"]
```

Keep `raw`, `group` and `subheaders` alongside the chosen names to retain provenance; adapt the explicit names and ranges to the actual workbook. Ergonomics 1: this needs manual naming and separate reads for merged headers. Failure 1: the table reader's duplicate/blank-header diagnostic is not specified. Findability 2: header options and merged-cell guidance are in different locations. Correctness 2: the merged-cell reference says write mode is required while its own example uses `readxlsx`. Completeness 1: the pieces are present, but automatic provenance and a two-row-header recipe are absent. Clarity 2: the reader must combine examples and resolve that mode contradiction.

### 5. Column types — [1, 1, 2, 3, 1, 2]

```julia
df = XLSX.readto("report.xlsx", DataFrame; infer_eltypes=false)
zip_text = [ismissing(x) ? missing : string(x) for x in df.zip]
parsed = [ismissing(x) ? missing : x isa Number ? Float64(x) : tryparse(Float64, x) for x in df.amount]
bad_rows = [i + 1 for i in eachindex(parsed) if parsed[i] === nothing]
```

Replace `nothing` in `parsed` with `missing` after recording `bad_rows`. Numeric zip cells have already lost any leading zeros not represented by their formatting; explicit padding requires knowing the code width. Ergonomics 1: conversion and location tracking are manual. Failure 1: there is no documented typed-read conversion diagnostic for the two cells. Findability 2: inference is discussed in the table reference, not a dedicated conversion guide. Completeness 1: it covers inferred types, but not requested coercion, mixed zip formatting or a conversion-problems report. Clarity 2: the basic inference option is understandable but leaves the user to devise conversion.

### 6. Dates and times — [1, 1, 2, 3, 1, 2]

```julia
df = XLSX.readto("dates.xlsx", DataFrame)
df1904 = XLSX.readto("dates1904.xlsx", DataFrame)
f = XLSX.readxlsx("dates.xlsx"); raw = [XLSX.getcell(f[1], XLSX.CellRef(r,c)).value for r in 2:4, c in 1:3]
```

The raw cell values are the internal stored representations and need numeric parsing; adapt the range to the sheet. Ergonomics 1: retrieving raw numbers requires cell-level work. Failure 1: the behavior for a stray `unknown` is not specified. Findability 2: type handling and internal-cell access are in the tutorial and reference. Completeness 1: the supplied documentation does not explain the 1904 system or provide a raw-number table recipe. Clarity 2: dates are tied to formatting, but the complete workflow is not demonstrated.

### 7. Missing values and errors — [1, 1, 2, 3, 2, 2]

```julia
f = XLSX.readxlsx("report.xlsx"); s = f[1]
df = DataFrame(XLSX.gettable(s; missing_strings=["NA", ".", "-"], stop_in_empty_row=false, keep_empty_rows=true))
errors = XLSX.geterror(s, "A1:Z100")
```

Use the actual sheet bounds for the error scan. Ergonomics 1: reading the table and inspecting errors requires several calls. Failure 1: the supplied docs describe error inspection but do not state what table reading does with error cells or whether it warns. Findability 2: missing-string and error APIs are in separate references. Completeness 2: blank and string handling and error inspection are covered, but the table-read result for errors is not explicit. Clarity 2: the reader must combine the pieces.

### 8. Every sheet — [1, 1, 2, 3, 1, 2]

```julia
f = XLSX.readxlsx("report.xlsx")
tables = Dict(n => DataFrame(XLSX.gettable(f[n])) for n in XLSX.sheetnames(f))
```

Ergonomics 1: this iterates and reads each sheet separately. Failure 1: the documentation does not say what `gettable` returns for an empty worksheet. Findability 2: sheet listing and table reading appear in the tutorial, but not as an all-sheets recipe. Completeness 1: the primitives are documented, not the empty-sheet case. Clarity 2: combining those primitives requires some work.

### 9. Write a table — [3, 2, 2, 3, 2, 2]

```julia
XLSX.writetable("out.xlsx", df)
```

Numbers, strings, booleans, dates and date-times use their supported cell types; missing values become blanks. Other column types are converted to strings, which includes categorical values unless converted first. Failure 2: writing fails if the file exists, but the precise message is not documented. Findability 2: writing guidance is in the tutorial. Completeness 2: types and overwrite are covered, but categorical behavior is only inferable from the general conversion rule. Clarity 2: the examples do not show the entire mixed-type result in Excel.

### 10. Write several tables — [1, 1, 2, 3, 2, 2]

```julia
XLSX.writetable("three.xlsx", "First" => a, "Second" => b, "Third" => c)
XLSX.openxlsx("stacked.xlsx", mode="w") do f
    s = f[1]; s["A1"] = "First"; XLSX.writetable!(s, a; anchor_cell=XLSX.CellRef("A2"))
    r = size(a, 1) + 5; s["A$r"] = "Second"; XLSX.writetable!(s, b; anchor_cell=XLSX.CellRef("A$(r+1)"))
end
```

Ergonomics 1: the stacked case needs a workbook, several writes and a calculated anchor. Failure 1: the slash-in-sheet-name message is not given. Findability 2: multi-sheet and anchored writes are in the tutorial. Completeness 2: both primitives are shown, but the combined stacking and invalid-name cases are not. Clarity 2: the user must calculate placement from the table height.

### 11. Format the output — [1, 1, 2, 2, 1, 2]

```julia
f = XLSX.newxlsx(); s = f[1]; XLSX.writetable!(s, df; as_table=true)
XLSX.setFont(s, 1, 1:size(df,2); bold=true)
XLSX.setFormat(s, 2:size(df,1)+1, findfirst(==("share"), names(df)); format="0.0%")
XLSX.setFormat(s, 2:size(df,1)+1, findfirst(==("amount"), names(df)); format="#,##0")
XLSX.freezePanes(s); XLSX.writexlsx("out.xlsx", f)
```

The native Excel Table supplies filters. Widths must be calculated from displayed contents and set per column with `setColumnWidth`; no automatic fit is documented, so this is a partial implementation. Ergonomics 1: formatting requires many calls and manual width work. Failure 1: a missing column name is handled by the user's lookup, with no documented library diagnostic. Findability 2: formatting, panes, widths and tables are separate topics. Correctness 2: the width reference contains a misspelled `seColumnWidth` example. Completeness 1: the pieces are covered, but fitting contents and the named-column probe are not. Clarity 2: combining the separate features takes work.

### 12. Fill an existing workbook — [1, 1, 2, 3, 1, 2]

```julia
f = XLSX.opentemplate("results.xlsx"); d = f["Data"]
d[:] = missing  # clear the existing populated extent; retain the sheet
XLSX.writetable!(d, new_data)
f["Cover"]["C4"] = 1250; f["Cover"]["C5"] = Date(2024,12,31)
XLSX.writexlsx("results-filled.xlsx", f)
```

This is a best-effort cell replacement; inspect template-specific objects and chart references before relying on the result. Ergonomics 1: opening, clearing, writing cells and saving are separate operations. Failure 1: the documentation cautions about charts but does not guarantee this chart survives unchanged. Findability 2: template editing is in the tutorial and reference. Completeness 1: it describes preserving existing data and formatting but does not give a complete chart-preservation contract or replacement recipe. Clarity 2: the warning leaves the chart outcome uncertain.

### 13. Labels — [0, 1, 0, 0, 0, 0]

No documented Library A operation handles Stata variable and value labels or preserves long headers as variable labels. A user would need to extract and transform metadata with other tooling and write ordinary cells; no such interoperable workflow is specified here. Failure 1: behavior for an unlabelled code is not documented. The documentation scores are 0 because the label task is not covered.

## Library B

### 1. Install — [2, 3, 3, 3, 3, 3]

```r
install.packages("remotes")
remotes::install_github("Library B")
```

Ergonomics 2: a fresh machine needs two installation calls.

### 2. Read a sheet — [3, 3, 3, 3, 3, 3]

```r
scores <- read_xlsx("report.xlsx")
```

The documented result is a tibble with integer, character, double, logical and `Date` columns respectively.

### 3. Choose what to read — [3, 3, 3, 3, 3, 3]

```r
xlsx_sheets("report.xlsx")
sales <- read_xlsx("report.xlsx", sheet = "Sales 2024", range = "B5:F40")
```

Each separately scored part takes one direct call.

### 4. Header and names — [3, 3, 3, 3, 3, 3]

```r
one <- read_xlsx("report.xlsx", sheet = "Headers", names = "snake")
two <- read_xlsx("report.xlsx", sheet = "Two-row header", header = 4:5)
```

Repairs are reported, and changed header text is kept as column `label` attributes.

### 5. Column types — [2, 3, 3, 3, 3, 3]

```r
df <- read_xlsx("report.xlsx", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```

Ergonomics 2: the read and the full problems report take two calls. Numeric zip values retain displayed zero padding only when the workbook's format supplies it; otherwise known-width padding is needed.

### 6. Dates and times — [3, 3, 3, 3, 3, 3]

```r
dates <- read_xlsx("dates.xlsx")
dates1904 <- read_xlsx("dates1904.xlsx")
raw <- read_xlsx("dates.xlsx", dates = FALSE)
raw1904 <- read_xlsx("dates1904.xlsx", dates = FALSE)
```

Each workbook and representation is one direct call; the workbook date system is respected.

### 7. Missing values and errors — [2, 3, 3, 3, 3, 3]

```r
df <- read_xlsx("report.xlsx", na = c("NA", ".", "-"))
xlsx_problems(df)
```

Ergonomics 2: distinguishing errors from blanks takes a second call.

### 8. Every sheet — [3, 3, 3, 3, 3, 3]

```r
all <- read_sheets("report.xlsx")
```

### 9. Write a table — [3, 3, 3, 3, 3, 3]

```r
write_xlsx(df, "out.xlsx")
```

The type mapping, blank `NA` cells and refusal to overwrite by default are documented.

### 10. Write several tables — [3, 3, 3, 3, 3, 3]

```r
write_xlsx(list(First = a, Second = b, Third = c), "three.xlsx")
write_xlsx(list(Results = list("First" = a, "Second" = b)), "stacked.xlsx", gap = 2)
```

Each part takes one call; `gap = 2` leaves two blank rows between tables.

### 11. Format the output — [3, 3, 3, 2, 3, 3]

```r
write_xlsx(df, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```

Correctness 2: the reference's multi-sheet example applies `share`, `amount`, and `region` to sheets whose selected columns need not contain all of them, despite saying format and style names must match each table; it needs adjustment. The guide's single-table example is direct.

### 12. Fill an existing workbook — [2, 3, 3, 3, 3, 3]

```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```

Ergonomics 2: the replacement and cell updates require two calls. The documentation distinguishes cleared Data-cell formats from the preserved chart and other workbook content, and explains fixed chart ranges.

### 13. Labels — [2, 3, 3, 3, 2, 3]

```r
write_xlsx(df, "survey.xlsx", header = "labels")
df2 <- read_xlsx("survey.xlsx", names = "stata")
```

Ergonomics 2: producing the labelled output and reading another sheet are separate calls; checking attributes takes further language calls. Completeness 2: the guide explains labels and name rules, but `snake` alone does not promise a short name for an arbitrarily long header; `stata` supplies a 32-character limit.

```json
{"B":{"1":[2,3,3,3,3,3],"2":[3,3,3,3,3,3],"3":[3,3,3,3,3,3],"4":[3,3,3,3,3,3],"5":[2,3,3,3,3,3],"6":[3,3,3,3,3,3],"7":[2,3,3,3,3,3],"8":[3,3,3,3,3,3],"9":[3,3,3,3,3,3],"10":[3,3,3,3,3,3],"11":[3,3,3,2,3,3],"12":[2,3,3,3,3,3],"13":[2,3,3,3,2,3]},"A":{"1":[3,1,3,3,2,2],"2":[3,1,2,3,2,2],"3":[1,1,2,3,2,2],"4":[1,1,2,2,1,2],"5":[1,1,2,3,1,2],"6":[1,1,2,3,1,2],"7":[1,1,2,3,2,2],"8":[1,1,2,3,1,2],"9":[3,2,2,3,2,2],"10":[1,1,2,3,2,2],"11":[1,1,2,2,1,2],"12":[1,1,2,3,1,2],"13":[0,1,0,0,0,0]}}
```
