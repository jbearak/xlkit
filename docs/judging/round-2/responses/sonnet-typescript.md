# Round 2 judging: Library A, Library B, Library C

Score order: [ergonomics, failure, findability, correctness, completeness, clarity].
Libraries scored: A, B, C. No library in this file is Stata, so there is no Stata entry.
Library A is a JavaScript/TypeScript workbook-object library, Library B is the R package, Library C is a JavaScript/TypeScript sheet-object library (community edition).
A scenario with several operations joined by "and" counts all calls. A loop counts as several calls.

---

## Library A

**1 Install.** `npm install Library A`.
Ergonomics 3. Failure 1: nothing on install failures or system requirements. Findability 3. Correctness 3. Completeness 1: command only; versions appear only in the ES5 note and the changelog. Clarity 2: no result described.

**2 Read a sheet.**
```js
const wb = new Excel.Workbook(); await wb.xlsx.readFile('report.xlsx');
wb.worksheets[0].eachRow((row, n) => rows.push(row.values));
```
Ergonomics 1: object to create, then manual row loop; no table. Failure 1: missing file is not described. Findability 3 ("Reading XLSX"). Correctness 2: the option table under "Reading XLSX" says "reading CSV", and examples use `Excel` while the import is `Library A`. Completeness 1: no column-type mapping to a table. Clarity 2: no result shown.

**3 Choose what to read.**
```js
const ws = wb.getWorksheet('Sales 2024'); const names = wb.worksheets.map(w => w.name);
for (let r = 5; r <= 40; r++) for (let c = 2; c <= 6; c++) ws.getRow(r).getCell(c).value;
```
Ergonomics 1: no range read; manual loops. Failure 1: a misspelled name is not described (the typings return `undefined`). Findability 2: sheets are easy to find, a range read is not. Correctness 3. Completeness 1: no range or title-skipping read. Clarity 2.

**4 Header and names.** Manual: `ws.getRow(1).values`, then dedupe and blank-fill by hand; merge group names by hand.
Ergonomics 1. Failure 1: not described. Findability 0, correctness 0, completeness 0, clarity 0: reading headers is not covered (the `columns` header is for building sheets).

**5 Column types.** Manual: `String(cell.value).padStart(5,'0')`; `typeof v === 'number'` check for `amount`.
Ergonomics 1. Failure 1: mixed cells come back as-is; not described. Findability 1: only the Value Types sections imply it. Correctness 2. Completeness 1. Clarity 2.

**6 Dates and times.**
```js
const wb = new Excel.Workbook(); await wb.xlsx.readFile('dates.xlsx');  // cell.value is a Date for date cells
```
Stored numbers and the 1904 read are not documented; the user converts by hand.
Ergonomics 1. Failure 1: a text cell such as `unknown` is not described. Findability 2: only `date1904` for writing, and Date Value. Correctness 2: the date system is documented only for writing. Completeness 1. Clarity 2.

**7 Missing values and errors.** Manual loop: map `'NA'`, `'.'`, `'-'` to null; test `cell.type === Excel.ValueType.Error`.
Ergonomics 1. Failure 2: errors read as `{error:'#N/A'}` objects, so they are distinguishable and documented, but there is no message. Findability 2. Correctness 3. Completeness 1: no missing-code mapping. Clarity 2.

**8 Every sheet.**
```js
const out = {}; wb.eachSheet(ws => { out[ws.name] = ws.getSheetValues(); });
```
Ergonomics 1: loop. Failure 1: the empty-sheet case is not described. Findability 2. Correctness 3. Completeness 1: no conversion to tables. Clarity 2.

**9 Write a table.**
```js
const ws = wb.addWorksheet('Sheet1'); ws.columns = [...]; ws.addRows(rows); ws.getColumn('d').numFmt = 'yyyy-mm-dd';
await wb.xlsx.writeFile('out.xlsx');
```
Ergonomics 1: create, fill, save. Failure 1: an existing file is not described. Findability 3. Correctness 2: `createAndFillWorkbook()` is a placeholder and `Excel` is not the import name. Completeness 2: value types are listed, overwrite is not. Clarity 2.

**10 Write several tables.**
```js
wb.addWorksheet('A').addRows(a); wb.addWorksheet('B').addRows(b); wb.addWorksheet('C').addRows(c);
ws.addRow(['Title 1']); ws.addRows(t1); ws.addRow([]); ws.addRow([]); ws.addRow(['Title 2']); ws.addRows(t2);
```
Ergonomics 1. Failure 1: `Q1/Q2` appears only as a changelog item, with no message shown. Findability 2. Correctness 2: one snippet redeclares `const sheet` several times. Completeness 2. Clarity 2.

