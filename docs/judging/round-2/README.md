# Design round 2

- Judged: xlkit's docs at commit `e9e7115`, after the changes listed in
  [round 1](../round-1/README.md).
- Prompts: `python docs/judging/bundle.py OTHERS OUT 20261105` at that
  commit. The letters are in [letters.json](letters.json).
- Judges: Claude Sonnet 5.5 (`claude-sonnet-5-5`, effort high) and GPT
  Terra 6.1 (`gpt-6.1-terra`, reasoning effort high), one fresh session
  per judge and group, each told to read its prompt in 300-line chunks
  to the end. Every session returned scores on its first run.

## Scores

| judge | other library | xlkit design | other design | xlkit docs | other docs | xlkit lowest (design, docs) | pass |
|---|---|---|---|---|---|---|---|
| sonnet | readxl + writexl | 32.50 | 14.50 | 33.00 | 27.75 | 2.50, 3.00 | yes |
| sonnet | openxlsx2 | 38.50 | 17.50 | 39.00 | 26.00 | 2.50, 3.00 | yes |
| sonnet | pandas | 35.50 | 15.00 | 35.50 | 28.50 | 2.50, 2.75 | yes |
| sonnet | openpyxl | 29.50 | 10.50 | 29.50 | 17.75 | 2.50, 2.75 | yes |
| sonnet | polars | 32.50 | 17.00 | 32.75 | 21.50 | 2.50, 2.75 | yes |
| sonnet | XLSX.jl | 35.00 | 16.00 | 36.00 | 24.25 | 2.50, 3.00 | yes |
| sonnet | SheetJS CE | 32.00 | 12.00 | 32.75 | 24.50 | 2.50, 2.75 | yes |
| sonnet | ExcelJS | 29.00 | 11.50 | 29.75 | 19.75 | 2.50, 2.75 | yes |
| sonnet | Stata | 36.00 | 17.00 | | | 3.00 | yes |
| terra | readxl + writexl | 31.50 | 14.00 | 33.00 | 28.00 | 2.50, 3.00 | yes |
| terra | openxlsx2 | 37.50 | 18.50 | 38.75 | 26.25 | 2.50, 2.75 | yes |
| terra | pandas | 34.00 | 13.50 | 35.75 | 29.50 | 2.50, 2.75 | yes |
| terra | openpyxl | 28.50 | 11.50 | 29.75 | 21.00 | 2.50, 2.75 | yes |
| terra | polars | 31.50 | 12.50 | 32.75 | 23.25 | 2.50, 2.75 | yes |
| terra | XLSX.jl | 33.50 | 15.00 | 35.75 | 22.75 | 2.50, 2.75 | yes |
| terra | SheetJS CE | 31.50 | 13.50 | 32.50 | 23.25 | 2.50, 2.75 | yes |
| terra | ExcelJS | 28.50 | 11.00 | 29.50 | 19.75 | 2.50, 2.75 | yes |
| terra | Stata | 35.00 | 14.50 | | | 2.50 | yes |

Round passes.

Both judges score xlkit's design and docs above every other library's,
in every group, with every common task at 2.5 or more for design and
2.75 or more for docs. The design rounds stop here (rubric.md,
"Rounds"); the release round judges the implemented package.

As in round 1, Terra also scored Stata in the R, Python and TypeScript
sessions; those scores are ignored.

## After the round

Terra gave task 3 a correctness score of 2 because the example workbook
had `Sales 2024` as the fourth sheet while the scenario says third. The
example workbook's sheets are now `Summary`, `Sales 2023`,
`Sales 2024`, `Regions` and `Notes`, so it is the third.

Review with GPT Sol then corrected four Stata translations in
`docs/stata.md` (the 1960 date origin in `putexcel`, `datestring()`
writing text, matrices without `names`, and `if` dropping missing
values), added `merge` to `write_xlsx()`'s reference, allowed resizing
an Excel table in ADR 0006, and made `bundle.py` blind Julia's `XLSX`
and SheetJS's `xlsx` in imports. The release round judges the docs as
they are then.
