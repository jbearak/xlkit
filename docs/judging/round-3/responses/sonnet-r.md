# Judge response: Library A (reader+writer), Library B, Library C

Score order: [ergonomics, failure, findability, correctness, completeness, clarity].
Only scores below 3 get a reason.

Evidence used:
- Library B's "Coming from" table says Library A reads Excel errors as NA "without a word", and that a text cell past row 1,000 is NA "with a warning".
- Where Library A's or Library C's own docs are silent, I score failure behavior 1.

---------------------------------------------------------------------------
## Library B
---------------------------------------------------------------------------

**1 Install.** `install.packages("remotes"); remotes::install_github("Library B")`
Scores: [2,3,3,3,3,3]
- Ergonomics 2: two calls, and Rust must be installed first (not on CRAN).

**2 Read a sheet.** `read_xlsx("report.xlsx")`
Scores: [3,3,3,3,3,3]. The type table gives integer, character, double, logical and Date.

**3 Choose what to read.**
```r
read_xlsx(path, sheet = "Sales 2024", range = "B5:F40")
xlsx_sheets(path)
```
Scores: [3,3,3,3,3,3]. The misspelled sheet error lists the sheets and suggests the close match.

**4 Header and names.**
```r
read_xlsx(path, sheet = "Headers", names = "snake")
read_xlsx(path, sheet = "Two-row header", header = 4:5)
```
Scores: [3,3,3,3,3,3]. The "New names" message says which header each name came from, and the `label` attribute keeps the header text.

**5 Column types.** `read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number"))`
Scores: [3,3,3,3,3,3]. The warning names C2003 and C2004; `xlsx_problems()` lists all of them.

**6 Dates and times.**
```r
read_xlsx("dates.xlsx")
read_xlsx("dates1904.xlsx")
read_xlsx("dates.xlsx", dates = FALSE)
```
Scores: [3,3,3,3,3,3]. The 1904 system is read from the workbook. The stray `unknown` cell is named in a message, and `types = c(day = "date")` fixes it.

**7 Missing values and errors.**
```r
df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-"))
xlsx_problems(df)
```
Scores: [3,3,3,3,3,3]. The warning names the error cells, and `xlsx_problems()` marks them "Excel error".

**8 Every sheet.** `read_sheets(path)`
Scores: [3,3,3,3,3,3]. An empty sheet reads as a 0×0 tibble, and the docs say so.

**9 Write a table.** `write_xlsx(df, "out.xlsx")`
Scores: [3,3,3,3,3,3]. An existing file stops with its sheet names and the hint `replace = TRUE`.

**10 Write several tables.**
```r
write_xlsx(list(A = a, B = b, C = c), "wb.xlsx")
write_xlsx(list(Results = list("Table 1" = t1, "Table 2" = t2)), "tables.xlsx", gap = 2)
```
Scores: [3,3,3,3,3,3]. `Q1/Q2` stops before writing and suggests `Q1-Q2`.

**11 Format the output.**
```r
write_xlsx(sales, "sales.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
Scores: [3,3,3,3,3,3]. A bold header, frozen header and fitted widths are defaults. An unknown column in `formats` errors with "Did you mean `share`?".

**12 Fill an existing workbook.**
```r
write_sheet(new_data, "results.xlsx", sheet = "Data")
write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
Scores: [2,3,3,3,3,3]
- Ergonomics 2: two calls, one for the sheet and one for the cells. Each call has direct arguments.

**13 Labels.**
```r
write_xlsx(df, "survey.xlsx", header = "labels")
read_xlsx("survey.xlsx", names = "snake")
```
Scores: [3,3,3,3,3,3]. A code without a value label gets a message naming its cells and is written as the code.

---------------------------------------------------------------------------
## Library A (reader + writer)
---------------------------------------------------------------------------

**1 Install.** `install.packages("Library A (reader)"); install.packages("Library A (writer)")`
Scores: [2,1,3,3,1,3]
- Ergonomics 2: reading and writing are two separate packages, so two calls.
- Failure 1: the docs only say "no external dependencies" and give no failure guidance.
- Completeness 1: no R versions, no explicit platform list, nothing on what to do if install fails.

**2 Read a sheet.** `read_excel("report.xlsx")`
Scores: [3,1,3,3,3,3]
- Failure 1: the docs do not say what a missing file does.