**11 Format the output.**
```js
ws.getRow(1).font = {bold:true}; ws.getColumn('share').numFmt = '0.0%'; ws.getColumn('amount').numFmt = '#,##0';
ws.views = [{state:'frozen', ySplit:1}]; ws.autoFilter = 'A1:E1'; /* widths: compute and set column.width by hand */
```
Ergonomics 1: several calls, and no auto-fit. Failure 1: an unknown column is not described. Findability 3. Correctness 3. Completeness 2: no auto-fit width. Clarity 3.

**12 Fill an existing workbook.**
```js
await wb.xlsx.readFile('results.xlsx'); wb.getWorksheet('Data').spliceRows(1, n); /* add rows */
wb.getWorksheet('Cover').getCell('C4').value = 5; ...getCell('C5').value = new Date(); await wb.xlsx.writeFile('results.xlsx');
```
Ergonomics 1. Failure 1: the chart is not mentioned. Findability 1: no template section, only separate read and write. Correctness 1: silence on what a round trip loses can mislead. Completeness 0: keeps and loses are not covered. Clarity 1.

**13 Labels.** Manual: map codes to labels in JS, write a header array; on read, keep long headers in a separate object.
Ergonomics 1. Failure 1. Findability 0, correctness 0, completeness 0, clarity 0: not covered.

---

## Library B

**1 Install.**
```r
install.packages("remotes"); remotes::install_github("Library B")
```
Ergonomics 2: two calls, plus a separate Rust install. Other four scores 3: failure gives the `building needs cargo` message with a fix; platforms, R version and requirements are all stated.

**2 Read a sheet.** `read_xlsx("report.xlsx")`. All 3: type table given; a misspelled path gives "Did you mean report.xlsx?".

**3 Choose what to read.** `read_xlsx(p, sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets(p)`. All 3: a wrong name lists the sheets.

**4 Header and names.** `read_xlsx(p, sheet = "Headers")`; `read_xlsx(p, sheet = "Two-row header", header = 4:5)`. All 3: "New names:" lists each repair; the header text is kept as a label.

**5 Column types.** `read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))`. All 3: the warning names the cells and points to `xlsx_problems()`.

**6 Dates and times.** `read_xlsx(p)`; `read_xlsx(p, types = c(day = "number", clock = "number"))`; the 1904 workbook reads the same way. All 3: the `unknown` cell is named.

**7 Missing values and errors.** `read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))`, then `xlsx_problems(df)`. All 3: the warning names the error cells.

**8 Every sheet.** `read_sheets(p)`. All 3: an empty sheet reads as an empty tibble, and the docs say so.

**9 Write a table.** `write_xlsx(df, "out.xlsx")`. All 3: type table given; an existing file stops with a fix.

**10 Write several tables.** `write_xlsx(list(S = a, D = b, N = c), p)`; `write_xlsx(list(R = list("T1" = a, "T2" = b)), p, gap = 2)`. All 3: `Q1/Q2` stops with a suggestion.

**11 Format the output.** `write_xlsx(sales, "s.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)`. All 3: bold, freeze and widths are defaults; a bad column name gets "Did you mean".

