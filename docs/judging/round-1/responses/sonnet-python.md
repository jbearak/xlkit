# Round 1 judging: python.md

Score order everywhere: [ergonomics, failure, findability, correctness, completeness, clarity].

Basis: only the text in python.md. Library A is the R package. B is a DataFrame library that reads through an external engine and writes through a writer library. C is a DataFrame library with read_excel and to_excel. D is a cell-level workbook library with no table reader. Task 13 is Stata-specific and no library except A addresses it. For Stata I score A only, but B, C and D get a row as instructed.

Convention for unsupported tasks (B 12, 13; C 13; D 13): ergonomics 0 when the docs show no way to do it. Failure 1 because the docs do not say what happens. Docs scores 0.

---

## Library A (R)

### 1 Install
```r
install.packages("remotes"); remotes::install_github("Library A")
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls (remotes, then install), and a Rust toolchain must be installed first.

### 2 Read a sheet
```r
scores <- read_xlsx("report.xlsx")
```
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs never say what happens when the path does not exist, and the Messages table has no row for it.

### 3 Choose what to read
```r
sales <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets("sales.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

### 4 Header and names
```r
read_xlsx(p, sheet = "Headers", names = "snake")
read_xlsx(p, sheet = "Two-row header", header = 4:5)
```
Scores: [3, 3, 3, 3, 3, 3]

### 5 Column types
```r
df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]

### 6 Dates and times
```r
read_xlsx("dates.xlsx"); read_xlsx("dates1904.xlsx")
read_xlsx("dates.xlsx", types = c(day = "number", clock = "number"))
```
Scores: [3, 3, 3, 3, 3, 3]

### 7 Missing values and errors
```r
df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores: [3, 3, 3, 3, 3, 3]

### 8 Every sheet
```r
all <- read_sheets("book.xlsx")
```
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs do not say how an empty sheet is read.

### 9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3, 3, 3, 3, 3, 3]

### 10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "book.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "results.xlsx", gap = 2)
```
Scores: [3, 2, 3, 3, 3, 3]
- Failure 2: the docs say a sheet name holding `/` is an error that says which value broke the limit, but they show no message text and give no fix.

### 11 Format the output
```r
write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3, 1, 3, 3, 3, 3]
- Failure 1: the docs describe errors for unknown keys in `styles` and `types`, but not for an unknown column in `formats`.

### 12 Fill an existing workbook
```r
write_sheet(new_data, path, sheet = "Data")
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [2, 3, 3, 3, 3, 3]
- Ergonomics 2: two calls are needed.

### 13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")
df <- read_xlsx("survey.xlsx", names = "snake")
```
Scores: [3, 2, 3, 3, 3, 3]
- Failure 2: the docs say a code with no label is written as the raw code, a sensible rule, but nothing warns that a code was unlabelled.

---

## Library B (DataFrame library, reads via an engine, writes via a writer)

### 1 Install
```python
pip install Library B fastexcel xlsxwriter
```
Scores: [2, 1, 3, 3, 2, 3]
- Ergonomics 2: the base install does not read or write Excel; the Excel guide needs separate engine and writer packages.
- Failure 1: the docs do not say what to do when a build or install fails for a missing system requirement.
- Completeness 2: supported platforms, Python versions and system requirements are not stated in the pages given.

### 2 Read a sheet
```python
df = pl.read_excel("report.xlsx")
```
Scores: [3, 1, 2, 3, 1, 2]
- Failure 1: the docs do not say what happens for a missing file.
- Findability 2: the README links only to the general user guide; the Excel page must be found there.
- Completeness 1: the docs do not say which type each column gets. They mention only `infer_schema_length` and `schema_overrides`.
- Clarity 2: the example is a bare call, with no result described.

