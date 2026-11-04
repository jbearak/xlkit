# xlkit documentation test: 13 scenarios

Method: only README.md, docs/r.md, docs/stata.md and man/*.txt were read. Inputs were made with openpyxl (`python3 -I`) or haven. Code was run with `R_LIBS=<fresh/lib> Rscript`. Scripts, inputs and outputs are in `fresh/work/` (`make_inputs.py`, `s123.R`, `s48.R`, `s8.R`, `s9.R`, `s1011.R`, `s11.R`, `s12.R`, `s13.R`, `s13b.R`, `s5b.R`, `inspect.py`).

xlkit 0.1.0.9000. Every Rscript run prints `OMP: Warning #179: Function Can't set size of /tmp file failed`. That comes from the sandbox, not xlkit, and I filtered it from the output below.

---

## 1 Install
```r
library(xlkit); packageVersion("xlkit"); xlsx_sheets("report.xlsx")
#> [1] ‘0.1.0.9000’
#> [1] "Scores"
```
**Succeeded: yes.** `library(xlkit)` loads from the given library. I could not install from GitHub here, so I only judged the text.

On a fresh machine the install section would tell me:
- the two `remotes` lines;
- that R 4.2 or later and a Rust toolchain are needed;
- the Rtools and `rustup target add` steps on Windows;
- what to do when the build stops with "building needs cargo".

Doc problems:
- `dtaparser`, which scenario 13 needs, has no install instruction anywhere.
  - docs/r.md says "It reads and writes dtaparser's labelled columns without depending on dtaparser".
  - README links only "datakit" (the repo `dta-parser`).
  - A new user does not learn how to get `dtaparser::read_dta()` or `save_dta()`.
- Nothing else was wrong that I could see. I did not test the Rust build steps or the "R 4.2 or later" claim.

## 2 report.xlsx types
```r
scores <- read_xlsx("report.xlsx"); str(scores)
#> id int | name chr | score num | passed logi | joined Date
```
Values: ids 1:4, scores 91.5, 78, 85.25, 60.5, passed TRUE/FALSE/TRUE/FALSE, joined 2024-01-15 and so on. Types are exactly as the docs table says.

**Succeeded: yes.** The returned tibble also carries an `xlkit_problems` attribute (0 rows). `str()` shows it. This is not mentioned in the guide's "Read a sheet" section, though `xlsx_problems()` is.

## 3 "Sales 2024" in B5:F40, plus sheet names
```r
xlsx_sheets("sales.xlsx")   # "Summary" "Sales 2023" "Sales 2024" "Regions" "Notes"
s <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")   # 35 x 5: chr int dbl dbl Date
identical(s, read_xlsx("sales.xlsx", sheet = 3, header = 5))           # TRUE
read_xlsx("sales.xlsx", sheet = "Sales 2024")   # no range: warns "Row 1 has text only in B1 ..." and uses the title as header
read_xlsx("sales.xlsx", sheet = "Sales 2042")
#> ! sales.xlsx has no sheet "Sales 2042".
#> ℹ Did you mean "Sales 2024"?
#> ℹ Its sheets are "Summary", "Sales 2023", "Sales 2024", "Regions" and "Notes".
read_xlsx("sales.xslx")
#> ! sales.xslx does not exist.  ℹ Did you mean sales.xlsx?
```
**Succeeded: yes.** Position 3 and `header = 5` give the same result as the range. The messages match the docs.

Doc problems: none found. The docs examples match the real output exactly.

## 4 Header repair and two-row headers
```r
h <- read_xlsx("messy.xlsx", sheet = "Headers")
#> New names:  • C1 "Total" is `Total_C` (it repeats B1)  • D1 (blank) is `D`
names(h)  # "Region" "Total" "Total_C" "D" "Share %"
attr(h$Total_C, "label")   # "Total"    (all other columns: NULL)
read_xlsx(..., names = "snake")  # region total total_c d share_percent; labels "Region","Total","Total","Share %", d = NULL
read_xlsx(..., names = "stata")  # Region Total Total_C D Share
read_xlsx(..., names = c("stata","lower"))  # region total total_c d share
t1 <- read_xlsx("messy.xlsx", sheet = "Two-row", header = 1:2)   # A1 blank, B1:D1 merged "Income", row 2: Region 2020 2021 2022
names(t1)  # "Region" "Income 2020" "Income 2021" "Income 2022"  (no labels, since names equal the header text)
read_xlsx(..., header = 1:2, names = "snake")  # region income_2020 ...; labels "Region", "Income 2020", ...
read_xlsx(..., sheet = "Two-row")  # no header arg: warns "Row 1 has text only in B1 ("Income")", suggests header = 2
```
**Succeeded: yes.** Names match the docs tables, and the merged group name is spread across its three columns. The label attribute tells where each name came from when `names` differs from the text.

Doc problems:
- docs/r.md: "When a name differs from its header text, the text is kept as the column's variable label, so you can always see where a name came from". With the default `names = "unique"`, a blank-header column (`D`) has no label and `Total` does not either, so "always see where a name came from" is not true for blanks. For a joined two-row header the name is the text, so there is no label either. The docs never say that the label is the only record of the original and absent when names equal the text.
- The `Two-row header` description assumes the header is in rows 4:5. The docs never say what a blank cell in the first of two header rows does (my A1 was blank and `Region` came out clean, which is good but undocumented).
- With `names = "stata"`, two headers that agree in their first 32 characters are made unique silently (`..._ali` and `..._a_B`). The docs say "only these repairs [blank or repeated] get [a message]", so a truncation collision having no message is consistent, but it can surprise.
- `header = 50` (past the data) returns a 0 x 0 tibble with no error or message. docs/r.md says only that a *range* outside the sheet stops with an error. A `header` outside the sheet is not described.

## 5 zip as text, amount as numbers
```r
read_xlsx("messy.xlsx", sheet = "Types")   # both columns character; message:
#> `amount` is text because 2 of its 2,003 values are not numbers:
#> B2002 ("n/a") and B2003 ("12,5").
#> ℹ To read it as numbers, use `types = c(amount = "number")`; those cells become NA.
ty <- read_xlsx("messy.xlsx", sheet = "Types", types = c(zip = "text", amount = "number"))
#> Warning: 2 cells in `amount` could not be read as numbers and are NA: B2002 ("n/a") and B2003 ("12,5").
#> ℹ See them all with `xlsx_problems(df)`.
xlsx_problems(ty)
#>   cell  column   row value problem
#> 1 B2002 amount  2002 n/a   not a number
#> 2 B2003 amount  2003 12,5  not a number
```
- `zip` is character. The numeric cells formatted `00000` come out as `"02139"`, so the text and number mixes agree: 1,336 `"02139"` and 667 `"10001"`.
- `amount` is double, with 2 NA.
- `types = c(zipp = "text")` gives:
  ```
  ! `types` names `zipp`, which is not a column.
  ℹ Did you mean `zip`?  ℹ The columns are `zip` and `amount`.
  ```
- `types = c(amount = "integer")` gives a warning that 2,002 cells are not whole numbers, with the first five listed plus "and 1,997 more".
- Numbers typed with no number format come out as `"2139"` and `"501"`. The docs' `formatC(as.integer(df$zip), width = 5, flag = "0")` fixes that: `"02139" "02139" "10001" "10001" "00501"`. I tested this with `zip_plain.xlsx`.

**Succeeded: yes.**

Doc problems:
- docs/r.md uses `xlsx_problems(df)` in the warning text and in the examples, but the user's tibble may not be named `df`. This is trivial.
- The docs describe the `formatC` workaround only for the case where there is no leading zero anywhere; they do not say that mixed text/number columns get partially padded (text keeps `"02139"`, un-formatted numbers lose it). My test shows both cases, so a reader must combine the two paragraphs themselves.

## 6 Dates, date-times, times, 1904, stored numbers
```r
d <- read_xlsx("dates.xlsx")    # day Date | stamp POSIXct (tzone "UTC") | clock hms
all.equal(d, read_xlsx("dates1904.xlsx"), check.attributes = FALSE)   # TRUE
read_xlsx("dates.xlsx", types = c(day = "number", stamp = "number", clock = "number"))
#>     day  stamp clock
#> 1 45306 45306. 0.354 ; 45351 / 45352. / 0.712 ; 45657 / 45658. / 1.000   (stamp 45306.3541667 ...)
read_xlsx("dates1904.xlsx", types = ...)   # day 43844, 43889, 44195: stored numbers are 1462 days lower
read_xlsx("dates.xlsx", dates = FALSE)     # day is int, stamp dbl, clock dbl
read_xlsx("dates.xlsx", types = c(day = "dat"))
#> ! `types` has "dat", which is not a type.  ℹ Did you mean "date"?  ℹ The types are "guess", "text", ...
```
**Succeeded: yes.**

Doc problems:
- docs/r.md's example shows only `day` and `clock` as numbers. It does not say whether to include `stamp`; asking for `"number"` on the date-time works the same way. `dates = FALSE` makes `day` an integer but `stamp` and `clock` doubles, which the docs do not mention.
- The docs do not say that the 1904 file's stored numbers differ from the 1900 file's (by 1,462). A user who asks for "the stored numbers" from both gets different values for the same date. The docs only say the two files "give the same dates".

## 7 Missing values and Excel errors
```r
read_xlsx("messy.xlsx", sheet = "Missing")
#> Warning: 2 cells hold Excel errors and are NA: D4 (#N/A) and D5 (#DIV/0!).
#> x and y are character (NA, ".", "-" kept as text; -1 shows as "-1"); rate is double with 2 NA
m <- read_xlsx("messy.xlsx", sheet = "Missing", na = c("NA", ".", "-"))
#> x: int NA 3 times, y: int NA 4 times, rate: dbl NA 2 times
xlsx_problems(m)
#>   cell column row value   problem
#> 1 D4   rate     4 #N/A    Excel error
#> 2 D5   rate     5 #DIV/0! Excel error
read_xlsx(..., na = c("NA", ".", "-"), types = c(rate = "text"))$rate
#> "0.5" "0.6" "#N/A" "#DIV/0!" "0.7" "0.8"     (no warning)
```
The number `-1` in `x` is untouched by `na = "-"`. Blanks never appear in `xlsx_problems()`, so errors are told from blanks.

**Succeeded: yes.**

Doc problems: none. One small gap is that without `na`, the text codes make `x` and `y` character columns, with no message. The docs say the "text because N of its values are not numbers" message comes for a few cells, but here many cells are text, so no message appears. That is correct behaviour, but a user may expect one.

## 8 Twelve sheets into a list
```r
all <- read_sheets("twelve.xlsx")     # list of 12, names M01..M12, each 3 x 2
read_sheets("twelve.xlsx", sheets = "^M0[1-3]")      # M01 M02 M03
read_sheets("twelve.xlsx", sheets = c("M01","M12"))  # works
read_sheets("twelve.xlsx", sheets = c(2, 4))         # M02 M04
read_sheets("twelve.xlsx", sheets = c("M01","M13"))
#> ! twelve.xlsx has no sheet "M13".  ℹ Did you mean "M03"?  ℹ Its sheets are "M01", ... and "M12".
read_sheets("twelve.xlsx", sheets = "^Z")
#> ! No sheet of twelve.xlsx is named "^Z" or matches it as a regular expression.  ℹ Its sheets are ...
read_sheets("twelve.xlsx", sheets = "M01", names = "upper")   # MONTH VALUE
read_sheets("results.xlsx")     # chart sheet skipped: "Cover" "Data"
read_sheets("results.xlsx", sheets = "Chart")
#> ! Sheet "Chart" of results.xlsx is a chart sheet, and xlkit reads only worksheets.  ℹ Its worksheets are "Cover" and "Data".
```
**Succeeded: yes.**

Doc problems:
- docs/r.md and `read_sheets.txt` say chart sheets are "skipped unless named". Naming one is an error (as `xlsx_sheets()` says, "reading one is an error"). So "skipped unless named" is misleading: it should say "skipped, and an error if named".
- A regular expression that matches nothing is an error, which is not documented.
- The error for `sheets = c("M01","M13")` suggests "M03" for "M13". It is a fine suggestion, but a vector with one wrong name still stops the whole read.

## 9 Write a table, existing file
```r
x$n_int ... x$fct (factor), x$clock (hms), some NA
write_xlsx(x, "out.xlsx"); back <- read_xlsx("out.xlsx")
```
Read back with xlkit: int, dbl, chr, lgl, Date, POSIXct, **chr** for the factor, hms. NAs are NA.

With openpyxl:
- Integers and doubles are numbers (format General).
- Text is inline strings.
- The logical is boolean.
- The date has format `yyyy-mm-dd`, the date-time `yyyy-mm-dd hh:mm:ss`, and the factor is text `lo`/`hi`.
- hms is `[h]:mm:ss`, because a value of 25:00 was present, and openpyxl returns it as a timedelta of 1 day 1 hour.
- NA cells are empty, but they still carry the column format.
- Header is bold, with `freeze A2`.

```r
write_xlsx(x, "out.xlsx")   # second time
#> ! out.xlsx already exists, with sheet "Sheet1".
#> ℹ To replace the whole workbook, use `replace = TRUE`.
#> ℹ To change one sheet and keep the rest, use `write_sheet()` or `write_cells()`.
write_xlsx(x, "out.xlsx", replace = TRUE)   # ok
write_xlsx(x, ..., na = "NA")   # NA written as the text "NA"; every column reads back as character
write_xlsx(data.frame(a = c(1, NaN, Inf)), ...)
#> Warning: 2 cells hold NaN or Inf, which Excel cannot store, and are blank: A3 (NaN) and A4 (Inf).
write_xlsx(tibble(a = 1:2, l = list(1, 2)), ...)   # ! `l` is a list column, and a cell holds one value.
write_xlsx(data.frame(d = as.Date("1850-01-01")), ...)   # ! `d` has dates Excel cannot hold ... A2 (1850-01-01).
write_xlsx(x, "nodir/out.xlsx")   # ! ... cannot be written: its folder, nodir, does not exist.
write_xlsx(x, "out.csv", replace = TRUE)   # ! `path` must end in .xlsx, and out.csv does not.
```
Text `"=A1+1"` and `"https://x.org"` stay text. A New York `POSIXct` of 12:00 reads back as 12:00 UTC (the clock time is kept).

**Succeeded: yes.**

Doc problems:
- Factor columns come back from `read_xlsx()` as character. This is implied by the "its labels, as text" row, but the docs never say there is no round trip for factors, `hms`, etc.
- The docs do not list the "path must end in .xlsx" and "folder does not exist" errors anywhere (neither in r.md's messages table nor in the man pages).
- The "NaN or Inf" row in the table says "a number; NaN and Inf are blank with a warning". That is accurate.
- The docs do not say whether NA cells keep the column's number format. They do (the format is on the empty cell).

## 10 Several sheets; two tables on one sheet
```r
write_xlsx(list(Summary = a, Detail = b, Notes = cc), "three.xlsx")   # sheets "Summary" "Detail" "Notes"
write_xlsx(list(Results = list("Table 1. Means" = means, "Table 2. Counts" = counts)), "tables.xlsx", gap = 2)
```
With openpyxl:
- A1 is `Table 1. Means` in bold.
- Row 2 is the bold header, rows 3 to 4 hold the data.
- Rows 5 and 6 are blank.
- A7 is `Table 2. Counts` in bold, with the header in row 8 and data in rows 9 to 11.
- With the default `gap = 1`, the second title is in row 6.
- `list(means, counts)` gives no title.
- There is no freeze pane on a sheet with several tables.
- The title does not widen column A.

Failures:
```r
write_xlsx(list("Q1/Q2" = q, Q3 = q3), "quarters.xlsx")
#> ! Sheet name "Q1/Q2" has "/", which Excel does not allow in sheet names.
#> ℹ Use another name, such as "Q1-Q2".          (no file written)
list(abc = a, ABC = b)   # ! Sheet name "ABC" is the same as "abc" apart from case ...  ℹ such as "ABC 2"
list(a, b)               # ! Every sheet of `x` needs a name, and element 1 has none. + 2 hints
32-character name        # ! ... has 32 characters, which is more than the 31 Excel allows ...
```
**Succeeded: yes.**

Doc problems:
- docs/r.md says "the tables are stacked with one blank row between them (`gap = 2` for two)". The scenario's "two rows below the first" is ambiguous. `gap = 2` gives two blank rows (title 2 in row 7), which matches the docs, but a user who wants "the second table starting two rows below the first one's last row" has to work out that this is `gap = 1`. This is a wording problem, not a bug.
- Freeze is skipped on a multi-table sheet. This is documented only in the argument table ("on a sheet with one table"), not in "Write several tables".

## 11 Formats, widths, freeze, filter
```r
write_xlsx(sales, "fmt.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)
```
With openpyxl:
- `share` has number format `0.0%` and its value is unchanged (0.001428571...).
- `amount` has `#,##0` and its value is 1000.5.
- The header is bold, `freeze` is A2 and the filter range is A1:F36.
- Widths are fitted (a long note column is capped at 60.7).
- Reading the file back with xlkit gives the same values (`all.equal` TRUE).
- `widths = c(note = 30)` gives 30.7 for that column, `freeze = "B2"` gives B2, and `header_style = xl_style(bold = TRUE, fill = "lightyellow")` works.
- `header_style = NULL, freeze = FALSE` gives a plain header, no freeze and no filter.

Failures:
```r
formats = c(shar = "0.0%")
#> ! `formats` names `shar`, which is not a column of `sales`.  ℹ Did you mean `share`?
formats = c(zzz = "0.0%")  # same error without a hint; widths = c(zzz = 10) likewise
styles = list(zzz = xl_style(bold = TRUE))
#> ! `styles` names `zzz`, which is neither a column of `sales` nor a cell or range such as "A2:F2".
filter = TRUE with two tables on a sheet
#> ! `filter = TRUE` needs one table per sheet, and sheet "S" has 2.  ℹ Excel allows one filter per sheet...
xl_style(border = "dotted")  # ! `border` must be "thin", "medium", "thick" or "double"; ...  ✖ It is "dotted".
xl_style(fill = "notacolor") # ! `fill` must be a color as "#RRGGBB" or an R color name ...
freeze = "ZZ"                # ! `freeze` must be TRUE, FALSE or a cell such as "B2".
formats = c(share = "0.0%", "0.00")   # ! `formats` must be number formats named by column ...
```
No file is written for the bad formats call (`file.exists("fmt_bad.xlsx")` FALSE).

**Succeeded: yes.**

Doc problems:
- The "Common formats" table shows `"0%"` for 1234.5678 as `123457%`. That is correct arithmetic, but the docs say nothing about how the percent format scales the value. A user who holds the share as 25.6 rather than 0.256 gets 2560.0%. This is standard Excel but worth a line.
- The docs do not say what `freeze = "B2"` does on a multi-table sheet. I did not test it.

## 12 Fill in a template
Template (made with openpyxl): `Cover` has a merged B2:F2 title, C4 with the format `#,##0.00 "USD"`, bold, red font and yellow fill, C5 with a blue fill and a medium bottom border and General format, C6 `=C4*2`, a conditional format on C4 and a defined name `TotalCell`. `Chart` is a chart sheet. `Data` has a frozen header, red tab and column A width 18.

```r
file.copy("results.xlsx", "res_work.xlsx")
write_sheet(new_data, "res_work.xlsx", sheet = "Data")
write_cells("res_work.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```
**What was kept** (checked with openpyxl and a zip diff):
- Sheets are still Cover, Chart, Data, in that order.
- `chart1.xml`, `chartsheets/sheet1.xml`, `drawings/drawing1.xml`, `theme1.xml` and `workbook.xml` are byte-identical. The chart still plots the same range.
- Only `sheet1.xml`, `sheet2.xml` and `styles.xml` changed.
- C4 is now 1250 with the format `#,##0.00 "USD"`, bold, same font colour and fill.
- C5 is the date 2024-12-31 with `yyyy-mm-dd`, keeping the blue fill and the medium bottom border.
- C6 formula, B2 title (Arial 16 bold), merge B2:F2, column widths, the conditional format and the defined name `TotalCell` are all intact.
- Data now has 12 new rows with a bold header, `freeze A2`, red tab colour and width 18 for column A (all kept). The original template's Data header was not bold, so it was restyled.
- `read_xlsx()` on Data reads the new table; on Cover, C6 reads as NA (the formula has no stored result, as documented).

Chart warnings: a 20-row table gives "A chart plots 'Data'!A2:B13, which no longer matches the 20 rows written to A2:B21." and a 5-row table gives the same message with 5 rows. A 12-row table gives none.

Failures:
```r
write_cells(..., sheet = "Cover", C2 = "x")
#> ! C2 is inside the merged range B2:F2, which shows only its top-left cell, B2. Nothing was written.
#> ℹ Write to B2, or unmerge the range in Excel first.
write_cells(..., C4 = 1, ZZZZ1 = 2)  # ! `ZZZZ1` is not a cell; ...
write_cells(..., 5)                  # ! Each value in `...` needs the cell it goes in ...
write_sheet(new_data, ..., sheet = "Chart")  # ! Sheet "Chart" ... is a chart sheet, and xlkit writes only worksheets.
write_cells("nonexistent_dir/zzz.xlsx", ...)  # ! ... its folder, nonexistent_dir, does not exist.
write_cells(..., sheet = "Covr", C4 = 5)  # no error: a new sheet "Covr" is added (sheets: Cover Chart Data Covr)
write_sheet(new_data, ..., sheet = "Q1/Q2")  # ! Sheet name "Q1/Q2" has "/" ...
```
The original `results.xlsx` was unchanged (same MD5 before and after).

**Succeeded: yes.**

Doc problems:
- A misspelled sheet name in `write_cells()` silently adds a new sheet, with no message. The docs state this ("A sheet the workbook does not have is added after the last tab"), but they never warn that a typo in `sheet =` does this, and the example in docs/r.md ("Put values into cells") gives no hint. This is the opposite of the helpful "Did you mean" that `read_xlsx()` gives.
- The "recalculate on open" claim cannot be verified from outside Excel here. `workbook.xml` was already marked `fullCalcOnLoad="1"` by openpyxl, so my check could not show that xlkit sets it.
- The man page says "The new file is written beside the old one and moved over it". I did not test the failure path of this.
- In `write_cells`, `C5 = as.Date(...)` on a General-format cell gets `yyyy-mm-dd` and keeps the fill and border, as documented.

## 13 Stata labels
Input: `survey.dta` made with `haven::write_dta()` (`sex` 1/2 labelled Male/Female with label "Sex of respondent", `age` with label "Age in years"), read with `dtaparser::read_dta()` (`sex` has class `dtaparser_labelled`).

```r
write_xlsx(df, "survey.xlsx", header = "labels", replace = TRUE)
read_xlsx("survey.xlsx")
#>   id `Sex of respondent` `Age in years` income
#>    1 Male                23             100.5 ... Female ...
```
With openpyxl, the header cells are `id`, `Sex of respondent`, `Age in years`, `income` (bold, frozen at A2), and the sex cells are the text `Male`/`Female`.
- `header = "both"` gives two header rows (names, then labels, blank where there is none).
- `values = "codes"` gives 1/2 as numbers.
- The default `header = "names"` gives `sex` as the header with text values.
- `header = FALSE` gives no header row.
- `header = "label"` gives `! header must be "names", "labels", "both" or FALSE. ✖ It is "label"`; `values = "code"` gives a similar error.

Code without a label (9 added to `sex`, passed through `haven::write_dta()` then `dtaparser::read_dta()`):
```
`sex` has 2 cells whose code has no value label: 9 in B4 and B6.
They are written as codes.
ℹ Add a label with `dtaparser::with_labels()`, or write the column's codes with `values = "codes"`.
```
The cells hold the number 9 and the sheet reads back `Male Female 9 Female 9` as text. The same message comes for a haven `labelled` column passed directly to `write_xlsx()`.

Long headers:
```r
long.xlsx headers: "Age at first birth", "Number of children ever born (living and dead)", "Region of residence at time of survey"
r <- read_xlsx("long.xlsx", names = "snake")
names(r)   # "age_at_first_birth" "number_of_children_ever_born_living_and_dead" "region_of_residence_at_time_of_survey"
attr(r$age_at_first_birth, "label")   # "Age at first birth"
rs <- read_xlsx("long.xlsx", names = "stata")
names(rs)  # "Age_at_first_birth" "Number_of_children_ever_born_liv" "Region_of_residence_at_time_of_s"   (32 characters)
dtaparser::save_dta(rs, "long.dta")   # names and labels survive; haven::read_dta() also sees the labels
```
A custom function also works: `names = function(x) tolower(abbreviate(x, 12))` gives `agatfrstbrth` and so on, but the result is unreadable, and one name came out as `nmboceb(add)`, which is not a valid Stata name.

**Succeeded: partly.** The value-label and variable-label write is fully correct. "So names are short" is only met by `names = "stata"`, which cuts at 32 characters.

Doc problems:
- docs/r.md "Going the other way ... reads with short names and keeps the headers as variable labels" uses `names = "snake"`. That gives *clean* names, not *short* ones: the second header gives a 44-character name. Only `"stata"` caps at 32, cutting in mid-word. There is no documented way to ask for names of at most N characters or to shorten words. The example shows only a short header (`age_at_first_birth`), which hides this.
- The docs show `with_labels()` but never give its signature. I found `with_labels(x, labels, label = NULL)` only by calling `args()`.
- The sample message in docs/r.md ("9 in A5, A12 and A30") uses cell references that look like they come from column A, whereas the real message names the actual column of the labelled variable (B4 and B6 here). The format otherwise matches.
- The doc line `dtaparser::save_dta(df, "survey.dta")   # keeps them as variable labels` works, but dtaparser's install is never explained (see scenario 1).

---

## Summary

| # | scenario | succeeded | doc problems |
|---|---|---|---|
| 1 | Install | yes | dtaparser has no install instructions; Rust requirement is the only fresh-machine hurdle and is covered |
| 2 | report.xlsx types | yes | none (result carries an undocumented `xlkit_problems` attribute) |
| 3 | "Sales 2024" range, sheet names | yes | none |
| 4 | Header repair, two-row header | yes | "you can always see where a name came from" is untrue for blank headers and for names equal to the text; `header` beyond the data returns an empty tibble with no message; silent name collision after `"stata"` truncation |
| 5 | zip text, amount numbers, problems | yes | `formatC` workaround not tied to the mixed text/number case; otherwise accurate |
| 6 | Dates, times, 1904, stored numbers | yes | does not say the 1904 file's stored numbers differ (by 1,462) from the 1900 file's; `dates = FALSE` types not listed |
| 7 | Missing codes and Excel errors | yes | none significant |
| 8 | Twelve sheets to a list | yes | chart sheets "skipped unless named" — naming one is an error; no-match regex error undocumented |
| 9 | Write a table, existing file | yes | factor/hms do not round-trip (undocumented); "path must end in .xlsx" and "folder does not exist" errors undocumented |
| 10 | Several sheets; two tables on one sheet | yes | "two rows below" vs `gap` wording is ambiguous; no freeze on a multi-table sheet is only in the argument table |
| 11 | Formats, widths, freeze, filter | yes | percent format on a value already scaled is not warned about; `freeze` on multi-table sheets undocumented |
| 12 | Fill in a template | yes | a misspelled sheet name in `write_cells()` silently adds a sheet; recalculation marking could not be checked |
| 13 | Stata labels both ways | partly | `names = "snake"` gives clean, not short, names (only `"stata"` caps at 32, mid-word); `with_labels()` signature missing; sample message cell refs misleading |
