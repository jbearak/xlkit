# Judging: Libraries A, B, C and D

Score order is [ergonomics, failure, findability, correctness, completeness, clarity].

I judged only from the text in the file. A, B and C are Python libraries and D is R. For each task I give the code I would write, the scores, and a reason for each score below 3.

Rules I applied:
- **Parts:** where a scenario has parts, ergonomics is the lowest part.
- **Silent behaviour:** where the docs say nothing about a failure probe, failure scores 1.
- **Silent overwrite:** if the docs say a file is overwritten without a message, failure scores 0.
- **Uncovered tasks:** where the docs do not cover a task at all, correctness, completeness and clarity score 0.

---

## Library A (workbook object, cell by cell; pandas hand-off page)

### A1 Install
```
pip install Library A
```
Scores: [3,1,2,2,1,2]
- Failure 1: nothing says what to do when the install fails or a system requirement is missing.
- Findability 2: the README has no install command and only points at the docs. The command is in the tutorial.
- Correctness 2: the "working with a checkout" command uses `hg+`, which looks out of date.
- Completeness 1: no Python versions, platforms or system requirements. It mentions lxml and pillow only as optional extras.
- Clarity 2: short and plain, but the extras are not tied to a task.

### A2 Read a sheet
```python
ws = load_workbook("report.xlsx").active
rows = ws.values; cols = next(rows)
df = DataFrame(rows, columns=cols)
```
Scores: [1,1,2,2,1,2]
- Ergonomics 1: several calls, and the user builds the table.
- Failure 1: the docs do not say what happens for a missing file.
- Findability 2: the answer is on the pandas hand-off page, not on the front page.
- Correctness 2: the header example assumes an index column, and `DataFrame` is never imported.
- Completeness 1: it never says which type each column gets.
- Clarity 2: needs some rereading.

### A3 Choose what to read
```python
wb = load_workbook("f.xlsx"); names = wb.sheetnames
cells = wb["Sales 2024"]["B5:F40"]   # still a loop to make a table
```
Scores: [1,1,2,2,2,2]
- Ergonomics 1: the range comes back as cells, not a table.
- Failure 1: nothing is said about a misspelled sheet name.
- Findability 2: the answer is spread across the tutorial.
- Correctness 2: the tutorial has a typo ("Workbook.sheetname attribute").
- Completeness 2: no step from the range to a table.
- Clarity 2.