### 3 Choose what to read
```python
df = pl.read_excel("sales.xlsx", sheet_name="Sales 2024",
                   read_options={"header_row": 4, "use_columns": "B:F", "n_rows": 35})
fastexcel.read_excel("sales.xlsx").sheet_names
```
Scores: [2, 1, 2, 3, 2, 2]
- Ergonomics 2: `header_row` is a zero-based index and `n_rows` is a count, and the options go through a nested dict. Listing sheet names takes two steps through the other package.
- Failure 1: the docs do not say what happens for a misspelled sheet name.
- Findability 2: `sheet_name` is in the guide. Header row and column range are only in the engine package's docstring, and the sheet-name list is almost not shown.
- Completeness 2: the range part is never tied together with an example.
- Clarity 2: the pieces are spread over two packages' docs.

### 4 Header and names
```python
pl.read_excel(p, sheet_name="Headers", read_options={"column_names": [...]})
pl.read_excel(p, sheet_name="Two-row header", has_header=False)  # then build names by hand
```
Scores: [1, 1, 1, 2, 1, 1]
- Ergonomics 1: no handling of blank or duplicate headers or two-row headers is documented, so names are typed or built by hand.
- Failure 1: nothing says what happens with two `Total` cells and a blank cell.
- Findability 1: only the `has_header` and `column_names` parameter entries touch this.
- Correctness 2: the parameter text is right, but the task's key cases are not covered.
- Completeness 1: no source-of-name tracking, no merged-cell behaviour.
- Clarity 1: no example.

### 5 Column types
```python
pl.read_excel(p, sheet_name="Types", schema_overrides={"zip": pl.String, "amount": pl.Float64},
              infer_schema_length=None)
```
Scores: [1, 1, 1, 3, 1, 2]
- Ergonomics 1: no documented way to see which cells failed, so the user must read twice and compare.
- Failure 1: the docs do not say what happens to `n/a` and `12,5` in a column forced to numbers.
- Findability 1: only the function docstring, with a one-line example.
- Completeness 1: leading zeros and unconverted cells are not covered.
- Clarity 2: the example does not say what it returns.

### 6 Dates and times
```python
pl.read_excel("dates.xlsx")
pl.read_excel("dates.xlsx", schema_overrides={"day": pl.Float64, "clock": pl.Float64})
```
Scores: [2, 1, 1, 2, 1, 2]
- Ergonomics 2: the docs do not show that an override to a float type works on date cells.
- Failure 1: the docs do not say what a text cell in a date column does.
- Findability 1: only the `pl.Date` override example.
- Correctness 2: nothing wrong, but date handling is barely stated.
- Completeness 1: the 1904 system, time-of-day and stored numbers are not mentioned.
- Clarity 2: the example does not say what it gives.

### 7 Missing values and errors
```python
df = pl.read_excel(p, sheet_name="Missing")
df = df.with_columns(pl.all().replace(["NA", ".", "-"], None))  # sketch; errors not distinguishable
```
Scores: [1, 1, 0, 0, 0, 0]
- Ergonomics 1: no missing-value option is documented, so the user post-processes. Telling errors from blanks is not shown at all.
- Failure 1: nothing says how `#N/A` and `#DIV/0!` read.
- Docs 0: not covered.

### 8 Every sheet
```python
sheets = pl.read_excel("book.xlsx", sheet_id=0)
```
Scores: [2, 2, 1, 3, 3, 2]
- Ergonomics 2: `sheet_id=0` meaning "all sheets" is indirect.
- Failure 2: an empty sheet raises `NoDataError` by default, and the docs name `raise_if_empty=False` as the way round it, but give no message text.
- Findability 1: only in the function docstring; the Excel guide does not mention reading all sheets.
- Clarity 2: the all-sheets rule is a parenthetical inside a parameter entry.

### 9 Write a table
```python
df.write_excel("out.xlsx")
```
Scores: [3, 1, 3, 3, 1, 2]
- Failure 1: the docs do not say what happens when the file exists.
- Completeness 1: what each column becomes (categorical, missing values) and the overwrite behaviour are not stated.
- Clarity 2: the guide's example does not say what lands in Excel.

