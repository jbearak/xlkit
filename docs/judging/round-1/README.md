# Design round 1

- Judged: xlkit's docs at commit `ba7b1d4` (README.md, docs/r.md,
  docs/stata.md), the design written as the specification.
- Prompts: `python docs/judging/bundle.py OTHERS OUT 20261104` at that
  commit, with OTHERS the pinned sources of [sources.md](../sources.md).
  The letters are in [letters.json](letters.json).
- Judges: Claude Sonnet 5.5 (`claude-sonnet-5-5`, effort high) and GPT
  Terra 6.1 (`gpt-6.1-terra`, reasoning effort high), one fresh session
  per judge and group, run through T3 Code.

## Scores

| judge | other library | xlkit design | other design | xlkit docs | other docs | xlkit lowest (design, docs) | pass |
|---|---|---|---|---|---|---|---|
| sonnet | readxl + writexl | 28.50 | 15.00 | 32.75 | 28.75 | 2.00, 2.75 | yes |
| sonnet | openxlsx2 | 34.50 | 16.50 | 38.50 | 24.00 | 2.00, 2.75 | yes |
| sonnet | pandas | 31.50 | 14.00 | 36.00 | 27.50 | 2.00, 3.00 | yes |
| sonnet | openpyxl | 25.50 | 11.50 | 30.00 | 22.50 | 2.00, 3.00 | yes |
| sonnet | polars | 29.00 | 16.50 | 33.00 | 20.75 | 2.00, 3.00 | yes |
| sonnet | XLSX.jl | 31.50 | 16.00 | 35.75 | 23.50 | 2.00, 2.75 | yes |
| sonnet | SheetJS CE | 27.50 | 12.50 | 32.50 | 24.50 | 2.00, 2.75 | yes |
| sonnet | ExcelJS | 24.50 | 11.00 | 29.50 | 20.50 | 2.00, 2.75 | yes |
| sonnet | Stata | 31.00 | 17.00 | | | 2.00 | yes |
| terra | readxl + writexl | 28.50 | 15.50 | 32.25 | 26.25 | 2.00, 2.75 | yes |
| terra | openxlsx2 | 34.00 | 16.00 | 38.25 | 26.25 | 2.00, 2.75 | yes |
| terra | pandas | 30.50 | 13.50 | 35.00 | 24.25 | 2.00, 2.50 | yes |
| terra | openpyxl | 25.00 | 9.50 | 29.00 | 20.75 | 2.00, 2.50 | yes |
| terra | polars | 28.00 | 13.00 | 32.00 | 20.50 | 2.00, 2.50 | yes |
| terra | XLSX.jl | 29.00 | 15.50 | 35.75 | 24.50 | 1.50, 2.75 | no |
| terra | SheetJS CE | 26.50 | 11.00 | 31.75 | 24.00 | 1.50, 2.25 | no |
| terra | ExcelJS | 23.50 | 10.50 | 28.75 | 20.25 | 1.50, 2.25 | no |
| terra | Stata | 22.00 | 13.00 | | | 0.50 | no |

Round fails.

## What happened in the sessions

- Terra's first Python session read part of its 9,419-line prompt, said
  its tool output was truncated, and returned no scores. It was run
  again in a fresh session told to read the file in 300-line chunks;
  that response is the one here.
- In the R, TypeScript and Python sessions Terra also scored Stata,
  which those prompts did not ask for. Those scores are ignored.
- The Stata prompt was blinded by mistake (the rubric says it is not),
  so its install line read `remotes::install_github("Library A")`, and
  Terra marked task 1 incorrect for it. From round 2, the Stata prompt
  is not blinded, and every prompt tells the judges that "Library X" in
  an install line is the blinding, not an error.

## What changed for round 2

Every change answers a reason a judge gave for a score below 3:

| task | reason | change |
|---|---|---|
| 6, 5 | a date or number column with one stray text cell (`unknown`) silently became text (Terra: failure 0) | a message names the cells that kept the column text, and the `types =` that reads it |
| 9 to 13 | `write_xlsx()` silently replaced a workbook xlkit wrote before (Terra: ergonomics 1) | `write_xlsx()` never replaces a file without `replace = TRUE`, as in Stata; ADR 0005 rewritten |
| 4 | blank and repeated headers were renamed without a message (Terra: failure 0) | a "New names" message lists each repair |
| 13 | a code without a value label was written as the code silently (Terra: failure 0) | a message names those cells |
| 2 | the missing-file message was not documented (both: failure 1) | documented, with a suggested file name |
| 8 | the result for an empty sheet was not documented (both: failure 1) | a tibble with no rows and no columns, documented |
| 10 | the sheet-name error gave no remedy (both: failure 2) | it suggests a valid name, documented |
| 11 | a `formats` name that is not a column was not documented (both: failure 1) | an error that suggests the column, documented |
| 12 | what `write_sheet()` clears, and a chart whose range no longer fits, were not said (Sonnet: completeness 2) | both documented; xlkit says when a chart's range no longer matches |
| 6 | `dates1904.xlsx` was missing from the list of examples (Terra: correctness 2) | added |
