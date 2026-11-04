# Judging: Libraries A, B, C on 13 tasks

Scores are [ergonomics, failure, findability, correctness, completeness, clarity].
Reasons are given only for scores below 3.

Notes on scope:
- Library A is the reader plus writer pair (read_excel/excel_sheets and write_xlsx with the xl_* helpers).
- Library B is the single workbook package (wb_*, read_xlsx, write_xlsx).
- Library C is the third package.
- The file has no Stata material, so there are no Stata scores.
- A's stated scope is tasks 1-11 and tasks 12-13 are scored anyway.

---------------------------------------------------------------------
## Library A
---------------------------------------------------------------------

### A1 Install
Code: `install.packages("Library A (reader)"); install.packages("Library A (writer)")`
Scores: [2,1,3,3,1,3]
- Ergonomics 2: reading and writing are two separate packages, so two calls.
- Failure 1: the docs say there are no external dependencies. They never say what to do if the build fails.
- Completeness 1: only the command is given. There are no supported platforms or R versions, no system-requirements section and no failure advice.

### A2 Read a sheet
Code: `read_excel("report.xlsx")`
Scores: [3,1,3,3,3,3]
- Failure 1: the docs say nothing about a missing file such as `reprot.xlsx`.

### A3 Choose what to read
Code: `read_excel(p, sheet = "Sales 2024", range = "B5:F40"); excel_sheets(p)`
Scores: [3,1,3,3,3,3]
- Failure 1: the docs do not say what happens for a misspelled sheet name, and do not mention listing the names in an error.

### A4 Header and names
Code:
```r
read_excel(p, .name_repair = "universal")      # or the default "unique"
nm <- names(read_excel(p, sheet = 2, n_max = 0))   # then read_excel(..., skip = 2, col_names = cnames)
```
Scores: [1,2,3,3,2,3]
- Ergonomics 1: the two-row header takes three reads (names, data, metadata). The merged group name is never combined with the column names, so the user pastes them together by hand.
- Failure 2: the docs say names are made unique and non-empty, which is the right result. They do not say which header text became which name, and show no message.
- Completeness 2: the article's two-row case is a description row, not a merged group header. Nothing tells the user which header text each name came from.

### A5 Column types
Code:
```r
read_excel(p, col_types = c("text", "numeric"))   # one entry per column, in order
```
Scores: [1,1,3,3,2,3]
- Ergonomics 1: `col_types` must list every column, so the user peeks at the names first. There is no way to list the cells that failed to convert, so the user compares a text read with a numeric read by hand.
- Failure 1: the docs say non-numeric text "imports as NA". They do not say whether any message names the cells.
- Completeness 2: leading zeros lost in numeric `zip` cells are not discussed, and failed cells cannot be listed.

### A6 Dates and times
Code: `read_excel(p)` then `as.Date()` on the date column. For the numbers: `read_excel(p, col_types = "numeric")`.
Scores: [1,1,2,3,2,2]
- Ergonomics 1: dates and times of day both come back as POSIXct. There is no Date or time type, so the user converts afterwards.
- Failure 1: the docs do not say what happens to a text cell like `unknown` in a date column.
- Findability 2: there is no dates heading. The answer is in a README feature bullet and the types article table.
- Completeness 2: times of day are not covered. 1904 support is a one-line mention.
- Clarity 2: calling the POSIXct request type "date" needs a reread.

### A7 Missing values and errors
Code: `read_excel(p, na = c("NA", ".", "-"))`
Scores: [0,1,2,3,1,2]
- Ergonomics 0: Excel errors are not mentioned anywhere, and there is no way to tell them from blanks.
- Failure 1: the docs do not say what happens to `#N/A` or `#DIV/0!` in a numeric column.
- Findability 2: `na` is easy to find, but errors are not covered.
- Completeness 1: only the `na` argument is covered.
- Clarity 2: what is written is clear, but the error half of the scenario is absent.

### A8 Every sheet
Code:
```r
path |> excel_sheets() |> set_names() |> map(read_excel, path = path)
```
Scores: [1,1,3,2,2,3]
- Ergonomics 1: the user chains `excel_sheets`, `set_names` and `map`, or the base `lapply` plus `names<-`. That is several calls.
- Failure 1: the docs do not say what happens with an empty sheet.
- Correctness 2: the text says `range = "A5:E15"` while the code uses `A5:F15`.
- Completeness 2: named list, binding sheets and CSV caching are covered. Empty sheets are not.

### A9 Write a table
Code: `write_xlsx(df, "out.xlsx")`
Scores: [1,1,3,3,2,3]
- Ergonomics 1: the call has no overwrite guard, so an existing file is replaced by default.
- Failure 1: the docs never say what happens when `out.xlsx` already exists.
- Completeness 2: the type table, NA handling and time zones are covered. The existing-file case is not.

