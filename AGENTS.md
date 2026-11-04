# AGENTS.md

xlkit is an R package that reads and writes Excel `.xlsx` workbooks. It
gives each `import excel`, `export excel` and `putexcel` line of a
do-file translated to R one line of R, next to datakit's `:=` and
`read_fixed_width` and dtaparser's `read_dta` and `save_dta`. Plans live
in `docs/plans/`, decisions in `docs/adr/`, the words we use in
`CONTEXT.md`.

## Rules that override everything else

- Never run Stata. Do not install it or look for a copy.
- Stata is proprietary, so xlkit does not study it the way it studies
  the open-source libraries. Never read Stata's manuals, help files,
  ado files or website, and never copy text from them. Describe
  `import excel`, `export excel` and `putexcel` only from general
  knowledge, in your own words.
- Never use output Stata produced as a test oracle. Expected values come
  from open-source libraries (readxl, openpyxl, pandas, calamine and the
  like) and from the tests' own assertions.
- Study and copy only from projects whose license is compatible with
  GPL-3.0 (MIT, BSD, Apache-2.0, GPL-3.0 and the like). Copy code only
  with credit in `ACKNOWLEDGEMENTS.md` and in a comment where it lands.
- Make test workbooks without Excel: write them with this package, with
  rust_xlsxwriter, openpyxl or XlsxWriter, from data you create. A
  workbook from an open-source project's test suite may be used if its
  license allows, with credit.
- If you think another project has a bug, never file an issue, pull
  request or comment there without the user's approval of that report.

## Other repositories

- dta-parser holds dtaparser and datakit, the R packages xlkit sits
  next to. table-viewer reads and edits `.xlsx` files in TypeScript, and
  its `conformance/` corpus fixes what a surgical worksheet edit must
  produce. Read both to learn from them; never push to them.

## Publishing

Ask before publishing to CRAN, r-universe or any other registry.
