# write_xlsx() never replaces a file without replace = TRUE

`write_xlsx()` writes a new workbook. When `path` exists, it stops,
names the sheets the file has, and points to `replace = TRUE` (replace
the whole workbook) and to `write_sheet()` and `write_cells()` (change
part of it and keep the rest). This is Stata's rule for `export excel`,
so a translated do-file keeps its `replace` as `replace = TRUE`.

With `replace = TRUE`, the new workbook is written to a temporary file
in the same directory and then renamed over `path`, so an error leaves
the old file as it was.

## Considered options

- **Always replace** (writexl, pandas, polars, openxlsx2): reruns need no
  option, and a colleague's template or someone's annotations go
  without a word (polars #10692).
- **Replace only workbooks xlkit wrote**, known by a timestamp xlkit
  stores in the document properties that any other program's save
  changes. Reruns would need no option and templates would be safe,
  but the rule is one more thing to explain, and the first design round
  of judging (`docs/judging/round-1/`) scored the silent replacement of
  xlkit's own earlier output as a default that loses a file.