**12 Fill an existing workbook.**
```r
write_sheet(new_data, path, sheet = "Data"); write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Ergonomics 2: two calls. Failure 3: the docs say the chart stays. Findability 3. Correctness 2: the docs say "byte for byte" but also that the workbook is marked for recalculation; and `merge` is said to work "as in write_xlsx()", which has no `merge`. Completeness 3. Clarity 3.

**13 Labels.** `write_xlsx(df, "survey.xlsx", header = "labels")`; `read_xlsx("survey.xlsx", names = "snake")`. Failure 3: the message names the cells. Completeness 2: the read example does not shorten names (`age_at_first_birth` is still long); shortening needs the `"stata"` rule or a function. Other scores 3.

---

## Library C

**1 Install.** `npm i --save <tarball URL>` (after `npm rm --save xlsx` in an existing project).
Ergonomics 2: one command but a tarball URL, not a plain package name. Failure 1: nothing on a missing system requirement. Findability 2: nested under getting-started/installation. Correctness 3. Completeness 2: no Node versions or platforms. Clarity 3.

**2 Read a sheet.**
```js
const wb = XLSX.readFile('report.xlsx'); const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
```
Ergonomics 1: dates come back as numbers unless `cellDates: true`. Failure 1: a missing file is not described. Findability 2. Correctness 3. Completeness 2: types are per cell, not per column. Clarity 2.

**3 Choose what to read.**
```js
const wb = XLSX.readFile(f); const rows = XLSX.utils.sheet_to_json(wb.Sheets['Sales 2024'], {range: 'B5:F40'}); wb.SheetNames;
```
Ergonomics 2: two calls. Failure 1: a misspelled name is not described. Findability 2. Correctness 3. Completeness 2. Clarity 3.

**4 Header and names.** `sheet_to_json(ws)` renames duplicates `Total_1`; a two-row header needs `header: 1` and a manual merge using `!merges`.
Ergonomics 1. Failure 1: silent renaming, and blanks are not described. Findability 2. Correctness 3. Completeness 1: no blank-cell or two-row-header handling. Clarity 2.

**5 Column types.** Manual: `sheet_to_json(ws, {raw: false})` for text, then `typeof` checks.
Ergonomics 1. Failure 1: mixed cells stay as strings, silently. Findability 1. Correctness 2. Completeness 1. Clarity 2.

**6 Dates and times.**
```js
XLSX.utils.sheet_to_json(XLSX.readFile(f, {cellDates: true}).Sheets.Sheet1);  // again without cellDates for numbers
```
Ergonomics 2: two calls per part. Failure 1: a text cell is not described. Findability 2. Correctness 2: the `date1904` snippet has its branch comments swapped. Completeness 2: no text-in-date-column case. Clarity 3.

**7 Missing values and errors.** Manual: map `'NA'`, `'.'`, `'-'` by hand; inspect `ws[addr].t === 'e'`.
Ergonomics 1. Failure 1: what `sheet_to_json` does with error cells is not described. Findability 2. Correctness 3. Completeness 1. Clarity 2.

**8 Every sheet.**
```js
Object.fromEntries(wb.SheetNames.map(n => [n, XLSX.utils.sheet_to_json(wb.Sheets[n])]));
```
Ergonomics 1: loop. Failure 1: the empty-sheet guidance is for function authors. Findability 2. Correctness 3. Completeness 2. Clarity 2.

**9 Write a table.**
```js
const ws = XLSX.utils.json_to_sheet(rows, {cellDates: true}); const wb = XLSX.utils.book_new(ws, 'Sheet1'); XLSX.writeFile(wb, 'out.xlsx');
```
Ergonomics 1: three calls, and dates are numbers without `cellDates`. Failure 1: an existing file is not described. Findability 2. Correctness 2: one snippet uses `worksheet` where `ws` is defined. Completeness 2. Clarity 3.

**10 Write several tables.**
```js
XLSX.utils.book_append_sheet(wb, ws1, 'A'); ...; XLSX.utils.sheet_add_json(ws, t2, {origin: 'A' + row});
```
Ergonomics 1: several calls. Failure 1: invalid characters in sheet names are not described. Findability 2. Correctness 3. Completeness 2. Clarity 3.

**11 Format the output.** Number formats via `ws['B2'].z` per cell, widths via `!cols`, filter via `!autofilter`; bold header and frozen rows are not possible in the community edition.
Ergonomics 0. Failure 1: no column-name API, so the probe is not described. Findability 2. Correctness 3. Completeness 2. Clarity 3.

**12 Fill an existing workbook.**
```js
const wb = XLSX.readFile('results.xlsx', {cellStyles: true}); wb.Sheets.Data = XLSX.utils.json_to_sheet(rows);
XLSX.utils.sheet_add_aoa(wb.Sheets.Cover, [[1250]], {origin: 'C4'}); XLSX.writeFile(wb, 'results.xlsx');
```
Ergonomics 1. Failure 1: the docs only imply that charts and styles need the paid edition. Findability 1. Correctness 2. Completeness 1: keeps and loses are not listed. Clarity 2.

**13 Labels.** Manual: rewrite the header with `sheet_add_aoa`, map codes by hand; read with `header: [...]` and keep long headers in a side object.
Ergonomics 1. Failure 1. Findability 1: only a header-rewrite example. Correctness 2: that snippet uses an undefined `worksheet`. Completeness 0. Clarity 1.

---

```json
{"A": {"1": [3,1,3,3,1,2], "2": [1,1,3,2,1,2], "3": [1,1,2,3,1,2], "4": [1,1,0,0,0,0], "5": [1,1,1,2,1,2], "6": [1,1,2,2,1,2], "7": [1,2,2,3,1,2], "8": [1,1,2,3,1,2], "9": [1,1,3,2,2,2], "10": [1,1,2,2,2,2], "11": [1,1,3,3,2,3], "12": [1,1,1,1,0,1], "13": [1,1,0,0,0,0]},
 "B": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [2,3,3,2,3,3], "13": [3,3,3,3,2,3]},
 "C": {"1": [2,1,2,3,2,3], "2": [1,1,2,3,2,2], "3": [2,1,2,3,2,3], "4": [1,1,2,3,1,2], "5": [1,1,1,2,1,2], "6": [2,1,2,2,2,3], "7": [1,1,2,3,1,2], "8": [1,1,2,3,2,2], "9": [1,1,2,2,2,3], "10": [1,1,2,3,2,3], "11": [0,1,2,3,2,3], "12": [1,1,1,2,1,2], "13": [1,1,1,2,0,1]}}
```