### A4 Header and names
```python
rows = load_workbook(f)["Headers"].values; cols = next(rows)   # fix blanks and repeats by hand
```
Scores: [1,1,1,2,0,1]
- Ergonomics 1: all by hand.
- Failure 1: nothing about repeated or blank headers.
- Findability 1: only implied by the pandas header example and the merged-cell note.
- Correctness 2: what is said (a merged cell's value is in its top-left cell) is right but tangential.
- Completeness 0: nothing on blank or repeated headers, or on two-row headers.
- Clarity 1.

### A5 Column types
```python
for c in ws["C"]: c.data_type, c.value   # convert by hand, collect failures
```
Scores: [1,1,1,0,0,0]
- Ergonomics 1: manual per-cell loop.
- Failure 1: the docs say nothing.
- Findability 1: `Cell.data_type` appears only as a bare entry in the API list.
- Correctness 0, completeness 0, clarity 0: the task is not covered.

### A6 Dates and times
```python
wb = load_workbook(f); wb.epoch; ws["A2"].value   # datetime; ws["A2"].internal_value for raw
```
Scores: [1,1,3,3,2,2]
- Ergonomics 1: cell by cell. The only route to the raw number is `internal_value`, with a one-line description.
- Failure 1: nothing about a text cell in a date column.
- Completeness 2: the 1900/1904 systems, timezones and timedelta are covered. Times of day, raw numbers and text cells are not.
- Clarity 2: good prose, but no read example.

### A7 Missing values and errors
```python
[c.value for c in ws["D"] if c.data_type != "e"]   # by hand
```
Scores: [1,1,1,0,0,0]
- Ergonomics 1: by hand.
- Failure 1: the docs say nothing.
- Findability 1: `check_error` and `data_type` appear only in the API list.
- Correctness 0, completeness 0, clarity 0: not covered. The `check_error` entry is garbled.

### A8 Every sheet
```python
tables = {ws.title: DataFrame(ws.values) for ws in load_workbook(f)}
```
Scores: [1,1,1,3,1,2]
- Ergonomics 1: one call per sheet.
- Failure 1: nothing about an empty sheet.
- Findability 1: only the loop over `sheet.title` is shown.
- Completeness 1: main path only.
- Clarity 2.

### A9 Write a table
```python
wb = Workbook(); ws = wb.active
for r in dataframe_to_rows(df, index=False, header=True): ws.append(r)
wb.save("out.xlsx")
```
Scores: [1,0,2,2,2,2]
- Ergonomics 1: a loop with several calls.
- Failure 0: "overwrite existing files without warning". It silently overwrites someone else's file.
- Findability 2: split between "Saving to a file" and the pandas page.
- Correctness 2: the example lacks imports and defines no `df`.
- Completeness 2: numpy and datetime types and the overwrite are covered. Missing values and categoricals are not.
- Clarity 2.

### A10 Write several tables
```python
ws2 = wb.create_sheet("B"); ...   # one create_sheet per sheet, then append rows
ws.append(["Table 1"]); [ws.append(r) for r in t1]; ws.append([]); ws.append([]) ...
```
Scores: [1,1,2,3,1,2]
- Ergonomics 1: several calls, and the user tracks rows.
- Failure 1: nothing about `/` in a sheet name.
- Findability 2.
- Completeness 1: `create_sheet` only. No stacked tables or titles.
- Clarity 2.

### A11 Format the output
```python
for c in ws[1]: c.font = Font(bold=True)
# number_format per cell, column_dimensions widths, ws.freeze_panes = "A2", ws.auto_filter.ref = ws.dimensions
```
Scores: [1,1,2,2,1,2]
- Ergonomics 1: per-cell loops, and no autofit.
- Failure 1: the docs say nothing.
- Findability 2: styles and filters have pages. `freeze_panes` is only in the API list.
- Correctness 2: the "styles on columns and rows" paragraph is confusing.
- Completeness 1: no widths or autofit, and freeze panes is not explained.
- Clarity 2.

### A12 Fill an existing workbook
```python
wb = load_workbook("results.xlsx"); ws = wb["Data"]; ws.delete_rows(1, ws.max_row)
# append rows; wb["Cover"]["C4"] = 1250; wb["Cover"]["C5"] = date; wb.save("results.xlsx")
```
Scores: [1,1,2,3,1,2]
- Ergonomics 1: several calls.
- Failure 1: the docs do not say what happens to a chart.
- Findability 2: "Loading from a file" in the tutorial.
- Completeness 1: only "shapes will be lost". Formats and charts are not addressed.
- Clarity 2.

### A13 Labels
```python
# no label concept; map values and rename headers by hand
```
Scores: [1,1,0,0,0,0]
- Ergonomics 1: manual code only.
- Failure 1: the docs say nothing.
- Findability, correctness, completeness and clarity 0: not covered.

---

## Library B (DataFrame library; Excel via fastexcel and xlsxwriter)

### B1 Install
```
pip install Library B          # Excel: pip install fastexcel xlsxwriter
```
Scores: [3,1,3,3,2,3]
- Failure 1: only the source-build steps are given. Nothing says what to do when it fails.
- Completeness 2: no Python versions. A few platform notes (old CPU, Rosetta, more than 2^32 rows).

### B2 Read a sheet
```python
df = pl.read_excel("report.xlsx")
```
Scores: [3,1,2,3,2,2]
- Failure 1: nothing about a missing file.
- Findability 2: README, then the user guide, then the Excel page.
- Completeness 2: dtype inference is mentioned (`infer_schema_length`, `schema_overrides`), but there is no table of types.
- Clarity 2: examples show no result.

### B3 Choose what to read
```python
df = pl.read_excel(f, sheet_name="Sales 2024",
                   read_options={"header_row": 4, "use_columns": "B:F", "n_rows": 35})
fastexcel.read_excel(f).sheet_names
```
Scores: [2,1,1,3,2,2]
- Ergonomics 2: there is no range argument. A zero-based header row and a row count stand in for it. Sheet names need a second library's call.
- Failure 1: nothing about a misspelled sheet.
- Findability 1: the range and sheet-name answers are only in the `read_options` pointer and the fastexcel reference.
- Completeness 2: the pieces are documented, but the B5:F40 combination is never shown.
- Clarity 2.

### B4 Header and names
```python
df = pl.read_excel(f, sheet_name="Headers")
pl.read_excel(f, sheet_name="Two-row", has_header=False)   # then build names by hand
```
Scores: [1,1,1,3,1,2]
- Ergonomics 1: two-row headers need manual work.
- Failure 1: nothing about repeated or blank names.
- Findability 1: only `has_header` and `column_names` in reference text.
- Completeness 1: nothing on repeated or blank headers, or on where each name came from.
- Clarity 2.

### B5 Column types
```python
pl.read_excel(f, schema_overrides={"zip": pl.String, "amount": pl.Float64}, infer_schema_length=None)
```
Scores: [1,1,1,3,1,2]
- Ergonomics 1: there is no way to find the cells that did not convert.
- Failure 1: the docs do not say what happens.
- Findability 1: only the reference example.
- Completeness 1: nothing on leading zeros or failed cells.
- Clarity 2.

### B6 Dates and times
```python
pl.read_excel(f, schema_overrides={"d": pl.Date, "dt": pl.Datetime, "t": pl.Time})
```
Scores: [2,1,1,3,1,2]
- Ergonomics 2: the override is documented, but there is no documented way to get the stored numbers.
- Failure 1: nothing about a text cell in a date column.
- Findability 1: the example is in the reference only.
- Completeness 1: nothing on the 1904 system, times of day or stored numbers.
- Clarity 2.

### B7 Missing values and errors
```python
pl.read_excel(f)   # no na argument documented
```
Scores: [1,1,0,0,0,0]
- Ergonomics 1: no `na` argument, so the user replaces values by hand.
- Failure 1: nothing about `#N/A` or `#DIV/0!`.
- Findability, correctness, completeness and clarity 0: not covered.

### B8 Every sheet
```python
tables = pl.read_excel(f, sheet_id=0)   # dict keyed by sheet name
```
Scores: [2,2,1,3,2,2]
- Ergonomics 2: `sheet_id=0` meaning "all" is indirect.
- Failure 2: an empty sheet raises `NoDataError` by default, which names the problem. The docs say to pass `raise_if_empty=False`. The default aborts the whole read.
- Findability 1: only in the reference.
- Completeness 2.
- Clarity 2.

### B9 Write a table
```python
df.write_excel("out.xlsx")
```
Scores: [3,1,2,3,2,3]
- Failure 1: nothing about an existing file.
- Findability 2: the Write section of the user guide.
- Completeness 2: no table of what each dtype becomes, and nothing on missing values or categoricals. `float_precision` and `autofilter` defaults are listed.

### B10 Write several tables
```python
with Workbook("f.xlsx") as wb:
    df1.write_excel(workbook=wb, worksheet="A"); ...
    df.write_excel(workbook=wb, worksheet="S", position=(0, 0)); ws.write(...)   # titles
```
Scores: [1,1,1,3,2,2]
- Ergonomics 1: the user creates a workbook object. Titles and row offsets are by hand.
- Failure 1: nothing about `/` in a sheet name.
- Findability 1: the example is in the `write_excel` reference.
- Completeness 2: the two-tables-with-titles example exists. The three-sheet case is only implied.
- Clarity 2.

### B11 Format the output
```python
df.write_excel("out.xlsx", header_format={"bold": True},
               column_formats={"share": "0.0%", "amount": "#,##0"},
               autofit=True, freeze_panes="A2", autofilter=True)
```
Scores: [3,1,2,3,3,3]
- Failure 1: nothing about an unknown column name in `column_formats`.
- Findability 2: the guide only points to the `write_excel` reference.

### B12 Fill an existing workbook
```python
# not supported: write_excel creates workbooks only
```
Scores: [0,1,0,0,0,0]
- Ergonomics 0: no way to open and edit an existing file.
- Failure 1: the docs say nothing about charts.
- Findability, correctness, completeness and clarity 0: not covered.

### B13 Labels
```python
# no label concept
```
Scores: [1,1,0,0,0,0]
- Ergonomics 1: manual code only.
- Failure 1: the docs say nothing.
- Other scores 0: not covered.

---

## Library C (DataFrame library; read_excel / to_excel)

### C1 Install
```
pip install Library C        # Excel: pip install "Library C[excel]"
```
Scores: [3,1,3,3,2,3]
- Failure 1: nothing about failed installs or missing system requirements.
- Completeness 2: a dependency table with minimum versions, but no Python versions or platforms.

### C2 Read a sheet
```python
df = pd.read_excel("report.xlsx")
```
Scores: [3,1,3,3,2,3]
- Failure 1: nothing about a missing file.
- Completeness 2: no table of the type each column gets. Dates are said to convert automatically.

### C3 Choose what to read
```python
pd.read_excel(f, sheet_name="Sales 2024", header=4, usecols="B:F", nrows=35)
pd.ExcelFile(f).sheet_names
```
Scores: [2,1,2,3,2,3]
- Ergonomics 2: the header row is zero-based and `nrows` is a count. Sheet names need a second call.
- Failure 1: nothing about a misspelled sheet.
- Findability 2: the range has to be pieced together from separate sections.
- Completeness 2: a B5:F40 example is missing.

### C4 Header and names
```python
pd.read_excel(f, sheet_name="Headers")
pd.read_excel(f, sheet_name="Two-row", header=[0, 1])   # then flatten by hand
```
Scores: [1,1,2,3,1,2]
- Ergonomics 1: the two-row header gives a MultiIndex to flatten, and merged group names are not filled in.
- Failure 1: nothing about repeated or blank names.
- Findability 2: the "Reading a MultiIndex" heading.
- Completeness 1: nothing on repeated or blank names, or on which header text a name came from.
- Clarity 2.

### C5 Column types
```python
pd.read_excel(f, dtype={"zip": str, "amount": float}, decimal=",")
```
Scores: [1,1,2,3,1,2]
- Ergonomics 1: no way to list cells that did not convert.
- Failure 1: the docs do not say what a failed conversion does.
- Findability 2: "Dtype specifications" and "Cell converters" are headings, but failed cells are not covered.
- Completeness 1: nothing on leading zeros or on finding bad cells.
- Clarity 2.

### C6 Dates and times
```python
pd.read_excel(f)   # dates auto-converted; no documented way to read the stored numbers
```
Scores: [1,1,3,3,1,2]
- Ergonomics 1: no documented way to get the stored numbers.
- Failure 1: only "returned unaltered as object" for `parse_dates`, with no message.
- Completeness 1: nothing on times of day or on the 1904 system.
- Clarity 2.

### C7 Missing values and errors
```python
pd.read_excel(f, na_values=["NA", ".", "-", "#DIV/0!"])
```
Scores: [1,1,1,3,2,3]
- Ergonomics 1: `#DIV/0!` is not in the default list, so the user must add it. There is no way to tell errors from blanks.
- Failure 1: the docs do not say what happens to a column with `#DIV/0!` cells.
- Findability 1: only the `read_excel` reference.
- Completeness 2: errors versus blanks are missing.

### C8 Every sheet
```python
pd.read_excel(f, sheet_name=None)   # dict of DataFrames
```
Scores: [3,1,3,3,2,3]
- Failure 1: nothing about an empty sheet.
- Completeness 2.

### C9 Write a table
```python
df.to_excel("out.xlsx", index=False)
```
Scores: [2,0,3,3,2,3]
- Ergonomics 2: the index is written unless `index=False`.
- Failure 0: the docs say an existing file is overwritten, with no message.
- Completeness 2: nothing on what each dtype becomes, and nothing on categoricals.

### C10 Write several tables
```python
with pd.ExcelWriter("f.xlsx") as w:
    d1.to_excel(w, sheet_name="A"); d2.to_excel(w, sheet_name="B"); d3.to_excel(w, sheet_name="C")
    t1.to_excel(w, sheet_name="S", startrow=1); t2.to_excel(w, sheet_name="S", startrow=len(t1)+5)
```
Scores: [1,1,2,3,2,2]
- Ergonomics 1: the user creates a writer. Titles are not documented, and row offsets are by hand.
- Failure 1: nothing about `/` in a sheet name.
- Findability 2.
- Completeness 2: `startrow` and `startcol` exist, but titles are not covered.
- Clarity 2.

### C11 Format the output
```python
df.to_excel("out.xlsx", freeze_panes=(1, 0), autofilter=True)   # plus Styler for bold and number-format
```
Scores: [1,1,2,3,2,2]
- Ergonomics 1: bold and number formats need a Styler. Autofit has no option.
- Failure 1: nothing about an unknown column name.
- Findability 2.
- Completeness 2: no widths or autofit, and `number-format` has no example.
- Clarity 2.

### C12 Fill an existing workbook
```python
with pd.ExcelWriter("results.xlsx", mode="a", engine="Library A", if_sheet_exists="replace") as w:
    df.to_excel(w, sheet_name="Data", index=False)
# cells C4 and C5 need another overlay write with startrow=3, startcol=2, header=False
```
Scores: [1,0,1,3,2,2]
- Ergonomics 1: several writes, and single cells go through one-cell frames.
- Failure 0: the docs say charts are "silently lost" when appending.
- Findability 1: only the `ExcelWriter` and `to_excel` reference text.
- Completeness 2: the losses are stated (macros, charts, images). Formats and other sheets are not covered.
- Clarity 2.

### C13 Labels
```python
# header=[...] aliases for headers; value labels via .map by hand
```
Scores: [1,1,0,0,0,0]
- Ergonomics 1: manual code only.
- Failure 1: the docs say nothing.
- Other scores 0: not covered.

---

## Library D (R: read_xlsx, write_xlsx, write_sheet, write_cells)

### D1 Install
```r
install.packages("remotes"); remotes::install_github("Library D")
```
Scores: [2,3,3,3,3,3]
- Ergonomics 2: two calls (not on CRAN), and Rust must be installed first.

### D2 Read a sheet
```r
scores <- read_xlsx(xlkit_example("report.xlsx"))
```
Scores: [3,3,3,3,3,3]

### D3 Choose what to read
```r
read_xlsx(path, sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets(path)
```
Scores: [3,3,3,3,3,3]

### D4 Header and names
```r
read_xlsx(path, sheet = "Headers"); read_xlsx(path, sheet = "Two-row header", header = 4:5)
```
Scores: [3,3,3,3,3,3]

### D5 Column types
```r
df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores: [3,3,3,3,3,3]

### D6 Dates and times
```r
read_xlsx(path); read_xlsx(path, types = c(day = "number", clock = "number"))
```
Scores: [3,3,3,3,3,3]

### D7 Missing values and errors
```r
df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-")); xlsx_problems(df)
```
Scores: [3,3,3,3,3,3]

### D8 Every sheet
```r
all <- read_sheets(path)
```
Scores: [3,3,3,3,3,3]

### D9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores: [3,3,3,3,3,3]

### D10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "report.xlsx")
write_xlsx(list(Results = list("Table 1. Means" = m, "Table 2. Counts" = n)), "results.xlsx", gap = 2)
```
Scores: [3,3,3,3,3,3]

### D11 Format the output
```r
write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3,3,3,2,3,3]
- Correctness 2: the `xl_style()` text says to use it "in `merge`", but `write_xlsx()` has no `merge` argument in its reference signature.

### D12 Fill an existing workbook
```r
write_sheet(new_data, path, sheet = "Data")
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [3,3,3,2,3,3]
- Correctness 2: the `write_cells` text says `styles` and `merge` "work as in `write_xlsx()`", but `write_xlsx()` has no `merge`.

### D13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")
df <- read_xlsx("survey.xlsx", names = "snake")
```
Scores: [3,3,3,3,3,3]

---

```json
{"A": {"1": [3,1,2,2,1,2], "2": [1,1,2,2,1,2], "3": [1,1,2,2,2,2], "4": [1,1,1,2,0,1], "5": [1,1,1,0,0,0], "6": [1,1,3,3,2,2], "7": [1,1,1,0,0,0], "8": [1,1,1,3,1,2], "9": [1,0,2,2,2,2], "10": [1,1,2,3,1,2], "11": [1,1,2,2,1,2], "12": [1,1,2,3,1,2], "13": [1,1,0,0,0,0]},
 "B": {"1": [3,1,3,3,2,3], "2": [3,1,2,3,2,2], "3": [2,1,1,3,2,2], "4": [1,1,1,3,1,2], "5": [1,1,1,3,1,2], "6": [2,1,1,3,1,2], "7": [1,1,0,0,0,0], "8": [2,2,1,3,2,2], "9": [3,1,2,3,2,3], "10": [1,1,1,3,2,2], "11": [3,1,2,3,3,3], "12": [0,1,0,0,0,0], "13": [1,1,0,0,0,0]},
 "C": {"1": [3,1,3,3,2,3], "2": [3,1,3,3,2,3], "3": [2,1,2,3,2,3], "4": [1,1,2,3,1,2], "5": [1,1,2,3,1,2], "6": [1,1,3,3,1,2], "7": [1,1,1,3,2,3], "8": [3,1,3,3,2,3], "9": [2,0,3,3,2,3], "10": [1,1,2,3,2,2], "11": [1,1,2,3,2,2], "12": [1,0,1,3,2,2], "13": [1,1,0,0,0,0]},
 "D": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,2,3,3], "12": [3,3,3,2,3,3], "13": [3,3,3,3,3,3]}}
```
