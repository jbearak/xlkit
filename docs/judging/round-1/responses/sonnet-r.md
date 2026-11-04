# Round 1 judgement (sonnet-r)

Score order everywhere: [ergonomics, failure, findability, correctness, completeness, clarity].
Library A is a reader package (`read_excel`, `excel_sheets`) plus a writer package (`write_xlsx`, `xl_*`). Library C is the `wb_*` / `read_xlsx` / `write_xlsx` package. Judged only on the text in the prompt.

---------------------------------------------------------------------------
# Library A
---------------------------------------------------------------------------

## A1 Install
```r
install.packages(c("Library A (reader)", "Library A (writer)"))
```
Scores [3,1,3,3,2,3]
- Failure 1: the docs say there are no external dependencies and no Java, but never say what happens, or what to do, if an install fails.
- Completeness 2: the command and "no external dependencies / all operating systems" are given; R versions and failure advice are missing.

## A2 Read a sheet
```r
read_excel("report.xlsx")
```
Scores [3,1,3,3,3,3]
- Failure 1: no doc says what happens when the path does not exist.

## A3 Choose what to read
```r
read_excel("f.xlsx", sheet = "Sales 2024", range = "B5:F40")
excel_sheets("f.xlsx")
```
Scores [3,1,3,3,3,3]
- Failure 1: nothing says what happens for a misspelled sheet name.

## A4 Header and names
```r
read_excel(p, sheet = 1, .name_repair = "universal")
read_excel(p, sheet = 2, n_max = 2, col_names = FALSE)  # then paste and fill group names by hand
```
Scores [1,2,3,3,1,3]
- Ergonomics 1: the merged two-row header has no argument. It takes several reads plus hand-written combining.
- Failure 2: the docs say names are made unique and non-empty, but not what they become or which header text each came from.
- Completeness 1: only name repair is covered. The multiple-header article handles a metadata row, not merged group names, and nothing records the original header text.

## A5 Column types
```r
read_excel(p, col_types = c("text", "numeric"))   # one entry per column, by position
# then read again as text and compare, to find cells that did not convert
```
Scores [1,0,3,3,2,3]
- Ergonomics 1: `col_types` is positional for every column (the peek-at-names trick takes another read), and there is no way to list the cells that failed.
- Failure 0: the docs say unconvertible text becomes `NA`, with no message and no listing.
- Completeness 2: the coercion rules are thorough, but finding the failed cells is missing. Numbers read as text follow `as.character()`, so a numeric 02139 would read as 2139.

## A6 Dates and times
```r
d <- read_excel(p); d$day <- as.Date(d$day)
read_excel(p, col_types = "numeric")             # stored numbers; 1904 is handled by the reader
```
Scores [1,0,2,3,2,3]
- Ergonomics 1: every date-like column arrives as POSIXct, with no Date or time-of-day type, so the default type is wrong until converted. Stored numbers need per-column `col_types`.
- Failure 0: a text cell in the date column makes the whole column character (dates as serial numbers), or `NA` if forced to date, with no message documented.
- Findability 2: the answer is a README Features bullet and a row of the types table; there is no heading about dates.
- Completeness 2: POSIXct, UTC, 1900/1904 and the numeric view are covered, but no Date or time-of-day type and no text-in-date case.

## A7 Missing values and errors
```r
read_excel(p, na = c("", "NA", ".", "-"))
# no documented way to separate Excel errors from blanks
```
Scores [0,1,2,3,1,3]
- Ergonomics 0: telling errors from blanks has no documented route.
- Failure 1: the docs never mention Excel error cells.
- Findability 2: `na` is on the README and in the types article; errors appear nowhere.
- Completeness 1: only the `na` argument is covered.

## A8 Every sheet
```r
path |> excel_sheets() |> set_names() |> map(read_excel, path = path)
```
Scores [1,1,3,3,3,3]
- Ergonomics 1: one `read_excel()` call per sheet through `map`, plus helper calls.
- Failure 1: the docs do not say what an empty sheet gives.

## A9 Write a table
```r
write_xlsx(df, "out.xlsx")
```
Scores [3,1,2,2,2,3]
- Failure 1: nothing says what happens when the file already exists.
- Findability 2: the type table sits in the getting-started vignette under "What is written"; the README does not point to it.
- Correctness 2: the README says every column type survives a trip through the reader unchanged, but its own table turns factors into text, and the reader returns dates as POSIXct.
- Completeness 2: the overwrite behaviour is missing.

## A10 Write several tables
```r
write_xlsx(list(Summary = a, Detail = b, Notes = c), "out.xlsx")
# two titled tables on one sheet: no placement option; only hand-built xl_cell_general columns
```
Scores [1,3,2,3,1,3]
- Ergonomics 1: part one is one call. Part two has no placement argument, so the titles, headers and gap rows must be built as mixed cell columns by hand.
- Findability 2: the several-sheets section is one step from the vignette; two tables on one sheet is not found.
- Completeness 1: the second part is not covered.