**3 Choose what to read.**
```r
read_excel(path, sheet = "Sales 2024", range = "B5:F40")
excel_sheets(path)
```
Scores: [3,1,3,3,3,3]
- Failure 1: the docs do not say what a misspelled sheet does.

**4 Header and names.**
```r
read_excel(path, sheet = "Headers", .name_repair = "universal")
cn <- names(read_excel(path, sheet = 2, n_max = 0))   # then build names by hand
read_excel(path, sheet = 2, skip = 2, col_names = cn)
```
Scores: [1,1,3,3,2,3]
- Ergonomics 1: a merged group name over three columns needs several reads and hand-built names.
- Failure 1: the docs do not say whether a message appears for duplicates or blanks.
- Completeness 2: no merged-header handling and no record of which header text a name came from.

**5 Column types.**
```r
nm <- names(read_excel(path, n_max = 0))
ct <- ifelse(nm == "zip", "text", ifelse(nm == "amount", "numeric", "guess"))
read_excel(path, col_types = ct)
```
Scores: [1,1,3,3,2,3]
- Ergonomics 1: `col_types` is positional, not named, and nothing lists the cells that failed.
- Failure 1: the docs say bad text becomes NA but do not say what message appears.
- Completeness 2: no way to list unconverted cells.

**6 Dates and times.**
```r
read_excel(path)                          # date-times arrive as POSIXct
read_excel(path, col_types = "numeric")   # stored numbers
```
Scores: [2,1,2,3,2,2]
- Ergonomics 2: there is no Date type, so a Date column needs a conversion step.
- Failure 1: text in a date column becomes NA, and no message is documented.
- Findability 2: the information sits in a feature bullet and the types article, with no heading for dates.
- Completeness 2: time-of-day cells and a Date type are not covered.
- Clarity 2: the date examples are scattered.

**7 Missing values and errors.** `read_excel(path, na = c("NA", ".", "-"))`
Scores: [1,0,2,2,1,3]
- Ergonomics 1: no documented way to tell Excel errors from blanks.
- Failure 0: per Library B's docs, errors become NA without a word.
- Findability 2: `na` is easy to find, errors are not mentioned.
- Correctness 2: the `na` part is right, the error part is not covered.
- Completeness 1: only `na`.

**8 Every sheet.** `path |> excel_sheets() |> set_names() |> map(read_excel, path = path)`
Scores: [1,1,3,3,2,3]
- Ergonomics 1: several calls, and one `read_excel` call per sheet.
- Failure 1: the docs do not say what an empty sheet does.
- Completeness 2: no empty-sheet case.

**9 Write a table.** `write_xlsx(df, "out.xlsx")`
Scores: [3,1,3,3,2,3]
- Failure 1: the docs do not say what happens when the file exists.
- Completeness 2: the type table is good (factor becomes text, NA becomes a blank cell), but existing-file behavior is missing.

**10 Write several tables.**
```r
write_xlsx(list(A = a, B = b, C = c), "wb.xlsx")
# two titled tables on one sheet: no start-row option; only a hand-built
# data frame with xl_cell_general columns
```
Scores: [1,2,3,3,1,3]
- Ergonomics 1: the second part has no offset or start-row argument, only a contrived workaround.
- Failure 2: the sheet name is repaired with a warning that names the original and the replacement.
- Completeness 1: two tables on one sheet are not covered.

**11 Format the output.**
```r
sheet <- xl_sheet(df,
  cols = list(xl_col_spec("share",  format = xl_num_format("0.0%")),
              xl_col_spec("amount", format = xl_num_format("#,##0"))),
  freeze = "A2", auto_colwidth = TRUE, autofilter = TRUE)
write_xlsx(list(Sheet1 = sheet), "f.xlsx")
```
Scores: [1,1,2,3,3,3]
- Ergonomics 1: the user builds objects, then writes.
- Failure 1: the docs do not say what an unknown column name does.
- Findability 2: the pieces are spread over the formatting and worksheets vignettes.

**12 Fill an existing workbook.** Not possible. `write_xlsx` only creates new files, and the reader cannot write.
Scores: [0,1,0,0,0,0]
- Failure 1: the docs do not say what happens.

**13 Labels.** No Stata label support. `names(df) <- ...` then `write_xlsx`, and a manual first-row read.
Scores: [1,1,0,0,0,0]
- Failure 1: the docs do not say what happens.
- Documentation 0: the task is not covered.

---------------------------------------------------------------------------
## Library C
---------------------------------------------------------------------------

