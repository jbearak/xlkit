# Plan: xlkit, from prior art to a judged release

Status: done. PRs #1 to #5 are merged, and the release round in #6
passed for both judges.

## Goal

The user asked for an R package, xlkit, that complements datakit (in
dta-parser): datakit gives a translated do-file its `:=` and
`read_fixed_width`, and xlkit gives it Excel. Its API should be more
ergonomic than the xlsx readers and writers of R, Python, Julia,
TypeScript and Stata, and its design is revised until Claude Sonnet and
GPT Terra both judge its design and docs better than theirs. It studies
those tools where their licenses are compatible with GPL-3.0, credits
them, and lands as a sequence of pull requests.

## What xlkit is

- An R package. Stata appears in the user's list as a tool to beat, not
  a language to support, so the list names competitors rather than
  bindings. xlkit is judged in R against each of them.
- A Rust core inside the package, as in dta-parser (ADR 0007 there):
  calamine reads, rust_xlsxwriter writes new workbooks, and xlkit's own
  code makes surgical edits to existing ones. All three are MIT or
  Apache-2.0.
- Surgical edits follow table-viewer's rule: never load a workbook into
  a model and save it again, since a model keeps only what it knows.
  Splice the cells written and copy every other byte. table-viewer's
  `conformance/` corpus is the test of the worksheet splice.
- Labels follow dtaparser's representation (`label` attributes and the
  `dtaparser_labelled` class), so `read_dta()` to `write_xlsx()` and
  `read_xlsx()` to `save_dta()` keep them.

## Pull requests

1. **Prior art and rubric.** This plan, `AGENTS.md`, `CONTEXT.md`,
   `docs/prior-art.md`, `ACKNOWLEDGEMENTS.md`, and the judging rubric
   with its pinned sources, committed before any design.
2. **Design.** The user docs written as the specification: `README.md`,
   `docs/r.md` (guide and reference), `docs/stata.md` (each Stata line
   and its xlkit line), and ADRs for the main choices. Design rounds of
   judging, revised until both judges pass it (at most five rounds),
   published in `docs/judging/`.
3. **Read.** The package skeleton, the Rust bridge, CI, and the reading
   half of the design, tested against workbooks made with
   rust_xlsxwriter and openpyxl and checked against readxl and openpyxl.
4. **Write.** New workbooks, several tables, formats, labels.
5. **Edit.** Surgical edits to existing workbooks: replace a sheet, put
   values and tables into cells, keeping the rest. Passes table-viewer's
   conformance corpus; a template with a chart, comments and conditional
   formats comes back byte-identical outside the parts written.
6. **Release round.** The release round of judging and the fresh-agent
   check on the implemented package; the README states the result.

Each PR goes through review with GPT Sol before it is filed and is
merged once CI passes.

## Not planned

- Legacy `.xls` and `.xlsb` writing; reading them is calamine's and may
  come for free, but is not promised.
- Formula evaluation. xlkit writes formulas and reads their cached
  results.
- Publishing to CRAN or r-universe (ask first, `AGENTS.md`).
