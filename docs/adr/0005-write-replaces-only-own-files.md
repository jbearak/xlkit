# write_xlsx() replaces only workbooks that xlkit wrote

`write_xlsx()` writes a new workbook. When `path` exists, it replaces it
only if xlkit wrote it and no other program has saved it since.
Otherwise it stops, names the sheets the file has, and points to
`write_sheet()`, `write_cells()` and `replace = TRUE`.

xlkit stamps each workbook it writes with a custom document property,
`xlkit`, whose value is the workbook's `dcterms:modified` time. Excel,
LibreOffice, openpyxl and the others update `dcterms:modified` when they
save, so the two stop matching. Surgical edits (ADR 0006) change neither,
so a workbook xlkit wrote and then edited is still its own.

A script that writes its output and is run again needs no option. A
template that happens to share the output's name, or a report someone
opened and annotated in Excel, is not lost.

## Considered options

- **Always replace** (writexl, pandas, openxlsx2): reruns are easy, and a
  colleague's template or annotations go without a word.
- **Never replace without `replace = TRUE`** (Stata): safe, but every
  script needs the option, so it stops meaning anything.
- **Check `Application` in `docProps/app.xml`:** rust_xlsxwriter writes
  `Microsoft Excel` there, as Excel does, so it cannot tell them apart.