## A11 Format the output
```r
sh <- xl_sheet(df,
  cols = list(xl_col_spec("share",  format = xl_num_format("0.0%")),
              xl_col_spec("amount", format = xl_num_format("#,##0"))),
  freeze = "A2", auto_colwidth = TRUE, autofilter = TRUE)
write_xlsx(list(Data = sh), "out.xlsx")     # header is bold by default
```
Scores [1,1,2,2,3,3]
- Ergonomics 1: an `xl_sheet` object plus per-column spec and format constructors, then the write.
- Failure 1: nothing says what happens for a column name that is not in the table.
- Findability 2: the pieces are spread over the formatting vignette, the worksheets vignette and the `xl_sheet` reference.
- Correctness 2: the `write_xlsx` reference points to a "Formatting and workbook properties" vignette that is not in the set, and the `xl_num_format` example string is cut off.

## A12 Fill an existing workbook
Not possible: the reader only reads, and the writer "only writes" new files.
Scores [0,1,0,0,0,0]
- Ergonomics 0: there is no way to edit a template.
- Failure 1: the docs do not say what happens to a template's chart.
- Findability, correctness, completeness, clarity 0: the task is not covered.

## A13 Labels
```r
names(df) <- vapply(df, attr, "", "label"); df$sex <- factor(df$sex, 1:2, c("Male","Female"))
write_xlsx(df, "out.xlsx")   # and by hand in reverse for the reading half
```
Scores [1,1,0,0,0,0]
- Ergonomics 1: no label support, so it is hand-built from several base R calls.
- Failure 1: the docs say nothing about a code with no label.
- Findability, correctness, completeness, clarity 0: not covered.

---------------------------------------------------------------------------
# Library B
---------------------------------------------------------------------------

## B1 Install
```r
install.packages("remotes"); remotes::install_github("Library B")
```
Scores [2,3,3,3,3,3]
- Ergonomics 2: two calls (remotes first), and Rust must be installed outside R.

## B2 Read a sheet
```r
read_xlsx("report.xlsx")
```
Scores [3,1,3,3,3,3]
- Failure 1: a missing file is not covered by the docs or the messages table.

## B3 Choose what to read
```r
read_xlsx(p, sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets(p)
```
Scores [3,3,3,3,3,3]

## B4 Header and names
```r
read_xlsx(p, sheet = "Headers", names = "snake")
read_xlsx(p, sheet = "Two-row header", header = 4:5)
```
Scores [3,3,3,3,3,3]

## B5 Column types
```r
df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))
xlsx_problems(df)
```
Scores [3,3,3,3,3,3]

## B6 Dates and times
```r
read_xlsx(p)                                  # Date, POSIXct (UTC), hms; 1904 read from the file
read_xlsx(p, dates = FALSE)                   # stored numbers
```
Scores [3,2,3,3,3,3]
- Failure 2: with `types = "date"` a text cell becomes `NA` with a warning. By default the column silently stays character, which is documented but gives no message.

## B7 Missing values and errors
```r
df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))   # warns, naming the error cells
xlsx_problems(df)
```
Scores [3,3,3,3,3,3]

## B8 Every sheet
```r
read_sheets(p)
```
Scores [3,1,3,3,2,3]
- Failure 1: nothing says what an empty sheet gives.
- Completeness 2: no empty-sheet case, and it is unclear what happens with chart sheets, which `xlsx_sheets` lists and which cannot be read.

## B9 Write a table
```r
write_xlsx(df, "out.xlsx")   # refuses a file another program saved
```
Scores [3,3,3,3,3,3]

