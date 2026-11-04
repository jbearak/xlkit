# Design and documentation rubric

The user asked for xlkit's design and documentation to be judged better
than those of the other xlsx readers and writers for R, Python, Julia,
TypeScript and Stata, by two judges, Claude Sonnet and GPT Terra. This
file fixes the tasks, the scores, the pass rule and the protocol before
xlkit's design is written. It does not change once judging starts. A
later round may change xlkit's design and docs, never this file.

The method is the one dta-parser used for its documentation
(`docs/judging/rubric.md` there), with two scores added for the design.

## The thirteen tasks

Each task is a scenario a user of an xlsx library meets. A judge reads a
library's documentation, works out the code the library needs for the
scenario, and scores it. The scenarios are fixed so every library is
judged on the same problem.

| # | task | scenario |
|---|---|---|
| 1 | Install | Install the package on a fresh machine with the language's usual tools. The judge looks for the command, supported platforms and language versions, system requirements, and what to do when installation fails. |
| 2 | Read a sheet | `report.xlsx` has one sheet. Row 1 holds the names `id`, `name`, `score`, `passed`, `joined`; below are whole numbers, text, decimals, TRUE/FALSE and dates. Read it into the language's usual table, and know which type each column gets. |
| 3 | Choose what to read | Read the sheet named `Sales 2024`, the third of five, whose table sits in `B5:F40` under a title in `B1` and a note in `B2`. Also list the workbook's sheet names. |
| 4 | Header and names | The header row has a blank cell, two cells both named `Total`, and a name with spaces and a `%` sign. A second sheet has a two-row header: a group name merged across three columns, then the column names under it. Get usable column names, and know which header text each came from. |
| 5 | Column types | Column `zip` holds codes such as `02139`, some typed as text and some as numbers. Column `amount` is numeric for its first 2,000 rows, then has `n/a` and `12,5` as text. Read `zip` as text and `amount` as numbers, and find out which cells did not convert. |
| 6 | Dates and times | One column holds dates, one date-times and one times of day; a second workbook uses the 1904 date system. Read them as the language's date and date-time types, then read the same columns as the stored numbers. |
| 7 | Missing values and errors | Cells are blank, hold `NA`, `.` or `-` meaning missing, or hold the Excel errors `#N/A` and `#DIV/0!`. Read them all as missing values, and tell the errors apart from the blanks. |
| 8 | Every sheet | Read every sheet of a workbook with twelve sheets into a collection of tables named by sheet. |
| 9 | Write a table | Write a table with whole-number, decimal, text, logical, date, date-time and categorical columns, some values missing, to `out.xlsx`. Know what each column becomes in Excel and what happens when `out.xlsx` already exists. |
| 10 | Write several tables | Write three tables to one workbook, one per sheet, with given sheet names. Then write two tables onto one sheet, each with a title above it, the second starting two rows below the first. |
| 11 | Format the output | Make the header bold, show `share` as a percent with one decimal and `amount` with thousands separators, fit column widths to their contents, freeze the header row and add filter buttons. |
| 12 | Fill an existing workbook | `results.xlsx` is a template a colleague made, with a formatted `Cover` sheet, a chart on a `Chart` sheet and a `Data` sheet. Replace what is on `Data` with a new table, and put a number in `C4` and a date in `C5` of `Cover`, keeping everything else in the workbook as it was: formats, the chart, the other sheets. Know what the library keeps and what it loses. |
| 13 | Labels | A table read from a Stata `.dta` file has variable labels, and a column `sex` with codes 1 and 2 labelled `Male` and `Female`. Write it so the header shows the variable labels and the cells show the value labels. Then read a sheet with long headers so the column names are short and each long header is kept as a variable label. |

## Common and ours-only tasks

A task is **common** to xlkit and another library when the other library
supports it; otherwise it is **ours-only** for that pair. A reader-only
library (readxl) has no write tasks, and so on. The pass is decided on
common tasks; ours-only tasks are scored and published too, but do not
decide the pass.

