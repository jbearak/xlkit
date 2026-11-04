# xlkit for R

xlkit reads `.xlsx` workbooks into tibbles and writes tibbles to
`.xlsx`, and fills in workbooks that people made by hand without
disturbing what it does not write. You name cells the way Excel shows
them: a sheet by its tab name, a range as `B5:F40`, a header by its row
number.

Contents:

- [Install](#install)
- [The example workbooks](#the-example-workbooks)
- [Read a sheet](#read-a-sheet)
- [Choose a sheet and a range](#choose-a-sheet-and-a-range)
- [Header rows and column names](#header-rows-and-column-names)
- [Column types](#column-types)
- [Dates and times](#dates-and-times)
- [Missing values and Excel errors](#missing-values-and-excel-errors)
- [Read every sheet](#read-every-sheet)
- [Write a table](#write-a-table)
- [Write several tables](#write-several-tables)
- [Format the output](#format-the-output)
- [Fill in an existing workbook](#fill-in-an-existing-workbook)
- [Variable labels and value labels](#variable-labels-and-value-labels)
- [Messages and what to do about them](#messages-and-what-to-do-about-them)
- [Coming from readxl, writexl or openxlsx2](#coming-from-readxl-writexl-or-openxlsx2)
- [Reference](#reference)

Translating a do-file? [docs/stata.md](stata.md) gives the xlkit line
for each `import excel`, `export excel` and `putexcel` line.

## Install

xlkit needs R 4.2 or later on macOS, Windows or Linux. It is not on
CRAN yet. Install it from GitHub:

```r
install.packages("remotes")
remotes::install_github("jbearak/xlkit")
```

Building from source needs a Rust toolchain, because xlkit's reader and
writer are written in Rust:

- macOS and Linux: install Rust from <https://rustup.rs>, then restart R.
- Windows: install [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
  for your R version, then Rust from <https://rustup.rs>, then run
  `rustup target add x86_64-pc-windows-gnu`.

If installation stops with `xlkit: building needs cargo`, R cannot find
Rust: restart R (or your computer) after installing it, and check that
`Sys.which("cargo")` is not empty. Any other build error: open an issue
at <https://github.com/jbearak/xlkit/issues> with the output of
`remotes::install_github("jbearak/xlkit")` and `sessionInfo()`.

xlkit imports only rlang, tibble, vctrs and hms. It reads and writes
dtaparser's labelled columns without depending on dtaparser.

Check the install:

```r
library(xlkit)
xlsx_sheets(xlkit_example("report.xlsx"))
#> [1] "Scores"
```

## The example workbooks

`xlkit_example()` returns the path of a workbook that ships with xlkit,
so every example on this page runs as written. Called with no argument,
it lists them:

```r
xlkit_example()
#> [1] "dates.xlsx"     "dates1904.xlsx" "messy.xlsx"     "report.xlsx"
#> [5] "sales.xlsx"     "template.xlsx"
```

| workbook | what it holds |
|---|---|
| `report.xlsx` | one sheet, `Scores`, with a header in row 1 and five columns of different types |
| `sales.xlsx` | five sheets; `Sales 2024` has a title in `B1`, a note in `B2` and its table in `B5:F40` |
| `messy.xlsx` | sheets `Headers` (blank and duplicate header cells), `Two-row header`, `Types` (mixed columns) and `Missing` (missing-value codes and Excel errors) |
| `dates.xlsx` | dates, date-times and times of day; a copy in the 1904 date system is `dates1904.xlsx` |
| `template.xlsx` | a formatted `Cover` sheet, a chart on `Chart`, and a `Data` sheet the chart plots |

Copy one before writing to it, so the original stays as it was:

```r
path <- file.path(tempdir(), "template.xlsx")
file.copy(xlkit_example("template.xlsx"), path)
```

## Read a sheet

```r
library(xlkit)
scores <- read_xlsx(xlkit_example("report.xlsx"))
scores
#> # A tibble: 4 × 5
#>      id name  score passed joined
#>   <int> <chr> <dbl> <lgl>  <date>
#> 1     1 Ana    91.5 TRUE   2024-01-15
#> 2     2 Ben    78   FALSE  2024-02-03
#> 3     3 Chen   85.2 TRUE   2024-02-20
#> 4     4 Dee    NA   NA     2024-03-01
```

`read_xlsx()` reads the first sheet. Row 1 gives the column names and
the rows below are the body, down to the last row with a value. It
returns a tibble.

Each column's type comes from every cell in it, not from the first few
hundred rows:

| the column's cells hold | the column becomes |
|---|---|
| whole numbers only, each between -2,147,483,647 and 2,147,483,647 | integer |
| numbers, some not whole or larger | double |
| `TRUE` and `FALSE` only | logical |
| numbers formatted as dates without a time | `Date` |
| numbers formatted as dates, some with a time | `POSIXct` in UTC |
| numbers formatted as times of day or durations (`hh:mm`, `[h]:mm`) | `hms` |
| any text | character (numbers in it are written as Excel shows them, see [Column types](#column-types)) |
| nothing | logical, all `NA` |

Blank cells are `NA` in every type. Text that is only spaces is `NA`
too. Excel errors such as `#N/A` are `NA` with a warning; see
[Missing values and Excel errors](#missing-values-and-excel-errors).

A path that does not exist stops, and names a file with a similar name
in the same folder if there is one:

```r
read_xlsx("reprot.xlsx")
#> Error in `read_xlsx()`:
#> ! reprot.xlsx does not exist.
#> ℹ Did you mean report.xlsx?
```

A file that is not an `.xlsx` or `.xlsm` workbook, such as a CSV file
renamed `.xlsx`, stops with `... is not an .xlsx workbook (it looks
like text)`. An empty sheet reads as a tibble with no rows and no
columns.

## Choose a sheet and a range

List the sheets, in tab order:

```r
path <- xlkit_example("sales.xlsx")
xlsx_sheets(path)
#> [1] "Summary"    "Sales 2023" "Sales 2024" "Regions"    "Notes"
```

Pick a sheet by its name or its position (counting tabs from 1):

```r
read_xlsx(path, sheet = "Sales 2024")
read_xlsx(path, sheet = 3)
```

A name that is not in the workbook stops with the names that are:

```r
read_xlsx(path, sheet = "Sales 2042")
#> Error in `read_xlsx()`:
#> ! sales.xlsx has no sheet "Sales 2042".
#> ℹ Did you mean "Sales 2024"?
#> ℹ Its sheets are "Summary", "Sales 2023", "Sales 2024", "Regions" and "Notes".
```

`Sales 2024` has a title in `B1`, a note in `B2` and its table in
`B5:F40`. Give the range as Excel shows it:

```r
sales <- read_xlsx(path, sheet = "Sales 2024", range = "B5:F40")
```

The first row of the range, row 5, gives the names; rows 6 to 40 are
the body. Other ways to give a range:

| `range =` | reads |
|---|---|
| `"B5:F40"` | exactly those cells, padding with `NA` where the sheet has fewer |
| `"B5"` | from B5 to the last row and column with data |
| `"B5:F"` | columns B to F, from row 5 down to the last row with a value |
| `"B:F"` | columns B to F, from their first row with a value |
| `"5:40"` | rows 5 to 40, every column with a value |
| `"SalesTable"` | the Excel table (Insert ▸ Table) or defined name `SalesTable`, from any sheet |

When the table runs to the bottom of the sheet, the header row alone
is enough: `header = 5` reads from row 5 down, as wide as the data.

```r
sales <- read_xlsx(path, sheet = "Sales 2024", header = 5)
```

If you read such a sheet without either, xlkit takes the title in row 1
as the header and warns:

```r
df <- read_xlsx(path, sheet = "Sales 2024")
#> Warning message:
#> Row 1 has text only in B1 ("Sales by region, 2024"), but the rows below have up to 5 columns.
#> ℹ If the header is lower down, give its row: `header = 5`, or the range: `range = "B5:F40"`.
```

A range that lies outside the sheet, or past Excel's last row
(1,048,576) or column (`XFD`), stops with an error that says which.

## Header rows and column names

`header` says which rows hold the column names:

| `header =` | names come from |
|---|---|
| `TRUE` (the default) | the first row of the range, or of the sheet's data |
| `5` | row 5, as Excel numbers it; the body starts at row 6 |
| `4:5` | rows 4 and 5, joined with a space, so `Income` over `2020` gives `Income 2020` |
| `FALSE` | none; columns are named by their letters, `B`, `C`, ... and every row is body |

A header cell merged across several columns names each of them. That is
what a two-row header usually needs: `Income` merged across B4:D4 over
`2020`, `2021`, `2022` gives `Income 2020`, `Income 2021`,
`Income 2022`.

```r
path <- xlkit_example("messy.xlsx")
read_xlsx(path, sheet = "Two-row header", header = 4:5) |> names()
#> [1] "Region"      "Income 2020" "Income 2021" "Income 2022"
```

`names` says how header text becomes column names. Every choice gives
unique names; a blank header cell is named by its column letter.

The `Headers` sheet of `messy.xlsx` has `Region` in A1, `Total` in B1
and again in C1, nothing in D1, and `Share %` in E1.

| `names =` | `Region`, `Total`, `Total`, blank, `Share %` become |
|---|---|
| `"unique"` (the default) | `Region`, `Total`, `Total_C`, `D`, `Share %`: a repeat gets its column letter |
| `"snake"` | `region`, `total`, `total_c`, `d`, `share_percent` |
| `"stata"` | `Region`, `Total`, `Total_C`, `D`, `Share`: valid Stata names of at most 32 characters, each run of other characters becoming `_`, with none at the ends |
| `"lower"`, `"upper"` | `"unique"`, then lower or upper case; add one to another rule with `c("stata", "lower")` |
| a function | the function's result on the header text, made unique |

When xlkit has to change a header to make a name, because it is blank
or repeats another, it says which:

```r
df <- read_xlsx(path, sheet = "Headers")
#> New names:
#> • C1 "Total" is `Total_C` (it repeats B1)
#> • D1 (blank) is `D`
#> ℹ Choose another rule with `names =`, or set your own with `names(df) <- ...`.
```

The rules you choose with `names` change names without a message; only
these repairs get one.

When a name differs from its header text, the text is kept as the
column's variable label, so you can always see where a name came from:

```r
df <- read_xlsx(path, sheet = "Headers", names = "snake")
#> New names:
#> • C1 "Total" is `total_c` (it repeats B1)
#> • D1 (blank) is `d`
#> ℹ Choose another rule with `names =`, or set your own with `names(df) <- ...`.
names(df)
#> [1] "region"        "total"         "total_c"       "d"
#> [5] "share_percent"
attr(df$share_percent, "label")
#> [1] "Share %"
```

dtaparser's `var_label()` reads the same attribute, and its
`save_dta()` writes it as the Stata variable label.

## Column types

`read_xlsx()` guesses each column's type from every cell, using the
table in [Read a sheet](#read-a-sheet). A guess never loses a value:
a column with one text cell among numbers is character, not numbers
with an `NA`.

When a column is text only because a few of its cells are, xlkit says
which cells, since they are usually typos or codes in a column of
numbers or dates:

```r
path <- xlkit_example("messy.xlsx")
df <- read_xlsx(path, sheet = "Types")
#> `amount` is text because 2 of its 2,003 values are not numbers:
#> C2003 ("n/a") and C2004 ("12,5").
#> ℹ To read it as numbers, use `types = c(amount = "number")`; those cells become NA.
```

The message comes when 10 cells or fewer, and fewer than 1 in 10 of
the column's values, keep a column of numbers or dates from being one.

Give `types` to choose a type. Name the columns you care about; the rest
are guessed:

```r
path <- xlkit_example("messy.xlsx")
df <- read_xlsx(path, sheet = "Types", types = c(zip = "text", amount = "number"))
#> Warning message:
#> 2 cells in `amount` could not be read as numbers and are NA:
#> C2003 ("n/a") and C2004 ("12,5").
#> ℹ See them all with `xlsx_problems(df)`.
```

The types are:

| type | gives | a cell that does not fit |
|---|---|---|
| `"guess"` | the guess above | (none: the guess fits every cell) |
| `"text"` | character | (none: every cell has a text form) |
| `"number"` | double | text that is not a number becomes `NA` with a warning; `" 42 "` and `"1e3"` convert |
| `"integer"` | integer | as `"number"`, and a number that is not whole becomes `NA` with a warning |
| `"logical"` | logical | numbers: 0 is `FALSE`, others `TRUE`; text other than `TRUE`/`FALSE` becomes `NA` with a warning |
| `"date"` | `Date` | text in the form `2024-03-01` converts; other text becomes `NA` with a warning |
| `"datetime"` | `POSIXct` in UTC | as `"date"`, also `2024-03-01 14:30:00` |
| `"time"` | `hms` | a number's fraction of a day, or text like `14:30` |
| `"skip"` | the column is dropped | |

`"numeric"`, `"double"` and `"character"` work too. `types` can also be
one type for every column (`types = "text"`) or one type per column in
order (`types = c("text", "guess", "number")`). A name in `types` that
is not a column stops with the column names.

`"text"` writes a number as Excel shows it when its number format pads
with zeros, so `2139` formatted `00000` reads as `"02139"`. A code typed
as a number without such a format has no leading zero anywhere in the
file, and no reader can restore it; if the codes have a known width,
pad them after reading: `formatC(as.integer(df$zip), width = 5, flag = "0")`. Other numbers
are written in full, up to 15 significant digits (`0.1`, not
`0.1000000000000000055`), and dates as `2024-03-01`.

`xlsx_problems()` lists every cell that did not convert, and every
Excel error:

```r
xlsx_problems(df)
#> # A tibble: 2 × 5
#>   cell  column   row value problem
#>   <chr> <chr>  <int> <chr> <chr>
#> 1 C2003 amount  2003 n/a   not a number
#> 2 C2004 amount  2004 12,5  not a number
```

`cell` and `row` are as Excel shows them, so you can find the cell in
the workbook. A tibble without problems gives zero rows.

## Dates and times

Excel stores a date as a number of days and shows it as a date because
of its number format. xlkit reads a number as a date when its format
shows a date or time, so the cell and the column read the way the
sheet looks:

```r
path <- xlkit_example("dates.xlsx")
read_xlsx(path)
#> # A tibble: 3 × 3
#>   day        stamp               clock
#>   <date>     <dttm>              <time>
#> 1 2024-01-15 2024-01-15 08:30:00 08:30:00
#> 2 2024-02-29 2024-02-29 17:05:30 17:05:30
#> 3 2024-12-31 2024-12-31 23:59:59 23:59:59
```

- **Date-times are UTC.** Excel stores the time on the clock, without a
  time zone, and xlkit reads it in UTC so it prints as Excel shows it.
  To say it was New York time, keep the clock time and change the zone:
  `lubridate::force_tz(df$stamp, "America/New_York")`.
- **The 1904 date system** is read from the workbook, so
  `dates1904.xlsx` gives the same dates as `dates.xlsx`.
- **Excel's 1900 leap-day bug**: Excel counts a 29 February 1900 that
  did not exist. Dates from 1 March 1900 on are right; day 60 reads as
  `NA` with a warning.
- **The stored numbers**: ask for `"number"`, and a date column gives
  Excel's day count and a time its fraction of a day:

```r
read_xlsx(path, types = c(day = "number", clock = "number"))
#> # A tibble: 3 × 3
#>     day stamp               clock
#>   <dbl> <dttm>              <dbl>
#> 1 45306 2024-01-15 08:30:00 0.354
#> 2 45351 2024-02-29 17:05:30 0.712
#> 3 45657 2024-12-31 23:59:59 1.000
```

To read every date as its number, use `dates = FALSE`.

A date typed as text (`"2024-03-01"`) stays text unless you ask for
`"date"`. A column of dates with a stray text cell, such as `unknown`,
is text, and the message in [Column types](#column-types) names the
cell; `types = c(day = "date")` reads the dates and makes that cell
`NA`, with a warning.

## Missing values and Excel errors

Blank cells are `NA`. Give `na` for text that also means missing:

```r
path <- xlkit_example("messy.xlsx")
df <- read_xlsx(path, sheet = "Missing", na = c("NA", ".", "-"))
#> Warning message:
#> 2 cells hold Excel errors and are NA: D4 (#N/A) and D9 (#DIV/0!).
#> ℹ See them all with `xlsx_problems(df)`.
```

`na` matches the whole cell after trimming spaces, and only text cells:
`na = "-"` does not touch the number `-1`. The default is `na = ""`.

Excel errors (`#N/A`, `#DIV/0!`, `#VALUE!`, `#REF!`, `#NAME?`, `#NUM!`,
`#NULL!`) are `NA` in every type but `"text"`, with one warning that
names them. A guess never makes a column text because of its errors.
To tell errors from blanks, use `xlsx_problems()`:

```r
xlsx_problems(df)
#> # A tibble: 2 × 5
#>   cell  column   row value   problem
#>   <chr> <chr>  <int> <chr>   <chr>
#> 1 D4    rate       4 #N/A    Excel error
#> 2 D9    rate       9 #DIV/0! Excel error
```

To keep the error text instead, read the column as `"text"`: the cell
reads as `"#N/A"`, without a warning.

## Read every sheet

`read_sheets()` reads each sheet into a list of tibbles named by sheet:

```r
all <- read_sheets(xlkit_example("sales.xlsx"))
#> Warning messages:
#> 1: Sheet "Sales 2023": Row 1 has text only in B1 ("Sales by region, 2023"), but the rows below have up to 5 columns.
#> ℹ If the header is lower down, give its row: `header = 5`, or the range: `range = "B5:F40"`.
#> 2: Sheet "Sales 2024": Row 1 has text only in B1 ("Sales by region, 2024"), but the rows below have up to 5 columns.
#> ℹ If the header is lower down, give its row: `header = 5`, or the range: `range = "B5:F40"`.
names(all)
#> [1] "Summary"    "Sales 2023" "Sales 2024" "Regions"    "Notes"
all[["Regions"]]
#> # A tibble: 5 × 3
#>   region  manager office
#>   <chr>   <chr>   <chr>
#> 1 North   Ana     Oslo
#> 2 South   Ben     Lima
#> 3 East    Chen    Pune
#> 4 West    Dee     Accra
#> 5 Central Eve     Kyiv
```

It takes `read_xlsx()`'s arguments (except `sheet`) and uses them for
every sheet. `sheets = c("Sales 2023", "Sales 2024")` reads some; a
regular expression does too: `sheets = "^Sales"`. Each tibble keeps its
own `xlsx_problems()`. An empty sheet gives a tibble with no rows and
no columns, as in `read_xlsx()`. To stack sheets with the same columns
into one table, `dplyr::bind_rows(all, .id = "sheet")`.

## Write a table

```r
write_xlsx(scores, "scores.xlsx")
```

`write_xlsx()` writes a data frame to a new workbook, on a sheet named
`Sheet1`, with the column names in row 1. Its defaults are for a table
someone will read: the header is bold, the header row stays in view
when scrolling, and each column is as wide as its contents (up to 60
characters).

Each column type becomes:

| R type | in Excel |
|---|---|
| integer, double | a number; `NaN` and `Inf` are blank with a warning |
| character | text |
| logical | `TRUE` or `FALSE` |
| `Date` | a date, shown `yyyy-mm-dd` |
| `POSIXct` | a date-time on the clock of its time zone, shown `yyyy-mm-dd hh:mm:ss` |
| `hms`, `difftime` | a time, shown `hh:mm:ss` (`[h]:mm:ss` when one is 24 hours or more) |
| factor | its labels, as text |
| dtaparser or haven labelled | its value labels, as text (see [labels](#variable-labels-and-value-labels)) |
| list | an error naming the column |

`NA` is a blank cell; `na = "NA"` writes text instead. Text is always
written as text: `"=A1+1"` is not a formula and `"https://..."` is not
a link unless you say so with `xl_formula()`. `sheet` names the
sheet: `write_xlsx(scores, "scores.xlsx", sheet = "Scores")`.

**When the file exists.** `write_xlsx()` never replaces a file unless
you say so, as Stata's `export excel` does:

```r
write_xlsx(scores, "results.xlsx")
#> Error in `write_xlsx()`:
#> ! results.xlsx already exists, with sheets "Cover", "Chart" and "Data".
#> ℹ To replace the whole workbook, use `replace = TRUE`.
#> ℹ To change one sheet and keep the rest, use `write_sheet()` or `write_cells()`.
```

A script that rewrites its own output each time it runs passes
`replace = TRUE`. The new file is written beside the old one and then
moved over it, so an error part way leaves the old file as it was.

Excel's limits are errors that say which value broke them and what to
do: more than 1,048,576 rows or 16,384 columns (split the table across
sheets), text longer than 32,767 characters, dates before 1900 (write
them as text), and a sheet name longer than 31 characters or holding
`[ ] : * ? / \` (see [Write several tables](#write-several-tables)).

## Write several tables

A named list of data frames writes one sheet each, named by the list:

```r
write_xlsx(list(Summary = summary, Detail = detail, Notes = notes), "report.xlsx")
```

To put several tables on one sheet, make that sheet a named list too.
Each name is written as a title above its table, and the tables are
stacked with one blank row between them (`gap = 2` for two):

```r
write_xlsx(
  list(Results = list("Table 1. Means" = means, "Table 2. Counts" = counts)),
  "tables.xlsx",
  gap = 2
)
```

A sheet name Excel does not allow stops before anything is written, and
suggests one it does:

```r
write_xlsx(list("Q1/Q2" = q, Q3 = q3), "quarters.xlsx")
#> Error in `write_xlsx()`:
#> ! Sheet name "Q1/Q2" has "/", which Excel does not allow in sheet names.
#> ℹ Use another name, such as "Q1-Q2".
```

Names longer than 31 characters, holding `[ ] : * ? \`, or the same as
another sheet's name apart from case stop the same way.

`Table 1. Means` goes in `A1` in bold, `means` from `A2`, then two
blank rows, then `Table 2. Counts` and `counts`. An unnamed table
(`list(means, counts)`) gets no title. Sheets in one call can mix both
forms. To place a table at an exact cell, use `write_sheet(x, path,
sheet, at = "D2")` (see [Fill in an existing
workbook](#fill-in-an-existing-workbook)).

## Format the output

```r
write_xlsx(
  sales, "sales.xlsx",
  formats = c(share = "0.0%", amount = "#,##0"),
  filter = TRUE
)
```

`formats` gives an Excel number format for each column you name. The
value is unchanged; only how Excel shows it. Common formats:

| format | 1234.5678 shows as | 0.256 shows as |
|---|---|---|
| `"0"` | 1235 | 0 |
| `"0.00"` | 1234.57 | 0.26 |
| `"#,##0"` | 1,235 | 0 |
| `"#,##0.00"` | 1,234.57 | 0.26 |
| `"0%"` | 123457% | 26% |
| `"0.0%"` | 123456.8% | 25.6% |

Dates take formats such as `"yyyy-mm-dd"`, `"d mmm yyyy"` and
`"mm/dd/yyyy hh:mm"`.

The defaults already make the header bold, keep it in view and fit the
column widths. The arguments that change them:

| argument | default | does |
|---|---|---|
| `formats` | none | number formats by column name |
| `widths` | `"auto"` | `"auto"` fits contents, up to 60 characters so a long note does not make a column fill the screen; a number for every column; or a named vector, `c(notes = 80)`, with the rest fitted |
| `freeze` | `TRUE` | keep the header row in view (on a sheet with one table); `FALSE` does not; a cell such as `"B2"` freezes the rows above and the columns left of it |
| `filter` | `FALSE` | `TRUE` adds filter buttons to the header; Excel allows one filter per sheet, so it needs one table on each |
| `header_style` | `xl_style(bold = TRUE)` | the header cells' style; `NULL` for plain |
| `styles` | none | more styles, by column name or by range |

`xl_style()` makes a style: `bold`, `italic`, `underline`, `size`,
`font`, `color` and `fill` (as `"#RRGGBB"` or an R color name),
`border` (`"thin"`, `"medium"`, `"thick"`, `"double"`, or a vector of
them for top, right, bottom, left), `align` (`"left"`, `"center"`,
`"right"`), `valign`, `wrap`, `indent` and `format`. Use it in
`styles`, by column name or by range, and in `merge`
(`merge = list("A1:F1" = xl_style(align = "center"))`):

```r
write_xlsx(
  sales, "styled.xlsx",
  styles = list(region = xl_style(bold = TRUE), "A12:F12" = xl_style(border = c(top = "thin")))
)
```

A key that matches a column name styles that column's body; any other
key must be a cell or range. A name in `formats` or `widths` that is
not a column, or a `styles` key that is neither a column nor a range,
stops before anything is written:

```r
write_xlsx(sales, "sales.xlsx", formats = c(shar = "0.0%"))
#> Error in `write_xlsx()`:
#> ! `formats` names `shar`, which is not a column of `sales`.
#> ℹ Did you mean `share`?
```

## Fill in an existing workbook

`write_sheet()` and `write_cells()` change a workbook in place. They
rewrite only the cells they write and copy everything else in the file
as it was: other sheets, charts, images, comments, conditional formats,
data validation, defined names, pivot tables and macros. Neither ever
rebuilds the workbook from what it understands, which is how other
libraries lose charts and formats.

Using the example template:

```r
path <- file.path(tempdir(), "template.xlsx")
file.copy(xlkit_example("template.xlsx"), path)
```

**Replace what is on a sheet.** `write_sheet()` clears the sheet's
cells, with their values, formulas, formats and merged ranges, and
writes the table from `A1` with a bold header, as `write_xlsx()` does.
The sheet keeps its place among the tabs, its column widths, frozen
panes, tab color and print settings, and the chart that plots it now
plots the new data:

```r
write_sheet(new_data, path, sheet = "Data")
```

A chart plots a fixed range, such as `Data!A1:B13`. If the new table
has more rows, the chart still plots `A1:B13`; if fewer, it plots
blanks at the end. To have a chart follow the data, make the template's
chart plot an Excel table (Insert ▸ Table) and write into the table:
`write_sheet(new_data, path, sheet = "Data", at = "A1")`, where `A1` is
the table's top-left cell, resizes the table to fit `new_data`, and
charts that plot the table follow it. xlkit says when a chart plots a
range that no longer matches the data it wrote.

**Put values into cells.** `write_cells()` takes cell references and
values. A cell keeps its own format, so a template's formatted cell
shows the new value the way the template meant:

```r
write_cells(path, sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```

If a cell's format does not show dates and you write a date, xlkit
gives it the `yyyy-mm-dd` format and keeps its font, fill and borders.

What a value becomes:

| value | written |
|---|---|
| a number, text, logical, date or date-time | that cell |
| a vector of length 2 or more | down the column from that cell |
| a matrix | a block, from that cell |
| a data frame | a table with its header row, from that cell |
| `xl_formula("SUM(C2:C9)")` | a formula; Excel calculates it when the file is opened |
| `NA` | an empty cell, keeping its format |

`styles` and `merge` work as in `write_xlsx()`, by range:

```r
write_cells(
  path, sheet = "Cover",
  B2 = "Results for 2024",
  styles = list(B2 = xl_style(bold = TRUE, size = 14)),
  merge = "B2:F2"
)
```

**Put a table at a cell, keeping the rest of the sheet.** Give
`write_sheet()` the cell where the table starts. It writes only the
cells the table covers:

```r
write_sheet(model_table, path, sheet = "Data", at = "H2")
```

**Add a sheet.** `write_sheet()` with a sheet name the workbook does not
have adds it after the last tab (`after = "Cover"` to choose). With a
file that does not exist, it makes a new workbook, as `write_xlsx()`
does.

**Formulas.** When `write_sheet()` or `write_cells()` changes cells that
the template's formulas use, those formulas' stored results are out of
date. xlkit marks the workbook so Excel recalculates every formula when
it opens the file. Until then, `read_xlsx()` reads the old results.

**What xlkit refuses.** Files that are not `.xlsx` or `.xlsm` (such as
`.xls` or `.xlsb`), password-protected workbooks, and the rare
worksheets whose XML xlkit cannot edit safely stop with an error that
says why; nothing is written. Writing into a cell inside a merged range
other than its top-left cell, or over part of an Excel table's header,
stops too. Writing into an Excel table's body grows the table when the
new rows extend it.

## Variable labels and value labels

A table read with dtaparser's `read_dta()` keeps Stata's variable labels
in each column's `label` attribute, and value labels in labelled
columns. haven's labelled columns work the same way.

`write_xlsx()` writes value labels as text by default, as Stata's
`export excel` does. `header = "labels"` puts the variable labels in the
header row, using the name where a column has no label:

```r
df <- dtaparser::read_dta("survey.dta")
write_xlsx(df, "survey.xlsx", header = "labels")
```

| argument | does |
|---|---|
| `header = "names"` (default) | header row has the column names |
| `header = "labels"` | header row has the variable labels |
| `header = "both"` | two header rows: names, then labels (blank where a column has none) |
| `header = FALSE` | no header row; the body starts in row 1 |
| `values = "labels"` (default) | a labelled column is written as its labels; a code without a label is written as the code |
| `values = "codes"` | a labelled column is written as its codes |

A code without a value label is written as the code, with a message
that names the cells:

```r
#> `sex` has 3 cells whose code has no value label: 9 in A5, A12 and A30.
#> They are written as codes.
#> ℹ Add a label with `dtaparser::with_labels()`, or write the column's codes with `values = "codes"`.
```

Going the other way, a sheet with long headers reads with short names
and keeps the headers as variable labels:

```r
df <- read_xlsx("survey.xlsx", names = "snake")
attr(df$age_at_first_birth, "label")
#> [1] "Age at first birth"
dtaparser::save_dta(df, "survey.dta")   # keeps them as variable labels
```

xlkit does not turn text back into value labels; use
`dtaparser::with_labels()` or `haven::labelled()` after reading.

## Messages and what to do about them

| message | means | do |
|---|---|---|
| `... does not exist` | no file at that path | check the name; the message suggests a similar file |
| `... is not an .xlsx workbook` | the file is another format with an `.xlsx` name | open it with the reader for its real format |
| `... has no sheet "X"` | the name is not a tab | use one of the names listed, or `xlsx_sheets()` |
| `Row 1 has text only in B1` (warning) | the header row looks like a title | give `header =` or `range =` |
| `New names:` | blank or repeated headers were given names | nothing, or choose `names =` |
| `col is text because N of its values are not ...` | a few cells keep a column of numbers or dates from being one | `types =` for that column, or fix the cells |
| `N cells in col could not be read as ...` (warning) | `types` asked for a type some cells do not fit | `xlsx_problems(df)`; choose `"text"` and convert yourself |
| `N cells hold Excel errors` (warning) | formulas in the workbook gave errors | `xlsx_problems(df)`; `"text"` keeps the error text |
| `N cells hold NaN or Inf` (warning) | `write_xlsx()` wrote numbers Excel cannot store as blank cells | replace them with numbers or `NA` first |
| `... already exists` | `write_xlsx()` would replace a file | `replace = TRUE`, or `write_sheet()` / `write_cells()` to keep the rest |
| `Sheet name ... which Excel does not allow` | a sheet name breaks Excel's rules | use the suggested name |
| `formats names ..., which is not a column` | a name in `formats`, `widths` or `styles` is not in the table | fix the name; the message suggests one |
| `... has N cells whose code has no value label` | some codes of a labelled column have no text | add labels, or `values = "codes"` |
| `a chart plots ..., which no longer matches` | a template's chart plots a fixed range and the new table is another size | make the chart plot an Excel table (see above) |
| `... is open in Excel` (Windows) | Excel locks open files | close it in Excel and run again |
| `cannot edit this worksheet: ...` | the sheet's XML uses a form xlkit cannot splice safely | open and save the file in Excel, then try again |

## Coming from readxl, writexl or openxlsx2

| task | readxl / writexl | openxlsx2 | xlkit |
|---|---|---|---|
| read a sheet by name | `read_excel(p, sheet = "S")` | `wb_to_df(p, sheet = "S")` | `read_xlsx(p, sheet = "S")` |
| table below titles | `read_excel(p, skip = 4)` | `wb_to_df(p, start_row = 5)` | `read_xlsx(p, header = 5)` |
| some column types | all of them: `col_types = c("text", "guess", ...)` | `wb_to_df(p, types = c(zip = "character"))` | `types = c(zip = "text")` |
| read every sheet | `lapply(excel_sheets(p), read_excel, path = p)` | a loop over `wb_get_sheet_names()` | `read_sheets(p)` |
| write several sheets | `write_xlsx(list(a = x, b = y), p)` | `write_xlsx(list(a = x, b = y), p)` | `write_xlsx(list(a = x, b = y), p)` |
| number formats | `xl_sheet(df, cols = list(xl_col_spec("share", format = xl_num_format("0.0%"))))` | `wb$add_numfmt(dims = wb_dims(x = df, cols = "share"), numfmt = "0.0%")` | `formats = c(share = "0.0%")` |
| fill a template | not possible | `wb_load(p)$add_data(sheet = "Cover", x = 1250, dims = "C4")$save(p)` | `write_cells(p, "Cover", C4 = 1250)` |

Differences that change results:

- xlkit guesses types from every cell; readxl uses the first 1,000 rows
  (`guess_max`), so a text cell further down is `NA` with a warning.
- readxl reads an Excel error as `NA` without a word; xlkit warns and
  lists it in `xlsx_problems()`.
- openxlsx2 writes `NA` as the Excel error `#N/A` unless told otherwise,
  so `SUM()` over the column fails; xlkit writes a blank cell.
- openxlsx2 fills a template by loading it into its model and saving the
  model, which keeps what the model covers; xlkit's `write_cells()`
  copies every part it does not write.
- readxl counts `skip` from the first row with data; xlkit's `header`
  and `range` are Excel's own row numbers.
- `xlkit::read_xlsx()` and `xlkit::write_xlsx()` have the same names
  as functions in readxl, writexl and openxlsx2. Attach only one of
  them, or write `xlkit::`.

## Reference

### `read_xlsx()`

```r
read_xlsx(path, sheet = 1, range = NULL, header = TRUE, names = "unique",
          types = NULL, na = "", dates = TRUE)
```

Reads one sheet into a tibble.

- `path`: an `.xlsx` or `.xlsm` file.
- `sheet`: a sheet name, or a position counting tabs from 1.
- `range`: `NULL` for the sheet's data, or a range as in
  [the table above](#choose-a-sheet-and-a-range).
- `header`: `TRUE`, `FALSE`, a row number, or consecutive row numbers.
- `names`: `"unique"`, `"snake"`, `"stata"`, `"lower"`, `"upper"`, or a
  function of a character vector.
- `types`: `NULL` to guess; one type; one per column; or named by
  column. Types are listed in [Column types](#column-types).
- `na`: text that means missing.
- `dates`: `FALSE` reads date-formatted numbers as numbers.

Returns a tibble. Columns whose name differs from their header text
have a `label` attribute. Warns once per call about cells that did not
convert and Excel errors; `xlsx_problems()` lists them.

### `read_sheets()`

```r
read_sheets(path, sheets = NULL, ...)
```

Reads several sheets. `sheets`: `NULL` for every worksheet (chart
sheets are skipped unless named), a vector of names or
positions, or one regular expression matched against the names. `...`
goes to `read_xlsx()`. Returns a named list of tibbles.

### `xlsx_sheets()`

```r
xlsx_sheets(path)
```

The sheet names, in tab order, as a character vector. Chart sheets are
included; reading one is an error.

### `xlsx_problems()`

```r
xlsx_problems(x)
```

The cells of `x` (a tibble from `read_xlsx()`) that did not convert or
held Excel errors: a tibble with `cell`, `column`, `row`, `value` and
`problem`.

### `write_xlsx()`

```r
write_xlsx(x, path, sheet = "Sheet1", header = "names", values = "labels",
           formats = NULL, widths = "auto", freeze = TRUE, filter = FALSE,
           header_style = xl_style(bold = TRUE), styles = NULL, merge = NULL,
           gap = 1, na = "", replace = FALSE)
```

Writes a new workbook and returns `path` invisibly.

- `x`: a data frame; a named list of data frames (one sheet each); or a
  named list whose elements are lists of data frames (several tables on
  one sheet, titled by their names).
- `sheet`: the sheet name when `x` is one data frame.
- `header`: `"names"`, `"labels"`, `"both"`, or `FALSE` for no header row.
  With `"both"`, the labels row is blank where a column has no label.
- `values`: `"labels"` or `"codes"`, for labelled columns.
- `formats`, `widths`, `freeze`, `filter`, `header_style`, `styles`: see
  [Format the output](#format-the-output). They apply to every sheet.
- `merge`: ranges to merge, such as `"A1:F1"`, on every sheet written;
  or a list of styles named by range,
  `list("A1:F1" = xl_style(align = "center"))`. Excel keeps only a
  merged range's top-left value, so the other cells must be empty.
- `gap`: blank rows between tables on one sheet.
- `na`: text to write for `NA`; `""` leaves the cell empty.
- `replace`: `TRUE` replaces `path` if it exists; `FALSE` stops instead.

### `write_sheet()`

```r
write_sheet(x, path, sheet, at = NULL, after = NULL, header = "names",
            values = "labels", formats = NULL, styles = NULL, na = "")
```

Writes `x` to one sheet of a workbook, keeping the rest of the file.
Returns `path` invisibly.

- `at`: `NULL` replaces the sheet's cells with `x` from `A1`; a cell
  such as `"H2"` writes `x` there and keeps the other cells.
- `after`: where a new sheet goes; `NULL` for after the last tab.
- With `at = NULL` on a new sheet, the header is bold and frozen and
  the widths fitted, as in `write_xlsx()`. With `at`, the cells keep
  their formats unless `formats` or `styles` say otherwise.

### `write_cells()`

```r
write_cells(path, sheet, ..., styles = NULL, merge = NULL)
```

Writes values into cells of an existing sheet (made if missing),
keeping the rest of the file. `...` are `cell = value` pairs, as in
[the table above](#fill-in-an-existing-workbook). `merge`: ranges to
merge. Returns `path` invisibly.

### `xl_style()`

```r
xl_style(bold = NULL, italic = NULL, underline = NULL, size = NULL, font = NULL,
         color = NULL, fill = NULL, border = NULL, align = NULL, valign = NULL,
         wrap = NULL, indent = NULL, format = NULL)
```

A cell style. Arguments left `NULL` keep what the cell has.

### `xl_formula()`

```r
xl_formula(x)
```

Marks text as Excel formulas, with or without the leading `=`. A vector
writes one formula per cell.

### `xlkit_example()`

```r
xlkit_example(name = NULL)
```

The path of an example workbook, or their names when `name` is `NULL`.