**1 Install.** `install.packages("Library C")`
Scores: [3,1,3,3,1,3]
- Failure 1: no build-failure guidance.
- Completeness 1: no platforms or R versions. The zip requirement appears only under `wb_save`.

**2 Read a sheet.** `read_xlsx("report.xlsx")`
Scores: [3,1,3,3,2,2]
- Failure 1: the docs do not say what a missing file does.
- Completeness 2: there is no clear per-column type table. Dates become Date/POSIXct, times become hms only if the package is loaded, and integers are not discussed.
- Clarity 2: the man page is dense and the types are described by internal codes.

**3 Choose what to read.**
```r
read_xlsx(path, sheet = "Sales 2024", dims = "B5:F40")
wb_get_sheet_names(wb_load(path))
```
Scores: [2,1,2,3,2,3]
- Ergonomics 2: listing sheet names takes two calls.
- Failure 1: the docs do not say what a misspelled sheet does.
- Findability 2: the answer sits in a long vignette.
- Completeness 2: no way to list sheets straight from a path.

**4 Header and names.**
```r
wb_to_df(path, sheet = "Headers", check_names = TRUE)
wb_to_df(path, sheet = 2, dims = "B2:D2,B4:D+")   # names from one row; groups need fill_merged_cells + hand-merging
```
Scores: [1,1,1,2,1,1]
- Ergonomics 1: combining a group row and a name row has no direct option.
- Failure 1: the README shows a blank header named `<NA>` with no message, and duplicates are not discussed.
- Findability 1: only function-reference entries (`check_names`, `fill_merged_cells`, the `dims` example).
- Correctness 2: the task is mostly uncovered.
- Completeness 1: no record of which header text a name came from.
- Clarity 1: the `dims = "B2:C2,B4:C+"` example is cryptic.

**5 Column types.**
```r
df <- wb_to_df(path, types = c(zip = 0, amount = 1))
wb_to_df(path, types = c(zip = 0, amount = 1), keep_attributes = TRUE)   # type table "tt"
```
Scores: [1,1,2,3,1,2]
- Ergonomics 1: numeric type codes are indirect, and finding unconverted cells needs a second, obscure call.
- Failure 1: the docs do not say what message appears.
- Findability 2: the answer sits under the `types` heading of a long vignette.
- Completeness 1: no list of failed cells and no leading-zero guidance.
- Clarity 2: the codes are explained only by one example.

**6 Dates and times.**
```r
library(hms); wb_to_df(path)
wb_to_df(path, detect_dates = FALSE)
```
Scores: [2,1,2,3,2,3]
- Ergonomics 2: times come back as strings unless `hms` is loaded.
- Failure 1: the docs do not say what a text cell in a date column does.
- Findability 2: it sits under the `detect_dates` heading.
- Completeness 2: the 1904 system is not covered.

**7 Missing values and errors.**
```r
wb_to_df(path, na = c("NA", ".", "-", "#N/A", "#DIV/0!"))
wb_to_df(path)   # second read: error codes appear as text
```
Scores: [2,1,2,3,2,2]
- Ergonomics 2: telling errors from blanks takes a second read.
- Failure 1: errors come back as text codes, so a numeric column becomes character, with no message documented.
- Findability 2: under the `na` heading.
- Completeness 2: no explicit way to tell errors from blanks.
- Clarity 2: the error handling appears only as a README side note.

**8 Every sheet.**
```r
wb <- wb_load(path)
sapply(wb_get_sheet_names(wb), \(s) wb_to_df(wb, sheet = s), simplify = FALSE)
```
Scores: [1,3,1,2,1,1]
- Ergonomics 1: a manual loop, with one call per sheet.
- Findability 1: only the pieces exist, with no pointer from the guide.
- Correctness 2: nothing wrong is stated, but the task is not covered directly.
- Completeness 1: no guide for the task.
- Clarity 1: no example.
- Failure 3: the update vignette says an empty selection returns a data frame.

**9 Write a table.** `write_xlsx(df, file = "out.xlsx")`
Scores: [1,0,3,2,2,2]
- Ergonomics 1: an existing file is silently replaced and `NA` becomes `#N/A` by default.
- Failure 0: the existing file is replaced with no message. `overwrite = FALSE` is optional.
- Correctness 2: the `write_xlsx` examples use `col_widths`, but the listed argument is `widths`.
- Completeness 2: the Date/POSIXt styling and the `#N/A` default are stated, but factor and logical columns are not.
- Clarity 2: the page is mostly pass-through arguments.

