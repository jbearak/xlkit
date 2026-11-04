# Judge response: sonnet, typescript round 3

Scores are [ergonomics, failure, findability, correctness, completeness, clarity].
Library A is the R package. Library B is the SheetJS-style CE library. Library C is the ExcelJS-style library.
Tasks 5 and 13 are not common to B or C. I scored them anyway.

Library B notes: it is a community-edition library. Styling, frozen panes, images and charts are marked as Pro only. Its docs say its parsers and writers "focus on raw data".

---

## Library A (R)

**Task 1 Install**
```r
install.packages("remotes"); remotes::install_github("Library A")
```
- Ergonomics 2: two calls, not on CRAN, and it needs a Rust toolchain.
- The other five scores are 3. The docs give the command, R 4.2+, macOS/Windows/Linux, Rust/Rtools, and the `building needs cargo` failure with the fix (restart R, check `Sys.which("cargo")`).

**Task 2 Read a sheet**
```r
scores <- read_xlsx("report.xlsx")
```
All 3. The doc has a type table covering integer, double, logical, Date, POSIXct, hms and character. `reprot.xlsx` stops with "does not exist. Did you mean report.xlsx?".

**Task 3 Choose what to read**
```r
read_xlsx(path, sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets(path)
```
All 3. Each part is one call with Excel-style arguments. `Sales 2042` stops and lists the sheets, with a "did you mean".

**Task 4 Header and names**
```r
read_xlsx(path, sheet = "Headers", names = "snake")
read_xlsx(path, sheet = "Two-row header", header = 4:5)
```
All 3. Header rows are given by row number. A `New names:` message says which header each name came from. The original text is kept in the `label` attribute.

**Task 5 Column types**
```r
df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number")); xlsx_problems(df)
```
All 3. The warning names C2003 and C2004 and points to `xlsx_problems()`. The docs are honest that leading zeros typed as numbers cannot be restored.

**Task 6 Dates and times**
```r
read_xlsx(path)                                              # also dates1904.xlsx
read_xlsx(path, types = c(day = "number", stamp = "number", clock = "number"))   # or dates = FALSE
```
All 3. The docs cover 1904, UTC, the 1900 leap-day bug, and the stray `unknown` cell (the message names the cell; `types = date` makes it NA with a warning).

**Task 7 Missing values and errors**
```r
df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-")); xlsx_problems(df)
```
All 3. A warning lists the cells holding errors. `xlsx_problems()` tells errors from blanks.

**Task 8 Every sheet**
```r
all <- read_sheets("book.xlsx")
```
All 3. The docs say an empty sheet gives a tibble with no rows and no columns.

**Task 9 Write a table**
```r
write_xlsx(df, "out.xlsx")
```
All 3. The docs have a type-to-Excel table. An existing file stops with an error that lists its sheets and suggests `replace = TRUE`.

**Task 10 Write several tables**
```r
write_xlsx(list(A = a, B = b, C = c), "wb.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "t.xlsx", gap = 2)
```
All 3. `Q1/Q2` stops before anything is written and suggests `Q1-Q2`.