### 10 Write several tables
```python
with Workbook("out.xlsx") as wb:
    df1.write_excel(wb, "A"); df2.write_excel(wb, "B"); df3.write_excel(wb, "C")
# titles: write_excel(wb, "data", position=...) then ws.write(row, col, "Title", fmt)
```
Scores: [1, 1, 2, 3, 2, 2]
- Ergonomics 1: the user must create and close a separate workbook object. Titles and row offsets are hand-placed with the writer package.
- Failure 1: the docs do not say what happens for a sheet name containing `/`.
- Findability 2: the guide only points to the API docs for multi-sheet output.
- Completeness 2: the same-sheet example exists but three separate sheets are only implied.
- Clarity 2: the example is long and mixes two packages.

### 11 Format the output
```python
df.write_excel("out.xlsx", header_format={"bold": True},
               column_formats={"share": "0.0%", "amount": "#,##0"},
               autofit=True, freeze_panes="A2", autofilter=True)
```
Scores: [3, 1, 2, 3, 3, 2]
- Failure 1: the docs do not say what happens for a format on an unknown column.
- Findability 2: the guide points to the API docs.
- Clarity 2: the entry is dense and refers out to the writer package.

### 12 Fill an existing workbook
Not possible: the writer creates new workbooks only.

Scores: [0, 1, 0, 0, 0, 0]
- Docs say nothing about loading an existing file and keeping its chart.

### 13 Labels
Not possible: there is no label concept.

Scores: [0, 1, 0, 0, 0, 0]

---

## Library C (DataFrame library with read_excel and to_excel)

### 1 Install
```python
pip install "Library C[excel]"
```
Scores: [2, 1, 3, 3, 2, 3]
- Ergonomics 2: the README command alone installs no Excel engine; the extra is named only on the install page.
- Failure 1: the docs do not say what to do when a source build fails.
- Completeness 2: supported Python versions and platforms are deferred to a link.

### 2 Read a sheet
```python
df = pd.read_excel("report.xlsx")
```
Scores: [3, 1, 2, 3, 2, 2]
- Failure 1: nothing says what a missing file does.
- Findability 2: the README mentions Excel only as a link in a feature list.
- Completeness 2: the docs say datetimes convert automatically and `dtype` can override, but give no per-type table.
- Clarity 2: the guide's example is a bare call.

### 3 Choose what to read
```python
df = pd.read_excel(p, sheet_name="Sales 2024", header=4, usecols="B:F", nrows=35)
pd.ExcelFile(p).sheet_names
```
Scores: [2, 1, 2, 3, 2, 2]
- Ergonomics 2: `header=4` is zero-based, `nrows` is a count, and listing sheets takes two steps.
- Failure 1: the docs do not say what happens for a misspelled sheet name.
- Findability 2: sheets and columns are in separate guide sections.
- Completeness 2: no worked example of a table under titles.
- Clarity 2: no example shows how the three arguments combine.

### 4 Header and names
```python
pd.read_excel(p, sheet_name="Headers")                 # then rename
pd.read_excel(p, sheet_name="Two-row header", header=[3, 4])   # then flatten
```
Scores: [1, 1, 2, 3, 1, 2]
- Ergonomics 1: duplicates, blanks and a merged group name need extra clean-up steps.
- Failure 1: nothing says what happens with duplicate and blank headers.
- Findability 2: the multi-row header is under a MultiIndex heading; name cleaning has no entry.
- Completeness 1: name cleaning, merged group names and tracking the original text are not covered.
- Clarity 2: the MultiIndex material is about index layout, not the scenario.

### 5 Column types
```python
df = pd.read_excel(p, sheet_name="Types", dtype={"zip": str, "amount": float})
```
Scores: [1, 1, 2, 3, 1, 2]
- Ergonomics 1: nothing reports which cells failed to convert.
- Failure 1: nothing says what a forced numeric type does with `n/a` or `12,5`.
- Findability 2: under the dtype and converters headings.
- Completeness 1: leading zeros and unconverted cells are not covered.
- Clarity 2: no result is described.

