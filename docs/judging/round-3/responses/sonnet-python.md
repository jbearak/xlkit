# Judgement, round 3, python.md

Score order: [ergonomics, failure, findability, correctness, completeness, clarity]. Only scores below 3 get a reason. Judged only from the file's text.

---

## Library D (R)

**1 Install.** `remotes::install_github("Library D")` (after `install.packages("remotes")`) → [2,3,3,3,3,3]
- Ergonomics 2: two calls, not on CRAN, and Rust must be installed first.

**2 Read a sheet.** `read_xlsx("report.xlsx")` → [3,3,3,3,3,3]

**3 Choose what to read.** `read_xlsx(p, sheet="Sales 2024", range="B5:F40")`; `xlsx_sheets(p)` → [3,3,3,3,3,3]

**4 Header and names.** `read_xlsx(p, sheet="Headers")`; `read_xlsx(p, sheet="Two-row header", header=4:5)` → [3,3,3,3,3,3]

**5 Column types.** `df <- read_xlsx(p, sheet="Types", types=c(zip="text", amount="number")); xlsx_problems(df)` → [3,3,3,3,3,3]

**6 Dates and times.** `read_xlsx("dates.xlsx")`; `read_xlsx("dates1904.xlsx")`; `read_xlsx(p, dates=FALSE)` → [3,3,3,3,3,3]

**7 Missing values and errors.** `df <- read_xlsx(p, sheet="Missing", na=c("NA",".","-")); xlsx_problems(df)` → [3,3,3,3,3,3]

**8 Every sheet.** `read_sheets("book.xlsx")` → [3,3,3,3,3,3]

**9 Write a table.** `write_xlsx(df, "out.xlsx")` → [3,3,3,3,3,3]

**10 Write several tables.** `write_xlsx(list(A=a, B=b, C=c), "r.xlsx")`; `write_xlsx(list(Results=list("Table 1"=t1, "Table 2"=t2)), "t.xlsx", gap=2)` → [3,3,3,3,3,3]

**11 Format the output.** `write_xlsx(df, "o.xlsx", formats=c(share="0.0%", amount="#,##0"), filter=TRUE)` → [3,3,3,3,3,3]

**12 Fill an existing workbook.** `write_sheet(new, path, sheet="Data")`; `write_cells(path, sheet="Cover", C4=1250, C5=as.Date("2024-12-31"))` → [3,3,3,3,3,3]

**13 Labels.** `write_xlsx(df, "s.xlsx", header="labels")`; `read_xlsx("s.xlsx", names="snake")` → [3,3,3,3,3,3]

---

## Library A (pandas-like)

**1 Install.** `pip install "Library A[excel]"` → [2,1,2,3,2,3]
- Ergonomics 2: the README command `pip install Library A` does not bring an xlsx engine. The `[excel]` extra is only on the install page.
- Failure 1: nothing is said about what to do when an install fails.
- Findability 2: the extra sits behind the "full installation instructions" link.
- Completeness 2: no Python versions or platforms, and no failure advice.

**2 Read a sheet.** `pd.read_excel("report.xlsx")` → [3,1,3,3,2,2]
- Failure 1: the docs do not say what a missing file does.
- Completeness 2: the type each column gets is never listed.
- Clarity 2: the examples say "Returns a DataFrame" and show no result.

**3 Choose what to read.** `pd.read_excel(p, sheet_name="Sales 2024", header=4, usecols="B:F", nrows=35)`; `pd.ExcelFile(p).sheet_names` → [2,1,2,3,2,2]
- Ergonomics 2: no range argument. It needs a zero-based header index plus a row count.
- Failure 1: a misspelled sheet name is not covered.
- Findability 2: skipping title rows is only in the docstring.
- Completeness 2: B5:F40 is never shown as one case.
- Clarity 2: the pieces are spread over several arguments.

**4 Header and names.** `pd.read_excel(p, sheet_name="Headers")`; `pd.read_excel(p, sheet_name=2, header=[0,1])` → [2,1,2,2,1,2]
- Ergonomics 2: a zero-based list of rows gives a MultiIndex that must then be flattened.
- Failure 1: nothing is said about duplicate or blank header cells.
- Findability 2: only the MultiIndex section exists.
- Correctness 2: the task is only partly covered.
- Completeness 1: no merged-cell, blank or duplicate handling, and no source-text tracking.
- Clarity 2: the MultiIndex layout is explained, but not what the names look like.