**Task 11 Format the output**
```r
write_xlsx(df, "f.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
All 3. Bold header, freeze and auto widths are defaults. A misspelt column name stops with a "did you mean".

**Task 12 Fill an existing workbook**
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
All 3. The two sheets are two parts, each one call. The docs say everything else is copied byte for byte. They list what is refused. They say the library warns when a fixed chart range no longer matches the data.

**Task 13 Labels**
```r
write_xlsx(df, "survey.xlsx", header = "labels")      # value labels are the default
df <- read_xlsx("survey.xlsx", names = "snake")       # long headers kept in the label attribute
```
- Completeness 2: the long-header example only shows `snake`. Shortening is left to `names = "stata"` (at most 32 characters) or a function, and the section does not demonstrate it.
- The other five scores are 3. A code with no value label gives a message naming the cells and the fix.

---

## Library B (SheetJS-style)

**Task 1 Install**
```js
npm i --save <CDN tarball URL>
```
- Ergonomics 2: it is one command, but not the usual `npm i xlsx`. The registry copy is documented as out of date.
- Failure 1: the library is pure JS with no system requirement. The docs only show the Yarn usage-error workaround and say nothing about missing requirements.
- Correctness 2: the install page says `XLSX.stream.set_readable` while the API page says `XLSX.utils.set_readable`. It also says Boolean is a type `n` number.
- Completeness 2: no supported Node versions or platforms, and no system requirements.
- Findability 3 and clarity 3: the NodeJS install page is clear with tabs.

**Task 2 Read a sheet**
```js
const wb = XLSX.readFile("report.xlsx", {cellDates: true});
const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
```
- Ergonomics 1: two calls, the first sheet is reached by a zero-based index, and by default dates come back as numbers unless `cellDates` is set.
- Failure 1: the docs do not say what `readFile` does for a missing file.
- Findability 2: the answer is spread over the Reading Files page, the Arrays page and the import tutorial.
- Correctness 2: the "Type n includes Boolean" wording contradicts the `b` type.
- Completeness 2: types are per cell. The docs do not say that whole numbers and decimals are both JS numbers.
- Clarity 2: the reader has to assemble several pages.

**Task 3 Choose what to read**
```js
const wb = XLSX.readFile("sales.xlsx");
XLSX.utils.sheet_to_json(wb.Sheets["Sales 2024"], {range: "B5:F40"}); wb.SheetNames;
```
- Ergonomics 2: two calls, with an A1 range string and a name-keyed sheet.
- Failure 1: a misspelt name is not documented. `Sheets[...]` would be undefined and the docs are silent.
- Findability 2 and completeness 2: sheet names are on the processing page and the range option is on the Arrays page. There is no mention of a misspelt name.
- Correctness 3 and clarity 3.

**Task 4 Header and names**
```js
const aoa = XLSX.utils.sheet_to_json(ws, {header: 1});   // then build names by hand, filling merged group names
const rows = XLSX.utils.sheet_to_json(ws);                // duplicates become Total, Total_1
```
- Ergonomics 1: the two-row header with a merged group name needs manual code.
- Failure 1: duplicates are renamed silently with an `_1` suffix. The docs say nothing about a blank header cell. No message says where each name came from.
- Findability 2: the `foo_1` rule sits in the sheet_to_json option notes, and the merged-header handling is in the import tutorial.
- Completeness 1: no blank-header handling, no cleaning of `%` or spaces, and no two-row header helper.
- Clarity 2.
- Correctness 3.

**Task 5 Column types**
```js
const rows = XLSX.utils.sheet_to_json(ws, {raw: false});   // then String(zip), Number(amount) and a loop to collect failures
```
- Ergonomics 1: there is no types option.
- Failure 1: the docs say `sheet_to_json` does no field validation. There is no report of unconverted cells.
- Findability 1: only the `raw` option and the cell `w` field are relevant.
- Correctness 2: what is said is right but does not address the task.
- Completeness 1: the main path only.
- Clarity 1.

**Task 6 Dates and times**
```js
const wb = XLSX.readFile("dates.xlsx", {cellDates: true});
XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);   // second read without cellDates gives the stored numbers
```
- Ergonomics 1: the default gives numbers, and `cellDates` is needed for dates. Reading both forms means two reads.
- Failure 1: the docs do not say what happens with an `unknown` text cell in a date column.
- Findability 2: the CSF features "Dates and Times" page.
- Correctness 2: the `date1904` snippet has its comments inverted. The UTC-versus-local note is confusing.
- Completeness 2: times of day and automatic 1904 handling are not made explicit.
- Clarity 2.

**Task 7 Missing values and errors**
```js
XLSX.utils.sheet_to_json(ws, {defval: null});   // then map "NA", "." and "-" by hand; check ws[addr].t === "e" for errors
```
- Ergonomics 1: there is no `na` option, so you need a loop over cells.
- Failure 1: what `sheet_to_json` does with `#N/A` or `#DIV/0!` is not documented.
- Findability 1: the `e` type and `defval` are on different pages with no pointer.
- Correctness 2: the facts are right but thin.
- Completeness 1: the main path only.
- Clarity 2.

