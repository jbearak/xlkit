# Existing workbooks are edited surgically

`write_sheet()` and `write_cells()` never load a workbook into a model
and save the model. They open the `.xlsx` package, change only the
parts they must, and copy every other part, and every byte of a changed
part outside the cells written, as it was. This is Table Viewer's rule
(its `src/xlsx-cell-write.ts`): a model keeps only the features it
knows, so preservation must be a property of the method, not a list of
features to keep up to date.

The parts a write may change:

- the worksheet XML of the sheets written: `<c>` elements replaced or
  inserted in order, `<row>` elements added, `<dimension>`, `<mergeCells>`
  and, for `write_sheet()` without `at`, the whole `<sheetData>`;
- `xl/styles.xml`, only to append number formats, fonts, fills, borders
  and cell formats that a new style needs (existing indices never move);
- `xl/workbook.xml`, to add a sheet and to set `fullCalcOnLoad` so
  Excel recalculates formulas whose inputs changed;
- for a new sheet, its relationship and content-type entries.

Text is written as inline strings, so the shared string table is never
rewritten. The worksheet splice is tested against Table Viewer's
language-neutral corpus (`conformance/`): the same edits must give the
same bytes or the same refusal code. A worksheet shape that cannot be
spliced safely is refused before anything is written.

The write goes to a temporary file in the same directory, which then
replaces the original, so an error leaves the workbook as it was.

## Considered options

- **Load and save with a model** (openxlsx2, openpyxl, ExcelJS,
  XLSX.jl): simple, and each loses something: charts, images, pivot
  tables or conditional formats, depending on the library.
- **rust_xlsxwriter for the new sheet, spliced into the old package:**
  styles and shared strings would have to be merged across two
  packages, which is harder than writing the cells directly.