### A10 Write several tables
Code:
```r
write_xlsx(list(a = x, b = y, c = z), "out.xlsx")
# two titled tables on one sheet: build one frame with xl_cell_general mixed columns by hand
```
Scores: [1,3,2,2,1,2]
- Ergonomics 1: part 1 is one call. Part 2 has no placement or title support. It needs a hand-built mixed-type column object.
- Findability 2: part 1 is on the front page. Part 2 is not found.
- Correctness 2: the parts that are stated are right, but part 2 is not covered.
- Completeness 1: only the multi-sheet path is covered.
- Clarity 2: part 2 gives the reader nothing to follow.
- Failure 3: the docs say sheet names are repaired and a warning names the original and the replacement.

### A11 Format the output
Code:
```r
write_xlsx(list(Sales = xl_sheet(df,
  cols = list(xl_col_spec("share", format = xl_num_format("0.0%")),
              xl_col_spec("amount", format = xl_num_format("#,##0"))),
  freeze = "A2", auto_colwidth = TRUE, autofilter = TRUE)), "out.xlsx")
```
Scores: [1,1,2,2,3,3]
- Ergonomics 1: this takes six or more calls and several objects to build.
- Failure 1: the docs do not say what happens when `xl_col_spec` names a column that is not in the table.
- Findability 2: the answer is spread over the formatting and worksheets vignettes and the `xl_sheet` reference.
- Correctness 2: the number-format example string in the `xl_format_groups` reference is cut off (`"0`). This is exactly the percent case the task needs.

### A12 Fill an existing workbook
Code: not possible. The writer only creates new files and the reader only reads.
Scores: [0,1,0,0,0,0]
- Ergonomics 0: nothing edits a workbook.
- Failure 1: the docs say nothing about what happens to a template's chart.
- Findability 0, correctness 0, completeness 0, clarity 0: not covered.

### A13 Labels
Code: by hand: rename the header from `attr(x, "label")`, convert `sex` to text with another package, then `write_xlsx()`. To read, use `.name_repair`, then set the label attributes.
Scores: [1,1,0,0,0,0]
- Ergonomics 1: it is several manual steps with other packages.
- Failure 1: the docs say nothing about a code with no value label.
- Findability 0, correctness 0, completeness 0, clarity 0: labels are never mentioned.

---------------------------------------------------------------------
## Library B
---------------------------------------------------------------------

### B1 Install
Code: `install.packages('Library B')`
Scores: [3,1,3,3,2,3]
- Failure 1: the docs do not cover a build or install failure.
- Completeness 2: there are no platforms or R versions. The one system requirement, a zip utility, appears only in the `wb_save` reference, with its fixes (Rtools, `R_ZIPCMD`).

### B2 Read a sheet
Code: `read_xlsx("report.xlsx")`
Scores: [3,1,3,3,2,2]
- Failure 1: the docs say nothing about a missing file.
- Completeness 2: there is no table of which column gets which type. Whole numbers are not stated to be numeric.
- Clarity 2: the output is shown and the data types are named, but the guessing is only loosely explained. The rows are named by sheet row, which is unexplained.

### B3 Choose what to read
Code:
```r
read_xlsx(p, sheet = "Sales 2024", dims = "B5:F40")
wb_get_sheet_names(wb_load(p))
```
Scores: [2,1,2,3,3,2]
- Ergonomics 2: listing the sheet names takes two calls, a load and then the names.
- Failure 1: the docs do not say what a misspelled sheet name does.
- Findability 2: sheet names are in a man page and mentioned in passing in the manual.
- Clarity 2: the `dims` wildcard syntax needs rereading.

### B4 Header and names
Code:
```r
read_xlsx(p, check_names = TRUE)
read_xlsx(p, sheet = 2, dims = "B2:E3", col_names = FALSE, fill_merged_cells = TRUE)  # paste the two rows, then read the body
```
Scores: [1,1,1,2,1,1]
- Ergonomics 1: the two-row header needs several reads and a manual paste.
- Failure 1: the docs do not say how blank or repeated headers are handled.
- Findability 1: `check_names` is only in the function reference.
- Correctness 2: `check_names` is said to use `make.names()` with no word on uniqueness.
- Completeness 1: there is nothing on duplicate names or on where each name came from.
- Clarity 1: the reference text is terse.