### 6 Dates and times
```python
pd.read_excel("dates.xlsx")
```
Scores: [1, 1, 2, 3, 1, 2]
- Ergonomics 1: the docs show no way to read date columns as stored numbers.
- Failure 1: the docs describe only text-date parsing, not a text cell in a date column.
- Findability 2: "Parsing dates" is about text that looks like dates.
- Completeness 1: time-of-day, the 1904 system and stored numbers are not covered.
- Clarity 2: one line is stated for Excel dates.

### 7 Missing values and errors
```python
df = pd.read_excel(p, sheet_name="Missing", na_values=["NA", ".", "-", "#DIV/0!"])
```
Scores: [1, 1, 1, 3, 2, 3]
- Ergonomics 1: `#DIV/0!` is not in the default list, and there is no way to tell errors from blanks.
- Failure 1: nothing says what `#DIV/0!` does by default.
- Findability 1: only the function docstring and a one-off example.
- Completeness 2: the default list and `keep_default_na` are clear, but telling errors from blanks is not covered.

### 8 Every sheet
```python
sheets = pd.read_excel("book.xlsx", sheet_name=None)
```
Scores: [3, 1, 2, 3, 3, 3]
- Failure 1: nothing says what happens with an empty sheet.
- Findability 2: no heading says "all sheets".

### 9 Write a table
```python
df.to_excel("out.xlsx", index=False)
```
Scores: [1, 0, 2, 3, 2, 3]
- Ergonomics 1: by default the row index is written as an extra column, and an existing file is replaced.
- Failure 0: the docs say an existing file is overwritten, with no message.
- Findability 2: one step to a guide section.
- Completeness 2: what each column becomes (categorical, missing) is largely missing.

### 10 Write several tables
```python
with pd.ExcelWriter("out.xlsx") as w:
    a.to_excel(w, sheet_name="A", index=False); b.to_excel(w, sheet_name="B", index=False)
```
Scores: [1, 1, 2, 3, 2, 3]
- Ergonomics 1: the user must create and close a writer object, and titles above tables are not supported.
- Failure 1: nothing says what happens for a bad sheet name, apart from "other limits are the user's job".
- Findability 2: the examples are in the docstrings.
- Completeness 2: `startrow` and `startcol` are listed but titles are not covered.

### 11 Format the output
```python
df.style.map_index(lambda x: "font-weight: bold", axis=1).to_excel("out.xlsx", index=False, freeze_panes=(1, 0), autofilter=True)
```
Scores: [1, 1, 2, 3, 2, 2]
- Ergonomics 1: styling goes through a separate Styler object, and column-width fitting is not available in the documented arguments.
- Failure 1: nothing says what happens for a format on an unknown column.
- Findability 2: the style section and a separate Styler page.
- Completeness 2: widths are not covered; the percent format has no example.
- Clarity 2: the example does not say what it gives.

### 12 Fill an existing workbook
```python
with pd.ExcelWriter(p, mode="a", engine="Library D", if_sheet_exists="replace") as w:
    df.to_excel(w, sheet_name="Data", index=False)
# a second writer with if_sheet_exists="overlay", startrow=3, startcol=2 for C4 and C5
```
Scores: [1, 0, 1, 3, 2, 2]
- Ergonomics 1: two writers are needed, because replace and overlay conflict, and the chart is lost.
- Failure 0: the docs say charts and images are silently lost in append mode.
- Findability 1: only the `mode` entry in the writer docstring.
- Completeness 2: the loss of charts is clear, but writing single cells is not shown.
- Clarity 2: no worked example for cells.

### 13 Labels
Not possible: there is no label concept.

Scores: [0, 1, 0, 0, 0, 0]

---

## Library D (cell-level workbook library)

