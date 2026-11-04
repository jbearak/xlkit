# Prior art for xlkit

This file records how existing xlsx readers and writers handle the jobs that xlkit has to do. xlkit's goal is narrow: each `import excel`, `export excel` and `putexcel` line in a Stata do-file translated to R should become one line of R. So every library below is read with three questions in mind. What does the user type? What comes back? Where do users get hurt?

Studied on 2026-11-04. Each library is pinned to its latest release on that date. I read the source and docs at the pinned commits. I did not run any of the downloaded code.

## How to read this file

Each library section gives the pin, the license, and then the 13 tasks:

1. install
2. read a sheet into a table
3. choose what to read
4. header row and column names
5. column types
6. dates and times
7. missing values and Excel error values
8. read every sheet at once
9. write one table to a new workbook
10. write several tables
11. format output
12. write into an existing workbook
13. labels

Citations take three forms:

- Source lines, as `path:line` with a permalink at the pinned commit.
- Docs, by path in the pinned clone, or by a URL tied to a version where the project has one.
- Issues, by number with a URL. Every issue cited was looked up through the GitHub API (or the Gitea API for SheetJS) while writing this, to check that the number, title and state match.

Shorthand used in some sections:

- `SJ` is https://git.sheetjs.com/sheetjs/sheetjs/src/commit/8a7cfd47bde8258c0d91df6a737bf0136699cdf8/ (SheetJS source).
- `SJD` is https://git.sheetjs.com/sheetjs/docs.sheetjs.com/src/commit/8d1f8a0ea68341b33e51206392c095baad03cf11/docz/docs/ (SheetJS docs source).
- `EJ` is https://github.com/exceljs/exceljs/blob/ac96f9a61e9799c7776bd940f05c4a51d7200209/ (ExcelJS).
- In the pandas section, a bare `#Lnn` points into `pandas/io/excel/_base.py` at the pinned commit unless another file is named.
- In the openpyxl section, `openpyxl/...:line` is a path inside the 3.1.5 sdist, because the Mercurial repository could not be cloned (see below).

The clones are under `refs/others/<library>/` next to this repository (outside it). They are not part of xlkit.

## Pinned versions and licenses

| Library | Language | Version | Tag | Commit | License, file | GPL-3.0 compatible |
|---|---|---|---|---|---|---|
| readxl | R | 1.6.0 | `v1.6.0` | `9fcc1d21b77514d6b88ed15791054a8fb999e654` | MIT, `LICENSE` + `LICENSE.md` | yes |
| writexl | R | 2.0.1 | `v2.0.1` | `f4c283d996049da30d8704cbdddcf1e5579e2b49` | BSD-2-Clause, `LICENSE` | yes |
| openxlsx2 | R | 1.30 | `v1.30` | `4625e480577321a1dadf6de53ab3e52d2eee0b11` | MIT, `LICENSE` | yes |
| openxlsx | R | 4.2.9 | `4.2.9` (github.com/cran/openxlsx) | `adfbde151a086e1a829c20b408e8642ed53f0e4e` | MIT, `LICENSE` | yes |
| tidyxl | R | 1.0.10 | `1.0.10` (github.com/cran/tidyxl) | `40b3a5b00d3eee896f7cebadafeae43690ba270f` | MIT, `LICENSE` | yes |
| pandas | Python | 3.1.1 | `v3.1.1` | `3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1` | BSD-3-Clause, `LICENSE` | yes |
| openpyxl | Python | 3.1.5 | `3.1.5` (Mercurial, not reachable) | none; sdist sha256 `cf0e3cf56142039133628b5acffe8ef0c12bc902d2aadd3e0fe5878dc08d1050` | MIT, `LICENCE.rst` | yes |
| polars | Python | 2.1.0 | `py-2.1.0` | `7f902bd3ffd27ff82d14278a09a295ff2f7aed92` | MIT, `LICENSE` | yes |
| XlsxWriter | Python | 3.3.1 | `RELEASE_3.3.1` | `af5927c110cf01571046a3138600f63b256ea89a` | BSD-2-Clause, `LICENSE.txt` | yes |
| python-calamine | Python | 0.9.1 | `v0.9.1` | `551ab851b29fd19494346ffc58a71e368a363b6e` | MIT, `LICENSE` | yes |
| fastexcel | Python | 0.21.0 | `v0.21.0` | `8f8ab1580c2564240fff7263697f6a556c038263` | MIT, `LICENSE` | yes |
| XLSX.jl | Julia | 0.13.2 | `v0.13.2` | `13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5` | MIT, `LICENSE` | yes |
| SheetJS CE (xlsx) | JavaScript | 0.20.3 | `v0.20.3` (git.sheetjs.com) | `8a7cfd47bde8258c0d91df6a737bf0136699cdf8` | Apache-2.0, `LICENSE` | yes (Apache-2.0 suits GPL-3.0, though not GPL-2.0-only) |
| ExcelJS | JavaScript/TypeScript | 4.4.0 | `v4.4.0` | `ac96f9a61e9799c7776bd940f05c4a51d7200209` | MIT, `LICENSE` | yes |
| calamine | Rust | 0.38.0 | `v0.38.0` | `a4dba3b5309d81b2774018a13be39e68d938c3c7` | MIT, `LICENSE-MIT.md` | yes |
| rust_xlsxwriter | Rust | 0.102.0 | `v0.102.0` | `d850973d3836905db3a04022b093b3d5575ee85e` | MIT OR Apache-2.0, `LICENSE_MIT` + `LICENSE_Apache2.0` | yes |
| Stata | proprietary | n/a | n/a | n/a | proprietary; studied from general knowledge only | not applicable, nothing is used |

Every license here is compatible with GPL-3.0. The only one that is not MIT or BSD is Apache-2.0 (SheetJS CE, and one option of rust_xlsxwriter). Apache-2.0 is compatible with GPL-3.0 but not with GPL-2.0-only, so it is fine for a GPL-3.0 package. rust_xlsxwriter is dual-licensed, so xlkit can take it under MIT.

Notes on the pins:

- pandas 3.1.1 was uploaded to PyPI at 15:05 UTC on 2026-11-04, the day of this study, and is included.
- openpyxl's source lives in a Mercurial repository at https://foss.heptapod.net/openpyxl/openpyxl. It could not be cloned: there is no `hg` on this machine, the git endpoint answers "repository not found", and the web interface sits behind a bot challenge. I used the PyPI sdist for 3.1.5 and recorded its hash in place of a commit. The newest docs build is 3.1.3 (https://openpyxl.readthedocs.io/en/3.1.3/); `/en/3.1.5/` returns 404. openpyxl's issue tracker could not be searched for the same reason, so its pitfalls cite docs and source only.
- openxlsx and tidyxl were pinned through the CRAN mirror on GitHub. openxlsx's last GitHub release is v4.2.7, but CRAN has 4.2.9 (upstream merge commit `dedd7d6cc5fdc1e6df01f2b1934b8d9ce867a4e2`). tidyxl's upstream tags stop at v1.0.5 while CRAN has 1.0.10.
- SheetJS CE releases go to https://cdn.sheetjs.com/. The npm registry package `xlsx` stops at 0.18.5 (2022-03-24). The docs source repository (https://git.sheetjs.com/sheetjs/docs.sheetjs.com) was cloned at `8d1f8a0ea68341b33e51206392c095baad03cf11` (2026-08-02); it pins `xlsx-0.20.3` in `docz/package.json`.
- ExcelJS has a `v4.4.1` git tag (commit `1a8fd68371d7f34f58ea966fd6cf0f9ba7bfb0f5`, 2025-01-21) but no GitHub release for it, and npm only has `4.4.1-prerelease.0`. The latest release is 4.4.0.
- XLSX.jl moved from `felipenoris/XLSX.jl` to `JuliaData/XLSX.jl`. The old URL redirects; links below use the new one.
- rust_xlsxwriter and XlsxWriter publish git tags but no GitHub release objects. The tags match the crates.io and PyPI versions.

## readxl (R)

- Version 1.6.0, tag `v1.6.0`, commit `9fcc1d21b77514d6b88ed15791054a8fb999e654`, https://github.com/tidyverse/readxl. CRAN published 1.6.0 on 2026-10-17.
- License: MIT. `DESCRIPTION` says `License: MIT + file LICENSE`. The file `LICENSE` at the pinned commit reads, in full:

  ```
  YEAR: 2026
  COPYRIGHT HOLDER: readxl authors
  ```

  `LICENSE.md` holds the MIT text ("Copyright (c) 2026 readxl authors"). `LICENSE.note` covers bundled code: libxls (BSD-2-Clause, "Copyright 2004 Komarov Valery ... Copyright 2013-2018 Evan Miller") and others.
- GPL-3.0 compatibility: yes. MIT and BSD-2-Clause are permissive and GPL-compatible. xlkit takes design ideas only.
- Docs: https://readxl.tidyverse.org/

### 1 Install

```r
install.packages("readxl")
```

