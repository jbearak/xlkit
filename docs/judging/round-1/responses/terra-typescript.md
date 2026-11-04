Scores are ordered ergonomics, failure, findability, correctness, completeness, clarity. For Stata only the first two apply. JavaScript examples use the aliases `Excel` and `XLSX` for the respective packages; `rows`, `table`, and named data inputs are supplied by the caller. Where a complete operation is not documented, the example shows the useful portion and states what remains.

## Library A

1. `npm install Library A` — **[3,1,3,3,1,2]**. Failure: no missing-requirement diagnostic is specified. Completeness: platform/version requirements and recovery are incomplete. Clarity: the installation section is terse and version guidance is scattered.

2. `const wb = new Excel.Workbook(); await wb.xlsx.readFile('report.xlsx'); const rows = wb.worksheets[0].getSheetValues();` — **[1,1,2,3,1,2]**. Ergonomics: constructing a workbook and extracting rows takes several calls and the caller must build keyed records. Failure: the missing-file message is not documented. Findability: reading, rows and value types are separate sections. Completeness: no end-to-end typed table example. Clarity: the reader must combine examples and sparse row indexing.

3. `const wb = new Excel.Workbook(); await wb.xlsx.readFile('report.xlsx'); const ws = wb.getWorksheet('Sales 2024'); const rows = ws.getRows(5,36).map(r => r.values.slice(2,7)); const names = wb.worksheets.map(s => s.name);` — **[1,1,2,3,1,2]**. Ergonomics: workbook creation, lookup and row extraction require multiple calls and manual column selection. Failure: missing names yield no documented actionable diagnostic. Findability: sheet access and rows are separate. Completeness: bounded range to table is not shown. Clarity: translating the range and sparse row values requires work.

4. `const header = ws.getRow(1).values; const group = ws.getRow(4).values; const sub = ws.getRow(5).values;` — **[1,1,2,3,1,2]**. Ergonomics: the caller must repair names and keep the mapping, including merged headers. Failure: there is no automatic name-repair diagnostic. Findability: rows and merged cells are separately indexed. Completeness: no name repair or provenance recipe. Clarity: merged cells are explained, but not in a header-to-record example.

5. `ws.eachRow((row, n) => { /* inspect zip and amount cells, convert and record n/address when conversion fails */ });` — **[1,1,2,3,1,2]**. Ergonomics: conversions and problem tracking must be implemented cell by cell; a numeric zip without a zero-padding format has already lost its leading zero. Failure: conversion diagnostics are the caller's responsibility. Findability: cell access and formatting details must be assembled. Completeness: no typed-column conversion or problem report. Clarity: no complete example for mixed columns.

6. `const wb = new Excel.Workbook(); await wb.xlsx.readFile('dates.xlsx'); const values = wb.worksheets[0].getSheetValues();` — **[1,1,2,3,1,2]**. Ergonomics: extraction and any serial-number reconstruction require manual work, including the workbook date system. Failure: text in a date column has no documented conversion warning. Findability: dates and workbook properties are separate. Completeness: no complete date/time and raw-serial read recipe. Clarity: date cells are described, but the conversion details are not tied together.

7. `ws.eachRow((row, n) => { /* map null, NA, . and - to null; record cells whose value has an error property */ });` — **[1,1,2,3,1,2]**. Ergonomics: the caller must normalize values and collect error positions. Failure: numeric-column conversion and diagnostics are not provided. Findability: null and error values have separate entries. Completeness: no missing-code normalization or error audit example. Clarity: the value representations are illustrated but the combined workflow is left to the reader.

8. `const wb = new Excel.Workbook(); await wb.xlsx.readFile('book.xlsx'); const all = Object.fromEntries(wb.worksheets.map(s => [s.name, s.getSheetValues()]));` — **[1,1,2,3,1,2]**. Ergonomics: workbook construction, read, per-sheet extraction and collection need several calls. Failure: empty-sheet table behavior is not specified. Findability: workbook iteration and rows are separate. Completeness: no named collection of tables recipe. Clarity: the user must assemble it from examples.