**Task 8 Every sheet**
```js
const wb = XLSX.readFile("b.xlsx");
const all = Object.fromEntries(wb.SheetNames.map(n => [n, XLSX.utils.sheet_to_json(wb.Sheets[n])]));
```
- Ergonomics 1: one read plus a call per sheet.
- Failure 2: the docs say functions treat a sheet with no `!ref` as empty, but do not state the output of `sheet_to_json` for it.
- Findability 2, completeness 2 and clarity 2: the pieces exist, but there is no every-sheet recipe.
- Correctness 3.

**Task 9 Write a table**
```js
const ws = XLSX.utils.json_to_sheet(rows, {cellDates: true});
const wb = XLSX.utils.book_new(ws, "Sheet1"); XLSX.writeFile(wb, "out.xlsx");
```
- Ergonomics 1: three calls. Date objects get a date-only format by default, so date-times lose their time display.
- Failure 1: the docs do not say what happens when `out.xlsx` exists.
- Findability 2: the export tutorial and the array utilities.
- Correctness 2: the tutorial's `sheet_add_aoa(worksheet, ...)` uses a variable that was never declared in the array example.
- Completeness 2: the cell types are covered, but overwrite behaviour, categorical columns and the date-time format are not.
- Clarity 3.

**Task 10 Write several tables**
```js
// 3 sheets: 3x json_to_sheet, book_new, 3x book_append_sheet, writeFile
// 2 tables on one sheet: aoa_to_sheet for title, sheet_add_json(ws, t1, {origin: "A2"}), sheet_add_aoa title at computed row, sheet_add_json at computed origin
```
- Ergonomics 1: many calls and row arithmetic.
- Failure 1: only duplicate names are documented as errors. Characters such as `/` are not mentioned.
- Findability 2 and completeness 2: the `origin` option is documented. Invalid sheet-name rules are not.
- Correctness 3 and clarity 3.

**Task 11 Format the output**
```js
ws["B2"].z = "0.0%"; ws["!cols"] = [{wch: 12}]; ws["!autofilter"] = {ref: "A1:F40"}   // no bold or freeze in CE
```
- Ergonomics 0: bold header and frozen panes are Pro-only, so the full scenario is not possible. Formats are set per cell, widths are computed by hand, and there is no by-column format.
- Failure 1: there is no column-name format API, and the docs do not say what happens.
- Findability 2: spread over the number-format, column-properties and sheet pages.
- Correctness 2: the column page says `cellStyles: true` is required for widths, but the tutorials write `!cols` without it.
- Completeness 2: the Pro-only items are mentioned, but there is no way to do them.
- Clarity 2.

**Task 12 Fill an existing workbook**
```js
const wb = XLSX.readFile("results.xlsx");
wb.Sheets["Data"] = XLSX.utils.json_to_sheet(rows);
XLSX.utils.sheet_add_aoa(wb.Sheets["Cover"], [[1250], [new Date()]], {origin: "C4"}); XLSX.writeFile(wb, "results.xlsx");
```
- Ergonomics 0: charts, images and styles are Pro-only, so keeping the template as it was is not possible.
- Failure 1: the docs only say unlisted features "may not be serialized" and that Pro adds graphs. That does not say the chart is lost.
- Findability 1: the Pro tips sit in the options pages.
- Correctness 2, completeness 1 and clarity 2.

