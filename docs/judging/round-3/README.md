# Release round

- Judged: the implemented package at commit `db728d8` (main after #5, plus
  the API reference in the bundle): `README.md`, `docs/r.md`,
  `docs/stata.md` and `man/*.Rd` as text.
- Prompts: `python docs/judging/bundle.py OTHERS OUT 20261106` at that
  commit. The letters are in [letters.json](letters.json).
- Judges: Claude Sonnet 5.5 (`claude-sonnet-5-5`, effort high) and GPT
  Terra 6.1 (`gpt-6.1-terra`, reasoning effort high), one fresh session
  per judge and group, each reading its prompt in 300-line chunks.
  Every session returned scores on its first run. As in the design
  rounds, Terra also scored Stata in some non-Stata sessions; those
  scores are ignored.

## Scores

| judge | other library | xlkit design | other design | xlkit docs | other docs | xlkit lowest (design, docs) | pass |
|---|---|---|---|---|---|---|---|
| sonnet | readxl + writexl | 32.50 | 15.00 | 33.00 | 29.00 | 2.50, 3.00 | yes |
| sonnet | openxlsx2 | 38.00 | 18.50 | 39.00 | 25.75 | 2.50, 3.00 | yes |
| sonnet | pandas | 35.50 | 14.50 | 36.00 | 27.00 | 2.50, 3.00 | yes |
| sonnet | openpyxl | 29.50 | 11.00 | 30.00 | 21.25 | 2.50, 3.00 | yes |
| sonnet | polars | 32.50 | 16.50 | 33.00 | 23.00 | 2.50, 3.00 | yes |
| sonnet | XLSX.jl | 35.00 | 16.00 | 35.75 | 24.00 | 2.50, 2.75 | yes |
| sonnet | SheetJS CE | 32.50 | 11.50 | 33.00 | 23.00 | 2.50, 3.00 | yes |
| sonnet | ExcelJS | 29.50 | 11.50 | 30.00 | 22.50 | 2.50, 3.00 | yes |
| sonnet | Stata | 34.50 | 17.00 | | | 2.50 | yes |
| terra | readxl + writexl | 31.50 | 13.50 | 33.00 | 27.50 | 2.50, 3.00 | yes |
| terra | openxlsx2 | 37.00 | 18.00 | 38.50 | 26.25 | 2.50, 2.50 | yes |
| terra | pandas | 34.00 | 13.00 | 35.75 | 26.25 | 2.50, 2.75 | yes |
| terra | openpyxl | 28.50 | 11.00 | 29.75 | 21.50 | 2.50, 2.75 | yes |
| terra | polars | 31.50 | 14.00 | 32.75 | 22.00 | 2.50, 2.75 | yes |
| terra | XLSX.jl | 34.00 | 15.50 | 35.75 | 25.25 | 2.50, 2.75 | yes |
| terra | SheetJS CE | 31.50 | 11.50 | 33.00 | 23.25 | 2.50, 3.00 | yes |
| terra | ExcelJS | 28.50 | 10.50 | 30.00 | 21.00 | 2.50, 3.00 | yes |
| terra | Stata | 34.50 | 16.00 | | | 2.50 | yes |

Round passes.

Both judges score the implemented package's design and docs above
those of every other library in the R, Python, Julia and TypeScript
groups, and its design above Stata's commands, which they scored from
their own knowledge, unblinded and on design only (rubric.md, "Stata").
Every common task is at 2.5 or more for design and for docs. This is
the pass the README states.

## Fresh-agent check

A fresh Claude Sonnet 5.5 session got only xlkit's docs (README,
docs/r.md, docs/stata.md and the man pages as text), the installed
package, and an empty folder. It made its own workbooks for each
scenario with openpyxl, xlkit and dtaparser, did the 13 tasks, and
tried the failure each one invites. Its report is
[fresh/report.md](fresh/report.md).

Twelve tasks succeeded and one partly: in task 13, `names = "snake"`
gives clean names rather than short ones, and only `"stata"` caps them
at 32 characters. The rubric reports this check and does not score it.

Changed after the check, before this PR:

- `write_cells()` and `write_sheet()` now say when they add a sheet the
  workbook did not have, with "Did you mean" for a near name, since a
  misspelled sheet name silently added a sheet (task 12).
- Two doc lines the agent quoted as wrong were corrected: chart sheets
  in `read_sheets()` (naming one is an error, not a way to read it) and
  "you can always see where a name came from" (not for blank headers).

The agent's other notes are listed in its report as follow-ups.