9. `const wb = new Excel.Workbook(); const ws = wb.addWorksheet('Sheet1'); ws.addRows(rows); await wb.xlsx.writeFile('out.xlsx');` — **[1,1,2,3,1,2]**. Ergonomics: create, fill and save a workbook; the caller prepares headers and categorical values. Failure: behavior for an existing file is not specified in the supplied documentation. Findability: writing, rows and types are separate. Completeness: no full type mapping or overwrite discussion. Clarity: examples show pieces rather than this table.

10. `const wb = new Excel.Workbook(); for (const [name, rows] of tables) wb.addWorksheet(name).addRows(rows); await wb.xlsx.writeFile('out.xlsx');` — **[1,1,2,3,1,2]**. Ergonomics: multiple objects and calls are needed; for the second part add title rows and insert the two table blocks explicitly. Failure: invalid-name validation is mentioned, but its message is not documented. Findability: sheets, rows and writing are separate. Completeness: no complete titled, spaced layout example. Clarity: placement must be computed by the caller.

11. `ws.getRow(1).font = {bold:true}; ws.getColumn('B').numFmt = '0.0%'; ws.getColumn('C').numFmt = '#,##0'; ws.views = [{state:'frozen',ySplit:1}]; ws.autoFilter = 'A1:C100';` — **[1,1,2,3,1,2]**. Ergonomics: multiple operations and manual width calculation are required. Failure: a missing table column name is not validated by this cell-oriented approach. Findability: styles, columns, frozen views and filters are separate. Completeness: fitting widths to contents is not given as a complete operation. Clarity: the example must be assembled and column letters mapped by the caller.

12. `const wb = new Excel.Workbook(); await wb.xlsx.readFile('results.xlsx'); /* edit Data and Cover */ await wb.xlsx.writeFile('results.xlsx');` — **[0,1,2,3,1,2]**. Ergonomics: the supplied material does not establish that a chart and all other template content survive a model round trip, so the full preservation requirement cannot be assured. Failure: chart preservation is not specified. Findability: I/O and editing are separate. Completeness: preservation and losses are not described. Clarity: no template round-trip example establishes the result.

13. `/* No documented Stata label import/export or variable-label mapping. */` — **[0,1,0,0,0,0]**. Ergonomics: the label-aware round trip is not provided. Failure: an unlabelled code's behavior is not specified. Findability, correctness, completeness and clarity: the scenario is not covered.

## Library B

1. `npm i --save [link]` — **[3,1,2,3,2,2]**. Failure: no missing-system-requirement diagnostic is given. Findability: Node installation is nested in getting started. Completeness: version/platform and system-requirement coverage is incomplete. Clarity: the long page mixes installation, vendoring and module details.

2. `const wb = XLSX.readFile('report.xlsx', {cellDates:true}); const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);` — **[1,1,2,3,2,2]**. Ergonomics: default date handling produces numbers unless changed, and reading plus conversion are separate calls. Failure: the missing-file diagnostic is not specified. Findability: parsing, date options and array output are on separate pages. Completeness: column-level type guarantees are not provided. Clarity: the result has to be inferred across examples.

3. `const wb = XLSX.readFile('report.xlsx'); const rows = XLSX.utils.sheet_to_json(wb.Sheets['Sales 2024'], {range:'B5:F40'}); const names = wb.SheetNames;` — **[2,1,2,3,2,2]**. Ergonomics: file read and conversion are two calls. Failure: missing sheet access and resulting error are not documented as an actionable diagnostic. Findability: workbook and array conversion documentation are separate. Completeness: misspelled-name handling is not explained. Clarity: the reader must join the workbook model and range examples.

4. `const raw = XLSX.utils.sheet_to_json(ws, {header:1}); const rows = XLSX.utils.sheet_to_json(ws);` — **[1,1,2,3,2,2]**. Ergonomics: the user must construct the merged two-row names and retain their mapping. Failure: duplicate names are silently disambiguated and blank handling/provenance is not fully specified. Findability: array output and merge representation are separate pages. Completeness: no full merged-header provenance workflow. Clarity: the user must combine the two representations.