### B5 Column types
Code:
```r
wb_to_df(p, types = c(zip = 0, amount = 1), keep_attributes = TRUE)   # then inspect attr(, "tt")
```
Scores: [1,1,2,3,2,2]
- Ergonomics 1: types use numeric codes. Finding the cells that failed means keeping attributes and reading the type table.
- Failure 1: the docs do not say what happens to `n/a` or `12,5`. They mention only that an import might produce warnings.
- Findability 2: `types` has a vignette heading, but nothing on the front page points to it.
- Completeness 2: leading zeros and the failed cells are not covered.
- Clarity 2: the numeric codes need a lookup.

### B6 Dates and times
Code: `read_xlsx(p)`, then `read_xlsx(p, detect_dates = FALSE)`
Scores: [2,1,2,3,2,2]
- Ergonomics 2: times of day are strings unless `hms` is loaded.
- Failure 1: the docs do not say what happens to a text cell like `unknown` in a date column.
- Findability 2: `detect_dates` has its own vignette heading, but it is not on the front page.
- Completeness 2: the 1904 date system is not mentioned.
- Clarity 2: the explanation is brief.

### B7 Missing values and errors
Code:
```r
read_xlsx(p, na = c("NA", ".", "-"))
```
Scores: [2,1,2,3,2,2]
- Ergonomics 2: errors other than `#N/A` come back as text. Telling errors from blanks needs a second read.
- Failure 1: the docs say error codes are returned as text, so a numeric column becomes character with no message.
- Findability 2: `na` and the error-code remark are in different places.
- Completeness 2: the named-list form of `na` is covered. Telling errors from blanks is only implied.
- Clarity 2: the `na` default differs between the functions.

### B8 Every sheet
Code:
```r
wb <- wb_load(p)
lapply(setNames(nm = wb_get_sheet_names(wb)), \(s) wb_to_df(wb, sheet = s))
```
Scores: [1,2,1,2,1,1]
- Ergonomics 1: this is a hand-written loop.
- Failure 2: one line says a data frame is returned even if empty. It is vague about an empty sheet.
- Findability 1: no all-sheets recipe exists.
- Correctness 2: nothing is wrong, but the task is not covered.
- Completeness 1: only the pieces are documented.
- Clarity 1: the user must assemble the recipe.

### B9 Write a table
Code: `write_xlsx(df, "out.xlsx")`
Scores: [1,1,3,2,2,2]
- Ergonomics 1: the default replaces an existing file, and `NA` is written as an `#N/A` error unless `na` is set.
- Failure 1: the docs state that replacement is the default and `overwrite = FALSE` is optional. There is no message by default.
- Correctness 2: the reference examples use `col_widths` while the documented argument is `widths`, and the manual says explanations "will follow".
- Completeness 2: the Date and POSIXt styling and the NA behaviour are covered. Logical, integer and factor columns are not.
- Clarity 2: the long list of arguments forwarded from other functions is hard to follow.

### B10 Write several tables
Code:
```r
write_xlsx(list(a = x, b = y, c = z), "out.xlsx")
wb_workbook()$add_worksheet("S")$add_data(x = "T1", dims = "A1")$add_data(x = t1, dims = "A2")$
  add_data(x = "T2", dims = "A8")$add_data(x = t2, dims = "A9")$save("out.xlsx")
```
Scores: [1,1,2,3,2,2]
- Ergonomics 1: part 2 is a chain of about six calls.
- Failure 1: the sheet name is "validated against illegal characters", but the message and the behaviour are not shown.
- Findability 2: the answer is in the function examples.
- Completeness 2: the user has to assemble part 2 from `start_row` and `dims`.
- Clarity 2: the chain-versus-pipe style takes time to learn.

### B11 Format the output
Code:
```r
wb_workbook()$add_worksheet()$add_data(x = df, with_filter = TRUE)$
  add_font(dims = wb_dims(x = df, select = "col_names"), bold = TRUE)$
  add_numfmt(dims = wb_dims(x = df, cols = "share"), numfmt = "0.0%")$
  add_numfmt(dims = wb_dims(x = df, cols = "amount"), numfmt = "#,##0")$
  set_col_widths(cols = 1:ncol(df), widths = "auto")$freeze_pane(first_row = TRUE)$save("out.xlsx")
```
Scores: [1,1,2,2,3,2]
- Ergonomics 1: this is about eight calls.
- Failure 1: the docs do not say what a misnamed column in `wb_dims` does.
- Findability 2: the pieces are spread over many man pages.
- Correctness 2: some examples use the wrong argument names, such as `fill =` in the `wb_dims` example and `row =` in the filter example.
- Clarity 2: `dims` and the many layers take effort to learn.