Which tasks each library supports is fixed in
[sources.md](sources.md) from its documentation and source at the
pinned version, before xlkit's design is written.

## Scores

For each library and task, a judge gives six scores from 0 to 3: two
for the design and four for the documentation.

### Design

**Counting calls.** A call is a call to a function or method of the
library, or of the language, that does part of the task. These do not
count: importing or attaching the library; writing literal data or
arguments (R's `c()` and `list()`, Python's list and dict literals,
JavaScript's array and object literals); and printing the result. A
loop that calls the library once per sheet, row or cell counts as
several calls.

**Scenarios in parts.** Where a scenario has parts (separated by "Then"
or "Also", or a second workbook or sheet), score Ergonomics for each
part and give the task the lowest of them.

**Ergonomics.** The code a user writes for the scenario.

- 3: one call. Each argument says what it means in the workbook (a
  sheet name, a range as Excel shows it, a header row by its row
  number), and the defaults give the right result for the scenario.
- 2: one call that needs an argument whose meaning is indirect (a count
  of rows to skip instead of the header row, a zero-based index), or
  two calls.
- 1: several calls, or an object the user must create, fill and save,
  or a default that gives a wrong result for the scenario (lost values,
  wrong types, a file overwritten) unless the user knows to change it.
- 0: not possible with the library.

**Failure behavior.** What the user sees when the scenario goes wrong
in the one way this table fixes for each task. Score that probe only.

| # | probe |
|---|---|
| 1 | the build or install fails for a missing system requirement |
| 2 | the path names a file that does not exist (`reprot.xlsx`) |
| 3 | the sheet name is misspelled (`Sales 2042`) |
| 4 | the header has two cells named `Total` and a blank cell |
| 5 | the cells `n/a` and `12,5` in `amount` cannot be read as numbers |
| 6 | the date column has one cell holding the text `unknown` |
| 7 | `#N/A` and `#DIV/0!` cells in a column read as numbers |
| 8 | one of the twelve sheets is empty |
| 9 | `out.xlsx` already exists and was made by someone else |
| 10 | one sheet name contains `/` (`Q1/Q2`) |
| 11 | a number format is given for a column name that is not in the table |
| 12 | the template's chart on `Chart` |
| 13 | a code in `sex` has no value label |

- 3: the library stops or warns, and the message names the problem and
  what to do (for example, it lists the sheet names, or says which
  cells did not convert and how to see them).
- 2: it stops or warns, and the message names the problem only.
- 1: it fails with a message that does not name the problem, or the
  docs do not say what happens.
- 0: it gives a wrong result without a message.

Where the right handling of a probe needs no message (an empty sheet
read as an empty table, a chart kept as it was), score 3 when the
docs say the library gives the right result, 1 when they do not say
what happens, and 0 when they say it gives a wrong result.

### Documentation

These four are dta-parser's, unchanged in meaning.

**Findability.** Starting at the front page (README or documentation
home), how directly does a reader reach the answer?

- 3: a heading, table of contents entry or index entry names the task,
  one step from the front page.
- 2: the answer is there, but the reader has to search a long page or
  follow two or more links.
- 1: the answer is only in a function reference entry with no pointer
  from the guide, or only implied by an example.
- 0: not found.

**Correctness.** Is what the docs say true of the pinned version, and
would the examples run as written?

- 3: everything stated about the task is right and the examples run.
- 2: one small error or an example that needs an obvious fix.
- 1: an error that would mislead a user into wrong results.
- 0: wrong, or the task is not covered.

**Completeness.** Does the reader learn everything the scenario needs,
including options, limits and what is lost?

- 3: the main path, the options that change the result, and the edge
  cases the scenario names.
- 2: the main path and most options; an edge case missing.
- 1: the main path only.
- 0: not covered.

**Clarity.** Can a reader who knows the language but not the library
follow it?

- 3: plain words, a short example with its result described, terms
  explained where first used.
- 2: understandable with some rereading, or an example without saying
  what it gives.
- 1: hard to follow: jargon, no example, or contradictions.
- 0: not covered.

### Totals

A library's **design score** on a task is the mean of its two design
scores; its **docs score** is the mean of its four documentation scores
(each 0 to 3). Its **design total** and **docs total** against another
library are the sums of those scores over the tasks common to the pair.

## Pass rule

xlkit passes when, for **both** judges and against **every** other
library:

1. xlkit's design total is higher than the other library's;
2. xlkit's docs total is higher than the other library's; and
3. each common task has an xlkit design score and docs score of at
   least 2.

Ties fail. A judge's scores stand as given; the two judges are not
averaged.

Against Stata only rule 1 and the design half of rule 3 apply, because
its documentation is not bundled (see "Stata" below).

## Protocol

**Material.** Each library's documentation is bundled as plain text:

- xlkit: `README.md`, every file in `docs/guide/` if there is one, the
  R page `docs/r.md`, `docs/stata.md`, and the API reference
  (`man/*.Rd` as text once the package exists; before then, the
  reference section of `docs/r.md`). The commit is recorded with each
  round.
- The other libraries: the files listed in [sources.md](sources.md) at
  the pinned versions.

**Blinding.** In every bundle, package and repository names are replaced
by "Library A", "Library B" and so on, in prose and in install and
import lines. Function and argument names stay, since removing them
breaks the examples. Judges are told not to use outside knowledge of any
library they think they recognise.

**Sessions.** One fresh session per judge per language group, with no
memory of the others:

| group | libraries |
|---|---|
| R | xlkit, readxl with writexl (one toolset: readxl reads, writexl writes), openxlsx2 |
| Python | xlkit, pandas, openpyxl, polars |
| Julia | xlkit, XLSX.jl |
| TypeScript | xlkit, SheetJS Community Edition, ExcelJS |
| Stata | xlkit, Stata's `import excel`, `export excel` and `putexcel` |

xlkit is an R package in every group. The other groups judge whether
an R user of xlkit writes less, and clearer, code for each scenario
than a user of the best libraries in other languages writes there. The
letters are assigned per session by a seeded random number generator;
the seed and the outcomes are published with the round.

**Stata.** Stata is proprietary, and this project does not read its
manuals (see `AGENTS.md`). The Stata session gets xlkit's bundle only,
is not blinded, and asks the judge to score Stata's commands from the
judge's own knowledge of them, for the two design scores only. The
judge writes out the Stata code it scores for each task, so a reader
can check it.

**Prompt.** The judge receives this file's "thirteen tasks", "Scores"
and the group's common/ours-only table, then each bundle, and returns
for each library and task the code it would write (at most a few
lines), the six scores, and one or two sentences of reason for each
score below 3, then a JSON block of the scores.

**Judges.** Claude Sonnet and GPT Terra, the latest version of each
that T3 Code offers; the exact model identifiers are recorded with each
round.

**Rounds.** A design round judges xlkit's documentation written as the
specification, before the code exists; its Correctness scores judge
whether the docs are consistent and the examples would run against the
described API. After a design round that fails, we may revise xlkit's
design and docs (never the other bundles or this file) and judge again
with new letters. Design rounds stop at the first pass or after five
rounds.

The **release round** judges the docs of the implemented package at a
recorded commit, after the implementation PRs. Only a pass in a release
round lets xlkit's README say that the judges preferred it. Every
round's prompts, bundle commits or versions, raw responses, score
tables and any disagreement between the judges go in
`docs/judging/round-N/`.

**Fresh-agent check.** With the release round, one fresh agent receives
only xlkit's documentation and a scratch directory, makes the workbooks
each scenario describes, and does all thirteen tasks with xlkit. Its
transcript and whether each task succeeded are published with the
round. This check is reported, not scored.