**5 Column types.** `pd.read_excel(p, dtype={"zip": str, "amount": float})` → [1,1,2,2,1,2]
- Ergonomics 1: no way to list the cells that did not convert, so several manual steps.
- Failure 1: the docs do not say what a failed numeric cast does. Converters silently turn exceptions into missing values.
- Findability 2: the dtype and converters sections are there, but "which cells failed" is not.
- Correctness 2: leading zeros for numeric-typed codes are not warned about.
- Completeness 1: no non-conversion reporting.
- Clarity 2.

**6 Dates and times.** `pd.read_excel("dates.xlsx")` → [1,1,2,2,1,2]
- Ergonomics 1: no documented way to get the stored serial numbers.
- Failure 1: a stray text cell silently makes the column object, with no message.
- Findability 2: only "Parsing dates" for text dates.
- Correctness 2: partial coverage.
- Completeness 1: no times of day, no 1904 system and no stored numbers.
- Clarity 2.

**7 Missing values and errors.** `pd.read_excel(p, na_values=["NA",".","-","#DIV/0!"])` → [1,1,1,3,2,3]
- Ergonomics 1: `#DIV/0!` is not in the default list, and errors cannot be told apart from blanks without several calls.
- Failure 1: nothing says errors are reported. Only a `verbose` count exists.
- Findability 1: only the function reference and example arguments.
- Completeness 2: the default NA list is shown, but there is no error-versus-blank distinction.

**8 Every sheet.** `pd.read_excel(p, sheet_name=None)` → [3,1,3,3,2,3]
- Failure 1: the docs do not say what an empty sheet does.
- Completeness 2: no edge cases.

**9 Write a table.** `df.to_excel("out.xlsx", index=False)` → [1,0,3,3,1,3]
- Ergonomics 1: `index=True` is the default, so an extra column is written. An existing file is overwritten.
- Failure 0: the docs say an existing file is overwritten, with no message.
- Completeness 1: what each column becomes in Excel is not described.

**10 Write several tables.** `with pd.ExcelWriter("o.xlsx") as w: a.to_excel(w, sheet_name="A")` and so on, then `startrow` for the second table → [1,1,2,3,1,2]
- Ergonomics 1: the user creates and fills a writer. Titles need engine-level code that is not shown.
- Failure 1: sheet names containing `/` are not covered.
- Findability 2: the two-tables-on-one-sheet case is only in the docstring.
- Completeness 1: titles above tables are not covered.
- Clarity 2: `overlay` appears to need append mode, which is confusing.

**11 Format the output.** `df.to_excel("o.xlsx", freeze_panes=(1,0), autofilter=True)`, then Styler CSS for bold and number formats → [1,1,3,3,2,2]
- Ergonomics 1: Styler is needed for bold and percent. No autofit exists, and widths need the engine.
- Failure 1: unknown column names are not covered.
- Completeness 2: widths are not covered.
- Clarity 2: the formatting steps are split across pages.

**12 Fill an existing workbook.** `with pd.ExcelWriter(p, mode="a", engine="Library B", if_sheet_exists="replace") as w: new.to_excel(w, sheet_name="Data", index=False)`, plus a second writer or overlay for C4 and C5 → [1,0,2,3,2,3]
- Ergonomics 1: it takes several calls, and charts and images are lost.
- Failure 0: the docs say charts are silently lost.
- Findability 2: only the docstrings cover append mode.
- Completeness 2: what happens to cell formats is not stated.

**13 Labels.** `df.to_excel(o, header=[labels], index=False)`, with value labels mapped by hand → [1,1,1,2,1,1]
- Everything is manual. Only the header-alias argument is documented.
- Failure 1: the docs are silent on a code with no value label.

---

## Library B (openpyxl-like)

**1 Install.** `pip install Library B` → [3,1,2,3,2,3]
- Failure 1: nothing on what to do when an install fails.
- Findability 2: the README has no install command. It is in the tutorial.
- Completeness 2: optional lxml and pillow are mentioned, but not Python versions or platforms.

**2 Read a sheet.** `rows = list(load_workbook(p).active.values); df = DataFrame(rows[1:], columns=rows[0])` → [1,1,2,2,2,2]
- Ergonomics 1: no table reader, so several calls.
- Failure 1: a missing file is not covered.
- Findability 2: the DataFrame conversion is on a separate interop page.
- Correctness 2: the header example assumes an index column written by Library A.
- Completeness 2: no per-column typing.
- Clarity 2.

**3 Choose what to read.** `wb = load_workbook(p, read_only=True); ws = wb["Sales 2024"]; ws["B5":"F40"]`; `wb.sheetnames` → [1,1,2,2,2,3]
- Ergonomics 1: several calls, and the result is cells, not a table.
- Failure 1: a wrong sheet name is not covered.
- Findability 2.
- Correctness 2: the tutorial says "Workbook.sheetname", a typo.
- Completeness 2: no values-to-table step for a range.