### 1 Install
```python
pip install Library D
```
Scores: [3, 1, 2, 3, 2, 3]
- Failure 1: nothing says what to do when installation fails.
- Findability 2: the README has no command, only a link to the docs where the tutorial has the heading.
- Completeness 2: supported Python versions and platforms are not stated.

### 2 Read a sheet
```python
rows = list(load_workbook("report.xlsx").active.values)
df = DataFrame(rows[1:], columns=rows[0])
```
Scores: [1, 1, 2, 2, 1, 2]
- Ergonomics 1: there is no table reader, so the user loads, extracts and builds the table.
- Failure 1: nothing says what a missing file does.
- Findability 2: the answer is in a separate DataFrame page.
- Correctness 2: the docs' header example drops the first column (`[1:]`), which suits a pandas-written sheet with an index but not this one.
- Completeness 1: the types of each column are not described.
- Clarity 2: the DataFrame page needs rereading.

### 3 Choose what to read
```python
ws = load_workbook(p)["Sales 2024"]
rows = list(ws.iter_rows(min_row=5, max_row=40, min_col=2, max_col=6, values_only=True))
load_workbook(p).sheetnames
```
Scores: [1, 1, 2, 3, 3, 3]
- Ergonomics 1: several calls are needed to get a table.
- Failure 1: nothing says what a misspelled sheet name does.
- Findability 2: the tutorial sections on sheets and cell ranges.

### 4 Header and names
```python
# hand-written: read rows, fill the merged group name from the left, de-duplicate names in Python
```
Scores: [1, 1, 1, 2, 1, 2]
- Ergonomics 1: all of the work is the user's.
- Failure 1: nothing is documented for duplicate or blank headers.
- Findability 1: only the merge and unmerge notes.
- Correctness 2: the merged-cell notes are right but do not cover names.
- Completeness 1: only the top-left-cell rule for merged cells helps.
- Clarity 2: relevant facts are scattered.

### 5 Column types
```python
# loop over cells: str(v).zfill(5); try float(v) except -> record cell.coordinate
```
Scores: [1, 1, 1, 3, 1, 1]
- Ergonomics 1: conversion and failure tracking are hand-written loops.
- Failure 1: nothing says what happens.
- Findability 1: only the cell API entries (`data_type`, `coordinate`).
- Completeness 1: the cell value types are listed with no guidance.
- Clarity 1: no example.

### 6 Dates and times
```python
ws = load_workbook("dates.xlsx").active   # cell.value gives datetime values
wb.epoch                                  # the date system
```
Scores: [1, 1, 2, 3, 2, 3]
- Ergonomics 1: values are read per cell and assembled by hand, and the stored numbers are not shown.
- Failure 1: nothing says what a text cell in a date column does.
- Findability 2: a "Dates and Times" page, two steps from the README.
- Completeness 2: the 1904 system, time-of-day and durations are covered, but reading the raw numbers is not.

### 7 Missing values and errors
```python
# loop over cells: test v in ("NA", ".", "-"), then cell.data_type
```
Scores: [1, 1, 1, 2, 1, 1]
- Ergonomics 1: all handling is by hand.
- Failure 1: nothing says how `#N/A` or `#DIV/0!` read.
- Findability 1: only the cell API entries.
- Correctness 2: the `check_error` entry is cryptic but not wrong.
- Completeness 1: error cells are not explained.
- Clarity 1: no example.

### 8 Every sheet
```python
tables = {ws.title: DataFrame(ws.values) for ws in load_workbook("book.xlsx")}
```
Scores: [1, 3, 2, 3, 2, 2]
- Ergonomics 1: a loop with several calls per sheet.
- Findability 2: only a "loop through worksheets" snippet.
- Completeness 2: the named collection is hand-built.
- Clarity 2: the parts are on different pages.