**Task 13 Labels**
```js
// manual: header row from a labels array, value labels via a lookup map, aoa_to_sheet
```
- Ergonomics 1 and failure 1: possible only by hand, and the docs say nothing about it.
- The four documentation scores are 0: the docs have no Stata support, and the task is not covered.

---

## Library C (ExcelJS-style)

**Task 1 Install**
```
npm install Library C
```
- Ergonomics 3.
- Failure 1: the library is pure JS, and the docs do not say what happens when an install fails.
- Completeness 2: no system requirements. The language-version information is only about ES5 builds and polyfills.
- Findability 3, correctness 3 and clarity 3: the Installation heading is first in the README.

**Task 2 Read a sheet**
```js
const wb = new Excel.Workbook(); await wb.xlsx.readFile("report.xlsx");
const rows = []; wb.worksheets[0].eachRow((r, n) => { if (n > 1) rows.push(r.values); });
```
- Ergonomics 1: you create an object, fill it by reading, then loop. There is no table result.
- Failure 1: the docs do not say what `readFile` does for a missing file.
- Findability 2: "Reading XLSX" exists but does not say how to get a table.
- Correctness 2: the Reading XLSX section says "Options supported when reading CSV files".
- Completeness 2: the value types are listed, but the docs do not say when a cell becomes a Date.
- Clarity 2.

**Task 3 Choose what to read**
```js
const ws = wb.getWorksheet("Sales 2024");
for (let r = 5; r <= 40; r++) rows.push([2,3,4,5,6].map(c => ws.getCell(r, c).value));
const names = wb.worksheets.map(w => w.name);
```
- Ergonomics 1: there is no range read, so you loop with numeric rows and columns.
- Failure 1: the README does not say what a wrong name gives. The typings only show `Worksheet | undefined`.
- Findability 2 and completeness 1: sheet access and listing are documented, but there is no range read.
- Correctness 3 and clarity 3.

**Task 4 Header and names**
```js
// read row 1 .values, dedupe and clean names by hand; for a two-row header read row 1 (merged cells share the master value) and row 2, join
```
- Ergonomics 1: it is manual.
- Failure 1: nothing is said about blank or duplicate headers.
- Findability 1 and correctness 1: only the merged-cell behaviour is relevant.
- Completeness 0: the task is not covered.
- Clarity 1.
- The Total / blank case is not covered by any feature.

**Task 5 Column types**
```js
// cell.text for zip; Number(cell.value) for amount; loop and collect NaN cells
```
- Ergonomics 1: there is no types option.
- Failure 1: nothing is said about unconvertible cells.
- Findability 1, completeness 1 and clarity 1: only `cell.text` and the value types are relevant.
- Correctness 2: nothing is wrong, but it does not address the task.

**Task 6 Dates and times**
```js
// per cell: cell.value is a Date when the cell is a date; no way to get raw stored numbers except converting back
```
- Ergonomics 1: loops over cells, with no raw-number option.
- Failure 1: the docs do not say what happens with an `unknown` text cell in a date column. `cell.type` can be tested.
- Findability 2: the Date Value entry.
- Correctness 2: 1904 appears only as a write-time property.
- Completeness 1: no times of day, no reading of 1904 files, and no stored numbers.
- Clarity 2.

**Task 7 Missing values and errors**
```js
// loop: cell.type === Excel.ValueType.Error -> value.error; null for blank; map "NA", "." and "-" by hand
```
- Ergonomics 1: there is no `na` option.
- Failure 2: the docs show that an error reads as `{error: '#N/A'}` with a list of error texts, but give no message.
- Findability 2: the Error Value and Null Value entries.
- Completeness 1: no handling of the missing-value codes.
- Clarity 2.
- Correctness 3.

**Task 8 Every sheet**
```js
wb.eachSheet((ws) => { out[ws.name] = []; ws.eachRow(r => out[ws.name].push(r.values)); });
```
- Ergonomics 1: a loop with manual row conversion.
- Failure 1: the docs do not say what happens with an empty sheet.
- Completeness 2: iteration is shown, but not building tables.
- Findability 3, correctness 3 and clarity 3.

