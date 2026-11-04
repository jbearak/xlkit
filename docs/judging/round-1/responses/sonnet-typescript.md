# Judge response: sonnet, typescript round 1

Libraries in the file: A (JavaScript, workbook/worksheet object API), B (JavaScript, utils-based API), C (R). The file has no Stata section, so only A, B and C are scored.

Score order everywhere: [ergonomics, failure, findability, correctness, completeness, clarity].

Judging notes:
- Where a library has no concept for the scenario (A and B have no column types, no header handling, no labels), the user's own code is counted as calls. That gives ergonomics 1, not 0.
- Where the docs say nothing about the task, correctness, completeness and clarity are low, per the rubric.
- For C tasks 5 and 7 the full list of problem cells needs `xlsx_problems()`, so I counted two calls.

---

## Library C (R)

### C1 Install
```r
install.packages("remotes")
remotes::install_github("Library C")
```
Scores [2,3,3,3,3,3]
- Ergonomics 2: two calls (remotes first, then install_github), and the package is not on CRAN.

### C2 Read a sheet
```r
scores <- read_xlsx("report.xlsx")
```
Scores [3,1,3,3,3,3]
- Failure 1: the docs never say what a missing path does. The messages table has no entry for it.

### C3 Choose what to read
```r
sales <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets("sales.xlsx")
```
Scores [3,3,3,3,3,3]

### C4 Header and names
```r
read_xlsx("messy.xlsx", sheet = "Headers", names = "snake")   # or default "unique"
read_xlsx("messy.xlsx", sheet = "Two-row header", header = 4:5)
```
Scores [3,3,3,3,3,3]
- Failure scored 3 because the docs say a repeat gets its column letter, a blank gets its letter, and the original header text is kept as the `label` attribute. No message is needed.