### 9 Write a table
```python
wb = Workbook(); ws = wb.active
for r in dataframe_to_rows(df, index=False, header=True): ws.append(r)
wb.save("out.xlsx")
```
Scores: [1, 0, 2, 3, 2, 3]
- Ergonomics 1: the user creates, fills and saves a workbook, and existing files are overwritten.
- Failure 0: the docs say saving overwrites existing files without warning.
- Findability 2: the tutorial and the DataFrame page.
- Completeness 2: categorical and missing values are not covered.

### 10 Write several tables
```python
wb = Workbook(); wb.create_sheet("A"); ...; ws.cell(row=1, column=1, value="Table 1"); ws.append(...); wb.save(p)
```
Scores: [1, 1, 2, 3, 2, 3]
- Ergonomics 1: an object to create, fill and save, with row offsets worked out by hand.
- Failure 1: nothing says what happens for a sheet name containing `/`.
- Findability 2: the tutorial.
- Completeness 2: stacking tables with blank rows is not shown.

### 11 Format the output
```python
for c in ws[1]: c.font = Font(bold=True)
# cell.number_format = "0.0%"; ws.freeze_panes = "A2"; ws.auto_filter.ref = "A1:E40"; widths by hand
```
Scores: [1, 1, 2, 3, 2, 2]
- Ergonomics 1: per-cell loops, and widths are not fitted automatically.
- Failure 1: nothing says what happens for a missing column.
- Findability 2: styles and filters pages; `freeze_panes` is only an API entry.
- Completeness 2: widths and `freeze_panes` are not explained.
- Clarity 2: the filter page is about complex criteria.

### 12 Fill an existing workbook
```python
wb = load_workbook(p); ws = wb["Data"]; ws.delete_rows(1, ws.max_row)
# append rows; wb["Cover"]["C4"] = 1250; wb["Cover"]["C5"] = date; wb.save(p)
```
Scores: [1, 1, 2, 3, 2, 2]
- Ergonomics 1: many calls.
- Failure 1: the docs warn that shapes are lost on open and save, but do not say whether the chart on `Chart` is kept.
- Findability 2: the "Loading from a file" section.
- Completeness 2: formats kept or lost are not listed.
- Clarity 2: warnings are scattered.

### 13 Labels
Not possible: there is no label concept.

Scores: [0, 1, 0, 0, 0, 0]

---

```json
{"A": {"1": [2,3,3,3,3,3], "2": [3,1,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,1,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,2,3,3,3,3], "11": [3,1,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,2,3,3,3,3]},
 "B": {"1": [2,1,3,3,2,3], "2": [3,1,2,3,1,2], "3": [2,1,2,3,2,2], "4": [1,1,1,2,1,1], "5": [1,1,1,3,1,2], "6": [2,1,1,2,1,2], "7": [1,1,0,0,0,0], "8": [2,2,1,3,3,2], "9": [3,1,3,3,1,2], "10": [1,1,2,3,2,2], "11": [3,1,2,3,3,2], "12": [0,1,0,0,0,0], "13": [0,1,0,0,0,0]},
 "C": {"1": [2,1,3,3,2,3], "2": [3,1,2,3,2,2], "3": [2,1,2,3,2,2], "4": [1,1,2,3,1,2], "5": [1,1,2,3,1,2], "6": [1,1,2,3,1,2], "7": [1,1,1,3,2,3], "8": [3,1,2,3,3,3], "9": [1,0,2,3,2,3], "10": [1,1,2,3,2,3], "11": [1,1,2,3,2,2], "12": [1,0,1,3,2,2], "13": [0,1,0,0,0,0]},
 "D": {"1": [3,1,2,3,2,3], "2": [1,1,2,2,1,2], "3": [1,1,2,3,3,3], "4": [1,1,1,2,1,2], "5": [1,1,1,3,1,1], "6": [1,1,2,3,2,3], "7": [1,1,1,2,1,1], "8": [1,3,2,3,2,2], "9": [1,0,2,3,2,3], "10": [1,1,2,3,2,3], "11": [1,1,2,3,2,2], "12": [1,1,2,3,2,2], "13": [0,1,0,0,0,0]}}
```