5. `const cells = XLSX.utils.sheet_to_json(ws, {header:1, raw:true}); /* convert by column, record source addresses, use formatted text for padded zip cells */` — **[1,1,2,3,1,2]**. Ergonomics: conversion and problem collection require custom code; numeric zip cells lacking a padding format have irretrievably lost leading zeros. Failure: no conversion warning or problem list is documented. Findability: raw and formatted values are explained on separate pages. Completeness: no column typing and conversion-problem workflow. Clarity: the user must construct it.

6. `const dates = XLSX.readFile('dates.xlsx', {cellDates:true}); const serials = XLSX.readFile('dates.xlsx');` — **[1,1,2,3,2,2]**. Ergonomics: conversion to tables adds calls and the default yields serials rather than dates. Failure: text in a date column has no documented typed-column warning. Findability: parsing options and the date guide are separate. Completeness: the scenario requires combining date-system and extraction details. Clarity: date-system and JavaScript time-zone caveats take rereading.

7. `const raw = XLSX.utils.sheet_to_json(ws, {header:1, defval:null}); /* inspect cell types and map codes/errors to null while recording error addresses */` — **[1,1,2,3,1,2]**. Ergonomics: normalization and error provenance require custom traversal. Failure: no numeric-column error diagnostic is specified. Findability: array output and error-cell model are separate. Completeness: no combined missing-value and error audit. Clarity: source cell inspection must be added to the example.

8. `const wb = XLSX.readFile('book.xlsx'); const all = Object.fromEntries(wb.SheetNames.map(n => [n, XLSX.utils.sheet_to_json(wb.Sheets[n])]));` — **[1,1,2,3,2,2]**. Ergonomics: the per-sheet conversion loop entails several calls. Failure: empty-sheet handling is not explicitly established for the full workflow. Findability: workbook and conversion documentation are separate. Completeness: empty-sheet behavior is not covered in the example. Clarity: the collection must be constructed from the primitives.

9. `const ws = XLSX.utils.json_to_sheet(rows); const wb = XLSX.utils.book_new(ws); XLSX.writeFile(wb, 'out.xlsx');` — **[1,1,2,3,2,2]**. Ergonomics: worksheet, workbook and file require several calls; categorical values need preparation. Failure: existing-file behavior is not stated in the supplied material. Findability: conversion, workbook helpers and writing are separate. Completeness: categorical mapping and overwrite behavior are not fully documented. Clarity: the reader must combine examples.

10. `const wb = XLSX.utils.book_new(); for (const [name, rows] of tables) XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(rows), name); XLSX.writeFile(wb, 'out.xlsx');` — **[1,1,2,3,2,2]**. Ergonomics: several calls build and save the workbook; the second layout requires `sheet_add_aoa` and `sheet_add_json` with computed origins. Failure: the supplied documentation does not specify the invalid slash message. Findability: helper and array pages must be combined. Completeness: the full titled layout and invalid-name probe are not shown. Clarity: spacing and origins must be worked out.

11. `ws['!cols'] = widths; ws['!autofilter'] = {ref:'A1:C100'}; /* set number formats on cells */` — **[0,1,2,3,1,2]**. Ergonomics: the supplied CE documentation does not establish full bold styling and frozen header support for this scenario. Failure: no column-name validation diagnostic is described. Findability: formats and column properties are separate. Completeness: full formatting and fitting workflow is absent. Clarity: the partial features require stitching together.

12. `const wb = XLSX.readFile('results.xlsx'); /* edit cells */ XLSX.writeFile(wb, 'results.xlsx');` — **[0,0,2,3,1,2]**. Ergonomics: full template preservation is not supported by the documented data-focused codec. Failure: the documentation states graphs and styling require additional support, so the chart cannot be counted as preserved. Findability: parsing and writing feature limits are on separate pages. Completeness: no full preservation/loss inventory for this template. Clarity: the reader must infer the consequences of codec limits.

13. `/* No documented Stata variable/value-label round trip. */` — **[0,1,0,0,0,0]**. Ergonomics: the label-aware round trip is not provided. Failure: unlabeled-code behavior is unspecified. Findability, correctness, completeness and clarity: the scenario is not covered.

## Library C

1. `install.packages('remotes'); remotes::install_github('Library C')` — **[2,3,3,3,3,3]**. Ergonomics: installing the helper and package requires two calls.