**4 Header and names.** manual: read the rows, then build names by hand → [1,1,1,2,1,2]
- No header or name handling. Only merged-cell behaviour is documented: the value sits in the top-left cell.

**5 Column types.** manual conversion loop → [1,1,0,0,0,0]
- Not covered. No column types, no conversion reporting.

**6 Dates and times.** `[c.value for c in ws["A"]]`, `cell.internal_value` → [1,1,3,3,2,3]
- Ergonomics 1: there is no table reader. Getting stored serial numbers is not clearly documented.
- Failure 1: a text cell in a date column is not covered.
- Completeness 2: reading times of day and stored numbers is missing.

**7 Missing values and errors.** manual `None` and `data_type` checks → [1,1,1,2,1,1]
- Only `check_error` and `data_type` appear in the API listing.

**8 Every sheet.** `{ws.title: list(ws.values) for ws in wb}` → [1,2,2,3,1,2]
- Ergonomics 1: only the tutorial's "loop through worksheets", with no per-sheet table step.
- Failure 2: `iter_rows` returns an empty tuple for an empty sheet.
- Findability 2.
- Completeness 1: no collection by name.
- Clarity 2.

**9 Write a table.** `for r in dataframe_to_rows(df, index=False): ws.append(r)`; `wb.save("out.xlsx")` → [1,0,2,3,1,2]
- Ergonomics 1: several calls and an object the user creates and saves.
- Failure 0: the docs say `save` overwrites existing files without warning.
- Findability 2.
- Completeness 1: missing values, categorical and logical handling are not covered.
- Clarity 2.

**10 Write several tables.** `wb.create_sheet("A")` ×3 plus `append`; `ws.cell(row, col, value)` for titles → [1,1,2,3,2,2]
- Ergonomics 1: manual placement.
- Failure 1: sheet names containing `/` are not covered.
- Findability 2: the two-tables case is not found.
- Completeness 2: no start-row guidance.
- Clarity 2.

**11 Format the output.** loop `cell.font = Font(bold=True)`, `cell.number_format = "0.0%"`, `ws.auto_filter.ref`, `ws.freeze_panes` → [1,1,3,2,2,2]
- Ergonomics 1: per-cell loops, and no autofit.
- Failure 1: column names do not exist as a concept here.
- Correctness 2: the filters page has typos (`CustomerFilter`, `filters.filter`).
- Completeness 2: no width fitting. `freeze_panes` has no example.
- Clarity 2: the filter examples are heavy.

**12 Fill an existing workbook.** `wb = load_workbook(p); ws = wb["Data"]; ws.delete_rows(1, ws.max_row); ...; wb["Cover"]["C4"] = 1250; wb.save(p)` → [1,1,2,3,1,2]
- Ergonomics 1: several calls.
- Failure 1: the docs say shapes are lost but do not say what happens to the chart.
- Findability 2: the warning sits in the tutorial.
- Completeness 1: what is kept or lost is not stated for charts and formats.
- Clarity 2.

**13 Labels.** manual `ws.append(labels)` and manual value mapping → [1,1,0,0,0,0]
- Not covered.

---

## Library C (polars-like)

**1 Install.** `pip install Library C fastexcel xlsxwriter` → [2,1,3,2,2,3]
- Ergonomics 2: Excel support needs extra packages named only in the guide.
- Failure 1: the docs point to the install guide but do not say what to do on a failed build.
- Correctness 2: the guide has typos ("xlswriter", "xls2csv").
- Completeness 2: the platform notes (old CPU, Rosetta) are given, but not Python versions.

**2 Read a sheet.** `pl.read_excel("report.xlsx")` → [3,1,3,3,2,2]
- Failure 1: a missing file is not covered.
- Completeness 2: the inferred type per column is not listed.
- Clarity 2: no result is shown.

**3 Choose what to read.** `pl.read_excel(p, sheet_name="Sales 2024", read_options={"header_row":4, "use_columns":"B:F", "n_rows":35})`; `fastexcel.read_excel(p).sheet_names` → [2,1,2,3,2,2]
- Ergonomics 2: a zero-based header and a nested `read_options` dict. Listing sheets is a second library.
- Failure 1: a wrong sheet name is not covered.
- Findability 2: header and range options are only reachable through the `read_options` link.
- Completeness 2.
- Clarity 2.