**Task 9 Write a table**
```js
const ws = wb.addWorksheet("Data"); ws.columns = [{header: "id", key: "id"}, ...];
ws.addRows(rows); await wb.xlsx.writeFile("out.xlsx");
```
- Ergonomics 1: create, fill and save.
- Failure 1: the docs do not say what happens when the file exists.
- Findability 2: Writing XLSX and Add Rows are separate sections.
- Completeness 1: no type-to-Excel mapping beyond the value types, and no date-time format, missing-value handling or overwrite behaviour.
- Correctness 3 and clarity 3.

**Task 10 Write several tables**
```js
// addWorksheet x3 + addRows x3; on one sheet: addRow(title), addRows(t1), addRow([]), addRow([]), addRow(title2), addRows(t2)
```
- Ergonomics 1: many calls.
- Failure 1: the README only mentions in the release notes that worksheet names are validated. It gives no message.
- Findability 2 and completeness 2: no sheet-name rules.
- Correctness 3 and clarity 3.

**Task 11 Format the output**
```js
ws.getRow(1).font = {bold: true}; ws.getColumn("share").numFmt = "0.0%"; ws.getColumn("amount").numFmt = "#,##0";
ws.views = [{state: "frozen", ySplit: 1}]; ws.autoFilter = "A1:F1"; // widths: loop eachCell, set column.width
```
- Ergonomics 1: several calls, and there is no auto-fit for widths.
- Failure 1: the docs do not say what happens for an unknown column key.
- Completeness 2: no content-fit widths.
- Findability 3, correctness 3 and clarity 3: Frozen Views, Auto Filters and Styles are clearly covered.

**Task 12 Fill an existing workbook**
```js
await wb.xlsx.readFile("results.xlsx");
const d = wb.getWorksheet("Data"); d.spliceRows(1, d.rowCount); d.addRows(rows);
const c = wb.getWorksheet("Cover"); c.getCell("C4").value = 1250; c.getCell("C5").value = new Date();
await wb.xlsx.writeFile("results.xlsx");
```
- Ergonomics 1: several calls.
- Failure 1: the docs do not mention charts or what a read-modify-write keeps or loses.
- Findability 1 and correctness 2: there is no template guidance, so a reader may assume things are kept.
- Completeness 1: only the read-modify-write path is shown.
- Clarity 2.

**Task 13 Labels**
```js
// manual: write header from a labels array, map codes to labels before addRows
```
- Ergonomics 1 and failure 1: possible only by hand, and the docs say nothing about it.
- The four documentation scores are 0: the task is not covered.

---

```json
{"A": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [3,3,3,3,3,3], "13": [3,3,3,3,2,3]},
 "B": {"1": [2,1,3,2,2,3], "2": [1,1,2,2,2,2], "3": [2,1,2,3,2,3], "4": [1,1,2,3,1,2], "5": [1,1,1,2,1,1], "6": [1,1,2,2,2,2], "7": [1,1,1,2,1,2], "8": [1,2,2,3,2,2], "9": [1,1,2,2,2,3], "10": [1,1,2,3,2,3], "11": [0,1,2,2,2,2], "12": [0,1,1,2,1,2], "13": [1,1,0,0,0,0]},
 "C": {"1": [3,1,3,3,2,3], "2": [1,1,2,2,2,2], "3": [1,1,2,3,1,3], "4": [1,1,1,1,0,1], "5": [1,1,1,2,1,1], "6": [1,1,2,2,1,2], "7": [1,2,2,3,1,2], "8": [1,1,3,3,2,3], "9": [1,1,2,3,1,3], "10": [1,1,2,3,2,3], "11": [1,1,3,3,2,3], "12": [1,1,1,2,1,2], "13": [1,1,0,0,0,0]}}
```