### C5 Column types
```r
df <- read_xlsx("messy.xlsx", sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores [2,3,3,3,3,3]
- Ergonomics 2: the warning names the first cells, but the complete list needs a second call, `xlsx_problems()`.

### C6 Dates and times
```r
read_xlsx("dates.xlsx")
read_xlsx("dates1904.xlsx")
read_xlsx("dates.xlsx", dates = FALSE)   # stored numbers
```
Scores [3,2,3,3,3,3]
- Failure 2: with `types = "date"` text becomes `NA` with a warning, but the docs show no date example. Under the default guess, a column holding "unknown" silently becomes character.

### C7 Missing values and errors
```r
df <- read_xlsx("messy.xlsx", sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores [2,3,3,3,3,3]
- Ergonomics 2: telling errors from blanks, in full, takes a second call.

### C8 Every sheet
```r
read_sheets("book.xlsx")
```
Scores [3,1,3,3,2,3]
- Failure 1: nothing says what an empty sheet gives. The reference says only that chart sheets error.
- Completeness 2: the empty-sheet edge case is missing.

### C9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores [3,3,3,3,3,3]

### C10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "book.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "results.xlsx", gap = 2)
```
Scores [3,2,3,3,3,3]
- Failure 2: the docs say an illegal sheet-name character is an error that says which value broke the limit. They do not show the message or say what to do.

### C11 Format the output
```r
write_xlsx(df, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores [3,1,3,3,3,3]
- Failure 1: the docs cover an unknown name in `types` and an unknown key in `styles`, but not an unknown name in `formats`.

### C12 Fill an existing workbook
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores [2,3,3,3,2,3]
- Ergonomics 2: two calls.
- Completeness 2: what is kept is detailed, but what is lost is only implied. `write_sheet` clears the cells it replaces, and formula results go stale.

### C13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")   # value labels are the default
df2 <- read_xlsx("survey.xlsx", names = "snake")   # long header kept as label attribute
```
Scores [3,3,3,3,3,3]
- Failure scored 3 because the docs say a code without a label is written as the code, with no message.

---

## Library A (JavaScript)

### A1 Install
```js
npm install Library A
```
Scores [3,1,3,3,2,3]
- Failure 1: nothing about install failures or system requirements.
- Completeness 2: the command is given, and Node version hints appear only in the ES5 and news notes. No system requirements or failure help.

### A2 Read a sheet
```js
const wb = new Excel.Workbook(); await wb.xlsx.readFile('report.xlsx');
const ws = wb.worksheets[0]; const [, ...hdr] = ws.getRow(1).values;
const rows = []; ws.eachRow((r, n) => { if (n > 1) rows.push(Object.fromEntries(hdr.map((h, i) => [h, r.values[i + 1]]))); });
```
Scores [1,1,2,2,1,2]
- Ergonomics 1: there is no read-to-table call, so the user builds one.
- Failure 1: a missing file is not covered.
- Findability 2: "Reading XLSX" shows only readFile. The rows and cells API is elsewhere.
- Correctness 2: the "Reading XLSX" options table is labelled "CSV".
- Completeness 1: column types are never derived or explained. Only per-cell value types exist.
- Clarity 2: the sparse, 1-based `row.values` is explained only in the rows section.

### A3 Choose what to read
```js
const ws = wb.getWorksheet('Sales 2024');
for (let r = 5; r <= 40; r++) for (let c = 2; c <= 6; c++) ws.getRow(r).getCell(c).value;
const names = wb.worksheets.map(w => w.name);
```
Scores [1,1,2,3,2,2]
- Ergonomics 1: there is no range read, so the user loops.
- Failure 1: `getWorksheet` returns `undefined` per the types, but no docs say what the user sees.
- Findability 2: "Access Worksheets" is found. Reading a bounded range is not documented.
- Completeness 2: the range and title-above-table case is missing.
- Clarity 2: the id versus index warning needs rereading.

### A4 Header and names
```js
const h1 = ws.getRow(1).values;               // own code to dedupe/blank-fill
const g = ws.getCell('B4').value;             // merged cells read as the master's value
```
Scores [1,1,1,2,0,1]
- Ergonomics 1: no header or naming support, so everything is own code.
- Failure 1: nothing is said about duplicate or blank headers.
- Findability 1: only the merged-cell example hints at it.
- Correctness 2: the merge statements are right but not about headers.
- Completeness 0: blank and duplicate names, and where each came from, are not covered.
- Clarity 1: no example for the scenario.

### A5 Column types
```js
const zip = ws.getCell('B2').text;            // string form
const n = Number(ws.getCell('C2').value);     // own NaN check and problem list
```
Scores [1,1,1,2,1,2]
- Ergonomics 1: no types argument and no problem report.
- Failure 1: nothing says what happens to `n/a` or `12,5`.
- Findability 1: only `cell.text` and the value types are implied.
- Correctness 2: no errors, but nothing on leading zeros.
- Completeness 1: only the value types are listed.
- Clarity 2.

### A6 Dates and times
```js
const d = ws.getCell('A2').value;             // Date
const serial = (d - Date.UTC(1899, 11, 30)) / 864e5;  // hand-computed stored number
```
Scores [1,1,2,2,1,2]
- Ergonomics 1: no documented way to get the stored numbers, no time type, and 1904 handling on read is not stated.
- Failure 1: a text cell like "unknown" is not discussed.
- Findability 2: "Date Value" and `date1904` are in different places.
- Correctness 2: `date1904` is shown for writing only.
- Completeness 1: only the Date type is described.
- Clarity 2.

### A7 Missing values and errors
```js
ws.eachRow(r => r.eachCell({ includeEmpty: true }, c => { if (c.type === Excel.ValueType.Error) {/*...*/} }));
```
Scores [1,1,2,3,1,2]
- Ergonomics 1: the user maps `NA`, `.` and `-` by hand.
- Failure 1: the docs show the Error value type only for assignment, so what a read gives for `#N/A` is not said.
- Findability 2: the "Error Value" and "Null Value" headings exist.
- Completeness 1: no read example and no missing-code handling.
- Clarity 2.

### A8 Every sheet
```js
const out = {}; wb.eachSheet(ws => { out[ws.name] = /* own row loop */ });
```
Scores [1,1,2,3,1,2]
- Ergonomics 1: a loop with per-sheet row extraction.
- Failure 1: an empty sheet is not covered.
- Findability 2.
- Completeness 1: eachSheet only.
- Clarity 2.

### A9 Write a table
```js
const wb = new Excel.Workbook(); const ws = wb.addWorksheet('Data');
ws.columns = [{header:'id',key:'id'}, /*...*/]; ws.addRows(rows);
await wb.xlsx.writeFile('out.xlsx');
```
Scores [1,1,2,3,2,2]
- Ergonomics 1: an object to create, fill and save.
- Failure 1: nothing is said about overwriting an existing `out.xlsx`.
- Findability 2: the answer is spread over "Add a Worksheet", "Add Rows" and "Writing XLSX".
- Completeness 2: value types are listed, but there is no date versus date-time display, no categorical, and no overwrite behaviour.
- Clarity 2.

### A10 Write several tables
```js
['A','B','C'].forEach((n,i)=> wb.addWorksheet(n).addRows(tables[i]));
ws.addRow(['Table 1']); ws.addRows(t1); ws.addRow([]); ws.addRow([]); ws.addRow(['Table 2']); ws.addRows(t2);
```
Scores [1,1,2,3,2,2]
- Ergonomics 1: several calls in both parts.
- Failure 1: only changelog lines hint at sheet-name validation. No message is documented.
- Findability 2.
- Completeness 2: no sheet-name rules and no title or gap pattern.
- Clarity 2.

### A11 Format the output
```js
ws.getRow(1).font = { bold: true };
ws.getColumn('share').numFmt = '0.0%'; ws.getColumn('amount').numFmt = '#,##0';
ws.views = [{ state: 'frozen', ySplit: 1 }]; ws.autoFilter = 'A1:E1';  // widths set by hand
```
Scores [1,1,2,3,2,3]
- Ergonomics 1: several calls, and no auto-fit, so widths are computed by hand.
- Failure 1: an unknown column key is not covered.
- Findability 2: the pieces are in separate sections and fit-to-contents is not found.
- Completeness 2: auto-fit width is missing.

### A12 Fill an existing workbook
```js
await wb.xlsx.readFile('results.xlsx'); const d = wb.getWorksheet('Data');
d.spliceRows(1, d.rowCount); d.addRows(rows);
wb.getWorksheet('Cover').getCell('C4').value = 1250; /* C5 date */ await wb.xlsx.writeFile('results.xlsx');
```
Scores [1,1,1,2,0,1]
- Ergonomics 1: several calls, and preserving everything else is not assured.
- Failure 1: nothing is said about charts.
- Findability 1: there is no section on editing an existing file.
- Correctness 2: nothing false is stated.
- Completeness 0: what is kept or lost is not covered.
- Clarity 1.

### A13 Labels
```js
// own maps: header from labels, cells from value-label dict, then addRows/writeFile
```
Scores [1,1,0,0,0,0]
- The library has no labels concept and the docs do not cover it.

---

## Library B (JavaScript)

### B1 Install
```bash
npm i --save https://cdn.../xlsx-<version>.tgz
```
Scores [2,1,3,2,2,3]
- Ergonomics 2: one call, but the argument is a tarball URL, not a registry name.
- Failure 1: the docs have no missing-system-requirement case. Only a Yarn workaround is given.
- Correctness 2: `XLSX.stream.set_readable` on the install page conflicts with `XLSX.utils.set_readable` in the API index.
- Completeness 2: the command is given, but no Node version or system requirement.

### B2 Read a sheet
```js
const wb = XLSX.readFile('report.xlsx', { cellDates: true });
const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
```
Scores [1,1,2,3,2,2]
- Ergonomics 1: the default gives dates as numbers, so `cellDates` is needed. The user also takes the sheet by hand.
- Failure 1: a missing path is not covered.
- Findability 2: "Reading Files" and "Arrays of Data" are separate pages.
- Completeness 2: types are per cell, with no per-column rule.
- Clarity 2: the `t`/`v`/`!ref` jargon.

### B3 Choose what to read
```js
const wb = XLSX.readFile('sales.xlsx');
const rows = XLSX.utils.sheet_to_json(wb.Sheets['Sales 2024'], { range: 'B5:F40' });
wb.SheetNames;
```
Scores [2,1,2,2,3,2]
- Ergonomics 2: two calls, but A1-style range and sheet name.
- Failure 1: a misspelled name gives `undefined`, which is not documented.
- Findability 2.
- Correctness 2: sheet names are called case-insensitive in the `sheets` option and case-sensitive in Data Processing.
- Clarity 2.

### B4 Header and names
```js
const aoa = XLSX.utils.sheet_to_json(ws, { header: 1 });   // own two-row join and forward-fill
const rows = XLSX.utils.sheet_to_json(ws, { header: names, range: 2 });
```
Scores [1,2,2,2,1,2]
- Ergonomics 1: the two-row merged header needs hand code.
- Failure 2: duplicates get a documented `_1` suffix. A blank header's name is undocumented and no message is shown.
- Findability 2.
- Correctness 2: the header-rewrite example uses `worksheet` where the variable is `ws`.
- Completeness 1: blank cells, special characters and which header each name came from are missing.
- Clarity 2.

### B5 Column types
```js
XLSX.utils.sheet_to_json(ws, { raw: false });   // formatted text; own Number() and problem list
```
Scores [1,1,1,2,1,2]
- Ergonomics 1: no per-column types or conversion report.
- Failure 1: nothing is said about cells that cannot convert.
- Findability 1: only the cell types and the `raw` option are implied.
- Correctness 2: no errors, but nothing on leading zeros.
- Completeness 1.
- Clarity 2.

### B6 Dates and times
```js
const wb = XLSX.readFile('dates.xlsx', { cellDates: true });
const d = XLSX.utils.sheet_to_json(wb.Sheets.Sheet1);
const raw = XLSX.utils.sheet_to_json(XLSX.readFile('dates.xlsx').Sheets.Sheet1);   // stored numbers
```
Scores [2,1,3,2,2,2]
- Ergonomics 2: two calls with `cellDates`. Reading the stored numbers needs no option.
- Failure 1: a text cell like "unknown" is not discussed.
- Correctness 2: the 1904 snippet has its two comments swapped.
- Completeness 2: no separate time type, and no statement that 1904 files are read correctly.
- Clarity 2: long, with tangents.

### B7 Missing values and errors
```js
const rows = XLSX.utils.sheet_to_json(ws, { defval: null });  // own map of 'NA','.','-'; t==='e' scan
```
Scores [1,1,2,3,1,2]
- Ergonomics 1: there is no `na` option, and errors need a cell-type scan.
- Failure 1: the docs say error cells have numeric codes in `v`, but not what `sheet_to_json` gives.
- Findability 2.
- Completeness 1: no missing-code handling.
- Clarity 2.

### B8 Every sheet
```js
const wb = XLSX.readFile('book.xlsx'); const out = {};
wb.SheetNames.forEach(n => out[n] = XLSX.utils.sheet_to_json(wb.Sheets[n]));
```
Scores [1,3,2,3,2,2]
- Ergonomics 1: a loop with one call per sheet.
- Failure scored 3 because the docs say a sheet with no `!ref` is treated as empty.
- Findability 2.
- Completeness 2: no ready recipe for a collection named by sheet.
- Clarity 2.

### B9 Write a table
```js
const ws = XLSX.utils.json_to_sheet(rows, { cellDates: true });
const wb = XLSX.utils.book_new(ws, 'Sheet1');
XLSX.writeFile(wb, 'out.xlsx');
```
Scores [1,1,3,2,2,3]
- Ergonomics 1: three calls and an object to build.
- Failure 1: nothing is said about overwriting an existing `out.xlsx`.
- Correctness 2: an example uses `worksheet` for `ws`. The `write` options text says `bookType` is required while the table gives a default.
- Completeness 2: no overwrite behaviour. Date-times use format 14 by default unless `dateNF` or `z` is set.

### B10 Write several tables
```js
XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(a), 'A');   // x3
const ws = XLSX.utils.aoa_to_sheet([['Table 1']]);
XLSX.utils.sheet_add_json(ws, t1, { origin: 'A2' });
XLSX.utils.sheet_add_aoa(ws, [['Table 2']], { origin: 'A' + (3 + t1.length + 2) });
XLSX.utils.sheet_add_json(ws, t2, { origin: 'A' + (4 + t1.length + 2) });
```
Scores [1,1,2,3,2,3]
- Ergonomics 1: several calls, and the user computes the second origin.
- Failure 1: invalid sheet-name characters are not covered. Only a duplicate name errors.
- Findability 2.
- Completeness 2: no sheet-name rules.

### B11 Format the output
```js
// bold header and frozen row: not in the CE docs (Pro)
ws['B2'].z = '0.0%'; /* loop over cells */  ws['!cols'] = [{ wch: 18 }];  ws['!autofilter'] = { ref: 'A1:E1' };
XLSX.writeFile(wb, 'out.xlsx', { cellStyles: true });
```
Scores [0,1,2,2,2,2]
- Ergonomics 0: the docs say styling and frozen rows are Pro features, so the scenario cannot be done in CE. Widths are also manual and formats are per cell.
- Failure 1: formats are not by column name, and an unknown column is not covered.
- Findability 2.
- Correctness 2: the export tutorial sets `!cols` without `cellStyles` while the column page says it is required. A typo `ws["outline"]` appears too.
- Completeness 2: the limits are stated, but bold, freeze and auto-fit are missing.
- Clarity 2.

### B12 Fill an existing workbook
```js
const wb = XLSX.readFile('results.xlsx');
wb.Sheets.Data = XLSX.utils.json_to_sheet(newTable);
XLSX.utils.sheet_add_aoa(wb.Sheets.Cover, [[1250]], { origin: 'C4' });
XLSX.utils.sheet_add_aoa(wb.Sheets.Cover, [[new Date()]], { origin: 'C5' });
XLSX.writeFile(wb, 'results.xlsx');
```
Scores [0,0,2,3,2,2]
- Ergonomics 0: the CE docs say charts and styling are Pro features, so "keep everything else" cannot be met.
- Failure 0: the chart is silently dropped. There is no message.
- Findability 2: "Replace a Worksheet in place" and "Modify a single cell" are found, but not the loss warning.
- Completeness 2: what is lost is only implied by the Pro notes.
- Clarity 2.

### B13 Labels
```js
// own header/value maps, then json_to_sheet; on read, own long-to-short header map
```
Scores [1,1,0,0,0,0]
- No labels concept, and the docs do not cover it.

---

```json
{"C": {"1": [2,3,3,3,3,3], "2": [3,1,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [2,3,3,3,3,3], "6": [3,2,3,3,3,3], "7": [2,3,3,3,3,3], "8": [3,1,3,3,2,3], "9": [3,3,3,3,3,3], "10": [3,2,3,3,3,3], "11": [3,1,3,3,3,3], "12": [2,3,3,3,2,3], "13": [3,3,3,3,3,3]},
 "A": {"1": [3,1,3,3,2,3], "2": [1,1,2,2,1,2], "3": [1,1,2,3,2,2], "4": [1,1,1,2,0,1], "5": [1,1,1,2,1,2], "6": [1,1,2,2,1,2], "7": [1,1,2,3,1,2], "8": [1,1,2,3,1,2], "9": [1,1,2,3,2,2], "10": [1,1,2,3,2,2], "11": [1,1,2,3,2,3], "12": [1,1,1,2,0,1], "13": [1,1,0,0,0,0]},
 "B": {"1": [2,1,3,2,2,3], "2": [1,1,2,3,2,2], "3": [2,1,2,2,3,2], "4": [1,2,2,2,1,2], "5": [1,1,1,2,1,2], "6": [2,1,3,2,2,2], "7": [1,1,2,3,1,2], "8": [1,3,2,3,2,2], "9": [1,1,3,2,2,3], "10": [1,1,2,3,2,3], "11": [0,1,2,2,2,2], "12": [0,0,2,3,2,2], "13": [1,1,0,0,0,0]}}
```