Compiled C++ (cpp11) with rapidxml and a bundled libxls for `.xls`. Imports cellranger, cli, rlang, tibble and utils. No Java. Version 1.6.0 also reads password-encrypted xlsx through `read_xlsx(password = )` (`NEWS.md`, #794).

### 2 Read a sheet into a table

```r
df <- read_excel("survey.xlsx")
```

The result is a tibble. Each column gets one R type from the cell types it holds (`vignettes/cell-and-column-types.Rmd`):

| cells | column |
|---|---|
| all blank | `logical` of `NA` |
| boolean | `logical` |
| number with a date format | `POSIXct`, tz `"UTC"` |
| number | `double` (never `integer`) |
| text | `character` |
| mixed, with `col_types = "list"` | list of length-1 vectors |

Pitfalls:

- Dates always come back as `POSIXct`, never `Date`, even when the cell has no time part. The empty date column is built with `class = c("POSIXct", "POSIXt")` and `tzone = "UTC"` ([src/ColSpec.h:257-262](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/ColSpec.h#L257-L262)). Stata users expect a daily date (`%td`) to arrive as a date.
- An all-blank column becomes `logical`, not character or double ([src/ColSpec.h:203-213](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/ColSpec.h#L203-L213)).
- Formula cells give the cached value Excel last saved. readxl does not evaluate formulas, and a file written by a tool that does not compute values reads as blank there.

### 3 Choose what to read

```r
excel_sheets("survey.xlsx")                          # list sheet names
read_excel("survey.xlsx", sheet = "wave2")           # by name
read_excel("survey.xlsx", sheet = 2)                 # by position
read_excel("survey.xlsx", range = "B3:D87")
read_excel("survey.xlsx", range = "wave2!B3:D87")    # sheet inside range
read_excel("survey.xlsx", range = cell_rows(6:23))   # also cell_cols("B:D"), anchored("C4", dim = c(3, 2))
read_excel("survey.xlsx", skip = 3)                  # table below 3 title rows
```

Pitfalls:

- `skip` is a lower bound. Leading empty rows are skipped on top of it, so `skip = 1` on a sheet whose row 2 is empty skips both (`vignettes/sheet-geometry.Rmd`, "skip" section). `n_max` is an upper bound, and trailing empty rows never appear.
- `range` is taken literally and overrides `skip`, `n_max` and `sheet`. A sheet named in `range` wins over `sheet =` with only a message ([R/read_excel.R:315-325](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/R/read_excel.R#L315-L325)).
- The default "shrink wrap" rectangle can include cells that look empty but carry formatting, which adds rows or columns of `NA` (`vignettes/sheet-geometry.Rmd`, "what is a blank cell").
- Stata's `cellrange(A3:)` (open-ended) has a partial analogue in `cell_limits(c(3, 1), c(NA, NA))`. `range = "A3:"` is not valid.

### 4 Header row and column names

```r
read_excel(path)                                           # first row is the header
read_excel(path, col_names = FALSE)                        # names ...1, ...2
read_excel(path, col_names = c("id", "wt"), skip = 1)      # your own names
read_excel(path, .name_repair = "universal")               # syntactic names
read_excel(path, .name_repair = janitor::make_clean_names) # any function
```

`.name_repair` is passed to `tibble::as_tibble()`. The default `"unique"` turns blank names into `...3` and duplicates into `x...2`, `x...5` (vctrs rules; `vignettes/articles/column-names.Rmd`). `"minimal"` leaves names as they are.

Pitfalls:

- No multi-row header support. The article `vignettes/articles/multiple-header-rows.Rmd` reads the file twice: once with `n_max = 0` to get names, then with `skip = 2, col_names = cnames`. Users keep asking for a built-in ([#486](https://github.com/tidyverse/readxl/issues/486), closed; the last comment posts a `read_excel_multiheader()` wrapper; also [#379](https://github.com/tidyverse/readxl/issues/379)).
- A header row that holds numbers or dates gets converted to text with R's formatting, so a header of `2024` stays `"2024"` but a date header becomes a serial-looking string.

### 5 Column types

```r
read_excel(path, guess_max = 10000)
read_excel(path, guess_max = Inf)
read_excel(path, col_types = "text")                                   # recycled
read_excel(path, col_types = c("text", "skip", "numeric", "date", "guess"))
read_excel(path, col_types = c("text", "list"))
```

Guessing: readxl looks at the first `guess_max = min(1000, n_max)` data rows ([R/read_excel.R:152](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/R/read_excel.R#L152)) and keeps a running maximum per column over blank < logical < date < numeric < text ([src/SheetView.h:93-108](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/SheetView.h#L93-L108); the vignette calls text "the column type of last resort").

When a cell does not fit the chosen type, readxl coerces or writes `NA`, and warns per cell with its address ([src/SheetView.h:173-246](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/SheetView.h#L173-L246)):

- `Expecting numeric in B1002: got 'n/a'` gives `NA`.
- `Coercing text to numeric in B5: '12'` gives 12.
- `Coercing numeric to date in C4` treats the number as a serial.
- `Expecting numeric in D3: got a date` gives the serial number.
- A text column never warns: "text is the fallback column type and there are too many warnings to be helpful" ([src/SheetView.h:253-255](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/SheetView.h#L253-L255)).

Pitfalls:

- The classic failure: a column is numeric for 1,000 rows and has a text code at row 1,500. The guess is numeric, the text becomes `NA`, and the user gets hundreds of warnings. The fix is `guess_max` or `col_types`. `guess_max` was adopted from readr in [#223](https://github.com/tidyverse/readxl/issues/223).
- `col_types` is positional only. You cannot write `col_types = c(id = "text")`; you must give every column. The request for a readr-style named spec has been open since 2016 ([#198](https://github.com/tidyverse/readxl/issues/198), open since 2016-08-25; a 2025-02-28 comment says dates "are sometimes read as strings that look like '1/1/1900' or '24108'").
- `col_types` has no integer and no `Date` choice.

### 6 Dates and times

Detection is by number format, not by value:

- Built-in format ids 14-22, 27-36, 45-47, 50-58 and 71-81 are dates ([src/ColSpec.h:111-145](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/ColSpec.h#L111-L145)).
- A custom format (id 164 and up) is a date if it contains `d`, `h`, `m`, `s` or `y` outside quotes and brackets, and is not `General` ([src/ColSpec.h:157-188](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/ColSpec.h#L157-L188); the code credits tidyxl and [#388](https://github.com/tidyverse/readxl/issues/388)).

The 1904 system is read from `workbookPr/@date1904` ([src/XlsxWorkBook.h:332-353](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/XlsxWorkBook.h#L332-L353)), with offsets 25569 and 24107 days ([src/utils.h:47-51](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/utils.h#L47-L51)). The Lotus 1900 leap-year bug is handled: serials below 60 shift by a day, serial 60 (the fake 1900-02-29) becomes `NA` with a warning, and negative serials become `NA` ([src/utils.h:73-87](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/utils.h#L73-L87)). Values are rounded to the millisecond.

Time zone: always UTC. A request for a `tz` argument was closed as "best left as a well-documented, after-import transformation" ([#347](https://github.com/tidyverse/readxl/issues/347)).

To turn detection off for one column, use `col_types = "numeric"` to get the serial (with a per-cell warning) or `"text"`. There is no switch to turn it off for the whole sheet while keeping the other guesses.

Pitfalls:

- A time-only cell (`h:mm`) comes back as a `POSIXct` on 1899-12-31. readxl has no `hms` type.
- A date typed as text, or a date serial in a `General` cell, arrives as text or a number ([#198](https://github.com/tidyverse/readxl/issues/198) comments).

### 7 Missing values and Excel errors

```r
read_excel(path, na = c("", "NA", ".", "-99"))
```

`na` is matched against the cell's string, or against the raw `<v>` text for numbers, after optional trimming ([src/XlsxCell.h:128-139](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/XlsxCell.h#L128-L139)).

Error cells (`t="e"`: `#N/A`, `#DIV/0!`, `#VALUE!`) become blank, so they read as `NA` with no warning and no record of which error it was ([src/XlsxCell.h:168-172](https://github.com/tidyverse/readxl/blob/9fcc1d21b77514d6b88ed15791054a8fb999e654/src/XlsxCell.h#L168-L172)).

Pitfalls:

- Errors are silently lost.
- A cell holding only spaces becomes `NA` even with `trim_ws = FALSE` ([#572](https://github.com/tidyverse/readxl/issues/572), open).
- `na` is one vector for all columns. There is no per-column `na`.

### 8 Read every sheet at once

No function does this. The workflows article shows the idiom (`vignettes/articles/readxl-workflows.Rmd`):

```r
path <- "survey.xlsx"
sheets <- excel_sheets(path)
all <- lapply(setNames(sheets, sheets), read_excel, path = path)
# or: path |> excel_sheets() |> set_names() |> map(read_excel, path = path)
```

### 9 to 12 Writing

Not supported. readxl only reads. Its README mentions writexl as the writing option (`README.md:256`), and the pair is used together (`writexl/README.md` round-trips through `readxl::read_xlsx()`).

### 13 Labels

Not supported. readxl attaches no variable labels and no value labels.

## writexl (R)

- Version 2.0.1, tag `v2.0.1`, commit `f4c283d996049da30d8704cbdddcf1e5579e2b49`, https://github.com/ropensci/writexl. CRAN published 2.0.1 on 2026-08-21.
- License: BSD-2-Clause. `DESCRIPTION` says `License: BSD_2_clause + file LICENSE`. The file `LICENSE` at the pinned commit reads, in full:

  ```
  YEAR: 2017
  COPYRIGHT HOLDER: Jeroen Ooms
  ```

  The bundled libxlsxwriter (BSD-2-Clause, John McNamara) is covered by `inst/COPYRIGHT` and `inst/AUTHORS`.
- GPL-3.0 compatibility: yes. BSD-2-Clause is permissive and GPL-compatible.
- Docs: https://docs.ropensci.org/writexl/

Note: writexl 2.0.0 (2026-08) changed a lot. Bill Denney took over as maintainer and the package grew from "write a data frame" to most of libxlsxwriter: formats, column specs, freeze panes, filters, tables, merges, charts and images (`NEWS.md`, "writexl 2.0.0"). Older advice that "writexl cannot format anything" is out of date.

### 1 Install

```r
install.packages("writexl")
```

No R package dependencies. It bundles libxlsxwriter 1.2.4 and needs only zlib (`DESCRIPTION`).

### 2 to 8 Reading

Not supported. `vignettes/a-getting-started.Rmd` ends with "writexl only writes. To read, use readxl".

### 9 Write one table to a new workbook

```r
write_xlsx(df, "out.xlsx")
```

The signature is `write_xlsx(x, path = tempfile(fileext = ".xlsx"), col_names = TRUE, format_headers = TRUE, na = NA, use_zip64 = FALSE, constant_memory = NA, ...)` ([R/write_xlsx.R:56-59](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L56-L59)). It returns the path invisibly, so `read_xlsx(write_xlsx(df))` works.

Type mapping (`vignettes/a-getting-started.Rmd`, "What is written"; C side in [src/write_xlsx.c:35-55](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/src/write_xlsx.c#L35-L55)):

| R | Excel |
|---|---|
| character | text |
| numeric, integer | number |
| logical | TRUE/FALSE |
| Date, POSIXct | number with a date or datetime format |
| factor, hms | labels as text ([R/write_xlsx.R:374-377](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L374-L377)) |
| difftime | number of seconds |
| integer64 | double, with a warning |
| complex, raw, list | error naming the column ([R/write_xlsx.R:404-424](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L404-L424)) |

`NA` and `NaN` are written as empty cells. `na = "not measured"` writes a stand-in instead, and keeps its type.

Overwrite: there is no `overwrite` argument. libxlsxwriter creates a new file at `path`, and any existing file there is replaced without a prompt.

Pitfalls:

- Time zones. Excel has none. Since 2.0.0, if every `POSIXct` in the workbook shares one zone, writexl writes local wall-clock time. If the zones differ, it converts all of them to UTC and warns ([R/write_xlsx.R:221-243](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L221-L243)). Before 2.0.0 everything silently became UTC. Scripts that relied on that now see shifted values (`NEWS.md`, "Breaking changes").
- Dates before 1900-03-01 were written one day late before 2.0.0 (`NEWS.md`).
- The default `path` is a temp file. Forgetting `path` "works" and writes nowhere useful.
- More than 1,048,576 rows is an error ([R/write_xlsx.R:371-373](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L371-L373)).

### 10 Write several tables

```r
write_xlsx(list(Flowers = iris, Cars = mtcars), "out.xlsx")
```

A named list writes one sheet per element. Sheet names are repaired: forbidden characters `[ ] : * ? / \` are replaced, names are cut to 31 characters and deduplicated, with a warning ([R/sheet_names.R:92-97](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/sheet_names.R#L92-L97); `vignettes/a-getting-started.Rmd`).

Several tables on one sheet at given positions: not supported. `xl_sheet()` takes one data frame and writes it from A1 ([R/xl_sheet.R:243-252](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/xl_sheet.R#L243-L252)). There is no start-cell argument.

### 11 Format output

```r
write_xlsx(df, "out.xlsx")                    # header bold and centred by default
write_xlsx(df, "out.xlsx", format_headers = FALSE)

sheet <- xl_sheet(
  df,
  cols = list(
    xl_col_spec("income", format = xl_num_format("#,##0.00"), width = 12),
    xl_col_spec("share",  format = xl_num_format("0.0%"))
  ),
  freeze = "A2",
  auto_colwidth = TRUE,
  autofilter = TRUE,
  merge = xl_merge("A1:C1", value = "Title")
)
write_xlsx(list(Results = sheet), "out.xlsx")
```

Formats are objects that combine with `+`, for example `xl_num_format("$#,##0") + xl_font(bold = TRUE)`, and the same object can style a cell, a column, a chart series or a conditional rule (`vignettes/a-getting-started.Rmd`; `man/xl_format.Rd`). Workbook-wide defaults go in `xl_properties()`, for example `header_format`, `date_format` and `datetime_format`.

Pitfalls:

- `auto_colwidth` is a character-count heuristic, "since the xlsx format has no true AutoFit" ([R/xl_sheet.R:167-169](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/xl_sheet.R#L167-L169)).
- Excel does not apply an autofilter's criteria when it opens a file. writexl hides the excluded rows itself so the sheet looks the way the filter says (`NEWS.md`, "Autofilters").
- Streaming mode (`constant_memory`) is switched off for merges, tables, embedded images and multi-cell array formulas, because those cannot be streamed ([R/write_xlsx.R:37-44](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/R/write_xlsx.R#L37-L44)).

### 12 Write into an existing workbook

Not supported. libxlsxwriter cannot read a file. Requests to append or replace a sheet were closed as out of scope: [#29](https://github.com/ropensci/writexl/issues/29) ("Add an append option") and [#66](https://github.com/ropensci/writexl/issues/66) ("out of scope for this package since it writes files, only"). There is no `putexcel`-style cell writing into a template.

### 13 Labels

- Factors are written as their labels. This is the closest thing to "value labels as text".
- A `haven_labelled` double is a classed double, so `get_type()` treats it as a plain number. The value labels are dropped ([src/write_xlsx.c:35-55](https://github.com/ropensci/writexl/blob/f4c283d996049da30d8704cbdddcf1e5579e2b49/src/write_xlsx.c#L35-L55)).
- Variable labels (`attr(x, "label")`) are ignored. A grep for "labelled", "haven" and "label" attributes in `R/` and `src/write_xlsx.c` finds nothing.

## openxlsx2 (R)

- Version 1.30, tag `v1.30`, commit `4625e480577321a1dadf6de53ab3e52d2eee0b11`, https://github.com/JanMarvin/openxlsx2. CRAN published 1.30 on 2026-10-11.
- License: MIT. `DESCRIPTION` says `License: MIT + file LICENSE`. The file `LICENSE` at the pinned commit reads, in full:

  ```
  YEAR: 2021-2026
  COPYRIGHT HOLDER: openxlsx2 authors
  ```

- GPL-3.0 compatibility: yes. MIT is permissive and GPL-compatible.
- Docs: https://janmarvin.github.io/openxlsx2/

openxlsx2 is a rewrite of openxlsx around an R6 `wbWorkbook` object. Every `wb_*()` wrapper has a matching method (`wb_add_data(wb, ...)` and `wb$add_data(...)`). `dims` is the one way to address cells.

### 1 Install

```r
install.packages("openxlsx2")
```

Imports R6, Rcpp, grDevices, stringi and utils. Compiled C++ with pugixml. No Java.

### 2 Read a sheet into a table

```r
df <- read_xlsx("survey.xlsx")       # thin wrapper
df <- wb_to_df("survey.xlsx")        # full interface
```

The result is a plain `data.frame`, not a tibble. Types come from cell types, and every cell in the column is checked ([R/wb_functions.R:196-239](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/wb_functions.R#L196-L239)). A column gets a type only if every non-missing cell has it. Otherwise it is character. The type codes are 0 character, 1 numeric, 2 Date, 3 POSIXct, 4 logical, 5 hms and 6 formula (`man/wb_to_df.Rd`).

Pitfalls:

- A column with one stray text cell becomes character, and its numbers become strings. There is no running maximum as in readxl, and no warning.
- Time-only cells become `hms` if the hms package is loaded and `"hh:mm:ss"` strings if it is not ([R/read.R:79-82](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L79-L82)). The output type depends on session state.
- Formulas added with `wb_add_formula()` have no cached value, so reading them back gives empty cells unless `show_formula = TRUE` ([R/read.R:86-93](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L86-L93)).

### 3 Choose what to read

```r
wb_get_sheet_names(wb_load("survey.xlsx"))
wb_to_df(path, sheet = "wave2")             # or sheet = 2
wb_to_df(path, dims = "B3:D87")
wb_to_df(path, dims = "A3:F+")              # A3 to the last row of column F
wb_to_df(path, start_row = 4)               # table below 3 title rows
wb_to_df(path, rows = 4:100, cols = c(1, 3))
wb_to_df(path, cols = -2)                   # negative drops a column (1.29)
wb_to_df(path, named_region = "Table1")     # a defined name or an Excel table
wb_to_df(path, skip_hidden_rows = TRUE, skip_empty_cols = TRUE)
```

`dims` takes wildcards: `"A2:C+"` reads to the last row of C, and `"A-:+9"` reads from the first populated row ([R/read.R:66-75](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L66-L75)). Reading a named Excel table is something readxl cannot do.

Pitfalls:

- Before 1.x there were several overlapping ways to say the same thing (`start_row`, `rows`, `dims`). NEWS records argument renames across versions ([#681](https://github.com/JanMarvin/openxlsx2/issues/681), "Thoughts / observations about arguments / fn name consistency").
- `wb_to_df(file)` loads the file into a workbook first ([R/read.R:315](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L315)). It uses a data-only mode for this, but reading several sheets from a path parses the file once per call. Load once with `wb_load()` and pass the workbook instead.

### 4 Header row and column names

```r
wb_to_df(path, col_names = TRUE)        # default
wb_to_df(path, col_names = FALSE)       # names are column letters A, B, C
wb_to_df(path, check_names = TRUE)      # make.names(unique = TRUE)
wb_to_df(path, row_names = TRUE)        # first column becomes row names
```

The header row is converted to text with the same type engine, so a date header is formatted as a date string ([R/read.R:822-838](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L822-L838)).

Pitfalls:

- With the default `check_names = FALSE`, names are assigned as they are ([R/read.R:928-934](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L928-L934)). Duplicate and blank headers survive into the `data.frame`, and `df$x` then picks the first match.
- No multi-row header support and no function hook for name cleaning.

### 5 Column types

```r
wb_to_df(path, types = c(id = "character", income = "numeric"))
wb_to_df(path, types = c(id = 0, income = 1))
wb_to_df(path, convert = FALSE)          # everything as character
wb_to_df(path, keep_attributes = TRUE)   # attr(df, "tt") holds each cell's type
```

`types` is named, so you only list the columns you want to fix. The rest are guessed ([R/read.R:844-876](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L844-L876)). A name that is not in the data gives a warning; when no name matches, it is an error. The cell-by-cell type table `tt` is a useful debugging aid.

Pitfalls:

- `types` once matched by position rather than name ([#1146](https://github.com/JanMarvin/openxlsx2/issues/1146), closed).
- A cell that does not fit a forced type is coerced by `as.numeric()` and friends, which gives `NA` with R's generic "NAs introduced by coercion" warning and no cell address.

### 6 Dates and times

```r
wb_to_df(path, detect_dates = TRUE)    # default
wb_to_df(path, detect_dates = FALSE)   # serial numbers
```

Detection uses the cell style's number format: date, datetime and hms styles are found from `numFmts` (`numfmt_is_hms`, [R/read.R:408](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L408)). The 1904 system is read from `workbookPr` ([R/dates.R:91-104](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/dates.R#L91-L104)). Since 1.15 all datetimes come back in `"UTC"` ([R/read.R:117-120](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L117-L120)). Date-only formats give `Date`, which is better than readxl.

Pitfalls:

- `detect_dates = TRUE` is skipped when `types` is given ([R/read.R:592](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L592): `if (detect_dates && missing(types) ...)`). Fixing one column's type changes how dates in the other columns are found.
- On write, a datetime can differ by one second after a round trip because of floating point (`man/wb_add_data.Rd`, details).

### 7 Missing values and Excel errors

```r
wb_to_df(path, na = c("", "NA", "#N/A"))
wb_to_df(path, na = list(strings = c("", "."), numbers = -99))
```

The default is `na = "#N/A"` ([R/read.R:243](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L243)). Error cells (`t="e"`) are read as their text, for example `"#DIV/0!"` ([R/read.R:542-546](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/read.R#L542-L546)). `na` can separate string and numeric missing codes, which suits survey data with `-99`.

Pitfalls:

- Only `#N/A` becomes `NA` by default. One `#DIV/0!` in a numeric column turns the whole column into character, because the error is a string cell to the type engine.

### 8 Read every sheet at once

No built-in. Load once, then loop:

```r
wb <- wb_load(path)
all <- lapply(setNames(nm = wb_get_sheet_names(wb)), \(s) wb_to_df(wb, sheet = s))
```

### 9 Write one table to a new workbook

```r
write_xlsx(df, "out.xlsx")                                     # returns the wbWorkbook
wb_workbook()$add_worksheet("data")$add_data(x = df)$save("out.xlsx")
```

Type mapping is done in C++ `openxlsx2_type()` ([src/helper_functions.cpp:25-115](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/src/helper_functions.cpp#L25-L115)):

- Date and POSIXct are written with date and datetime formats, from `options("openxlsx2.dateFormat" = "mm/dd/yyyy")` and `options("openxlsx2.datetimeFormat")`.
- Classes `currency`, `accounting`, `percentage`, `scientific`, `comma`, `hyperlink` and `formula` get matching formats or cell kinds.
- A factor, or any vector with a `labels` attribute, is written as text.
- Any other classed numeric is also treated as factor-like and written as text.
- Logical is written as boolean and list columns are collapsed with `sep`.

Overwrite: `wb_save(overwrite = TRUE)` is the default ([R/class-workbook-wrappers.R:160-163](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/class-workbook-wrappers.R#L160-L163)). The vignette warns "The default is to save the file and replace an existing file" (`vignettes/openxlsx2.Rmd:177`).

Pitfalls:

- `NA` is written as the error value `#N/A` by default, not as an empty cell. The default `na = na_strings()` sets `na_missing`, and the writer emits `t="e"` with `#N/A` ([src/helper_functions.cpp:866-871](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/src/helper_functions.cpp#L866-L871); `R/write_xlsx.R:291-302`). Excel's `SUM()` over such a column returns `#N/A`. `NaN` becomes `#VALUE!` and `Inf` becomes `#NUM!`. Use `na = NULL` or `options(openxlsx2.na = "_openxlsx_NULL")` for blanks. This differs from writexl, which writes blanks, and from Stata, which writes blanks.
- The strings `"_openxlsx_NA"`, `"_openxlsx_Inf"`, `"_openxlsx_nInf"` and `"_openxlsx_NaN"` are reserved. Data that contains them is written wrongly (`man/wb_add_data.Rd`).
- Every `wb_add_*()` wrapper deep-copies the workbook: `wb$clone(deep = TRUE)$add_data(...)` ([R/class-workbook-wrappers.R:311](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/class-workbook-wrappers.R#L311)). This gives value semantics in pipes, but costs time and memory on large workbooks. The `wb$method()` form modifies in place.
- `options("openxlsx2.string_nums" = TRUE)` writes `"1"` as the number 1 (`R/openxlsx2-package.R:201-202`). Global options change output silently.

### 10 Write several tables

```r
write_xlsx(list(IRIS = iris, CARS = mtcars), "out.xlsx")
write_xlsx(l, "out.xlsx", start_col = c(1, 2, 3), start_row = 2)   # per-sheet vectors

wb <- wb_workbook()$add_worksheet("Results")
wb$add_data(x = tab1, dims = "A1")
wb$add_data(x = tab2, dims = wb_dims(from_row = nrow(tab1) + 3))
wb$add_data_table(x = tab3, dims = "H1", table_style = "TableStyleMedium2")
wb$save("out.xlsx")
```

`wb_dims()` computes ranges from a data frame: `wb_dims(x = df, cols = "income", select = "data")` gives the cells of one column below the header (`man/wb_dims.Rd`). Of the libraries studied, this is the most direct way to place several tables on one sheet and then style parts of them.

### 11 Format output

```r
wb <- wb_workbook()$add_worksheet("data")$add_data(x = df)
wb$add_font(dims = wb_dims(x = df, select = "col_names"), bold = TRUE)
wb$add_numfmt(dims = wb_dims(x = df, cols = "income"), numfmt = "#,##0.00")
wb$set_col_widths(cols = seq_along(df), widths = "auto")    # or "auto+2" (1.30)
wb$freeze_pane(first_row = TRUE)
wb$add_filter(rows = 1, cols = seq_along(df))
wb$merge_cells(dims = "A1:C1")
wb$save("out.xlsx")
```

Shortcuts in `write_xlsx()`: `col_widths = "auto"`, `first_row = TRUE` (freeze), `with_filter = TRUE` and `as_table = TRUE`. Reference pages: `man/wb_add_font.Rd`, `man/wb_add_numfmt.Rd`, `man/col_widths-wb.Rd`, `man/wb_freeze_pane.Rd`, `man/filter-wb.Rd` and `man/wb_merge_cells.Rd`. Styles are managed per cell range. `wb_add_cell_style()` sets alignment and wrap.

Pitfalls:

- `wb_add_font()` replaces the whole font, so a call with `bold = TRUE` also resets name, size and colour to its defaults, `name = "Aptos Narrow"` and size 11 ([R/class-workbook-wrappers.R:4138-4144](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/class-workbook-wrappers.R#L4138-L4144)). Styling in layers needs care.
- "auto" widths are estimated from string lengths, and the minimum and maximum are global options (`man/col_widths-wb.Rd`). The 1.30 NEWS fixes a bug where auto widths and `apply_numfmts` interacted ([#1683](https://github.com/JanMarvin/openxlsx2/pull/1683)).
- Only one autofilter per sheet (`man/wb_add_data.Rd`, `with_filter`).

### 12 Write into an existing workbook

Replace one sheet and keep the others:

```r
wb <- wb_load("report.xlsx")
wb$clean_sheet(sheet = "data")               # clears values, styles, merges
wb$add_data(sheet = "data", x = df)
wb$save("report.xlsx")
# or: wb$remove_worksheet("data")$add_worksheet("data")$add_data(x = df), then wb$set_order(...)
```

Put values into given cells of a template, like `putexcel`:

```r
wb <- wb_load("template.xlsx")
wb$add_data(sheet = "Table 1", x = 0.531, dims = "C5")
wb$add_data(sheet = "Table 1", x = coefs, dims = "B8", col_names = FALSE)
wb$add_formula(sheet = "Table 1", x = "SUM(C8:C12)", dims = "C13")
wb$save("filled.xlsx")
```

By default `add_data()` keeps the target cell's existing style (`apply_cell_style = TRUE`, `remove_cell_style = FALSE`; `man/wb_add_data.Rd`), so a template's number formats and borders survive. That is what `putexcel` users expect.

What is preserved: openxlsx2 says it imports "Every sheet, every chart, image, column, formula style, conditional formatting, pivot table and whatever else a spreadsheet file is allowed to carry" (`vignettes/openxlsx2.Rmd:41`). Exceptions:

- The calculation chain is dropped by default (`man/wb_load.Rd`).
- `.xlsb` loading lacks conditional formatting, data validation, pivot tables and slicers (`R/wb_load.R:40-48`).
- Partial loads with `sheet =` or `data_only = TRUE` are not meant to be saved again (`vignettes/openxlsx2.Rmd:161`).

Pitfalls:

- Round-trip bugs do happen. [#1032](https://github.com/JanMarvin/openxlsx2/issues/1032) ("wb_save outputs a file which Excel perceives as corrupted") was fixed in 1.7.
- Writing a smaller table over a larger one leaves the old cells. Call `wb_clean_sheet()` first. openxlsx 4.2.9 added an `overwrite` argument to `writeData()` for the same reason (openxlsx `NEWS.md`, #536).
- Formulas written from R have no cached values until Excel recalculates.

### 13 Labels

Value labels: a vector with a `labels` attribute (`haven_labelled`) is typed as "factor" ([src/helper_functions.cpp:86](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/src/helper_functions.cpp#L86)). `to_string()` then replaces each labelled value with its label text and leaves unlabelled values as numbers-in-text ([R/helper-functions.R:778-809](https://github.com/JanMarvin/openxlsx2/blob/4625e480577321a1dadf6de53ab3e52d2eee0b11/R/helper-functions.R#L778-L809); added in [#639](https://github.com/JanMarvin/openxlsx2/pull/639)). There is no switch to write the codes instead.

Pitfalls:

- A bug wrote the label only the first time each category appeared and the number after that ([#1406](https://github.com/JanMarvin/openxlsx2/issues/1406), closed).
- Because the whole column becomes text, unlabelled numeric codes are written as strings, not numbers.

Variable labels: not used. Headers are the column names, and no code reads `attr(x, "label")`.

## openxlsx (R, brief)

- Version 4.2.9 (CRAN, 2026-09-02). Pinned through the CRAN mirror: https://github.com/cran/openxlsx, tag `4.2.9`, commit `adfbde151a086e1a829c20b408e8642ed53f0e4e`. Upstream is https://github.com/ycphs/openxlsx. Its last GitHub release is v4.2.7 (2024-08-30), and the 4.2.9 merge is commit `dedd7d6cc5fdc1e6df01f2b1934b8d9ce867a4e2`.
- License: MIT. `LICENSE` reads `YEAR: 2014-2025` / `COPYRIGHT HOLDER: openxlsx authors`. GPL-3.0 compatible.
- Status: `NEWS.md` says openxlsx "is no longer under active development" and points new users to readxl, writexl or openxlsx2.

It differs from openxlsx2 in a few ways that taught users bad habits:

- `read.xlsx()` defaults to `detectDates = FALSE`, so dates arrive as serial numbers unless you ask (`R/readWorkbook.R`, signature).
- `na.strings = "NA"` is the default, and `check.names = FALSE` with `sep.names = "."` turns spaces in headers into dots.
- `saveWorkbook()` defaults to `overwrite = FALSE` (`R/wrappers.R:93`), but `write.xlsx()` defaults to `overwrite = TRUE` (`R/writexlsx.R:62`). Two save paths with opposite defaults.
- Arguments are camelCase (`startRow`, `colNames`), the API is function-based (`addWorksheet()`, `writeData()`, `addStyle()`, `createStyle()`, `setColWidths(widths = "auto")`, `freezePane()`, `mergeCells()`), and `loadWorkbook()` plus `writeData()` is the long-standing R answer to `putexcel` into a template.
- 4.2.9 added `overwrite` to `writeData()` to clear stale cells when a smaller range is written over a larger one ([ycphs/openxlsx#536](https://github.com/ycphs/openxlsx/pull/536)).
- Nothing handles labelled vectors.

The lesson for xlkit: date detection should be on by default, and every save path should share one overwrite default.

## tidyxl (R, brief)

- Version 1.0.10 (CRAN, 2023-12-21). Pinned through the CRAN mirror: https://github.com/cran/tidyxl, tag `1.0.10`, commit `40b3a5b00d3eee896f7cebadafeae43690ba270f`. Upstream is https://github.com/nacnudus/tidyxl, whose newest GitHub tag is v1.0.5, so CRAN releases after that are not tagged upstream.
- License: MIT. `LICENSE` reads `YEAR: 2020` / `COPYRIGHT HOLDER: Duncan Garmonsway`. GPL-3.0 compatible.

tidyxl does not build a data frame of your table. `xlsx_cells(path, sheets = NA)` returns one row per cell with `sheet`, `address`, `row`, `col`, `data_type`, and typed value columns (`numeric`, `date`, `character`, `logical`, `error`), plus `formula`, `is_array`, `character_formatted` (rich-text runs) and `local_format_id` (`README.md`; `R/xlsx_cells.R:148`). `xlsx_formats()` returns the formatting tables that `local_format_id` indexes, and `xlsx_names()` and `xlsx_validation()` expose defined names and validation rules. It reads only. The companion package unpivotr turns the cells into tidy data for messy layouts such as multi-row headers.

What it does differently: errors are kept in their own `error` column rather than lost, each cell keeps its own type, and the format-string test for dates that readxl uses came from tidyxl (readxl `src/ColSpec.h:150-152` credits it). The lesson for xlkit is that a low-level "cells" reader is the right tool for layouts no header rule can handle, and that error values deserve a column, not `NA`.

## pandas (Python)

- Version 3.1.1, tag `v3.1.1`, commit `3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1`, released 2026-11-04 (PyPI upload 15:05 UTC).
- Repository: https://github.com/pandas-dev/pandas. Sparse clone at `refs/others/pandas/` holding `pandas/io/excel/`, `pandas/io/formats/`, `pandas/core/generic.py`, `pandas/core/frame.py`, `doc/source/user_guide/io.rst`, `doc/source/reference/`, `LICENSE`, `LICENSES/`.
- License: BSD-3-Clause. `LICENSE` line 1 reads "BSD 3-Clause License"; `pyproject.toml` line 28 has `license = 'BSD-3-Clause'`. Copyright lines, verbatim:
  - "Copyright (c) 2008-2011, AQR Capital Management, LLC, Lambda Foundry, Inc. and PyData Development Team"
  - "Copyright (c) 2011-2026, Open source contributors."
- GPL-3.0 compatibility: yes. BSD-3-Clause is a permissive license that the FSF lists as GPL-compatible. xlkit would only borrow design ideas, so nothing needs to be carried over except credit.

pandas does not parse xlsx itself. It hands the file to an "engine" library and then runs the cell values through the same text parser it uses for CSV. Most of its Excel behavior, and most of its surprises, come from that split.

| Job | Default engine at 3.1.1 | Other choices |
|---|---|---|
| Read .xlsx/.xlsm | openpyxl (deprecated default; calamine will become the default) | calamine |
| Read .xls / .xlsb | xlrd / pyxlsb if installed (both deprecated), else calamine | calamine |
| Write .xlsx | xlsxwriter if installed, else openpyxl | openpyxl |
| Write .xlsm | openpyxl | none |
| Append to an existing file | openpyxl only | xlsxwriter raises "Append mode is not supported with xlsxwriter!" |

Sources: [pandas/io/excel/_util.py:68-95](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_util.py#L68-L95), [pandas/io/excel/_base.py:1686-1708](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L1686-L1708) (the FutureWarning-style `Pandas4Warning` about the calamine switch, GH 56542), [pandas/io/excel/_xlsxwriter.py:203-204](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_xlsxwriter.py#L203-L204).

### 1 Install

```python
pip install "pandas[excel]"   # pulls openpyxl, xlsxwriter, python-calamine, odfpy, pyxlsb, xlrd
```

The `excel` extra is defined in `pyproject.toml` line 96 (minimums: openpyxl 3.1.5, python-calamine 0.4.0, xlsxwriter 3.2.5). A plain `pip install pandas` installs none of them, and the first `read_excel` call fails with a "Missing optional dependency 'openpyxl'" import error. Users have to know which engine package matches which file type.

### 2 Read a sheet into a table

```python
df = pd.read_excel("survey.xlsx")              # first sheet, row 0 as header
df = pd.read_excel("survey.xlsx", engine="calamine")
```

Returns a `DataFrame` (or a `dict` of them, see task 8). Signature: [pandas/io/excel/_base.py:162-196](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L162-L196).

How cell types become column types. The engine first turns each cell into a Python value. With openpyxl ([pandas/io/excel/_openpyxl.py:713-729](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L713-L729)): an empty cell becomes `""`, an error cell becomes `np.nan`, a number that is a whole number becomes `int`, other numbers `float`, dates come back as `datetime` objects because openpyxl already applied the number format. With calamine ([pandas/io/excel/_calamine.py:104-127](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_calamine.py#L104-L127)): whole floats become `int`, `date` is widened to `datetime` to match openpyxl, times stay `datetime.time`. That list of lists then goes to `TextParser` ([pandas/io/excel/_base.py:945-971](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L945-L971)), which infers one dtype per column: `int64`, `float64`, `bool`, `datetime64[ns]`, the pandas 3 `str` dtype for text (whatsnew v3.0.0 "Dedicated string data type by default"), or `object` for anything mixed. Integer columns with a blank become `float64`, because NaN is a float (io.rst lines 3643-3648).

Pitfalls:
- Text that looks like a number is re-parsed as a number. A column of Excel text cells such as `'020099` comes back as `20099.0` and the leading zero is gone. Issue #20828, "ENH: read_excel respect Excel text type for numbers", open: https://github.com/pandas-dev/pandas/issues/20828. The Excel cell type is thrown away before inference.
- Mixed columns stay `object` with Python values of different types inside, so `df["x"].sum()` fails later. Mixing numbers and booleans used to be cast by first appearance (fixed in 3.1.0, whatsnew v3.1.0 line 948, GH 60088). With `dtype_backend="pyarrow"`, mixed columns still infer wrongly: #63830, open, https://github.com/pandas-dev/pandas/issues/63830.
- Round trips are lossy: a frame with the string `"None"`, an empty string, NaN and infinities does not come back equal after `to_excel` then `read_excel`. #63188, https://github.com/pandas-dev/pandas/issues/63188.

### 3 Choose what to read

```python
pd.read_excel(path, sheet_name="Data")          # by name
pd.read_excel(path, sheet_name=2)               # by 0-based position
pd.ExcelFile(path).sheet_names                  # list sheets
pd.read_excel(path, usecols="B:D", skiprows=3, nrows=50)   # a block
pd.read_excel(path, header=3)                   # header is on the 4th row
```

`sheet_name` docs: [pandas/io/excel/_base.py:227-240](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L227-L240). `usecols` takes Excel letters ("A,C:E"), 0-based integers, names or a callable (`#L267-L284`). Positions are 0-based everywhere, while Excel shows 1-based rows. There is no single `range="B4:D50"` argument; a rectangle has to be built from `usecols`, `skiprows`/`header` and `nrows`.

Pitfalls:
- `usecols` ignores order: `usecols=[1, 0]` is the same as `[0, 1]` (`#L279`).
- Leading blank rows behave differently by engine. python-calamine skips empty leading rows and columns by default (python-calamine `README.md`), so pandas passes `skip_empty_area=False` ([pandas/io/excel/_calamine.py:125](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_calamine.py#L125)) to keep row numbers the same as openpyxl. When pandas 1.2 switched from xlrd to openpyxl, `header=2` broke for some files: #38956, https://github.com/pandas-dev/pandas/issues/38956, and blank-row handling had to be restored: #39808, https://github.com/pandas-dev/pandas/issues/39808.
- Chart sheets do not count as positions (`#L228-L229`), so position 1 in pandas can differ from the second tab a user sees.
- Excel "tables" (ListObjects) cannot be read by name; pandas has no option for that.

### 4 Header row and column names

```python
pd.read_excel(path, header=None, names=["id", "age"])   # no header row
pd.read_excel(path, header=[0, 1])                      # two header rows -> MultiIndex
```

- Blank header cells become `"Unnamed: 0"`, `"Unnamed: 1"` (position-based, from the shared parser).
- Duplicates become `x`, `x.1`, `x.2` (io.rst lines 573-588, section "Duplicate names parsing"). With `usecols`, names are still mangled because of duplicates elsewhere on the sheet: #64198, open, https://github.com/pandas-dev/pandas/issues/64198. Only the first of the mangled columns got the right dtype: #35211, https://github.com/pandas-dev/pandas/issues/35211.
- Multi-row headers become a `MultiIndex`, with forward-filling of merged header cells (`fill_mi_header`, [pandas/io/excel/_util.py:236](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_util.py#L236)). When `index_col` is also given, pandas assumes the row after the header is an index-name row as written by `to_excel`. A sheet not written by pandas can lose its first data row: documented in io.rst lines 3559-3574 and the docstring `#L261-L266`.
- No name cleaning. Spaces, line breaks and punctuation in headers are kept as-is.

### 5 Column types

```python
pd.read_excel(path, dtype={"zip": str, "n": "Int64"})
pd.read_excel(path, converters={"flag": lambda v: v == "Y"})
pd.read_excel(path, dtype_backend="numpy_nullable")   # Int64, boolean, string with pd.NA
```

- Guessing uses every row, not a sample. There is no `guess_max`. This avoids readxl's "guessed from the first 1000 rows" failure but means one stray text cell turns the whole column to `object` with no warning.
- `dtype=str` does not protect missing cells: they are still NA because NA detection runs first (`#L289-L292`). Before that was fixed, empty cells came back as the string `'nan'`: #20377, https://github.com/pandas-dev/pandas/issues/20377.
- `converters` replace `dtype` for that column (`#L293-L294`) and run per cell, so the column dtype is not guaranteed (io.rst lines 3643-3648).
- A cell that does not fit a requested numeric dtype raises a `ValueError` for the whole read, with the sheet name appended to the message (`#L982-L984`). There is no per-cell "coerce to NA and warn" mode.

### 6 Dates and times

Detection happens in the engine, by number format. openpyxl marks a numeric cell as a date when its style's format contains date letters (`openpyxl/styles/numbers.py:104-109`, see the openpyxl section). pandas then sees `datetime` objects and makes a `datetime64` column. calamine does the same in Rust.

- 1900 and 1904 systems: handled by the engine. openpyxl reads `date1904` from `workbook.xml` (`openpyxl/reader/workbook.py:47-48`). pandas has no option of its own.
- Time-only cells come back as `datetime.time` and the column is `object`. Duration formats such as `[h]:mm` give `timedelta`.
- Turning detection off: not possible. `parse_dates=False` is about parsing strings and does not stop format-based conversion: #47269, https://github.com/pandas-dev/pandas/issues/47269. To get raw serial numbers you have to drop to openpyxl.
- `parse_dates` only parses text that looks like dates (io.rst lines 3620-3630). If one value fails, the whole column stays `object` (`#L376-L378`).
- Time zones on write: tz-aware values raise "Excel does not support datetimes with timezones" ([pandas/io/formats/excel.py:601-606](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/formats/excel.py#L601-L606)). Long-standing user reports: #7056, https://github.com/pandas-dev/pandas/issues/7056; #27008, https://github.com/pandas-dev/pandas/issues/27008.

### 7 Missing values and Excel error values

```python
pd.read_excel(path, na_values=[".", -99], keep_default_na=False)
```

- Default NA strings (`#L338-L343`): `''`, `'#N/A'`, `'#N/A N/A'`, `'#NA'`, `'-1.#IND'`, `'-1.#QNAN'`, `'-NaN'`, `'-nan'`, `'1.#IND'`, `'1.#QNAN'`, `'<NA>'`, `'N/A'`, `'NA'`, `'NULL'`, `'NaN'`, `'None'`, `'n/a'`, `'nan'`, `'null'`. A text cell holding a real name or code such as "NA" (Namibia, "not applicable") or "None" becomes missing: #61788, https://github.com/pandas-dev/pandas/issues/61788.
- Excel error cells (`#N/A`, `#DIV/0!`, `#REF!`) become NaN under openpyxl ([pandas/io/excel/_openpyxl.py:721-722](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L721-L722)). python-calamine turns them into empty cells (`python-calamine/src/types/cell.rs:122-124`, final `else` branch), which pandas then treats as NA. Either way the user cannot tell an error from a blank.
- `keep_default_na`, `na_values` and `na_filter` interact in four documented ways (`#L344-L358`). Non-bool values for these now raise (whatsnew v3.1.0 line 1119, GH 68341); before, `keep_default_na="False"` silently meant True.

### 8 Read every sheet at once

```python
sheets = pd.read_excel(path, sheet_name=None)    # dict: sheet name -> DataFrame
```

`sheet_name=None` or a list returns a `dict`; a single name or int returns a `DataFrame` (`#L764-L773`, `#L829-L832`). One function with two return types surprises people: #60909, "pandas.read_excel returns dict type if sheet_name=None", https://github.com/pandas-dev/pandas/issues/60909. The same parsing options apply to every sheet; for per-sheet options the docs show a loop over `ExcelFile` (io.rst lines 3429-3454). `ExcelFile.parse` is deprecated in 3.1.0 (#58247, https://github.com/pandas-dev/pandas/issues/58247).

### 9 Write one table to a new workbook

```python
df.to_excel("out.xlsx", sheet_name="Data", index=False)
```

Signature: [pandas/core/generic.py:2106-2126](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/core/generic.py#L2106-L2126).

Type mapping ([pandas/io/excel/_base.py:1388-1434](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L1388-L1434)): ints, floats, bools and `Decimal` are written as numbers or booleans; `datetime` gets format `YYYY-MM-DD HH:MM:SS` and `date` gets `YYYY-MM-DD` (defaults set at `#L1346-L1353`, changeable through `ExcelWriter(date_format=, datetime_format=)`); `timedelta` is written as a fraction of a day with number format `"0"` (`#L1420-L1422`), so a 6-hour duration displays as `0`; everything else goes through `str()`, so lists and dicts become their Python repr. Strings over 32,767 characters are truncated with a warning (`#L1425-L1433`). NaN is written as `na_rep` (default empty cell) and infinity as the text `"inf"` (`inf_rep`).

Overwrite behavior: a path always produces a brand-new file and silently replaces any existing file, including its other sheets (`generic.py#L2135-L2138`, "will overwrite the existing file because the default mode is write"). Size limits of 1,048,576 rows and 16,384 columns are checked up front ([pandas/io/formats/excel.py:538-539](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/formats/excel.py#L538-L539), `#L948-L953`).

Pitfalls:
- `index=True` is the default, so most users get an unwanted first column of row numbers.
- Both writers turn a string that starts with `=` into a formula: openpyxl at `openpyxl/cell/cell.py:198-199`, XlsxWriter through `strings_to_formulas`, default True (`XlsxWriter/xlsxwriter/workbook.py:87`, `worksheet.py:535-536`). XlsxWriter also turns strings that start with `http://` into hyperlinks (`worksheet.py:542-552`). User data is changed on the way out depending on which engine happens to be installed.

### 10 Write several tables

```python
with pd.ExcelWriter("out.xlsx") as xw:
    df1.to_excel(xw, sheet_name="Summary", index=False)
    df2.to_excel(xw, sheet_name="Summary", startrow=len(df1) + 3, index=False)
    df3.to_excel(xw, sheet_name="Detail", index=False)
```

Writing to a sheet name already used in the same writer reuses that sheet ([pandas/io/excel/_openpyxl.py:476-477](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L476-L477), [pandas/io/excel/_xlsxwriter.py:255-257](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_xlsxwriter.py#L255-L257)), so `startrow`/`startcol` place several tables on one sheet. Positions are 0-based offsets that the user computes by hand. There is no dict-of-frames writer; it takes a `with` block and one call per frame. The file is only written when the writer closes (`#L1460-L1463`).

### 11 Format output

```python
df.to_excel(path, index=False, freeze_panes=(1, 0), autofilter=True, float_format="%.2f")
df.style.map_index(lambda _: "font-weight: bold", axis=1).to_excel(path)   # bold header
```

- Since pandas 3.0, `to_excel` writes no styling at all; the old bold, bordered header is gone (whatsnew v3.0.0 line 968, GH 54154; io.rst lines 3806-3812). Styling goes through `Styler.to_excel`, which maps a subset of CSS (`font-weight`, `color`, `background-color`, borders, `text-align`, plus pseudo-CSS `number-format`) to Excel styles (user guide "Export to Excel", https://pandas.pydata.org/pandas-docs/version/3.1/user_guide/style.html#Export-to-Excel).
- `float_format="%.2f"` rounds the stored value ([pandas/io/formats/excel.py:599-600](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/formats/excel.py#L599-L600): `float(self.float_format % val)`); it does not set an Excel number format. Data is lost.
- `freeze_panes=(row, col)` counts rows and columns to freeze, which is easy to misread (`generic.py#L2176-L2178`).
- `autofilter=True` is new in 3.0 (whatsnew v3.0.0 line 226) and cannot be combined with merged MultiIndex cells ([pandas/io/formats/excel.py:966-979](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/formats/excel.py#L966-L979)).
- Merged cells only appear for MultiIndex labels (`merge_cells=`).
- Column widths and autofit: no parameter in `to_excel` (see the signature). Users reach into the engine: `xw.sheets["Data"].autofit()` with XlsxWriter, or `ws.column_dimensions["A"].width = 20` with openpyxl. The XlsxWriter docs carry the pandas recipes (https://xlsxwriter.readthedocs.io/working_with_pandas.html); its page still says pandas writes the header "with a default cell format" (`XlsxWriter/dev/docs/source/working_with_pandas.rst:170`), which stopped being true in pandas 3.0.

### 12 Write into an existing workbook

```python
with pd.ExcelWriter(path, mode="a", engine="openpyxl", if_sheet_exists="replace") as xw:
    df.to_excel(xw, sheet_name="Data", index=False)

with pd.ExcelWriter("template.xlsx", mode="a", engine="openpyxl", if_sheet_exists="overlay") as xw:
    df.to_excel(xw, sheet_name="Report", startrow=4, startcol=1, header=False, index=False)
```

- `if_sheet_exists` is `error` (default), `new`, `replace` or `overlay` ([pandas/io/excel/_base.py:1053-1061](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_base.py#L1053-L1061)) and is rejected outside append mode (`#L1330-L1331`). `replace` deletes the sheet and recreates it at the same position ([pandas/io/excel/_openpyxl.py:459-463](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L459-L463)), so column widths, formats and data validation on that sheet are gone. `overlay` writes over cells and leaves everything else.
- What is lost: the docstring warns that in append mode "the existing workbook is read and completely rewritten by the engine, so any content the engine cannot represent (e.g. VBA macros in .xlsm files, charts or images) is silently lost" (`#L1037-L1042`). The openpyxl section lists exactly what that engine drops.
- `mode="a"` fails if the file does not exist yet; users ask for an "append or create" mode: #61634, open, https://github.com/pandas-dev/pandas/issues/61634. `overlay` behavior confused users: #52189, https://github.com/pandas-dev/pandas/issues/52189. Replace mode once skipped the first frame: #50198, https://github.com/pandas-dev/pandas/issues/50198.
- The workbook is saved back into the same file handle and then truncated ([pandas/io/excel/_openpyxl.py:105-111](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L105-L111)). That is not an atomic write; a crash in the middle leaves a damaged file.
- putexcel-style single values: no API. Users build a 1x1 DataFrame and overlay it, or use `xw.book` (the openpyxl `Workbook`) directly.

### 13 Labels

pandas has no variable labels or value labels. Two pieces come close:
- `header=["Age in years", ...]` on `to_excel` writes aliases instead of column names (`generic.py#L2153-L2155`).
- A `Categorical` column is written as its category values (text), which is how a Stata value-labelled variable usually lands in pandas after `read_stata`. Reading back gives a plain `str` column.

## openpyxl (Python)

- Version 3.1.5 (latest on PyPI as of 2026-11-04, uploaded 2024-06-28).
- Source used: PyPI sdist `openpyxl-3.1.5.tar.gz`, sha256 `cf0e3cf56142039133628b5acffe8ef0c12bc902d2aadd3e0fe5878dc08d1050` (wheel sha256 `5282c12b107bffeef825f4617dc029afaf41d0ea60823bbb665ef3079dc79de2`), unpacked at `refs/others/openpyxl/openpyxl-3.1.5/`. The upstream repository is Mercurial at https://foss.heptapod.net/openpyxl/openpyxl (tag `3.1.5`). It could not be cloned: no `hg` on this machine, the git endpoint returns "repository not found", and the web UI is behind an Anubis bot challenge. So there is no commit hash; citations below are paths inside the sdist, written `openpyxl/...:line`.
- Docs: https://openpyxl.readthedocs.io/en/3.1.3/ is the newest docs build ("stable" also reports 3.1.3; `/en/3.1.5/` returns 404). Doc sources were fetched as `/_sources/<page>.rst.txt`.
- License: MIT. `LICENCE.rst` (British spelling) begins "This software is under the MIT Licence"; copyright line verbatim: "Copyright (c) 2010 openpyxl". PyPI metadata gives `MIT`.
- GPL-3.0 compatibility: yes. MIT is permissive and GPL-compatible.

openpyxl is a cell-level object model of an .xlsx file. It has no data frame layer, so tasks 2 to 8 are things the user assembles from cells. It is the engine pandas uses for reading by default and for every append.

### 1 Install

```python
pip install openpyxl            # pure Python
pip install lxml pillow         # optional: faster large writes; needed to add images
```

Tutorial "Installation" (`tutorial.rst` lines 4-27). The README warns that without `defusedxml` openpyxl "does not guard against quadratic blowup or billion laughs xml attacks" (`README.rst`, Security). So opening untrusted files safely needs an extra install the user has to know about.

### 2 Read a sheet into a table

```python
from openpyxl import load_workbook
wb = load_workbook("survey.xlsx", read_only=True, data_only=True)
rows = list(wb["Data"].values)          # list of tuples, header included
```

`load_workbook(filename, read_only=False, keep_vba=False, data_only=False, keep_links=True, rich_text=False)` at `openpyxl/reader/excel.py:316-349`. There is no table type; `ws.values` (`openpyxl/worksheet/worksheet.py:463`) and `ws.iter_rows(..., values_only=True)` (`:405`) yield tuples. The docs' recipe for a DataFrame is `DataFrame(ws.values)` plus manual header handling (`pandas.rst`, "Converting a worksheet to a Dataframe").

Cell value types: `int`/`float` for numbers, `str`, `bool`, `datetime`/`date`/`time`/`timedelta` for date-formatted numbers, `None` for empty. Error cells keep their text (`"#N/A"`) with `data_type == "e"` (`openpyxl/cell/cell.py:46-47`).

Pitfalls:
- `data_only=False` is the default, so formula cells return the formula text (`"=SUM(A1:A3)"`) instead of a value (`openpyxl/worksheet/_reader.py:208`). With `data_only=True` you get the value Excel cached at last save; a file written by a library and never opened in Excel has no cached values, so you get `None`. openpyxl never computes formulas.
- Read-only mode must be closed explicitly (`optimized.rst`, warning at lines 26-31).
- In normal mode, looping over a range creates every cell in memory even when empty (`tutorial.rst` lines 135-143).

### 3 Choose what to read

```python
wb.sheetnames                      # list sheets
ws = wb["Data"]; ws = wb.worksheets[0]
block = ws["B4:D50"]               # tuple of row tuples of Cell objects
ws.iter_rows(min_row=4, max_col=3, values_only=True)
ws.tables["Sales"].ref             # address of a named Excel table, e.g. "A3:F120"
```

Ranges use Excel notation and 1-based indexes, which matches what users see. Named tables are exposed through `ws.tables` (`worksheet.py:586`) but only as an address; the user still slices the cells.

### 4 Header row and column names

Not supported. The first tuple from `ws.values` is just the first row. Blank, duplicate and multi-row headers are the user's problem.

### 5 Column types

Not supported as columns. Each cell has its own Python type, so a column can mix `int`, `str` and `None`. There is nothing like `guess_max` or `dtype=`.

### 6 Dates and times

Date detection is per cell, by number format. On load, openpyxl collects the style ids whose format passes `is_date_format` (`openpyxl/styles/numbers.py:104-109`: take the first section before `;`, strip quoted literals and `[...]` locale blocks, then look for any of `d m h y s` not escaped by `\` or `_`). Numbers with those styles are converted with `from_excel` (`openpyxl/worksheet/_reader.py:213-224`). Formats such as `[h]:mm:ss` give `timedelta` (`is_timedelta_format`, `numbers.py:112-116`). A serial below 1 gives a `time` (`openpyxl/utils/datetime.py:115-116`).

- 1904 system: read from the workbook properties (`openpyxl/reader/workbook.py:47-48`, sets `wb.epoch = CALENDAR_MAC_1904`). Writers can set `wb.epoch` (`datetime.rst`, "The 1900 and 1904 date systems").
- The 1900 leap-year bug is handled for serials below 60 (`utils/datetime.py:117-118`); 29 February 1900 cannot be represented (`datetime.rst`).
- Out-of-range serials in a date-formatted cell are turned into a `#VALUE!` error with a warning (`_reader.py:220-224`).
- Turning detection off: no flag. The user can recover the serial with `openpyxl.utils.datetime.to_excel(cell.value, wb.epoch)`.
- Time zones: "openpyxl can only deal with naive datetime/time objects" (`datetime.rst`, Timezones). Writing a tz-aware value raises `TypeError` (`openpyxl/cell/_writer.py:29-31`).
- `wb.iso_dates = True` writes ISO 8601 strings instead of serials (`datetime.rst`).

### 7 Missing values and Excel error values

Empty cells are `None`. Error cells hold the error text and `data_type == "e"`; the recognized codes are `#NULL!`, `#DIV/0!`, `#VALUE!`, `#REF!`, `#NAME?`, `#NUM!`, `#N/A` (`cell.py:46-47`). That is the most faithful behavior in this group: the error is visible and distinguishable from a blank. The flip side: assigning the Python string `"#N/A"` to a cell writes an error, not text (`cell.py:200-201`).

### 8 Read every sheet at once

Not supported directly. `{ws.title: list(ws.values) for ws in wb.worksheets}`. Chart sheets are in `wb.chartsheets`, not `wb.worksheets`.

### 9 Write one table to a new workbook

```python
from openpyxl import Workbook
from openpyxl.utils.dataframe import dataframe_to_rows
wb = Workbook(); ws = wb.active
for r in dataframe_to_rows(df, index=False, header=True):
    ws.append(r)
wb.save("out.xlsx")
```

`ws.append` at `worksheet.py:641`; `dataframe_to_rows` at `openpyxl/utils/dataframe.py:9`. Python types map to cell types in `Cell._bind_value` (`cell.py:175-201`): numbers, `bool`, `str`, and `datetime`/`date`/`time`/`timedelta` with a default date format (`cell.py:34-39`). Unknown types raise "Cannot convert ... to Excel".

Overwrite behavior: `wb.save()` "will overwrite existing files without warning" (`tutorial.rst` lines 279-281). A new `Workbook()` already has one sheet named "Sheet"; pandas removes it ([pandas/io/excel/_openpyxl.py:86-87](https://github.com/pandas-dev/pandas/blob/3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1/pandas/io/excel/_openpyxl.py#L86-L87)), direct users often forget.

Pitfalls: any string that starts with `=` becomes a formula (`cell.py:198-199`), and strings equal to an error code become errors. Illegal control characters raise `IllegalCharacterError` (`ILLEGAL_CHARACTERS_RE`, `cell.py:45`) instead of being cleaned.

### 10 Write several tables

```python
ws2 = wb.create_sheet("Detail")
ws.cell(row=20, column=2, value="Second table")   # any position, 1-based
```

`create_sheet(title, index)` at `openpyxl/workbook/workbook.py:184`. Several tables on one sheet means writing each cell at an offset yourself. Write-only mode (`Workbook(write_only=True)`) is faster but only allows `append()`, with no random cell access (`optimized.rst` lines 93-113).

### 11 Format output

```python
from openpyxl.styles import Font
for c in ws[1]: c.font = Font(bold=True)
ws["B2"].number_format = "0.00"
ws.column_dimensions["A"].width = 20
ws.freeze_panes = "A2"
ws.auto_filter.ref = "A1:D100"
ws.merge_cells("A1:D1")
```

- Number formats: `styles.rst` line 237. Bold: `usage.rst` (Font(bold=True)).
- Column or row styles only apply to cells Excel creates later; to style existing cells "you must apply the style to each cell individually" (`styles.rst`, "Columns and Rows", lines 165-180).
- Widths: `column_dimensions[...].width`. No autofit. `bestFit`/`auto_size` exist (`openpyxl/worksheet/dimensions.py:130-131`) but only write a flag; openpyxl never measures text.
- Freeze panes: give the top-left cell of the scrolling area (`worksheet.py:184-200`). That is clearer than pandas' row/column counts.
- Autofilter: openpyxl only writes the filter definition; it will "neither actually filter nor sort" (`filters.rst`).
- Merged cells: all cells but the top-left are removed (`editing_worksheets.rst` lines 58-64). When loading, a comment on a merged-away cell is dropped with a warning (`openpyxl/reader/excel.py:213`).

### 12 Write into an existing workbook

```python
wb = load_workbook("template.xlsx")
ws = wb["Report"]
ws["C5"] = 0.732; ws["C5"].number_format = "0.0%"
del wb["Data"]; ws_new = wb.create_sheet("Data", 1)
wb.save("report.xlsx")
```

This is the closest Python equivalent of `putexcel`: open, set cells by address, save. Cell styles already in the template are kept when you only set `.value`.

What is lost or changed:
- Shapes and drawings other than charts and images: the tutorial warns "shapes will be lost from existing files if they are opened and saved" (`tutorial.rst`, after "Loading from a file"); the reader warns "DrawingML support is incomplete and limited to charts and images only. Shapes and drawings will be lost." (`openpyxl/reader/drawings.py:33`).
- Worksheet extension lists are dropped with a warning "<type> extension is not supported and will be removed" (`openpyxl/worksheet/_reader.py:327-329`). The list (`openpyxl/xml/constants.py:114-124`) covers newer conditional formatting, data validation that refers to other sheets, sparklines, slicers, protected ranges, ignored errors, web extensions and timelines.
- Conditional formatting rules that fail to parse are discarded with a warning (`_reader.py:309-313`).
- VBA is dropped unless `keep_vba=True`, and the extension must match (`tutorial.rst` lines 316-343).
- With `data_only=True`, formulas are not read (`_reader.py:208`), so saving writes the cached values in their place.
- Inserting or deleting rows does not update formulas, tables or charts that refer to them (`editing_worksheets.rst`, note under "Deleting rows and columns").
- Images can only be kept or added with Pillow installed (`tutorial.rst` lines 19-27).

### 13 Labels

Not supported. Labels have to be written as ordinary header text and cell values.

## polars (Python)

Pinned: polars 2.1.0 (PyPI, released 2026-10-25), git tag `py-2.1.0`, commit `7f902bd3ffd27ff82d14278a09a295ff2f7aed92`, repository https://github.com/pola-rs/polars. Sparse clone at `refs/others/polars/` (Excel code, `DataFrame.write_excel`, docs, tests).

Reading delegates to fastexcel 0.21.0 (tag `v0.21.0`, commit `8f8ab1580c2564240fff7263697f6a556c038263`, clone at `refs/others/fastexcel/`), which wraps the Rust calamine crate. Writing delegates to XlsxWriter (3.3.1, commit `af5927c110cf01571046a3138600f63b256ea89a`).

License: MIT. The repository root `LICENSE` and `py-polars/LICENSE` carry the MIT permission text with these copyright lines, verbatim:

> Copyright (c) 2025 Ritchie Vink
> Copyright (c) 2024 (Some portions) NVIDIA CORPORATION & AFFILIATES. All rights reserved.

`py-polars/pyproject.toml:14` declares `license = { file = "LICENSE" }`; the file has no SPDX header, but the text is the standard MIT license. MIT is compatible with GPL-3.0: a GPL-3 program may include or adapt MIT code as long as the MIT notice is kept.

### 1 Install

```python
pip install "polars[excel]"        # pulls fastexcel, openpyxl, xlsx2csv, xlsxwriter
pip install polars fastexcel xlsxwriter   # minimum for default read + write
```

The `excel` extra is defined at `py-polars/pyproject.toml:60-64`. Without fastexcel, `pl.read_excel()` fails at call time through `import_optional("fastexcel", min_version="0.7.0")` ([functions.py:872](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L872)). Writing without xlsxwriter fails the same way ([frame.py:3806](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3806)).

### 2 Read a sheet into a table

```python
df = pl.read_excel("survey.xlsx")                    # first sheet -> pl.DataFrame
```

Returns a `pl.DataFrame` for one sheet, or `dict[str, DataFrame]` when several sheets are requested ([functions.py:357-362](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L357)). A list or glob of workbooks is read and stacked with `concat(how="vertical_relaxed")` ([functions.py:88-111](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L88)).

There are three engines, chosen with `engine=`:

- `"calamine"` (default since polars 1.0): fastexcel reads cells through calamine into Arrow, and polars wraps the result. It is the fastest and the only one that reads `.xls` and `.xlsb` too.
- `"openpyxl"`: polars opens the book with `openpyxl.load_workbook(source, data_only=True)` ([functions.py:867](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L867)), builds one `pl.Series` per column and lets polars infer types.
- `"xlsx2csv"`: converts the sheet to an in-memory CSV and parses it with `pl.read_csv` ([functions.py:1301-1348](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1301)).

Cell-to-column mapping (calamine engine): fastexcel classifies each sampled cell as Int, Float, String, Bool, DateTime, Date, Duration or Null ([fastexcel dtype/mod.rs:120-201](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/dtype/mod.rs#L120)), then polars post-processes. Two post-processing steps surprise users: a Float64 column whose values are all whole numbers is cast to Int64, and a Datetime column whose times are all 00:00:00 is cast to Date ([functions.py:1158-1184](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1158)). The first step can fail: issue [#22408](https://github.com/pola-rs/polars/issues/22408) (open) reports `InvalidOperationError` when a whole-number float is outside the Int64 range.

Pitfall: the three engines give different results for the same file. Issue [#18937](https://github.com/pola-rs/polars/issues/18937) shows a column holding `-` and `0.123456789012345`: openpyxl returned the string `"0.123457"`, calamine returned the full value.

### 3 Choose what to read

```python
pl.read_excel(path, sheet_name="Data")          # by name
pl.read_excel(path, sheet_id=2)                 # by 1-based position
pl.read_excel(path, sheet_id=0)                 # all sheets -> dict
pl.read_excel(path, table_name="Sales")         # a named Excel table (ListObject)
pl.read_excel(path, columns=["id", "score"])    # by header name or 0-based index
pl.read_excel(path, read_options={"header_row": 3, "n_rows": 50, "use_columns": "B:F"})
```

Sheet selection logic is in `_get_sheet_names` ([functions.py:784-831](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L784)). Passing both `sheet_id` and `sheet_name` raises `ValueError`.

Polars has no public function to list sheet names. Users call `fastexcel.read_excel(path).sheet_names` or open the file with openpyxl.

There is no `range="B3:F50"` argument. Cell-range reading goes through engine-specific `read_options` that polars passes to fastexcel's `load_sheet`: `header_row` (0-based; rows above it are skipped), `skip_rows` (counted after the header, not from the top of the sheet), `n_rows`, and `use_columns` (`"A:E"`, `"A,C,E:F"`, or a callable) ([fastexcel `__init__.py`:355-397](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/python/fastexcel/__init__.py#L355)). With the xlsx2csv engine, `read_options` goes to `read_csv` instead, so the same key means different things per engine.

Pitfalls: `read_options` is an untyped dict, so typos are not caught; issue [#17727](https://github.com/pola-rs/polars/issues/17727) (open) asks for the fastexcel options to be exposed as real parameters. Issue [#10380](https://github.com/pola-rs/polars/issues/10380) (open) reports that `skip_rows` with xlsx2csv counts from the first populated cell rather than row 1. `_get_read_options` raises `ParameterCollisionError` when a top-level argument and its `read_options` twin are both given ([functions.py:741-756](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L741)).

### 4 Header row and column names

```python
pl.read_excel(path, has_header=False)                          # column_0, column_1, ...
pl.read_excel(path, read_options={"column_names": ["a", "b"]})  # calamine only
```

- Blank header cells: fastexcel names them `__UNNAMED__{col}` ([column_info/mod.rs:341](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/excelsheet/column_info/mod.rs#L341)). With `drop_empty_cols=True` (the default), polars then drops unnamed columns that are all null, or all zero/null if numeric ([functions.py:972-997](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L972)). A numeric column with no header whose values are all zero therefore disappears.
- Duplicate headers: calamine engine gives `x`, `x_1`, `x_2` ([column_info/mod.rs:478-491](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/excelsheet/column_info/mod.rs#L478)). The openpyxl engine uses polars' `deduplicate_names`, which gives `x`, `x0`, `x1` (`_utils/various.py:279-286`). xlsx2csv output passes through `read_csv`'s `_duplicated_n` names, then `_standardize_duplicates` rewrites them ([functions.py:83-85](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L83)). Same file, three naming schemes.
- Multi-row headers and name cleaning: not supported. Users read with `has_header=False` and build names themselves.

### 5 Column types

```python
pl.read_excel(path, infer_schema_length=None)                        # scan all rows
pl.read_excel(path, schema_overrides={"zip": pl.String, "dt": pl.Date})
pl.read_excel(path, infer_schema_length=0)                           # everything as String
pl.read_excel(path, read_options={"dtype_coercion": "strict"})       # error on mixed columns
```

Inference scans the first 100 rows by default (`N_INFER_DEFAULT: Final = 100`, `datatypes/constants.py:9`), which polars passes as fastexcel's `schema_sample_rows` ([functions.py:754](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L754)). fastexcel's own default is 1,000, so the same file can produce different types through polars and through fastexcel directly.

Mixed columns: with the default `dtype_coercion="coerce"`, Int+Bool becomes Int, Int+Float+Bool becomes Float, and any mix that includes a string becomes String ([dtype/mod.rs:225-276](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/dtype/mod.rs#L225)). Strings such as `"NA"`, `"null"`, `"None"`, `"n/a"` and `""` count as null during inference ([dtype/mod.rs:114-118](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/dtype/mod.rs#L114)).

A cell that does not fit the chosen type becomes null without warning. Example: a column sampled as Int with a text cell at row 150. The non-fitting value fails `as_i64()` and is stored as null (from the source, not run: polars calls `load_sheet`/`load_sheet_eager`, [functions.py:1105-1111](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1105), which use the array builders without error collection). fastexcel has a `to_arrow_with_errors()` method that reports such cells, but polars does not use it.

Overrides are translated to fastexcel dtypes ([functions.py:1072-1087](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1072)). Forcing an integer type on a float cell truncates it, because calamine's `as_i64` does `*v as i64` ([calamine datatype.rs:163-171](https://github.com/tafia/calamine/blob/a4dba3b5309d81b2774018a13be39e68d938c3c7/src/datatype.rs#L163)): 2.7 becomes 2 (from the source, not run). Issue [#21718](https://github.com/pola-rs/polars/issues/21718) (open) asks for a CSV-style `infer_schema=False` switch.

### 6 Dates and times

calamine decides that a numeric cell is a date from its number format, and it handles the 1904 date system. fastexcel turns those cells into DateTime or Duration ([dtype/mod.rs:149-160](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/dtype/mod.rs#L149)). Then polars casts all-midnight datetimes to `Date` (see task 2). Datetimes come back naive, with no time zone. Reading a time zone means overriding a text column: `schema_overrides={"ts": pl.Datetime(time_zone="Asia/Tokyo")}` parses strings with `str.to_datetime` ([functions.py:1133-1139](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1133)).

No option turns date detection off. Overriding a date column to `pl.Float64` does not return the serial number: calamine's `as_f64` returns `None` for DateTime cells ([datatype.rs:173-181](https://github.com/tafia/calamine/blob/a4dba3b5309d81b2774018a13be39e68d938c3c7/src/datatype.rs#L173)), so the column comes back null (from the source, not run). Dates stored as text stay String unless overridden to `pl.Date`; the xlsx2csv engine needs an extra string-to-date pass ([functions.py:958-968](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L958)).

### 7 Missing values and Excel errors

Empty cells become null. In the calamine engine, `#N/A`, `#VALUE!`, `#NULL!`, `#REF!`, `#NUM!` and `#DIV/0!` count as null for type inference. Other error kinds, such as `#NAME?`, raise `CalamineCellError` ([dtype/mod.rs:177-193](https://github.com/ToucanToco/fastexcel/blob/8f8ab1580c2564240fff7263697f6a556c038263/src/types/dtype/mod.rs#L177)). There is no `na=` argument to declare extra missing-value strings; the `"NA"`/`"null"` list above is fixed. `read_options={"whitespace_as_null": True}` treats blank-looking cells as null. `drop_empty_rows=True` (default) silently removes all-null rows ([functions.py:1001-1002](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L1001)); issue [#18250](https://github.com/pola-rs/polars/issues/18250) shows a user surprised that blank rows were dropped.

### 8 Read every sheet

```python
sheets = pl.read_excel(path, sheet_id=0)   # {"Sheet1": df1, "Sheet2": df2}
```

Options apply to every sheet at once. The docstring says to make separate calls when sheets need different options ([functions.py:376-378](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/functions.py#L376)).

### 9 Write one table to a new workbook

```python
df.write_excel("out.xlsx")                       # worksheet "Sheet1"
df.write_excel("out.xlsx", worksheet="results")
```

`write_excel` always writes the frame as an Excel table object (`ws.add_table(...)`, [frame.py:3862-3876](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3862)), with an autofilter on by default (`autofilter: bool = True`, frame.py:3403).

With `workbook=None` it writes `dataframe.xlsx` in the working directory, and a path without a suffix gets `.xlsx` added ([_write_utils.py:623-635](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/_write_utils.py#L623)). An existing file is replaced without warning.

Type mapping and default formats ([_write_utils.py:52-57, 470-489](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/_write_utils.py#L52)):

- Integers get `#,##0;[Red]-#,##0`. A year or ID column shows as `2,024` with red negatives.
- Floats get `#,##0.000;[Red]-#,##0.000` (`float_precision=3`). Only the display is rounded.
- Date gets `yyyy-mm-dd;@`, Datetime gets `yyyy-mm-dd hh:mm:ss`, Time gets `hh:mm:ss;@`.
- Nested and object columns are written as their string form ([_write_utils.py:356-368](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/_write_utils.py#L356)).
- NaN and Inf become Excel errors (`nan_inf_to_errors: True`); strings starting with `=` stay text (`strings_to_formulas: False`) ([_write_utils.py:613-618](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/io/spreadsheet/_write_utils.py#L613)).

The docstring tells users who want plain output to pass `column_formats={~cs.temporal(): "General"}` ([frame.py:3580-3582](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3580)).

Pitfall (from the source, not run): polars does not set XlsxWriter's `remove_timezone` option, and XlsxWriter raises `TypeError("Excel doesn't support timezones in datetimes...")` for aware datetimes ([XlsxWriter utility.py:869-885](https://github.com/jmcnamara/XlsxWriter/blob/af5927c110cf01571046a3138600f63b256ea89a/xlsxwriter/utility.py#L869)). A frame with a time-zone-aware column is expected to fail until the user strips the zone.

### 10 Write several tables

One per sheet, or several on one sheet: pass an open `xlsxwriter.Workbook` and call `write_excel` repeatedly ([frame.py:3622-3673](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3622)).

```python
from xlsxwriter import Workbook
with Workbook("report.xlsx") as wb:
    df1.write_excel(wb, worksheet="summary")
    df2.write_excel(wb, worksheet="detail")
    df3.write_excel(wb, worksheet="detail", position=(df2.height + 3, 0))  # or "A40"
```

`position` takes `"B4"` or a 0-based `(row, col)` tuple. The caller has to compute offsets for stacked tables. Writing past 1,048,576 rows or 16,384 columns raises `InvalidOperationError` before writing ([frame.py:3851-3859](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3851)). The call returns the `Workbook`, so users can add titles with XlsxWriter calls. There is no dict-of-frames shortcut.

### 11 Format output

All of these are arguments to `write_excel` ([frame.py:3383-3416](https://github.com/pola-rs/polars/blob/7f902bd3ffd27ff82d14278a09a295ff2f7aed92/py-polars/src/polars/dataframe/frame.py#L3383)):

```python
df.write_excel(
    "out.xlsx",
    table_style="Table Style Medium 4",         # or {"style": ..., "banded_rows": True}
    column_formats={"share": "0.0%", cs.numeric(): "#,##0"},   # names or selectors
    dtype_formats={pl.Date: "dd/mm/yyyy"},
    header_format={"bold": True},
    autofit=True, column_widths={"name": 200},   # widths in pixels
    freeze_panes="A2", autofilter=True,
    column_totals=True, conditional_formats={"score": "3_color_scale"},
    hidden_columns=["id"], hide_gridlines=True,
)
```

Details:

- `autofit` calls XlsxWriter's `ws.autofit()` (frame.py:3902-3907). Explicit `column_widths` win because they are applied afterwards (frame.py:3897-3929).
- `freeze_panes` accepts `"A2"`, `(1, 0)` or a four-value form with the scroll position (frame.py:3535-3548, 3955-3959).
- Extras: `column_totals` and `row_totals` (formula-based), `formulas`, `sparklines`, `row_heights`, `sheet_zoom`.
- No merged-cell argument. Merging needs the returned XlsxWriter worksheet.

The many options are this function's strength and its main ergonomic cost. Format values are XlsxWriter format dicts, so users must learn XlsxWriter's property names too.

### 12 Write into an existing workbook

Not supported. XlsxWriter only creates new files, so `write_excel("existing.xlsx", worksheet="new")` replaces the whole file. Issue [#10692](https://github.com/pola-rs/polars/issues/10692) reports that the other sheets were deleted, and it was closed without a feature. Users switch to openpyxl or pandas `ExcelWriter(mode="a")`. Issue [#25726](https://github.com/pola-rs/polars/issues/25726) (open) proposes adding an editing engine. Template filling in the putexcel style is not possible.

### 13 Labels

Not applicable. Polars has no variable or value labels. `Enum` and `Categorical` columns are written as their string values, so the text is what lands in the cells.

## XlsxWriter (Python, brief)

- Version 3.3.1, tag `RELEASE_3.3.1`, commit `af5927c110cf01571046a3138600f63b256ea89a`, PyPI upload 2026-10-28. https://github.com/jmcnamara/XlsxWriter. Clone at `refs/others/XlsxWriter/`.
- License: BSD-2-Clause. `LICENSE.txt` line 1 "BSD 2-Clause License"; copyright verbatim: "Copyright (c) 2013-2026, John McNamara <jmcnamara@cpan.org>". GPL-3.0 compatible (permissive, FSF-listed as compatible).

What it does differently. XlsxWriter only writes new files: "It cannot read or modify existing Excel XLSX files" (`dev/docs/source/introduction.rst:33`). It is the default pandas writer for .xlsx when installed. The same author wrote rust_xlsxwriter, which xlkit plans to use, so the Python API is a preview of the Rust one.

- Formats are objects created once and reused: `fmt = wb.add_format({"bold": True, "num_format": "0.00"})`, then `ws.write(row, col, value, fmt)` or `ws.set_column(first, last, width, fmt)` (`worksheet.py:2055`).
- `ws.autofit(max_width=None)` estimates widths from the written data (`worksheet.py:2167-2200`). It is a simulation ("Simulate autofit based on the data, and datatypes in each column"), and it is a no-op with a warning in `constant_memory` mode (`:2179-2181`).
- `ws.add_table()` (`:3460`) writes a real Excel table with header, filter buttons and banding; `freeze_panes()` (`:4101`), `autofilter()` (`:2525`), `merge_range()` (`:2442`), `write_datetime()` (`:1258`).
- Workbook options change how values are written: `strings_to_formulas` (default True), `strings_to_urls` (default True), `strings_to_numbers` (default False), `nan_inf_to_errors` (default False, NaN/Inf otherwise raise), `remove_timezone` (default False, tz-aware datetimes otherwise raise) (`workbook.py:86-95`, `worksheet.py:530-560`).
- `constant_memory=True` streams rows to disk but then requires row-by-row writing.

Lesson for xlkit: rust_xlsxwriter inherits the same create-only model, so xlkit's "edit an existing workbook" path cannot rely on it alone. The pandas recipes in XlsxWriter's docs (`working_with_pandas.rst`) show what users reach for after `to_excel`: column formats, header formats, autofit, tables and conditional formats.

## python-calamine and fastexcel (Python, brief)

python-calamine
- Version 0.9.1, tag `v0.9.1`, commit `551ab851b29fd19494346ffc58a71e368a363b6e`, PyPI upload 2026-11-03. https://github.com/dimastbk/python-calamine. Clone at `refs/others/python-calamine/`.
- License: MIT. `LICENSE` line 1 "MIT License"; copyright verbatim: "Copyright (c) 2021 dimastbk". GPL-3.0 compatible.
- A thin PyO3 binding to the Rust calamine crate, and the engine behind `pd.read_excel(engine="calamine")`. `CalamineWorkbook.from_path(p).get_sheet_by_name("S").to_python()` returns a list of lists.
- Differences that matter: leading empty rows and columns are skipped by default (`skip_empty_area=True`, `README.md`; `python/python_calamine/_python_calamine.pyi:77-96`), so row numbers do not match the sheet unless you turn it off. Error cells become empty (`src/types/cell.rs:122-124`). Each date-formatted cell becomes `date` when the serial is whole and `datetime` otherwise (`cell.rs:74-92`), so a column can mix the two. Serials below 1 become `time`. `load_tables=True` reads named Excel tables (xlsx only, `.pyi:189-206`).

fastexcel
- Version 0.21.0, tag `v0.21.0`, commit `8f8ab1580c2564240fff7263697f6a556c038263`, PyPI upload 2026-08-19. https://github.com/ToucanToco/fastexcel. Clone at `refs/others/fastexcel/`.
- License: MIT. `LICENSE` line 1 "MIT License"; copyright verbatim: "Copyright (c) 2024 ToucanToco". GPL-3.0 compatible.
- Rust (calamine) plus Arrow. It is what polars' `read_excel` uses by default. It returns Arrow data that polars or pandas take without copying.
- Ideas worth borrowing, from `load_sheet` (`python/fastexcel/__init__.py:289-403`): `header_row=` (rows above it are skipped), `column_names=` to override, `schema_sample_rows=1_000` (like readxl's `guess_max`; `None` means all rows), `dtype_coercion="coerce"` or `"strict"` (strict raises when a guessed column holds several types, `:375-379`), `use_columns=` with names, indexes, an Excel letter string or a callable, `dtypes=` per column, `whitespace_as_null=`, `skip_whitespace_tail_rows=`. `reader.table_names()` and `reader.load_table("MyTable")` read named tables. Blank headers become `__UNNAMED__<i>` (`src/types/excelsheet/column_info/mod.rs:341`) and duplicates get aliases (`alias_for_name`, `:478`).

## XLSX.jl (Julia)

Pinned: XLSX.jl 0.13.2 (registered 2026-10-21), git tag `v0.13.2`, commit `13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5`. The repository moved from `felipenoris/XLSX.jl` to https://github.com/JuliaData/XLSX.jl; the old URL redirects. Clone at `refs/others/XLSX.jl/`.

License: MIT. `LICENSE` at the pinned commit starts with "MIT License" and has this copyright line, verbatim:

> Copyright (c) 2018-2026 Felipe Noronha Tavares
> and other contributors:
>
> https://github.com/juliadata/XLSX.jl/contributors

`Project.toml:3` has `license = "MIT"`. MIT is compatible with GPL-3.0, for the reason given in the polars section.

### 1 Install

```julia
using Pkg; Pkg.add("XLSX")       # needs Julia 1.10 or later
using XLSX, DataFrames
```

The package is pure Julia, with no C or binary dependency (`Project.toml` deps: ZipArchives, XML, Tables, Dates and others). An optional FileIO extension adds `load`/`save` (`docs/src/tutorial/FileIOtutorial.md`).

### 2 Read a sheet into a table

```julia
df = DataFrame(XLSX.readtable("data.xlsx", "Sheet1"))
df = XLSX.readto("data.xlsx", "Sheet1", DataFrame)   # same, one call
```

`readtable` returns an `XLSX.DataTable`, a Tables.jl source with `data::Vector{Any}` of column vectors and `column_labels::Vector{Symbol}`. Any Tables.jl sink can consume it.

Cell to Julia type: String, Int64, Float64, Bool, Date, Time, DateTime, or `missing` ([cell.jl:533-552](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L533)). A number whose style shows decimals comes back as Float64 even if it is stored as an integer ([cell.jl:523-525](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L523)). So a column can be Int64 or Float64 depending on cell formatting, not on the values.

The lower-level calls are `XLSX.readdata(file, "Sheet1!A2:B4")`, which returns a `Matrix{Any}`, and `XLSX.readxlsx(file)`, which returns an `XLSXFile` you index with `xf["Sheet1"]["B2"]` (`docs/src/tutorial/XLSXtutorial.md`).

### 3 Choose what to read

```julia
XLSX.readtable(f, "Data")                       # by name
XLSX.readtable(f, 2)                            # by position
XLSX.sheetnames(XLSX.readxlsx(f))               # list sheets
XLSX.readtable(f, "Data", "B:E"; first_row=4)   # columns B:E, table starts at row 4
XLSX.readtable(f, "Data"; table_name="Sales")   # named Excel table
XLSX.readdata(f, "Data!B4:E20")                 # exact range, Matrix{Any}, no header handling
```

With no `first_row`, the reader takes the first non-empty row as the header. With no `columns`, it takes the first run of contiguous non-empty cells in that row as the column range ([table.jl:193-220](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/table.jl#L193); keyword docs at [table.jl:675-723](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/table.jl#L675)). By default the table ends at the first empty row (`stop_in_empty_row=true`). `stop_in_row_function` can end it at a sentinel row such as "Total".

Pitfall: a sheet with a title row reads as a one-column table. Issue [#355](https://github.com/JuliaData/XLSX.jl/issues/355) shows a file with three header rows where only the column under the title was returned. The maintainer's answer was `first_row=4`.

### 4 Header row and column names

```julia
XLSX.readtable(f, 1; header=false)                       # labels from column letters: :A, :B
XLSX.readtable(f, 1; column_labels=["id", "score"])
XLSX.readtable(f, 1; normalizenames=true)                # valid Julia identifiers
```

- Blank header cells become `"#Empty"`. Duplicates get `_2`, `_3` suffixes: `x`, `x_2` ([table.jl:48-65](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/table.jl#L48)). Issue [#169](https://github.com/JuliaData/XLSX.jl/issues/169) asked for this for headers built from merged cells.
- Name cleaning: `normalizenames=true` follows CSV.jl. It replaces invalid characters with `_`, prefixes reserved words and leading digits with `_`, and collapses repeated underscores ([table.jl:67-79](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/table.jl#L67)).
- Multi-row headers: not supported; one header row only ([#355](https://github.com/JuliaData/XLSX.jl/issues/355) comment).
- `readtransposedtable` reads tables laid out in rows.

### 5 Column types

`infer_eltypes=true` is the default since 0.11 (`docs/src/migration.md`). Each column's element type is the `promote_type` of its non-missing values, plus `Missing` if any are missing ([table.jl:557-572](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/table.jl#L557)). Every row is used; there is no guess window like readxl's `guess_max`.

Mixed columns are not coerced. Int and Float promote to Float64, but Int and String give `Any`, and the cells keep their own types. A cell that "does not fit" therefore never becomes missing; instead the whole column becomes `Vector{Any}`.

There is no per-column type override. Users convert afterwards (`df.zip = string.(df.zip)`), or pass `infer_eltypes=false` to get `Vector{Any}` everywhere. `missing_strings=["NA", "."]` turns given strings into `missing` before inference.

### 6 Dates and times

Detection uses the cell's number format. Built-in ids 14-22 and 45-47 count as dates, and so does any custom format (id > 81) whose code, after quoted text and bracketed sections are stripped, contains `d`, `m`, `yy`, `h`, `s`, `a/p` or `am/pm` ([styles.jl:223-253](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/styles.jl#L223)). Built-in East Asian date ids (27-36, 50-58) are not in that list.

The 1904 system is read from `workbookPr/@date1904` ([read.jl:908-918](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/read.jl#L908)) and used for both reading and writing ([cell.jl:469-510](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L469)). A date-formatted cell holding an integer becomes `Date`, a fraction below 1 becomes `Time`, and anything else becomes `DateTime`. Datetimes round to the nearest second, so milliseconds are lost ([cell.jl:497-504](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L497); compare issue [#409](https://github.com/JuliaData/XLSX.jl/issues/409)). A negative serial in a date-formatted cell throws `XLSXError` instead of returning a value ([cell.jl:498](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L498)).

Time zones do not exist in the model. No switch turns date conversion off; `XLSX.getcell` exposes the raw value.

### 7 Missing values and Excel errors

Empty cells, empty strings and error cells all read as `missing` ([cell.jl:535-539](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cell.jl#L535)). The maintainers discussed this choice in issue [#327](https://github.com/JuliaData/XLSX.jl/issues/327) ("Should cells containing errors return missing?") and kept it. `XLSX.iserror(sheet, "M4")` and `XLSX.geterror(sheet, "M4")` return the error code for one cell (exported from `src/XLSX.jl`). There is no table-level way to tell an error from a blank.

`missing_strings` adds user-declared NA strings. `keep_empty_rows=false` (default) drops all-missing rows inside the table range.

Issue [#460](https://github.com/JuliaData/XLSX.jl/issues/460) (fixed in 0.12.4) is a regression worth noting: in 0.12.3, text cells with a leading space written by a third-party app read as `missing` with no warning.

### 8 Read every sheet

No single call does it. Users loop:

```julia
xf = XLSX.readxlsx(f)
sheets = Dict(s => DataFrame(XLSX.gettable(xf[s])) for s in XLSX.sheetnames(xf))
```

### 9 Write one table to a new workbook

```julia
XLSX.writetable("out.xlsx", df; sheetname="results", overwrite=true)
XLSX.writetable("out.xlsx", df; as_table=true, table_name="Data", table_style="TableStyleMedium2")
```

Overwriting is off by default: with an existing file and no `overwrite=true`, it throws `"out.xlsx already exists."` ([write.jl:2117-2119](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L2117)). Most other writers in this file replace an existing file without asking.

Supported cell types are String, Number (stored as Int64 or Float64), Bool, Date, Time, DateTime and `missing`. Values of any other type are written as `string(x)`, either per element or for the whole column ([write.jl:1225-1236](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L1225); docstring [write.jl:1258-1262](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L1258)). `missing` and `nothing` become empty cells. Dates get built-in format 14, times 20 (`h:mm`) and datetimes 22 (`m/d/yyyy h:mm`) ([styles.jl:33-35](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/styles.jl#L33)). Seconds are therefore not shown for written times and datetimes, although the stored value keeps them.

### 10 Write several tables

One per sheet:

```julia
XLSX.writetable("report.xlsx", "Summary" => df1, "Detail" => df2; overwrite=true)
```

Several on one sheet, at given anchors:

```julia
XLSX.openxlsx("report.xlsx", mode="w") do xf
    s = xf[1]
    XLSX.writetable!(s, df1; anchor_cell=XLSX.CellRef("A1"))
    XLSX.writetable!(s, df2; anchor_cell=XLSX.CellRef("A20"))
end
```

Pair syntax: [tables_interface.jl:89-120](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/tables_interface.jl#L89). `writetable!` with an anchor: tables_interface.jl:122-128 and [write.jl:1239-1300](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L1239). Issue [#180](https://github.com/JuliaData/XLSX.jl/issues/180) is the 2021 request that led to the anchor approach.

Single cells and blocks: `sheet["A1"] = "Title"`, `sheet["A5"] = collect(1:5)` (written along the row), `sheet["A7:C9"] = matrix`.

### 11 Format output

Since 0.11 (2026-03) formatting has been done cell by cell or range by range, after writing (`docs/src/formatting/*.md`, `src/cellformats/*.jl`):

```julia
XLSX.setFont(s, "A1:D1"; bold=true)
XLSX.setFormat(s, "C2:C100"; format="0.0%")        # or built-in names: "Percentage", "Currency"
XLSX.setColumnWidth(s, "A:D"; width=18)
XLSX.freezePanes(s)                                 # first row; or freezePanes(s, "B2")
XLSX.mergeCells(s, "A1:D1")
XLSX.setAlignment(s, "A1"; horizontal="center")
XLSX.setBorder(s, "A1:D10"; allsides=["style"=>"thin"])
```

Functions and docs:

- `setFormat`: [numberformat.jl:120-161](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cellformats/numberformat.jl#L120).
- `setColumnWidth`: [widthheight.jl:1-51](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/cellformats/widthheight.jl#L1). It adds 0.71 units of padding and says the result is close to Excel's, not equal.
- `freezePanes`: `docs/src/formatting/freezeAndSplitPanes.md`.
- Also available: `setFill`, `setConditionalFormat`, and `setUniform*` variants, which are faster on large ranges.
- No autofit and no plain-range autofilter. An autofilter comes only with an Excel table (`as_table=true` or `addtable!`).
- `setColumnWidth` and the other `set*` functions need a writable file (`mode="w"`/`"rw"` or `opentemplate`).

Pitfall: issue [#454](https://github.com/JuliaData/XLSX.jl/issues/454) (fixed in 0.12.3). Assigning a number to a cell that already had an integer-like number format reset the format to General.

### 12 Write into an existing workbook

Fill a template, putexcel style:

```julia
XLSX.openxlsx("template.xlsx", mode="rw") do xf
    s = xf["Table 1"]
    s["B3"] = 0.532
    XLSX.writetable!(s, df; anchor_cell=XLSX.CellRef("B5"), write_columnnames=false)
end
```

Replace one sheet and keep the others:

```julia
xf = XLSX.opentemplate("book.xlsx")
XLSX.deletesheet!(xf, "results")
XLSX.writetable!(XLSX.addsheet!(xf, "results"), df)
XLSX.writexlsx("book.xlsx", xf; overwrite=true)
```

`deletesheet!` is at [write.jl:1932-1935](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L1932). `addsheet!` appends, so the replaced sheet moves to the end of the tab order.

What survives:

- Cell styles, Excel tables (definition, style, autofilter, totals), and chart parts are kept through a read-write cycle (`docs/src/tables/excelTables.md` "Preserving Tables in existing files"; `docs/src/charts/chartLimitations.md` line 47).
- Pivot tables and slicers are not supported (`excelTables.md:587`).
- The `openxlsx` docstring warns that a do-block in `"rw"` mode overwrites the source when the block ends. Elements XLSX.jl cannot process, "such as charts, pivot tables, etc", may be lost. Opening without the do-block and calling `writexlsx` to a new name is the safe path ([read.jl:486-496](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/read.jl#L486)). If the block throws, the source is left unchanged.
- Formulas: issue [#159](https://github.com/JuliaData/XLSX.jl/issues/159) (2021, closed) reported formulas replaced by values after an empty `rw` round trip. Issue [#324](https://github.com/JuliaData/XLSX.jl/issues/324) (closed) covered dynamic-array formulas that did not round-trip.
- Strict OOXML files are converted to transitional on write ([write.jl:72-79](https://github.com/JuliaData/XLSX.jl/blob/13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5/src/write.jl#L72)).

### 13 Labels

Not applicable. Julia tables have no variable or value labels. CategoricalArrays values are not in the allowed type list, so they are written through `string(x)`, which gives the level text.

## SheetJS Community Edition (JavaScript)

Pinned: version 0.20.3, tag `v0.20.3` on https://git.sheetjs.com/sheetjs/sheetjs, commit `8a7cfd47bde8258c0d91df6a737bf0136699cdf8` (tag dated 2024-07-18; still the latest tag on 2026-11-04). The release tarball is https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz. The public npm package `xlsx` stops at 0.18.5 (published 2022-03-24). The install docs say so: "the registry is out of date. The latest version on that registry is 0.18.5" (`SJD` 02-getting-started/01-installation/03-nodejs.md#L94-L95). The old GitHub repo SheetJS/sheetjs is not archived but its description points to git.sheetjs.com.

Docs: docs.sheetjs.com, source repo https://git.sheetjs.com/sheetjs/docs.sheetjs.com at commit `8d1f8a0ea68341b33e51206392c095baad03cf11` (2026-08-02). The docs site pins `"xlsx": "https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz"` in `docz/package.json:41`, and `docz/version.js` prints that version, so the docs describe 0.20.3.

License: `LICENSE` at the pinned commit is the Apache License 2.0 (SPDX `Apache-2.0`; `package.json:179` says `"license": "Apache-2.0"`). Copyright line, `LICENSE:189`: "Copyright (C) 2012-present   SheetJS LLC". There is no NOTICE file. The README adds "All rights not explicitly granted by the Apache 2.0 License are reserved by the Original Author", which does not narrow the Apache grant. Apache-2.0 is compatible with GPL-3.0 (the FSF lists it as GPLv3-compatible, though not GPLv2-compatible), so xlkit could borrow ideas or code with attribution.

SheetJS Pro is a separate paid product. Cell styling, frozen panes, images, charts and pivot tables on write are Pro features; the CE docs say so repeatedly (for example `SJD` 08-api/05-write-options.md#L112 and #L265).

### 1 Install

```sh
npm i --save https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz
```

```js
const XLSX = require("xlsx");     // or: import * as XLSX from "xlsx";
```

Pitfall: `npm install xlsx` silently installs 0.18.5, two years and many date fixes behind. The dates page says "Date and time handling was overhauled in version 0.20.0" (`SJD` 07-csf/07-features/01-dates.md). ESM builds need `XLSX.set_fs(fs)` before `readFile` works in Node (`SJD` 08-api/index.md).

### 2 Read a sheet into a table

```js
const wb = XLSX.readFile("data.xlsx");
const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);   // array of objects
const aoa  = XLSX.utils.sheet_to_json(ws, { header: 1 });             // array of arrays
```

There is no data frame. `read`/`readFile` return a workbook object `{SheetNames, Sheets, Workbook}`; each sheet is a map from A1 address to a cell object `{t, v, w, z, f, ...}` or, with `{dense: true}`, an array of arrays in `ws["!data"]` (`SJD` 07-csf/03-sheet.md). Cell types are `b` boolean, `e` error, `n` number, `d` date, `s` string, `z` stub (`SJD` 07-csf/02-cell.md#L73-L82). `sheet_to_json` turns each row into a plain object; the value in each field is the JS value of that single cell. Nothing unifies a column's type, so one column can hold numbers in some rows and strings in others. The TypeScript generic `sheet_to_json<T>()` is "purely informational" and does no validation (`SJD` 08-api/07-utilities/01-array.md, "Array Output").

### 3 Choose what to read

- List sheets: `wb.SheetNames`. To get names without parsing cells: `XLSX.readFile(f, {bookSheets: true})`.
- Parse only some sheets: `XLSX.readFile(f, {sheets: ["Data"]})` (by name or index).
- Sheet by position: `wb.Sheets[wb.SheetNames[2]]`.
- Cell range: `sheet_to_json(ws, {range: "B3:F200"})`.
- Skip title rows: `sheet_to_json(ws, {range: 4})`. A number keeps the sheet's own range but starts at that 0-based row, so the header is taken from row 5.
- Row limit at parse time: `{sheetRows: n}`.

Pitfalls: ranges use the sheet's self-reported `!ref` (the `<dimension>` element). "If files include cells outside this range, the parsers will save cell information but other utility functions will ignore those cells". The `nodim: true` option recomputes the range (`SJD` 08-api/03-parse-options.md, "Range"). Row numbers are 0-based in `range: n` and `origin: n` but 1-based in A1 strings, a common source of off-by-one errors.

### 4 Header row and column names

The default takes the first row of the range as keys. `header: 1` returns arrays, `header: "A"` uses column letters, and `header: [...]` takes explicit names. In the source (`SJ` bits/90_utils.js#L85-L94), a blank header cell becomes `"__EMPTY"`. A repeated name gets `_1`, `_2`, and so on ("three columns have header `foo` the output fields are `foo`, `foo_1`, `foo_2`", `SJD` 08-api/07-utilities/01-array.md). Header text is the formatted text of the cell (`format_cell`), so a date or number header becomes its display string. With an explicit `header` array, names are not de-duplicated, and repeated names silently overwrite each other ("This can lead to unexpected results if the array values are not unique!"). No name cleaning and no multi-row header support: users read with `header: 1` and build the names themselves.

### 5 Column types

No column typing at all. Each cell keeps its own Excel type. `raw: true` (default) returns underlying values. `raw: false` returns the formatted text `w` for every cell, so all values become strings. `rawNumbers` overrides for numbers only (`SJ` bits/90_utils.js#L42). Users who want a typed column must convert after the fact. A cell that "does not fit" stays as it is, for example a string in a numeric column.

### 6 Dates and times

Excel stores dates as serial numbers with a date number format. By default SheetJS returns them as numbers (type `n`). `cellDates: true` on read converts cells whose format passes `fmt_is_date` into JS `Date` objects (`SJ` bits/67_wsxml.js#L501). `XLSX.SSF.is_date(fmt)` exposes the test. The 1904 system is read from `wb.Workbook.WBProps.date1904` and applied during parse (`#L335`, `#L501`).

Time zones are the main problem. A JS `Date` is an absolute instant; an Excel date is a wall-clock value with no zone. Since 0.20.0, "the actual values stored in cells are intended to be correct when interpreted using UTC date methods". By contrast, `sheet_to_json` converts to local time unless `UTC: true` is passed (`SJ` bits/90_utils.js#L32; `SJD` 07-csf/07-features/01-dates.md, "UTC Option"). On write, `aoa_to_sheet`/`json_to_sheet` treat `Date` values as local unless `UTC: true`. Dates are written as numbers with format 14 (`m/d/yy`) unless `cellDates: true`. In that case they are written as ISO strings in `t="d"` cells, which the docs warn "is not used in the default Excel XLSX export and third-party support is poor" (`SJ` bits/67_wsxml.js#L274-L284).

Pitfalls, verified:
- Off-by-one-day reports going back years: git.sheetjs.com issue 1435 "sheet_to_json: date value is printed the day before" (https://git.sheetjs.com/sheetjs/sheetjs/issues/1435) and issue 3019 "Formatting dates in XLSX.utils.sheet_to_json makes date lose 1 day" (https://git.sheetjs.com/sheetjs/sheetjs/issues/3019, closed). Also issue 2910 (https://git.sheetjs.com/sheetjs/sheetjs/issues/2910): `cellDates` gives `20:59:59.999` instead of `21:00:00`.
- Dates before 1900-03-01 are one day wrong: issue 2942 (https://git.sheetjs.com/sheetjs/sheetjs/issues/2942, open).
- `SSF.is_date` false positives on non-standard format codes turn numbers into dates near 1899-12-31: issue 3354 (https://git.sheetjs.com/sheetjs/sheetjs/issues/3354, open, reported against 0.20.3).
- `cellStyles: true` changes date conversion and gives "1/0/1900": issue 3268 (https://git.sheetjs.com/sheetjs/sheetjs/issues/3268, open).
- When a numeric cell has a date format `z`, `sheet_to_json` calls `numdate(v)` without the workbook's 1904 flag. The source carries the comment "TODO: date1904 setting should also be stored in worksheet object" (`SJ` bits/90_utils.js#L29).

Turning detection off means leaving `cellDates` false and `cellNF` false; you then get serial numbers.

### 7 Missing values and Excel errors

Empty cells are absent from the sheet map. In object output they are skipped, so the key is missing from that row's object, unless `defval` is set. Then every empty cell gets that value: `sheet_to_json(ws, {defval: null})`. Blank rows are skipped in object mode and kept in array mode (`blankrows`).

Error cells have `t: "e"`, a numeric code in `v` and the text (`#N/A`) in `w`. `sheet_to_json` handles them as `v = (v == 0 ? null : void 0)` (`SJ` bits/90_utils.js#L26). So `#NULL!` becomes `null`, and every other error, including `#N/A` and `#DIV/0!`, is dropped like an empty cell or replaced by `defval`. The user cannot tell an error from a blank in the output. With `raw: false` you get the error text instead.

### 8 Read every sheet

```js
const all = Object.fromEntries(wb.SheetNames.map(n => [n, XLSX.utils.sheet_to_json(wb.Sheets[n])]));
```

`readFile` parses every sheet by default, so this is a loop over `SheetNames`.

### 9 Write one table to a new workbook

```js
const ws = XLSX.utils.json_to_sheet(rows);           // or aoa_to_sheet(arrays)
const wb = XLSX.utils.book_new(ws, "Data");          // 2-arg form since 0.20.1
XLSX.writeFile(wb, "out.xlsx");
```

JS number becomes `n`, string becomes `s`, boolean becomes `b`, and `Date` becomes `n` with format `m/d/yy`. `null` and `undefined` are skipped unless `sheetStubs`/`nullError` is set. NaN is written as `#NUM!` and Infinity as `#DIV/0!` (`SJ` bits/67_wsxml.js#L269-L271). `json_to_sheet` writes "All fields from each row"; `header` only orders them. Strings over 32767 characters throw. `writeFile` overwrites an existing file without asking. Writing a workbook with no sheets throws (`SJD` 08-api/07-utilities/08-wb.md).

### 10 Write several tables

One per sheet: call `XLSX.utils.book_append_sheet(wb, ws, name)` repeatedly. A duplicate name throws "Worksheet with name |x| already exists!" unless the fourth argument `roll` is true, which appends a number (`SJ` bits/90_utils.js#L308-L323). `check_ws_name` enforces the 31-character limit, the forbidden characters `: \ / ? * [ ]`, no leading or trailing apostrophe, and no sheet named "History" (`SJ` bits/71_wbcommon.js#L117-L127).

Several tables on one sheet: `sheet_add_aoa(ws, data, {origin: "E2"})` or `sheet_add_json(ws, rows, {origin: "A20"})`. `origin: -1` appends below the last row (`SJD` 08-api/07-utilities/01-array.md). This `origin` argument is the closest thing to `putexcel` in the JS world.

### 11 Format output

| Feature | CE support | How |
|---|---|---|
| Number formats | yes | `ws["B2"].z = "0.00%"` per cell; there is no column-level setter |
| Bold header, fonts, fills | no | Pro only. The writer emits only `numFmtId` per cell and fixes `fontId:0, fillId:0, borderId:0` (`SJ` bits/66_wscommon.js#L60-L82) |
| Column widths | yes | `ws["!cols"] = [{wch: 20}, ...]` |
| Autofit | no | The export tutorial computes `max_width` by hand (`SJD` 02-getting-started/02-examples/02-export.md#L537-L538) |
| Freeze panes | no | The sheetView writer emits only `workbookViewId` and `rightToLeft` (`SJ` bits/67_wsxml.js#L255-L260); the tutorial points to Pro for "frozen rows" (`#L500-L501`) |
| Autofilter | yes | `ws["!autofilter"] = {ref: "A1:D100"}` |
| Merged cells | yes | `ws["!merges"] = [{s:{r:0,c:0}, e:{r:0,c:3}}]` |

### 12 Write into an existing workbook

Read, change the in-memory object, write it back:

```js
const wb = XLSX.readFile("template.xlsx", {cellStyles: true});
XLSX.utils.sheet_add_aoa(wb.Sheets["Report"], [[42]], {origin: "C5"});
wb.Sheets["Data"] = XLSX.utils.json_to_sheet(rows);    // replace one sheet in place
XLSX.writeFile(wb, "out.xlsx");
```

This is a full re-serialization, not an edit of the original XML. The CE parser keeps data, formulas, merges, column widths (with `cellStyles`), autofilter, comments, hyperlinks and defined names. The CE writer drops fonts, fills, borders, frozen panes, conditional formatting, images, charts and pivot tables. Charts come back only as chartsheets of cached data (`SJD` 07-csf/03-sheet.md, "Chartsheet Object"). The parse and write option pages both say features not documented "may not be extracted" or "may not be serialized" and point to Pro (`SJD` 08-api/03-parse-options.md, 08-api/05-write-options.md#L108-L113). For a styled template this means the output loses its look. CE cannot do putexcel-style template filling.

### 13 Labels

Nothing built in. Readers can rename headers with `sheet_add_aoa(ws, [names], {origin: "A1"})` after `json_to_sheet`, which the docs show as the way to write display names that differ from object keys (`SJD` 08-api/07-utilities/01-array.md). Value labels would be a user-side `map` before writing. The SheetJS monorepo ships a `dta` package for reading Stata files (README "Constellation"), but it does not connect labels to Excel output.

## ExcelJS (JavaScript and TypeScript)

Pinned: version 4.4.0, tag `v4.4.0`, commit `ac96f9a61e9799c7776bd940f05c4a51d7200209`, https://github.com/exceljs/exceljs. This is the latest GitHub release (2023-10-19) and the npm `latest` dist-tag. A later git tag `v4.4.1` (commit `1a8fd68371d7f34f58ea966fd6cf0f9ba7bfb0f5`, dated 2025-01-21) exists, but it has no GitHub release and only `4.4.1-prerelease.0` on npm (2024-12-20), so I pinned 4.4.0. Maintenance is thin: issue #2764 "Intent to fork - maintainers attention required" (https://github.com/exceljs/exceljs/issues/2764, open since 2024-05-20) was opened by MUI because security fixes and issues went unanswered.

License: `LICENSE` at the pinned commit is the MIT License (SPDX `MIT`; `package.json:6` `"license": "MIT"`). Copyright line, `LICENSE:3`: "Copyright (c) 2014-2019 Guyon Roche". MIT is compatible with GPL-3.0.

Docs: everything lives in `README.md` (24,478 words), with TypeScript signatures in `index.d.ts`. There is no separate site.

### 1 Install

```sh
npm install exceljs
```

```js
const ExcelJS = require("exceljs");
```

All file I/O is async (`await`).

### 2 Read a sheet into a table

```js
const wb = new ExcelJS.Workbook();
await wb.xlsx.readFile("data.xlsx");
const ws = wb.worksheets[0];
const rows = [];
ws.eachRow((row, i) => rows.push(row.values));   // row.values is 1-based: index 0 is empty
```

ExcelJS is a document object model, not a table reader. There is no function that returns records or a data frame. `ws.getSheetValues()` (typed in `index.d.ts:1271`, not in the README) returns a sparse array of sparse row arrays. Cell values are JS values or objects, depending on `cell.type` (README "Value Types", `EJ` README.md#L2543-L2802): number, string, `Date`, boolean, `null`, `{formula, result}`, `{richText: [...]}`, `{text, hyperlink}` and `{error: "#N/A"}`. A rich-text or formula cell is an object, not a string or number, so naive code that expects scalars breaks.

### 3 Choose what to read

- By name: `wb.getWorksheet("Data")`.
- By position: `wb.worksheets[0]`. Do not use `wb.getWorksheet(1)`, which looks up by internal id. The README warns that ids "very often" do not start at 1 and that "`workbook.getWorksheet(1) != Workbook.worksheets[0]`" (`EJ` README.md#L347-L358).
- List: `wb.worksheets.map(s => s.name)` or `wb.eachSheet(...)`.
- Range or title rows: no option. Users loop `getRow(r)` from the row they want, or slice `getSheetValues()`.
- The whole workbook is loaded; `ignoreNodes` can skip parts such as `dataValidations` or `conditionalFormatting` for speed (README "Reading XLSX", `#L2141-L2176`). A streaming reader exists (`ExcelJS.stream.xlsx.WorkbookReader`).

### 4 Header row and column names

No header concept on read. `ws.columns = [{header, key, width}]` exists for building sheets, but "apart from the column width, they will not be fully persisted" (`EJ` README.md#L663-L665). Keys are lost after a round trip. Blank and duplicate names, multi-row headers and cleaning are all left to user code.

### 5 Column types

None. Each cell keeps its own type. No guessing, no coercion, no override.

### 6 Dates and times

On read, a numeric cell whose style number format passes `utils.isDateFmt` becomes a JS `Date` (`EJ` lib/xlsx/xform/sheet/cell-xform.js#L449-L454). Formula results are converted the same way (`#L457-L459`). `isDateFmt` removes `[...]` and quoted text, then matches `/[ymdhMsb]+/` (`EJ` lib/utils/utils.js#L140-L151). Two consequences:
- Elapsed-time formats like `[h]:mm` keep `:mm`, so durations become `Date` objects near 1899-12-30.
- Any literal letter outside quotes, for example an escaped `\m`, flags a number as a date.

There is no option to turn this off.

The conversion is `new Date(Math.round((v - 25569 + (date1904 ? 1462 : 0)) * 86400000))` (`EJ` lib/utils/utils.js#L58-L61). The resulting `Date` carries Excel's wall-clock time in its UTC fields. On write, `dateToExcel` uses `d.getTime()`, which is also UTC (`#L55-L57`). So `new Date(2017, 2, 15)`, which is local midnight, is written as the UTC instant and shows in Excel shifted by the zone offset. That is issue #486 "Date timezone issue" (https://github.com/exceljs/exceljs/issues/486, open since 2018). The README's own example uses `new Date(2017, 2, 15)` (`#L2592-L2602`), so following the docs reproduces the bug outside UTC.

1904 system: `wb.properties.date1904` is read from `workbookPr` and passed to cell conversion (`EJ` lib/xlsx/xlsx.js#L124, lib/xlsx/xform/book/workbook-properties-xform.js#L15). Issue #1002 "Incorrect parsing of 1904 Date format" (https://github.com/exceljs/exceljs/issues/1002, closed) and #2695 "Dates are not correct when loading files saved in 'Strict Mode'" (https://github.com/exceljs/exceljs/issues/2695, open) show the edge cases. A written `Date` without `numFmt` gets the default format `mm-dd-yy` (`EJ` lib/xlsx/xform/style/styles-xform.js#L260-L261).

### 7 Missing values and Excel errors

Empty cells are `null`, or holes in the sparse `row.values` array. `eachRow`/`eachCell` skip them unless `{includeEmpty: true}`. Error cells come back as `{error: "#N/A"}` objects with the error text preserved (README "Error Value", `#L2781-L2802`). This is better than SheetJS because the error text survives, but every consumer has to check for the object.

### 8 Read every sheet

```js
wb.eachSheet((ws, id) => { all[ws.name] = ws.getSheetValues(); });
```

### 9 Write one table to a new workbook

```js
const wb = new ExcelJS.Workbook();
const ws = wb.addWorksheet("Data");
ws.columns = [{header: "Id", key: "id", width: 10}, {header: "Name", key: "name", width: 32}];
ws.addRows(records);                       // objects matched to keys, or arrays
await wb.xlsx.writeFile("out.xlsx");
```

Number, string, boolean and `Date` map to the matching cell types; `null` is not written. `addTable({name, ref, columns, rows, style})` writes an Excel table object with header, filter buttons and an optional totals row. It overwrites "any data on the sheet covered by the resulting table" (`EJ` README.md#L1218-L1250). `writeFile` replaces an existing file without asking.

Sheet names: more than 31 characters are truncated with only a `console.warn`. Duplicates (compared case-insensitively) and forbidden characters throw (`EJ` lib/doc/worksheet.js#L134-L172). Truncation can turn two distinct long names into a duplicate-name error at the second sheet.

### 10 Write several tables

One per sheet: call `wb.addWorksheet(name)` again for each table. On one sheet, `ws.addTable({ref: "H2", ...})` or `ws.getRow(r).values = [...]`, or set cells one by one. `addRow` always appends after the last row. There is no "write this data frame at E5" helper apart from `addTable`.

### 11 Format output

| Feature | Call |
|---|---|
| Number format | `ws.getColumn(3).numFmt = "0.00%"` or `cell.numFmt = ...` |
| Bold header | `ws.getRow(1).font = {bold: true}` |
| Column width | `ws.getColumn("B").width = 20` or `columns: [{width}]` |
| Autofit | none; issue #83 "Auto Column Width" (https://github.com/exceljs/exceljs/issues/83) asks for it, and the README has no autofit |
| Freeze panes | `ws.views = [{state: "frozen", xSplit: 0, ySplit: 1}]` (README `#L585-L599`) |
| Autofilter | `ws.autoFilter = "A1:D1"` (`#L618-L658`) |
| Merge | `ws.mergeCells("A1:D1")` (`#L880-L906`) |

Pitfall: style objects are shared by reference. "If the same style object is assigned to more than one spreadsheet entity... all entities referencing that style object will be modified too" (`EJ` README.md#L1461-L1466). Changing one cell's font after a bulk assignment changes them all. Row and column styles apply only to cells that exist when you set them, plus new cells created later.

### 12 Write into an existing workbook

```js
await wb.xlsx.readFile("template.xlsx");
const ws = wb.getWorksheet("Report");
ws.getCell("C5").value = 42;
await wb.xlsx.writeFile("out.xlsx");
```

This is the closest JS equivalent of `putexcel`, and it keeps cell styles because ExcelJS models them. To replace a sheet, call `wb.removeWorksheet(ws.id)` and then `addWorksheet(name)`. The new sheet takes the next `orderNo`, so it moves to the end unless you reset `orderNo` (`EJ` lib/doc/workbook.js#L81-L88). Formulas referring to the old sheet are not updated.

Everything outside ExcelJS's model is lost on save:
- Pivot tables: #261 "Losing formatting/pivot table from loaded file" (https://github.com/exceljs/exceljs/issues/261, open since 2017) and #1678 "Losing Pivot tables when loading a file" (https://github.com/exceljs/exceljs/issues/1678, open), where Excel then reports the file as damaged.
- Charts: #1173 "Charts are disappearing from the worklist" (https://github.com/exceljs/exceljs/issues/1173, open).
- Formula results are not recalculated. ExcelJS "cannot process the formula to generate a result, it must be supplied" (README "Formula Value"), so cells that depend on edited values show stale results until Excel recalculates.

### 13 Labels

Nothing built in. Header text from `columns: [{header}]` can differ from the data `key`, which gives "variable label as header" for free when writing. Value labels must be mapped by the user. Data validation lists (`cell.dataValidation = {type: "list", formulae: [...]}`) could expose a value-label set as a dropdown, but nobody uses it that way.

## calamine (Rust, planned reading dependency)

Pinned: crate 0.38.0, tag `v0.38.0`, commit `a4dba3b5309d81b2774018a13be39e68d938c3c7`, https://github.com/tafia/calamine. Released 2026-11-02.

License: `Cargo.toml:8` says `license = "MIT"`. The only license file is `LICENSE-MIT.md`, which reads "The MIT License (MIT)" and "Copyright (c) 2016 Johann Tuffe". Source files carry `// SPDX-License-Identifier: MIT` (for example `src/formats.rs:1`). MIT is compatible with GPL-3.0: a GPL-3.0 package may link MIT code as long as the MIT notice is kept.

What it supports. calamine is read-only. It reads xls, xlsx, xlsm, xlsb, xla, xlam and ods (`README.md`). For xlsx it gives:

- `open_workbook::<Xlsx<_>, _>(path)` and `open_workbook_auto(path)`; `sheet_names()`, `sheets_metadata()` (includes visibility), `worksheet_range(name)`, `worksheet_range_at(n)`, `worksheets()` for all sheets at once (`src/lib.rs:391` onward).
- Cell values as the enum `Data` with variants `Int`, `Float`, `String`, `Bool`, `DateTime(ExcelDateTime)`, `DateTimeIso`, `DurationIso`, `Error(CellErrorType)` and `Empty` (`src/datatype.rs:40`). xlsx numbers are always parsed as `f64` (`src/xlsx/cells_reader.rs:802`); `Int` comes from other formats.
- Error cells as `CellErrorType::{Div0, NA, Name, Null, Num, Ref, Value, GettingData}` (`src/lib.rs:135`), so a reader can tell `#N/A` from an empty cell.
- Date detection from the number format: built-in format ids (`src/formats.rs:52`) and a small parser for custom format codes that skips quoted text, escapes and `[color]` brackets and returns `DateTime`, `TimeDelta` (for `[h]:mm` style elapsed time) or `Other` (`src/formats.rs:15`). Only the first section of a format code (before `;`) is checked.
- The 1904 date system flag from `workbookPr date1904` (`src/xlsx/mod.rs:672`), exposed as `has_1904_epoch()` (`src/xlsx/mod.rs:1356`). Each `ExcelDateTime` carries its own `is_1904` flag (`src/datatype.rs:694`).
- Formulas as text via `worksheet_formula(name)`; values are the cached results Excel saved. calamine does not calculate.
- Excel tables (ListObjects): `load_tables()`, `table_names()`, `table_by_name()` (`src/xlsx/mod.rs:1723`, `:1897`).
- Merged regions: `load_merged_regions()` and `merged_regions_by_sheet()` (`src/xlsx/mod.rs:1531`, `:1686`).
- New in 0.38.0: `worksheet_style(name)` returns font, fill, borders, alignment and the number format code of each styled cell (`Changelog.md`, `src/style.rs:606`, `src/xlsx/mod.rs:2777`). xlkit could use the format code to decide date vs. number itself, or to report formats.
- `with_header_row(HeaderRow::Row(n))` and `Range::headers()` (`src/lib.rs:380`, `:1571`); serde deserialization of rows.

Points xlkit must handle itself:

- `worksheet_range()` returns a `Range` that starts at the first non-empty cell, not at A1 (`src/xlsx/mod.rs:2928`). `Range::start()` (`src/lib.rs:874`) gives the absolute position. xlkit has to add that offset back before applying a user's cell range or "skip n rows", or the user's `A3:F20` will point at the wrong cells.
- There is no column typing, header cleaning, NA strings or type guessing. calamine returns cells; everything readxl does on top of cells is xlkit's job.
- Recent bugs show the date system is easy to get wrong: a `x15:workbookPr` element inside `extLst` reset the 1904 flag, so 1904 workbooks were read on the 1900 epoch (issue #706, https://github.com/tafia/calamine/issues/706, fixed by #708 before this release). Any unrecognised `t="b"` value decoded as `true` (issue #724, https://github.com/tafia/calamine/issues/724, closed 2026-10-18). Open: a malformed file can request a 13 GB allocation (issue #726, https://github.com/tafia/calamine/issues/726) and a reversed `<dimension ref>` underflows (issue #692, https://github.com/tafia/calamine/issues/692). xlkit should not trust the `<dimension>` element and should run its own tests for 1904 files.
- Maintainer capacity: issue #698 (https://github.com/tafia/calamine/issues/698, open) asks for more maintainers because of the volume of issues and PRs. Pin an exact version and vendor it.

## rust_xlsxwriter (Rust, planned writing dependency)

Pinned: crate 0.102.0, tag `v0.102.0`, commit `d850973d3836905db3a04022b093b3d5575ee85e`, https://github.com/jmcnamara/rust_xlsxwriter. Released 2026-10-29. No GitHub "release" objects exist; the tag and crates.io are the release channel.

License: `Cargo.toml:10` says `license = "MIT OR Apache-2.0"`. Files `LICENSE_MIT` ("Copyright 2022-2026 John McNamara <jmcnamara@cpan.org>") and `LICENSE_Apache2.0` (Apache License 2.0 text). Both are compatible with GPL-3.0. Apache-2.0 is compatible with GPL-3.0 (not with GPL-2.0-only); choosing the MIT side avoids the question entirely.

What it supports. It writes new xlsx files only. `README.md:11` and `src/lib.rs:18`: "It cannot be used to modify an existing file." Features listed in `README.md`: all basic cell types, full cell formatting, formulas, charts, hyperlinks, merged ranges, conditional formats, data validation, notes, images, autofilters, worksheet tables, defined names, serde serialization, a constant-memory mode, and optional `polars`, `chrono` and `jiff` features (`Cargo.toml` `[features]`).

Calls xlkit will wrap:

- `Workbook::new()`, `add_worksheet()`, `Worksheet::set_name()` (`src/worksheet.rs:2047`), `workbook.save(path)` (overwrites the target file).
- `write()` / `write_with_format()` (`src/worksheet.rs:2216`), `write_column()`, `write_row_matrix()` (`:2591`), `write_blank()`.
- `Format::new().set_bold().set_num_format("yyyy-mm-dd")`; `set_column_width()` (`:7997`), `set_column_format()` (`:8165`), `autofit()` (`:14669`), `set_freeze_panes()` (`:13310`), `autofilter()` (`:8659`), `merge_range()` (`:4992`), `add_table()` (`:9000`).
- `ExcelDateTime` with a 1904 option (`src/datetime.rs:960`).

Points xlkit must handle itself:

- Missing values. Excel has no NaN. rust_xlsxwriter writes `f64::NAN` as the string `"NAN"` unless told otherwise (doc comment above `set_nan_value()`, `src/worksheet.rs:14840`). R's `NA_real_` is a NaN payload, so xlkit must check `is.na()` in R and write a blank cell (or the user's `na =` string), never pass the NaN through.
- `autofit()` is a simulation based on Calibri 11 character widths and ignores number formats unless the `enhanced_autofit` feature is on (doc comment above `src/worksheet.rs:14669`). Good enough, but xlkit should document it.
- Editing an existing workbook (putexcel, `export excel ..., sheet(, modify)`) cannot be done with rust_xlsxwriter. The options are: (a) read everything with calamine and rewrite, which drops formatting, charts, pivot tables and anything calamine does not read; or (b) edit the xlsx ZIP package directly, replacing one worksheet XML part and patching `sharedStrings.xml`, `styles.xml`, `workbook.xml` and the relationships. Option (b) is what openpyxl, openxlsx2 and ExcelJS approximate with a full object model, and each loses parts it does not model (see their sections). xlkit should decide this early and say in the docs which parts survive.
- Limits: `XlsxError::RowColumnLimitError` and `MaxStringLengthExceeded` (`src/error.rs:37`, `:59`) for more than 1,048,576 rows, 16,384 columns or strings over 32,767 characters. xlkit should check these in R first and give an R-level error that names the column.

## Stata: import excel, export excel, putexcel (general knowledge only)

Stata is proprietary. This section is written only from general knowledge of how the commands behave. I did not read Stata's manuals, help files or website for it, so details below may be incomplete, and option spellings should be checked against a real Stata before xlkit claims compatibility. No license applies to xlkit here because no Stata code or documentation is used.

1. Install. Built into Stata (import excel and export excel since Stata 12, putexcel since Stata 13, with the cell-formatting syntax added in Stata 14).
2. Read a sheet. `import excel using "data.xlsx", clear` replaces the dataset in memory. A column whose cells are all numeric becomes a numeric variable; a column with any text cell becomes a string variable, and the numbers in it become text.
3. Choose what to read. `sheet("Data")` picks a sheet by name; there is no sheet-by-position option. `cellrange(A3:F200)` or `cellrange(A3)` picks a range or a start cell. `import excel using "data.xlsx", describe` lists sheets and their used ranges.
4. Header row. `firstrow` takes the first row of the range as variable names. Header text is turned into a valid Stata name (spaces and illegal characters removed, length cut to 32), and the original header text is kept as the variable label. `case(lower|upper|preserve)` controls case. Without `firstrow`, variables are named after the column letters (`A`, `B`, `C`). There is no multi-row header support; users read the rows separately.
5. Column types. Decided from all cells in the column, so one stray text cell turns a numeric column into strings. `allstring` forces every variable to string. Users then run `destring`.
6. Dates. Cells with a date number format are converted to Stata dates or datetimes with a date display format. Dates stored as text stay strings and need `date()` afterwards.
7. Missing values. Empty cells become `.` (numeric) or `""` (string). Excel error values come in as missing.
8. Every sheet at once. Not supported; users loop over the sheet list from `describe`.
9. Write one table. `export excel using "out.xlsx", firstrow(variables) replace`. Without `replace` (or a `sheet(, modify)` option) Stata refuses to overwrite an existing file. Value labels are written as their text by default; `nolabel` writes the numeric codes. Dates are written as Excel dates; a `datestring()` option writes them as formatted text.
10. Several tables. `export excel ... , sheet("Second") ` adds or replaces one sheet in an existing file, with `sheet("name", modify)` or `sheet("name", replace)`. `cell(B5)` sets the upper-left cell, so several datasets can go to one sheet by repeated calls.
11. Format output. export excel has little formatting (`keepcellfmt` keeps the existing cell formats when modifying). putexcel does formatting: `putexcel A1:F1, bold border(bottom)`, `putexcel B2:B20, nformat(number_d2)`, `putexcel A1:F1, merge hcenter`, plus font, fill and alignment options.
12. Write into an existing workbook. `putexcel set "report.xlsx", sheet("Results") modify` then `putexcel B2 = r(mean)`, `putexcel A1 = "Title"`, `putexcel B3 = matrix(M), names`, `putexcel A10 = formula(SUM(B2:B9))`, or a stored estimation table. Cells not named are left alone. This is the command xlkit most needs to match: template workbooks keep their formatting and only the targeted cells change.
13. Labels. Variable labels can be the header row (`export excel ..., firstrow(varlabels)`), value labels are exported as text by default, and `import excel, firstrow` stores header text as variable labels. No other library here does this; R's haven `labelled` class and the `label` attribute are the closest R equivalent.

Pitfalls known from experience with Stata (not from its documentation): a single note like "n/a" in a numeric column turns the whole column into strings; a title row above the header needs `cellrange()` plus `firstrow`; the variable name made from a header is not predictable for headers with punctuation; and `export excel` with `replace` replaces the whole workbook, not one sheet, which surprises users who wanted `sheet(, replace)`.

## What xlkit should take from each

These are design ideas, not code. Nothing has been copied. Each idea names where it came from.

### From Stata (the behavior to match)

- Type each column from every cell in it, not from a sample. A column with one text cell is text. This is what `import excel` users expect, and a translated do-file should give the same types.
- `firstrow` semantics: header text becomes a valid name, and the original text is kept as the variable label (R: the `label` attribute that haven uses).
- `export excel` writes value labels as text by default and has `nolabel` to write codes. `firstrow(varlabels)` writes variable labels as the header. xlkit should support both directions for haven `labelled` vectors.
- Refuse to overwrite an existing file unless `replace` is given, and keep "replace the file" separate from "replace one sheet" and "modify one sheet" (`sheet("x", replace)`, `sheet("x", modify)`).
- `cell(B5)` places a table at a given cell, so several tables can share one sheet.
- `putexcel set file, sheet() modify` followed by `putexcel B2 = expr`: write values into named cells of a template and leave everything else as it was, including the template's formatting.

### From R packages

- readxl: one `range` argument that takes `"Sheet!B3:D87"`, plus helpers for open-ended ranges. It maps straight onto Stata's `cellrange()`.
- readxl: coercion warnings that name the cell, such as `Expecting numeric in B1002: got 'n/a'`. xlkit should cap them and print a count.
- readxl: `.name_repair` that takes a strategy string or a function.
- readxl: handle the 1900 leap-year bug (serial 60 becomes `NA` with a warning) and read the 1904 flag.
- readxl: the sheet-geometry vignette's plain account of how the data rectangle is found. xlkit should write the same kind of page for its own rules.
- writexl: a short table in the docs mapping each R type to an Excel cell type.
- writexl: an error that names the column when a type cannot be written.
- writexl: one time zone rule per workbook, with a warning only when zones differ.
- writexl: sheet-name repair (forbidden characters, 31 characters, duplicates) with a warning that shows old and new names.
- writexl: the writer returns the path invisibly, and `na =` keeps its own type.
- openxlsx2: one cell-addressing argument (`dims`) used by every function, and `wb_dims(x = df, cols = "income", select = "data")` to compute the cells of part of a table. This is the right base for `putexcel` and for formatting after a write.
- openxlsx2: wildcard ranges like `"A3:F+"` (to the last row), which match Stata's open-ended `cellrange(A3)`.
- openxlsx2: type overrides by name (`types = c(id = "character")`) that leave other columns guessed.
- openxlsx2: `na = list(strings = ..., numbers = ...)`, so text and numeric missing codes are separate.
- openxlsx2: read a defined name or an Excel table by name (`named_region =`).
- openxlsx2: when writing into existing cells, keep the cell's style by default.
- openxlsx2: the per-cell type table (`keep_attributes = TRUE`) as a debugging aid.
- openxlsx2: `"auto+2"` column widths, meaning autofit plus padding.
- openxlsx: one overwrite default for every save path. openxlsx has two with opposite defaults.
- tidyxl: a low-level "one row per cell" reader for layouts no header rule can handle, with Excel errors kept in their own column.

### From Python packages

- pandas: name the "sheet already exists" policy with values `"error"`, `"replace"` and `"overlay"` (`if_sheet_exists`).
- pandas: `freeze_panes` and `autofilter` as plain writer arguments.
- pandas: accept Excel column letters for column selection (`usecols = "A,C:E"`).
- pandas: add the sheet name to parse errors.
- openpyxl: Excel addresses everywhere, 1-based, and freeze panes given as the top-left scrolling cell (`"A2"`).
- openpyxl: error cells kept apart from blanks (`data_type == "e"`).
- openpyxl: an explicit choice between cached values and formula text (`data_only`), with values as the default for analysis.
- openpyxl: read the workbook's date system once and use it on write (`wb.epoch`).
- polars: read an Excel table by name (`table_name =`). The table's own range sets the bounds, so there is nothing to guess.
- polars: positions as `"B4"` or `c(row, col)`, freeze panes as `"A2"` or `c(1, 0)`.
- polars: default formats per type that the caller can override per column (`dtype_formats`, `column_formats`).
- polars: check Excel's row and column limits before writing anything.
- fastexcel: a `strict` / `coerce` switch for cells that do not fit the column type.
- fastexcel: collect the cells that failed conversion (`to_arrow_with_errors()`) and return them.
- python-calamine: its `skip_empty_area` default shows why xlkit should keep sheet coordinates intact. Row 5 in Excel must stay row 5.
- XlsxWriter: reusable format objects, autofit by estimating text width, and real Excel tables as an output option.

### From Julia

- XLSX.jl: `overwrite = FALSE` by default; writing to an existing path is an error that names the file.
- XLSX.jl: write a template edit to a new path by default. If the source must be replaced, replace it only after the edit succeeds.
- XLSX.jl: cell assignment by address (`s["B3"] = x`), the nearest existing match to `putexcel B3 = x`.
- XLSX.jl: `first_row =` for tables below title rows, and an optional end-of-table marker (`stop_in_row_function`).
- XLSX.jl: multi-sheet writes as name/table pairs. In R that is a named list.

### From JavaScript

- SheetJS: one `origin` argument for placement: a cell (`"E2"`), or "append below the last row".
- SheetJS: keep value, formatted text and number format for each cell. A single switch then returns what Excel displays, which covers `import excel ..., allstring` cases.
- SheetJS: a metadata-only read for listing sheets, and a filter to parse only the sheets asked for.
- SheetJS: exact sheet-name validation (31 characters, `: \ / ? * [ ]`, apostrophes, "History").
- ExcelJS: a column spec that pairs display header, data key and width. For xlkit the header can be the variable label while the R name stays the key.
- ExcelJS: `addTable()` writes a real Excel table in one call.
- ExcelJS: return the error text (`{error: "#N/A"}`) rather than discarding it.

### From the Rust crates xlkit will use

- calamine: `Data::Error(CellErrorType)` lets xlkit tell `#N/A` from a blank at no cost.
- calamine: `worksheet_style()` (new in 0.38.0) exposes number format codes, so xlkit can decide date versus number in one place and offer an off switch.
- calamine: `table_by_name()`, `merged_regions_by_sheet()` and `has_1904_epoch()` cover named tables, merged headers and the date system.
- rust_xlsxwriter: formats, `autofit()`, `set_freeze_panes()`, `autofilter()`, `merge_range()` and `add_table()` cover task 11 directly.

## Mistakes to avoid

1. Guessing column types from a sample. readxl looks at the first 1,000 rows (`R/read_excel.R:152`), polars at 100 (`N_INFER_DEFAULT`), fastexcel at 1,000. The readxl failure mode (numeric guess, text at row 1,500, hundreds of `NA` warnings) runs through readxl #223 and #198. Stata scans the whole column, so xlkit should too.
2. Re-inferring types from cell text. pandas runs cells through its CSV parser, so text `'020099` becomes `20099.0` (pandas #20828, open) and the strings "None" and "NA" become missing (pandas #61788). Type columns from the cell types stored in the file.
3. Default missing-value strings that eat real data. pandas has 19 default NA strings (`_base.py#L338-L343`); fastexcel treats "NA", "null", "None" and "n/a" as null during inference. Only empty cells should be missing by default. Extra NA codes should be opt-in.
4. Turning a cell that does not fit into `NA` without a trace. polars does this with no warning; openxlsx2 gives R's generic "NAs introduced by coercion" with no address. Report the sheet and cell address of every coerced cell.
5. Losing Excel error values. readxl turns them into blanks (`src/XlsxCell.h:168-172`); SheetJS drops every error except `#NULL!` (`bits/90_utils.js#L26`); XLSX.jl, python-calamine and pandas with openpyxl all map them to missing (XLSX.jl #327). Keep them distinguishable, at least as a count in a warning and a record of which cells.
6. Writing R `NA` as anything but an empty cell. openxlsx2 writes `#N/A` by default (`src/helper_functions.cpp:866-871`), which breaks `SUM()`. rust_xlsxwriter writes NaN as the string `"NAN"` unless told otherwise (`src/worksheet.rs:14840`), and R's `NA_real_` is a NaN. SheetJS writes NaN as `#NUM!`. Stata writes blanks. Check `is.na()` in R before handing values to Rust.
7. Converting dates through the local time zone. ExcelJS #486 has been open since 2018, and its README example triggers it outside UTC. SheetJS has years of off-by-one-day reports (SheetJS issues 1435, 3019, 2910). Excel dates are wall-clock values; map them to `Date` and UTC `POSIXct` and never consult the system zone.
8. Deciding the date type from values instead of the number format. polars casts all-midnight datetimes to `Date` and whole floats to `Int64` after inference (`functions.py:1158-1184`), which can crash (polars #22408). readxl goes the other way and returns `POSIXct` even for date-only formats. Use the format: a date-only format gives `Date`, a format with time gives `POSIXct`, `[h]:mm` gives a duration.
9. A loose date-format test. ExcelJS matches `/[ymdhMsb]+/` after stripping brackets (`lib/utils/utils.js#L140-L151`), so `[h]:mm` durations become dates. SheetJS's `SSF.is_date` has false positives (SheetJS issue 3354). XLSX.jl misses the built-in East Asian date ids (`src/styles.jl:239`). readxl had to fix `[red]` being read as a date (readxl #388). Test the detector on odd formats.
10. No way to turn date detection off. pandas (`parse_dates=False` does not do it, pandas #47269), ExcelJS and polars have none. xlkit should have a switch, per column and for the whole sheet.
11. Getting the 1904 system wrong. calamine reset the flag when `x15:workbookPr` appeared (calamine #706, fixed before 0.38.0); SheetJS's `sheet_to_json` converts without the workbook's flag (`bits/90_utils.js#L29`, a TODO in the source); SheetJS also gets dates before 1900-03-01 wrong (SheetJS issue 2942). xlkit needs its own test files for both systems and for early 1900 dates.
12. Overwriting a whole workbook without asking. `DataFrame.to_excel(path)`, polars `write_excel` (polars #10692, where the user lost the other sheets), writexl, SheetJS and ExcelJS all replace the file silently. Stata refuses without `replace`; xlkit should too.
13. Turning strings into formulas or links. openpyxl treats any string starting with `=` as a formula (`openpyxl/cell/cell.py:198-199`). XlsxWriter defaults `strings_to_formulas` and `strings_to_urls` to true, so what pandas writes depends on which engine is installed. Strings must be written as strings.
14. Editing through a full object model that drops what it does not model. openpyxl drops shapes and many extension-list features (`openpyxl/reader/drawings.py:33`, `openpyxl/worksheet/_reader.py:327-329`). ExcelJS loses pivot tables and charts (ExcelJS #261, #1678, #1173). SheetJS CE loses all styling. pandas' own docstring warns that append mode loses charts, images and VBA (`_base.py#L1037-L1042`). For `putexcel` and sheet replacement, xlkit should patch only the parts it changes and copy everything else byte for byte. Where it cannot, it should refuse and say what would be lost.
15. Saving in place without a safe swap. pandas append mode writes back into the same handle and truncates (`pandas/io/excel/_openpyxl.py:105-111`). The XLSX.jl `"rw"` do-block overwrites the source when it ends. Write to a temporary file in the same directory and rename it over the target only after success.
16. A return type that depends on an argument value. `pd.read_excel(sheet_name=None)` returns a dict, otherwise a DataFrame (pandas #60909). Use a separate function for "all sheets".
17. Global options and loaded packages that change output. openxlsx2 reads `options("openxlsx2.na")`, `openxlsx2.string_nums` and `openxlsx2.dateFormat`, and returns `hms` or strings depending on whether hms is loaded (`R/read.R:79-82`). The same call should give the same file in every session.
18. Several engines with different rules behind one function. polars' three readers give different values and three different duplicate-name schemes (polars #18937). pandas is switching its default reader. One engine, one set of rules.
19. Dropping rows and columns by default. polars drops all-null rows and unnamed all-zero columns (`functions.py:972-1003`, polars #18250). python-calamine skips leading empty rows. A Stata user expects every row in the range.
20. Guessing table bounds from the first row. XLSX.jl reads a sheet with a title row as a one-column table (XLSX.jl #355). Also note that calamine's `worksheet_range()` starts at the first non-empty cell, so xlkit must add `Range::start()` back before applying user ranges.
21. Display defaults that change what users see, or change the data. polars writes integers with thousands separators and red negatives and floats to 3 decimals (`_write_utils.py:52-53`). pandas `float_format` rounds the stored value (`pandas/io/formats/excel.py:599-600`). XLSX.jl's default datetime format hides seconds. Write plain values with plain formats, like `export excel`.
22. Positional-only type overrides. readxl's `col_types` must list every column; the request for named specs has been open since 2016 (readxl #198).
23. Silent truncation of sheet names. ExcelJS cuts names over 31 characters with only a `console.warn` (`lib/doc/worksheet.js#L134-L172`). Also avoid two ways to index sheets that disagree (`getWorksheet(1)` versus `worksheets[0]` in ExcelJS).
24. Dropping labels without a way back. writexl writes `haven_labelled` values as bare codes and ignores variable labels. openxlsx2 writes labels as text with no switch for codes, and once wrote the label only on first occurrence (openxlsx2 #1406). xlkit should do what `export excel` does: labels by default, codes on request, variable labels as the header on request.
25. A stale install channel. `npm install xlsx` gives SheetJS 0.18.5 from 2022, behind the 0.20.0 date fixes. xlkit should be on CRAN or r-universe with one version, and vendor its Rust crates at pinned versions (calamine's maintainers have asked for help in calamine #698).
