# xlkit

Read and write Excel `.xlsx` workbooks from R, and fill in workbooks
people made by hand without losing their charts and formats.

```r
library(xlkit)

sales <- read_xlsx("sales.xlsx", sheet = "Sales 2024", range = "B5:F40")

write_xlsx(list(Summary = summary, Detail = sales), "report.xlsx",
           formats = c(share = "0.0%", amount = "#,##0"))

write_cells("template.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))
```

- **Cells as Excel shows them.** A sheet by its tab name, a range as
  `B5:F40`, a header by its row number. No counting rows to skip.
- **Types from every cell.** A column with one text cell in row 5,000
  is text, not numbers with an `NA`. Name the columns whose type you
  want and the rest are guessed.
- **Nothing lost quietly.** Cells that do not fit a type, and Excel
  errors such as `#N/A`, are `NA` with a warning that names the cells,
  and `xlsx_problems()` lists them.
- **Readable output by default.** A bold header that stays in view, and
  columns as wide as their contents. Number formats by column name.
- **Templates stay intact.** `write_sheet()` and `write_cells()` rewrite
  only the cells they write and copy the rest of the file byte for
  byte: charts, comments, conditional formats, pivot tables, macros.
  `write_xlsx()` never replaces a file unless told to.
- **Stata's labels.** Variable labels as the header, value labels as
  the text, and long headers back as variable labels, in the form
  dtaparser's `read_dta()` and `save_dta()` use.

xlkit sits next to [datakit](https://github.com/jbearak/dta-parser),
which translates do-files to R: [docs/stata.md](docs/stata.md) gives the
xlkit line for each `import excel`, `export excel` and `putexcel` line.

## Install

```r
install.packages("remotes")
remotes::install_github("jbearak/xlkit")
```

R 4.2 or later. Building needs Rust (<https://rustup.rs>); on Windows,
Rtools as well. See [Install](docs/r.md#install) for each platform and
what to do when it fails.

## Guide

[docs/r.md](docs/r.md) covers every task with examples that run against
workbooks shipped with the package (`xlkit_example()`):

| to | see |
|---|---|
| read a sheet, and know each column's type | [Read a sheet](docs/r.md#read-a-sheet) |
| pick a sheet by name, list sheets, read a range or a table below titles | [Choose a sheet and a range](docs/r.md#choose-a-sheet-and-a-range) |
| handle blank, repeated and two-row headers, and clean names | [Header rows and column names](docs/r.md#header-rows-and-column-names) |
| choose some columns' types, and find cells that did not convert | [Column types](docs/r.md#column-types) |
| read dates, date-times, times and the 1904 date system | [Dates and times](docs/r.md#dates-and-times) |
| treat `NA`, `.` or `-` as missing, and find Excel errors | [Missing values and Excel errors](docs/r.md#missing-values-and-excel-errors) |
| read every sheet at once | [Read every sheet](docs/r.md#read-every-sheet) |
| write a table, and know what each column becomes | [Write a table](docs/r.md#write-a-table) |
| write one table per sheet, or several on one sheet | [Write several tables](docs/r.md#write-several-tables) |
| number formats, bold headers, widths, frozen panes, filters | [Format the output](docs/r.md#format-the-output) |
| fill in a template: replace a sheet, put values into cells | [Fill in an existing workbook](docs/r.md#fill-in-an-existing-workbook) |
| write Stata's variable and value labels, read headers as labels | [Variable labels and value labels](docs/r.md#variable-labels-and-value-labels) |
| understand a warning or an error | [Messages](docs/r.md#messages-and-what-to-do-about-them) |
| switch from readxl, writexl or openxlsx2 | [Coming from ...](docs/r.md#coming-from-readxl-writexl-or-openxlsx2) |
| look up every argument | [Reference](docs/r.md#reference) |

## Acknowledgements

xlkit reads with [calamine](https://github.com/tafia/calamine) and
writes new workbooks with
[rust_xlsxwriter](https://github.com/jmcnamara/rust_xlsxwriter). Its
design learned from readxl, writexl, openxlsx2, pandas, openpyxl,
polars, XLSX.jl, SheetJS and ExcelJS, and its surgical edits from
[Table Viewer](https://github.com/jbearak/table-viewer). See
[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## License

GPL-3.0. See [LICENSE](LICENSE).