**10 Write several tables.**
```r
write_xlsx(list(A = a, B = b, C = c), "wb.xlsx")
wb <- wb_workbook()$add_worksheet("Results")$add_data(x = "Table 1", start_row = 1)$
  add_data(x = t1, start_row = 2)$add_data(x = "Table 2", start_row = 2 + nrow(t1) + 3)$
  add_data(x = t2, start_row = 3 + nrow(t1) + 3)
wb_save(wb, "tables.xlsx")
```
Scores: [1,2,2,3,2,2]
- Ergonomics 1: several calls and manual row arithmetic for the one-sheet part.
- Failure 2: the docs say sheet names are validated, with no message text.
- Findability 2: split between the `write_xlsx` page and `wb_add_data`.
- Completeness 2: `start_row` exists, but titled stacking is not covered.
- Clarity 2.

**11 Format the output.**
```r
wb <- wb_workbook()$add_worksheet()$add_data(x = df, with_filter = TRUE)$
  add_font(dims = wb_dims(x = df, select = "col_names"), bold = TRUE)$
  add_numfmt(dims = wb_dims(x = df, cols = "share"),  numfmt = "0.0%")$
  add_numfmt(dims = wb_dims(x = df, cols = "amount"), numfmt = "#,##0")$
  set_col_widths(cols = seq_along(df), widths = "auto")$freeze_pane(first_row = TRUE)
wb_save(wb, "f.xlsx")
```
Scores: [1,1,2,2,3,2]
- Ergonomics 1: a workbook object, many calls, and a save.
- Failure 1: the docs do not say what an unknown column name in `wb_dims` does.
- Findability 2: spread over the style vignette and separate man pages.
- Correctness 2: small example slips, for example `wb_dims` uses `fill =` where the argument is `color`.
- Clarity 2.

**12 Fill an existing workbook.**
```r
wb <- wb_load("results.xlsx")
wb <- wb_clean_sheet(wb, "Data") |> wb_add_data("Data", new_data) |>
  wb_add_data("Cover", 1250, dims = "C4") |> wb_add_data("Cover", as.Date("2024-12-31"), dims = "C5")
wb_save(wb, "results.xlsx")
```
Scores: [1,3,2,3,2,2]
- Ergonomics 1: load, clean, several writes and a save.
- Findability 2: no heading names template filling.
- Completeness 2: charts and sheets are said to be kept, but losses are not listed.
- Clarity 2.
- Failure 3: the docs say `wb_load` keeps charts and the sheet cleaner leaves them alone.

**13 Labels.** No Stata label support; the labels have to be applied with base R before writing, and a manual first-row read gets them back.
Scores: [1,1,0,0,0,0]
- Failure 1: the docs do not say what happens.
- Documentation 0: the task is not covered.

---------------------------------------------------------------------------

```json
{"B": {"1": [2,3,3,3,3,3], "2": [3,3,3,3,3,3], "3": [3,3,3,3,3,3], "4": [3,3,3,3,3,3], "5": [3,3,3,3,3,3], "6": [3,3,3,3,3,3], "7": [3,3,3,3,3,3], "8": [3,3,3,3,3,3], "9": [3,3,3,3,3,3], "10": [3,3,3,3,3,3], "11": [3,3,3,3,3,3], "12": [2,3,3,3,3,3], "13": [3,3,3,3,3,3]},
 "A": {"1": [2,1,3,3,1,3], "2": [3,1,3,3,3,3], "3": [3,1,3,3,3,3], "4": [1,1,3,3,2,3], "5": [1,1,3,3,2,3], "6": [2,1,2,3,2,2], "7": [1,0,2,2,1,3], "8": [1,1,3,3,2,3], "9": [3,1,3,3,2,3], "10": [1,2,3,3,1,3], "11": [1,1,2,3,3,3], "12": [0,1,0,0,0,0], "13": [1,1,0,0,0,0]},
 "C": {"1": [3,1,3,3,1,3], "2": [3,1,3,3,2,2], "3": [2,1,2,3,2,3], "4": [1,1,1,2,1,1], "5": [1,1,2,3,1,2], "6": [2,1,2,3,2,3], "7": [2,1,2,3,2,2], "8": [1,3,1,2,1,1], "9": [1,0,3,2,2,2], "10": [1,2,2,3,2,2], "11": [1,1,2,2,3,2], "12": [1,3,2,3,2,2], "13": [1,1,0,0,0,0]}}
```