**4 Header and names.** `read_options={"column_names":[...]}` → [1,1,1,2,1,2]
- Names must be written by hand. Duplicate, blank and two-row headers are not covered.

**5 Column types.** `pl.read_excel(p, schema_overrides={"zip": pl.Utf8, "amount": pl.Float64}, infer_schema_length=None)` → [1,1,2,3,2,2]
- Ergonomics 1: no way to list the cells that did not convert.
- Failure 1: what a failed cast does is not covered.
- Findability 2: only the docstring.
- Completeness 2: the inference-length trap is mentioned, but not reporting.
- Clarity 2.

**6 Dates and times.** `pl.read_excel(p, schema_overrides={"dt": pl.Date})` → [1,1,1,2,1,1]
- Only one docstring example. No times, no 1904, no stored numbers, and a text cell is not covered.

**7 Missing values and errors.** `pl.read_excel(p, engine="xlsx2csv", read_options={"null_values":[...]})` → [1,1,1,2,1,1]
- No null-value argument on `read_excel`, only a pointer to `read_csv`. Excel errors are not mentioned.

**8 Every sheet.** `pl.read_excel(p, sheet_id=0, raise_if_empty=False)` → [3,2,1,3,3,2]
- Failure 2: an empty sheet raises `NoDataError` by default, which names the problem. The `raise_if_empty` fix is documented.
- Findability 1: only the docstring, not the guide.
- Clarity 2: "set 0 to load all sheets" is cryptic.

**9 Write a table.** `df.write_excel("out.xlsx")` → [3,1,3,2,1,2]
- Failure 1: the docs do not say what happens when the file exists.
- Correctness 2: "xlswriter" typo.
- Completeness 1: what each column becomes is not described. Missing values and categorical are not covered.
- Clarity 2.

**10 Write several tables.** `with Workbook("o.xlsx") as wb: a.write_excel(wb, "A"); ...`; two tables on one sheet via `position=` plus `ws.write` for titles → [1,1,2,3,2,3]
- Ergonomics 1: the user creates the workbook object and calls several times.
- Failure 1: sheet names containing `/` are not covered.
- Findability 2: the worked example is only in the docstring.
- Completeness 2: three sheets are implied, not shown.

**11 Format the output.** `df.write_excel("o.xlsx", column_formats={"share":"0.0%","amount":"#,##0"}, header_format={"bold":True}, autofit=True, freeze_panes="A2", autofilter=True)` → [3,1,2,3,3,3]
- Failure 1: a format for a missing column is not covered.
- Findability 2: the guide only points to the API docs.

**12 Fill an existing workbook.** not possible: `write_excel` creates a workbook → [0,1,0,1,0,0]
- Editing an existing file is not offered. The line about writing to an existing workbook can mislead.

**13 Labels.** manual renaming and value mapping → [1,1,0,0,0,0]
- Not covered.

---

```json
{"D": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [3,3,3,3,3,3], "13": [3,3,3,3,3,3]},
 "A": {"1": [2,1,2,3,2,3], "2": [3,1,3,3,2,2], "3": [2,1,2,3,2,2], "4": [2,1,2,2,1,2], "5": [1,1,2,2,1,2], "6": [1,1,2,2,1,2], "7": [1,1,1,3,2,3], "8": [3,1,3,3,2,3], "9": [1,0,3,3,1,3], "10": [1,1,2,3,1,2], "11": [1,1,3,3,2,2], "12": [1,0,2,3,2,3], "13": [1,1,1,2,1,1]},
 "B": {"1": [3,1,2,3,2,3], "2": [1,1,2,2,2,2], "3": [1,1,2,2,2,3], "4": [1,1,1,2,1,2], "5": [1,1,0,0,0,0], "6": [1,1,3,3,2,3], "7": [1,1,1,2,1,1], "8": [1,2,2,3,1,2], "9": [1,0,2,3,1,2], "10": [1,1,2,3,2,2], "11": [1,1,3,2,2,2], "12": [1,1,2,3,1,2], "13": [1,1,0,0,0,0]},
 "C": {"1": [2,1,3,2,2,3], "2": [3,1,3,3,2,2], "3": [2,1,2,3,2,2], "4": [1,1,1,2,1,2], "5": [1,1,2,3,2,2], "6": [1,1,1,2,1,1], "7": [1,1,1,2,1,1], "8": [3,2,1,3,3,2], "9": [3,1,3,2,1,2], "10": [1,1,2,3,2,3], "11": [3,1,2,3,3,3], "12": [0,1,0,1,0,0], "13": [1,1,0,0,0,0]}}
```