2. `scores <- read_xlsx('report.xlsx')` — **[3,1,3,3,3,3]**. Failure: the missing-file diagnostic is not shown in the supplied documentation.

3. `sales <- read_xlsx('report.xlsx', sheet='Sales 2024', range='B5:F40'); xlsx_sheets('report.xlsx')` — **[3,3,3,3,3,3]**. Each part is a direct call; the documented bad-sheet message suggests the right name and lists sheets.

4. `a <- read_xlsx('book.xlsx', sheet='Headers', names='snake'); b <- read_xlsx('book.xlsx', sheet='Two-row header', header=4:5)` — **[3,3,3,3,3,3]**. Names are unique and changed text is retained as labels; merged headers are propagated.

5. `df <- read_xlsx('book.xlsx', types=c(zip='text', amount='number')); xlsx_problems(df)` — **[2,3,3,3,3,3]**. Ergonomics: reading and retrieving the problem list take two calls. Numeric zip cells without a zero-padding format cannot recover zeros that were never stored.

6. `read_xlsx('dates.xlsx'); read_xlsx('dates1904.xlsx'); read_xlsx('dates.xlsx', dates=FALSE)` — **[3,0,3,2,2,2]**. Failure: the default guesses a mixed text/date column as character without warning, rather than reporting the unexpected date value. Correctness: the example workbook list omits the referenced `dates1904.xlsx`. Completeness: the `unknown` probe and resulting type are not explicitly demonstrated. Clarity: the apparent omission from the shipped examples list causes uncertainty.

7. `df <- read_xlsx('book.xlsx', na=c('NA','.','-')); xlsx_problems(df)` — **[2,3,3,3,3,3]**. Ergonomics: the read and problem inspection take two calls.

8. `all <- read_sheets('book.xlsx')` — **[3,1,3,3,2,3]**. Failure: the docs do not specify the empty-sheet result. Completeness: that named edge case is missing.

9. `write_xlsx(df, 'out.xlsx')` — **[3,3,3,3,3,3]**. The type mapping and refusal to replace another program's workbook are documented.

10. `write_xlsx(list(A=a,B=b,C=c), 'out.xlsx'); write_xlsx(list(Results=list(First=a,Second=b)), 'two.xlsx', gap=2)` — **[3,2,3,3,3,3]**. Failure: the invalid sheet name is identified, but the documented error does not say how to fix it.

11. `write_xlsx(df, 'out.xlsx', formats=c(share='0.0%', amount='#,##0'), filter=TRUE)` — **[3,1,3,3,2,3]**. Failure: invalid `formats` column names are not explicitly covered; the stated key validation concerns `styles`. Completeness: that specific invalid-format-name case is absent.

12. `write_sheet(new_data, 'results.xlsx', sheet='Data'); write_cells('results.xlsx', sheet='Cover', C4=1250, C5=as.Date('2024-12-31'))` — **[2,3,3,3,3,3]**. Ergonomics: replacing the sheet and editing Cover take two library calls, plus date construction.

13. `write_xlsx(df, 'survey.xlsx', header='labels'); df2 <- read_xlsx('long.xlsx', names='stata')` — **[3,3,3,3,3,3]**. The docs say an unlabelled code is written as the code, and changed names retain header text as labels.

## Stata