## B10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "out.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "results.xlsx", gap = 2)
```
Scores [3,2,3,3,3,3]
- Failure 2: the error "says which value broke" the sheet-name rule but gives no advice on what to do.

## B11 Format the output
```r
write_xlsx(df, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Bold header, frozen header and fitted widths are defaults.
Scores [3,1,3,3,3,3]
- Failure 1: only `types` and `styles` keys are documented to stop on unknown names; `formats` is not.

## B12 Fill an existing workbook
```r
write_sheet(new_data, path, sheet = "Data")
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores [3,3,3,3,2,3]
- Completeness 2: the docs do not say whether the chart's range follows a table that is longer than the old one, or whether the cleared Data cells lose their formats.

## B13 Labels
```r
write_xlsx(df, "survey.xlsx", header = "labels")      # value labels are written by default
df <- read_xlsx("survey.xlsx", names = "snake")       # long header kept as the label
```
Scores [3,3,3,3,3,3]

---------------------------------------------------------------------------
# Library C
---------------------------------------------------------------------------

## C1 Install
```r
install.packages("Library C")
```
Scores [3,1,3,3,1,3]
- Failure 1: nothing is said about installation failures or system requirements. The zip-utility need appears only under `wb_save`.
- Completeness 1: only the commands; no platforms, R versions or requirements.

## C2 Read a sheet
```r
read_xlsx("report.xlsx")
```
Scores [3,1,2,3,2,2]
- Failure 1: a missing file is not covered.
- Findability 2: `read_xlsx` is on the README and under "Basic import", but there is no heading on column types.
- Completeness 2: there is no type table or rule for how a column's type is chosen; it only says date, logical, numeric and character.
- Clarity 2: the vignette is chatty, with loose wording ("(logical too?)") and unexplained row names.

## C3 Choose what to read
```r
read_xlsx(p, sheet = "Sales 2024", dims = "B5:F40")
wb_get_sheet_names(wb_load(p))
```
Scores [2,1,2,3,3,2]
- Ergonomics 2: listing the sheets needs two calls (load, then the name function).
- Failure 1: a misspelled sheet name is not covered.
- Findability 2: `dims` has a heading, but sheet names appear only in the basic manual and a reference page.
- Clarity 2: `dims` is described in openxml terms, with wildcards explained only in a reference.

## C4 Header and names
```r
read_xlsx(p, check_names = TRUE)
read_xlsx(p, sheet = 2, dims = "B2:E3", col_names = FALSE, fill_merged_cells = TRUE)  # then paste by hand
```
Scores [1,1,1,2,1,1]
- Ergonomics 1: the two-row merged header needs several calls and hand-made names.
- Failure 1: duplicate and blank headers are not addressed; the README shows a blank header left as an `NA` column name.
- Findability 1: `check_names` and `fill_merged_cells` appear only in the reference.
- Correctness 2: `check_names` is described as `make.names()`, which does not say that duplicates become unique.
- Completeness 1: no recipe for group headers and no record of the original header text.
- Clarity 1: terse reference text and a cryptic `"B2:C2,B4:C+"` example.

## C5 Column types
```r
df <- read_xlsx(p, types = c(zip = 0, amount = 1), keep_attributes = TRUE)  # 0 = character, 1 = numeric
```
Scores [1,1,2,3,1,2]
- Ergonomics 1: the type codes are numeric, and finding failed cells means inspecting the `tt` attribute by hand.
- Failure 1: nothing says what happens to `n/a` or `12,5`, or that any message appears.
- Findability 2: the `types` heading is easy to find; `keep_attributes` is in the reference only.
- Completeness 1: conversion failures and leading zeros are not covered.
- Clarity 2: the codes are explained, but the `tt` table is not.

## C6 Dates and times
```r
read_xlsx(p)                            # Date / POSIXct (UTC); times are hms only if hms is loaded
read_xlsx(p, detect_dates = FALSE)      # stored numbers
```
Scores [2,1,2,3,2,2]
- Ergonomics 2: the time-of-day type depends on whether `hms` is loaded, and the 1904 system is not mentioned.
- Failure 1: the docs do not say what a text cell in a date column does.
- Findability 2: `detect_dates` has a heading; 1904 is not found.
- Completeness 2: the 1904 system and text-in-date are missing.
- Clarity 2: the explanations are short and the `hms` rule sits in a reference paragraph.

## C7 Missing values and errors
```r
read_xlsx(p, na = c("NA", ".", "-", "#N/A", "#DIV/0!"))
# a second read without the error codes keeps them as text
```
Scores [2,0,2,3,1,2]
- Ergonomics 2: two reads are needed to get missing values and also tell errors apart.
- Failure 0: error codes such as `#DIV/0!` come back as text in a numeric column, with no message.
- Findability 2: `na` has a heading; error handling is a single sentence in the upgrade vignette.
- Completeness 1: no explicit treatment of Excel errors or of telling them from blanks.
- Clarity 2: the `na` example (`na = ""`) does not show a missing-value code.

## C8 Every sheet
```r
wb <- wb_load(p)
sapply(wb_get_sheet_names(wb), function(s) wb_to_df(wb, sheet = s), simplify = FALSE)
```
Scores [1,1,1,0,0,0]
- Ergonomics 1: it builds a loop around several calls.
- Failure 1: the docs do not clearly say what an empty sheet gives; "even if it empty" is about selected cells.
- Findability 1: only implied by the sheet-name and `sheet =` examples.
- Correctness, completeness, clarity 0: the task is not covered.

## C9 Write a table
```r
write_xlsx(df, "out.xlsx", na = "")
```
Scores [1,0,2,3,2,2]
- Ergonomics 1: by default `NA` becomes the Excel `#N/A` error and an existing file is replaced.
- Failure 0: an existing workbook is overwritten with no message; `overwrite = FALSE` has to be chosen.
- Findability 2: the write heading is there, but what each column becomes is in the `wb_add_data` and `write_xlsx` reference details.
- Completeness 2: Date and POSIXct are covered; logical, integer and factor are not.
- Clarity 2: "`na_strings()` uses the special #N/A value" needs rereading.

## C10 Write several tables
```r
write_xlsx(list(A = a, B = b, C = c), "out.xlsx")
wb <- wb_workbook()$add_worksheet("S")$add_data(x = "Table 1", dims = "A1")$add_data(x = t1, dims = "A2")
# ... then the same for Table 2 at a computed row, then wb$save("out.xlsx")
```
Scores [1,1,2,3,2,2]
- Ergonomics 1: part two is a workbook object, several `add_data` calls, hand-computed rows and a save.
- Failure 1: sheet names are "validated", but the docs do not say what the user sees.
- Findability 2: the list form is in the `write_xlsx` examples; the offset form is in `wb_add_data`.
- Completeness 2: row placement and the illegal-name case are not worked through.
- Clarity 2: the workbook workflow is chatty and the wrapper-versus-chain distinction takes rereading.

## C11 Format the output
```r
wb <- wb_workbook()$add_worksheet("Data")$add_data(x = df, with_filter = TRUE)$
  add_font(dims = wb_dims(x = df, select = "col_names"), bold = TRUE)$
  add_numfmt(dims = wb_dims(x = df, cols = "share"), numfmt = "0.0%")$
  add_numfmt(dims = wb_dims(x = df, cols = "amount"), numfmt = "#,##0")$
  set_col_widths(cols = seq_along(df), widths = "auto")$freeze_pane(first_row = TRUE)$save("out.xlsx")
```
Scores [1,1,2,2,3,2]
- Ergonomics 1: it takes a workbook object and about seven calls.
- Failure 1: nothing says what a column name that is not in the table does.
- Findability 2: the answers are spread over the style vignette and four reference pages.
- Correctness 2: the `write_xlsx` examples use `col_widths` where the arguments list `widths`, and the style vignette mixes `textRotation` with `text_rotation`.
- Clarity 2: the style vignette is long, with bare-metal detours and leftover predecessor wording.

## C12 Fill an existing workbook
```r
wb <- wb_load("results.xlsx")
wb$clean_sheet("Data")$add_data("Data", new_data)$add_data("Cover", 1250, dims = "C4")$
  add_data("Cover", as.Date("2024-12-31"), dims = "C5")$save("results.xlsx")
```
Scores [1,3,2,3,2,2]
- Ergonomics 1: load, clean, three writes and a save on an object.
- Findability 2: there is no template heading; it is in "Importing as workbook" and the `wb_clean_sheet` reference.
- Completeness 2: the manual says every chart and image is imported, but there is no keep/lose list, and nothing on whether C4 and C5 keep their formats.
- Clarity 2: the steps have to be assembled from separate pages.

## C13 Labels
```r
names(df) <- vapply(df, attr, "", "label"); df$sex <- factor(df$sex, 1:2, c("Male","Female"))
write_xlsx(df, "out.xlsx")   # and by hand in reverse for the reading half
```
Scores [1,1,0,0,0,0]
- Ergonomics 1: no label support, so it is hand-built from several base R calls.
- Failure 1: nothing is said about a code with no label.
- Findability, correctness, completeness, clarity 0: not covered.

---------------------------------------------------------------------------

```json
{"A": {"1": [3,1,3,3,2,3], "2": [3,1,3,3,3,3], "3": [3,1,3,3,3,3], "4": [1,2,3,3,1,3], "5": [1,0,3,3,2,3], "6": [1,0,2,3,2,3], "7": [0,1,2,3,1,3], "8": [1,1,3,3,3,3], "9": [3,1,2,2,2,3], "10": [1,3,2,3,1,3], "11": [1,1,2,2,3,3], "12": [0,1,0,0,0,0], "13": [1,1,0,0,0,0]},
 "B": {"1": [2,3,3,3,3,3], "2": [3,1,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,2,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,1,3,3,2,3], "9": [3,3,3,3,3,3], "10": [3,2,3,3,3,3], "11": [3,1,3,3,3,3], "12": [3,3,3,3,2,3], "13": [3,3,3,3,3,3]},
 "C": {"1": [3,1,3,3,1,3], "2": [3,1,2,3,2,2], "3": [2,1,2,3,3,2], "4": [1,1,1,2,1,1], "5": [1,1,2,3,1,2], "6": [2,1,2,3,2,2], "7": [2,0,2,3,1,2], "8": [1,1,1,0,0,0], "9": [1,0,2,3,2,2], "10": [1,1,2,3,2,2], "11": [1,1,2,2,3,2], "12": [1,3,2,3,2,2], "13": [1,1,0,0,0,0]}}
```
