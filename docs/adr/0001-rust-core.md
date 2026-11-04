# A Rust core: calamine reads, rust_xlsxwriter writes, xlkit edits

xlkit is an R package with its Rust code in `src/rust`, built by cargo
when the package installs, as dtaparser is (dta-parser ADR 0007).

- **Reading** goes through calamine. It parses `.xlsx` and `.xlsm`
  (also `.xlsb` and `.xls`, which xlkit does not promise), gives typed
  cells, number formats, merged regions, Excel tables, defined names and
  the 1904 flag, and is fast: it streams the sheet XML with quick-xml.
- **New workbooks** are written by rust_xlsxwriter, which writes files
  Excel opens without repair, with number formats, fonts, fills,
  borders, merged ranges, frozen panes, autofilters and column widths.
- **Existing workbooks** are edited by xlkit's own code (ADR 0006),
  since neither crate edits a file in place.

Both crates are MIT (rust_xlsxwriter: MIT or Apache-2.0), compatible
with GPL-3.0, and credited in `ACKNOWLEDGEMENTS.md`. Their versions are
pinned in `src/rust/Cargo.lock`.

## Considered options

- **Build on readxl and openxlsx2.** Fast to write, but xlkit would
  inherit openxlsx2's load-and-save model for templates (it keeps only
  what it models) and readxl's type guessing from a sample, the two
  behaviours xlkit exists to change.
- **C++ with a vendored XML parser, as readxl does.** More code to own
  for reading, and nothing comparable to rust_xlsxwriter for writing.
- **One crate for both, umya-spreadsheet.** It reads into a model and
  writes the model out again, which drops parts it does not model.