1. `/* Stata's Excel commands are built in; install Stata using its installer. */` — **[3,1]**. Failure: the supplied material does not specify an installation failure diagnostic.
2. `import excel using "report.xlsx", firstrow clear` — **[3,2]**. Failure: a missing file stops with a file-not-found error, without a suggested correction.
3. `import excel using "report.xlsx", describe` then `import excel using "report.xlsx", sheet("Sales 2024") cellrange(B5:F40) firstrow clear` — **[3,2]**. Failure: a missing sheet stops with an error but does not supply a list of alternatives.
4. `import excel using "book.xlsx", firstrow clear` — **[1,1]**. Ergonomics: the merged two-row header requires additional manual reconstruction and labelling. Failure: the supplied material does not specify the duplicate/blank-name diagnostic.
5. `import excel using "book.xlsx", allstring firstrow clear` then `destring amount, generate(amount_num) force` — **[1,1]**. Ergonomics: conversion and locating failures require additional commands; missing leading zeros in numeric cells cannot be recovered without a format or external rule. Failure: forced conversion requires a separate comparison to identify cells.
6. `import excel using "dates.xlsx", firstrow clear` — **[1,1]**. Ergonomics: Stata's numeric date variables and display formats require additional conversion for the requested date/time representations and raw serials. Failure: the supplied material does not specify this mixed-date probe.
7. `import excel using "book.xlsx", firstrow clear` — **[1,0]**. Ergonomics: missing codes require recoding and the original error types need separate inspection. Failure: the supplied Stata comparison says Excel errors become missing without a warning.
8. `import excel using "book.xlsx", describe` followed by a loop over sheet names with `import excel ..., sheet(...) firstrow clear` — **[1,1]**. Ergonomics: the user loops and stores each dataset separately. Failure: empty-sheet behavior is not specified in the supplied material.
9. `export excel using "out.xlsx", firstrow(variables)` — **[3,2]**. Failure: an existing file prevents export unless `replace` is specified; the precise action guidance is not established in the supplied material.
10. `export excel using "out.xlsx", sheet("A") firstrow(variables)` followed by exports to sheets B and C; use `putexcel` for titled blocks — **[1,1]**. Ergonomics: separate exports and cell placement need multiple commands. Failure: the invalid-name diagnostic is not specified here.
11. `putexcel set "out.xlsx", sheet("Sheet1") modify` followed by formatting commands for the header and numeric ranges — **[0,1]**. Ergonomics: the supplied material does not establish all requested features, including automatic fit, freeze and filter buttons, through this workflow. Failure: column-name validation behavior is not specified.
12. `export excel using "results.xlsx", sheet("Data", replace) firstrow(variables)` then `putexcel set "results.xlsx", sheet("Cover") modify` and `putexcel C4 = 1250 C5 = date("2024-12-31", "YMD"), nformat("yyyy-mm-dd")` — **[1,1]**. Ergonomics: separate commands are required. Failure: chart preservation on this round trip is not established in the supplied material.
13. `export excel using "survey.xlsx", firstrow(varlabels)` then `import excel using "long.xlsx", firstrow clear` — **[3,1]**. Failure: the supplied material does not specify what an unlabelled code becomes on export.

```json
{"C":{"1":[2,3,3,3,3,3],"2":[3,1,3,3,3,3],"3":[3,3,3,3,3,3],"4":[3,3,3,3,3,3],"5":[2,3,3,3,3,3],"6":[3,0,3,2,2,2],"7":[2,3,3,3,3,3],"8":[3,1,3,3,2,3],"9":[3,3,3,3,3,3],"10":[3,2,3,3,3,3],"11":[3,1,3,3,2,3],"12":[2,3,3,3,3,3],"13":[3,3,3,3,3,3]},"A":{"1":[3,1,3,3,1,2],"2":[1,1,2,3,1,2],"3":[1,1,2,3,1,2],"4":[1,1,2,3,1,2],"5":[1,1,2,3,1,2],"6":[1,1,2,3,1,2],"7":[1,1,2,3,1,2],"8":[1,1,2,3,1,2],"9":[1,1,2,3,1,2],"10":[1,1,2,3,1,2],"11":[1,1,2,3,1,2],"12":[0,1,2,3,1,2],"13":[0,1,0,0,0,0]},"B":{"1":[3,1,2,3,2,2],"2":[1,1,2,3,2,2],"3":[2,1,2,3,2,2],"4":[1,1,2,3,2,2],"5":[1,1,2,3,1,2],"6":[1,1,2,3,2,2],"7":[1,1,2,3,1,2],"8":[1,1,2,3,2,2],"9":[1,1,2,3,2,2],"10":[1,1,2,3,2,2],"11":[0,1,2,3,1,2],"12":[0,0,2,3,1,2],"13":[0,1,0,0,0,0]},"Stata":{"1":[3,1],"2":[3,2],"3":[3,2],"4":[1,1],"5":[1,1],"6":[1,1],"7":[1,0],"8":[1,1],"9":[3,2],"10":[1,1],"11":[0,1],"12":[1,1],"13":[3,1]}}
```