### B12 Fill an existing workbook
Code:
```r
wb_load(p)$clean_sheet("Data")$add_data("Data", new)$add_data("Cover", 1250, dims = "C4")$
  add_data("Cover", as.Date("2024-12-31"), dims = "C5")$save(p)
```
Scores: [1,2,2,3,2,2]
- Ergonomics 1: this is about six calls.
- Failure 2: loading is said to keep every chart and image, and `wb_clean_sheet` leaves charts alone. Nothing says the chart's range still matches the new data.
- Findability 2: no section covers this task. It is spread over the load, clean and save pages.
- Completeness 2: what is lost on a round trip is not listed. Whether writing a Date over a template cell keeps its format is not said.
- Clarity 2: the user pieces it together.

### B13 Labels
Code: by hand: rename the header from the label attributes, convert `sex` to text, then `write_xlsx()`. To read, use `check_names` and set the label attributes.
Scores: [1,1,0,0,0,0]
- Ergonomics 1: this is manual work with other packages.
- Failure 1: the docs say nothing about a code with no value label.
- Findability 0, correctness 0, completeness 0, clarity 0: labels are not mentioned.

---------------------------------------------------------------------
## Library C
---------------------------------------------------------------------

### C1 Install
Code: `install.packages("remotes"); remotes::install_github("Library C")`
Scores: [2,3,3,3,3,3]
- Ergonomics 2: the user installs `remotes` first, and needs a Rust toolchain installed beforehand.

### C2 Read a sheet
Code: `read_xlsx("report.xlsx")`
Scores: [3,3,3,3,3,3]

### C3 Choose what to read
Code: `read_xlsx(p, sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets(p)`
Scores: [3,3,3,3,3,3]

### C4 Header and names
Code: `read_xlsx(p, sheet = "Headers")`; `read_xlsx(p, sheet = "Two-row header", header = 4:5)`
Scores: [3,3,3,3,3,3]

### C5 Column types
Code: `df <- read_xlsx(p, sheet = "Types", types = c(zip = "text", amount = "number"))`. The warning names the cells, and `xlsx_problems(df)` lists them all.
Scores: [3,3,3,3,3,3]

### C6 Dates and times
Code: `read_xlsx(p)` then `read_xlsx(p, dates = FALSE)`. The 1904 workbook is read the same way.
Scores: [3,3,3,3,3,3]

### C7 Missing values and errors
Code: `df <- read_xlsx(p, sheet = "Missing", na = c("NA", ".", "-"))`. The warning names the error cells, and `xlsx_problems(df)` lists them.
Scores: [3,3,3,3,3,3]

### C8 Every sheet
Code: `read_sheets(p)`
Scores: [3,3,3,3,3,3]

### C9 Write a table
Code: `write_xlsx(df, "out.xlsx")`
Scores: [3,3,3,3,3,3]

### C10 Write several tables
Code:
```r
write_xlsx(list(A = a, B = b, C = c), "out.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "out.xlsx", gap = 2)
```
Scores: [3,3,3,3,3,3]

### C11 Format the output
Code: `write_xlsx(sales, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)`. The bold header, the frozen header and the column widths are defaults.
Scores: [3,3,3,3,3,3]

### C12 Fill an existing workbook
Code:
```r
write_sheet(new_data, path, sheet = "Data")
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [3,3,3,3,3,3]

### C13 Labels
Code:
```r
write_xlsx(df, "survey.xlsx", header = "labels")
df <- read_xlsx("survey.xlsx", names = "stata")
```
Scores: [3,3,3,3,3,3]

---------------------------------------------------------------------

```json
{"A": {"1": [2,1,3,3,1,3], "2": [3,1,3,3,3,3], "3": [3,1,3,3,3,3], "4": [1,2,3,3,2,3], "5": [1,1,3,3,2,3], "6": [1,1,2,3,2,2], "7": [0,1,2,3,1,2], "8": [1,1,3,2,2,3], "9": [1,1,3,3,2,3], "10": [1,3,2,2,1,2], "11": [1,1,2,2,3,3], "12": [0,1,0,0,0,0], "13": [1,1,0,0,0,0]},
 "B": {"1": [3,1,3,3,2,3], "2": [3,1,3,3,2,2], "3": [2,1,2,3,3,2], "4": [1,1,1,2,1,1], "5": [1,1,2,3,2,2], "6": [2,1,2,3,2,2], "7": [2,1,2,3,2,2], "8": [1,2,1,2,1,1], "9": [1,1,3,2,2,2], "10": [1,1,2,3,2,2], "11": [1,1,2,2,3,2], "12": [1,2,2,3,2,2], "13": [1,1,0,0,0,0]},
 "C": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [3,3,3,3,3,3], "13": [3,3,3,3,3,3]}}
```
