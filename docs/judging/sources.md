# Documentation sources for judging

This file lists, for each library xlkit is compared against, the documentation that covers the 13 tasks in `docs/prior-art.md`. Use it to judge a library on its own docs, not on memory. Each bundle is a README, the user guide or vignettes, and the reference entries for the reading, writing, styling and editing functions. Pages that none of the 13 tasks needs (charts, conditional formatting, formula engines) are left out. Every bundle is under about 40,000 words.

Paths are relative to the pinned clone under `refs/others/<library>/`, which sits next to the xlkit repository, not inside it. Word counts come from `wc -w` on the pinned files and include markup. Where a project has no doc files in its repository, the URLs given are tied to a version.

The 13 tasks: 1 install; 2 read a sheet into a table; 3 choose what to read; 4 header row and column names; 5 column types; 6 dates and times; 7 missing values and Excel errors; 8 read every sheet at once; 9 write one table to a new workbook; 10 write several tables; 11 format output; 12 write into an existing workbook; 13 labels.

## readxl and writexl (one R toolset)

- readxl 1.6.0, tag `v1.6.0`, commit `9fcc1d21b77514d6b88ed15791054a8fb999e654`, https://github.com/tidyverse/readxl
- writexl 2.0.1, tag `v2.0.1`, commit `f4c283d996049da30d8704cbdddcf1e5579e2b49`, https://github.com/ropensci/writexl

| File | Words |
|---|---:|
| `readxl/README.md` | 1,312 |
| `readxl/vignettes/cell-and-column-types.Rmd` | 1,588 |
| `readxl/vignettes/sheet-geometry.Rmd` | 1,354 |
| `readxl/vignettes/articles/column-names.Rmd` | 446 |
| `readxl/vignettes/articles/multiple-header-rows.Rmd` | 374 |
| `readxl/vignettes/articles/readxl-workflows.Rmd` | 1,509 |
| `readxl/man/read_excel.Rd` | 974 |
| `readxl/man/excel_sheets.Rd` | 217 |
| `readxl/man/cell-specification.Rd` | 357 |
| `writexl/README.md` | 774 |
| `writexl/vignettes/a-getting-started.Rmd` | 708 |
| `writexl/vignettes/b-formatting.Rmd` | 774 |
| `writexl/vignettes/c-worksheets-workbooks.Rmd` | 889 |
| `writexl/vignettes/e-formulas-and-more.Rmd` | 808 |
| `writexl/man/write_xlsx.Rd` | 483 |
| `writexl/man/xl_sheet.Rd` | 844 |
| `writexl/man/xl_colrow_spec.Rd` | 391 |
| `writexl/man/xl_format.Rd` | 198 |
| `writexl/man/xl_format_groups.Rd` | 543 |
| `writexl/man/xl_properties.Rd` | 629 |
| `writexl/man/xl_merge.Rd` | 236 |
| `writexl/man/xl_filter.Rd` | 586 |
| `writexl/man/xl_table.Rd` | 470 |
| `writexl/man/xl_cell_general.Rd` | 1,022 |
| Total | 17,486 |

Left out: writexl `vignettes/d-charts-images.Rmd`, `vignettes/f-everything-at-once.Rmd` and the chart reference pages.

## openxlsx2

- openxlsx2 1.30, tag `v1.30`, commit `4625e480577321a1dadf6de53ab3e52d2eee0b11`, https://github.com/JanMarvin/openxlsx2

| File | Words |
|---|---:|
| `README.md` | 865 |
| `vignettes/openxlsx2.Rmd` | 2,119 |
| `vignettes/openxlsx2_read_to_df.Rmd` | 1,243 |
| `vignettes/openxlsx2_style_manual.Rmd` | 2,187 |
| `vignettes/Update-from-openxlsx.Rmd` | 1,821 |
| `man/wb_to_df.Rd` | 1,428 |
| `man/write_xlsx.Rd` | 562 |
| `man/wb_load.Rd` | 601 |
| `man/wb_save.Rd` | 552 |
| `man/wb_workbook.Rd` | 334 |
| `man/wb_add_worksheet.Rd` | 867 |
| `man/wb_remove_worksheet.Rd` | 78 |
| `man/sheet_names-wb.Rd` (`wb_get_sheet_names()`) | 152 |
| `man/wb_add_data.Rd` | 891 |
| `man/wb_add_data_table.Rd` | 890 |
| `man/wb_dims.Rd` | 1,198 |
| `man/wb_add_numfmt.Rd` | 512 |
| `man/wb_add_font.Rd` | 563 |
| `man/wb_add_cell_style.Rd` | 608 |
| `man/col_widths-wb.Rd` (`wb_set_col_widths()`) | 464 |
| `man/wb_freeze_pane.Rd` | 459 |
| `man/filter-wb.Rd` (`wb_add_filter()`) | 216 |
| `man/wb_merge_cells.Rd` | 297 |
| `man/wb_clean_sheet.Rd` | 314 |
| Total | 19,221 |

Left out: the charts, formulas and conditional-formatting vignettes.

## pandas

- pandas 3.1.1, tag `v3.1.1`, commit `3dcc6fbbbebc5e85dd3e83fe49b382ca7735cae1`, https://github.com/pandas-dev/pandas (sparse clone)
- The rendered docs are pinned to the 3.1 line at `https://pandas.pydata.org/pandas-docs/version/3.1/`; a 3.1.1 path returns 404. The docstrings in the clone are the exact 3.1.1 text that the reference pages are built from.

| Item | Location | Words |
|---|---|---:|
| README | `README.md` | 931 |
| Install, "Excel files" optional dependencies | https://pandas.pydata.org/pandas-docs/version/3.1/getting_started/install.html#excel-files | 71 |
| User guide, Excel sections (reading, `ExcelFile`, sheets, MultiIndex, columns, dates, converters, dtypes, writing, engines, style and formatting, calamine) | `doc/source/user_guide/io.rst` lines 3338-3889 | 2,563 |
| User guide, Styler "Export to Excel" | https://pandas.pydata.org/pandas-docs/version/3.1/user_guide/style.html#Export-to-Excel | 208 |
| `read_excel` reference | docstring in `pandas/io/excel/_base.py` lines 197-505 | 2,011 |
| `ExcelWriter` reference (`mode`, `if_sheet_exists`, `date_format`) | docstring in `pandas/io/excel/_base.py` lines 991-1184 | 899 |
| `ExcelFile` reference (`sheet_names`) | docstring in `pandas/io/excel/_base.py` lines 1569-1642 | 424 |
| `DataFrame.to_excel` reference | docstring in `pandas/core/generic.py` lines 2127-2248 | 701 |
| `Styler.to_excel` reference | docstring in `pandas/io/formats/style.py` lines 537-660 | 713 |
| Total | | about 8,520 |

The two web pages have no copy in the sparse clone. Their source is `doc/source/getting_started/install.rst` and `doc/source/user_guide/style.ipynb` at the pinned commit.

## openpyxl

- openpyxl 3.1.5, PyPI sdist `openpyxl-3.1.5.tar.gz`, sha256 `cf0e3cf56142039133628b5acffe8ef0c12bc902d2aadd3e0fe5878dc08d1050`, unpacked at `refs/others/openpyxl/openpyxl-3.1.5/`. Upstream Mercurial tag `3.1.5` at https://foss.heptapod.net/openpyxl/openpyxl could not be cloned, so there is no commit hash.
- The newest docs build is 3.1.3. URLs below are under `https://openpyxl.readthedocs.io/en/3.1.3/`. 3.1.4 and 3.1.5 were bug-fix releases.

| Item | Location | Words |
|---|---|---:|
| README | `openpyxl-3.1.5/README.rst` (sdist) | 160 |
| Tutorial (install, create, load, save, flags) | `tutorial.html` | 1,558 |
| Simple usage | `usage.html` | 383 |
| Read-only and write-only modes | `optimized.html` | 530 |
| Inserting, deleting, merging | `editing_worksheets.html` | 338 |
| Working with pandas | `pandas.html` | 300 |
| Dates and times | `datetime.html` | 608 |
| Styles (fonts, number formats, widths, merged cells) | `styles.html` | 1,356 |
| Filters and sorts | `filters.html` | 682 |
| Worksheet tables | `worksheet_tables.html` | 412 |
| Worksheet properties (freeze panes) | `worksheet_properties.html` | 315 |
| Data validation | `validation.html` | 352 |
| Reference: `openpyxl.reader.excel` (`load_workbook`) | `api/openpyxl.reader.excel.html` | 360 |
| Reference: `openpyxl.worksheet.worksheet` | `api/openpyxl.worksheet.worksheet.html` | 1,275 |
| Reference: `openpyxl.cell.cell` | `api/openpyxl.cell.cell.html` | 480 |
| Reference: `openpyxl.workbook.workbook` | `api/openpyxl.workbook.workbook.html` | 633 |
| Total | | about 9,740 |

## polars

- polars 2.1.0, tag `py-2.1.0`, commit `7f902bd3ffd27ff82d14278a09a295ff2f7aed92`, https://github.com/pola-rs/polars (sparse clone)
- Reading goes through fastexcel 0.21.0 (tag `v0.21.0`, commit `8f8ab1580c2564240fff7263697f6a556c038263`); writing goes through XlsxWriter 3.3.1 (tag `RELEASE_3.3.1`, commit `af5927c110cf01571046a3138600f63b256ea89a`). Their docs are included because polars passes `read_options` and format dicts straight to them.
- The online API docs at docs.pola.rs are not versioned, so the docstrings in the clone are the pinned reference.

| File | Covers | Words |
|---|---|---:|
| polars `README.md` | install, overview | 705 |
| polars `docs/source/user-guide/io/excel.md` | user guide: engines, read, write | 352 |
| polars `docs/source/src/python/user-guide/io/excel.py` | the guide's examples, which its `{{code_block(...)}}` lines include | 90 |
| polars `py-polars/docs/source/reference/io.rst` lines 53-60 | reference index for Excel | about 10 |
| polars `py-polars/src/polars/io/spreadsheet/functions.py` lines 255-410 | `read_excel` signature and docstring | 849 |
| polars `py-polars/src/polars/dataframe/frame.py` lines 3383-3794 | `DataFrame.write_excel` signature and docstring | 2,278 |
| fastexcel `README.md` | calamine engine | 729 |
| fastexcel `python/fastexcel/__init__.py` lines 286-400 | `load_sheet` options used through `read_options` | 711 |
| XlsxWriter `dev/docs/source/format.rst` | format keys used by `column_formats`, `header_format` | 4,551 |
| XlsxWriter `dev/docs/source/working_with_tables.rst` | table options behind `table_style` | 1,491 |
| Total | | about 11,700 |

## XLSX.jl

- XLSX.jl 0.13.2, tag `v0.13.2`, commit `13839d8c6fbbeb775c19b2b86669ba44c0f2dcd5`, https://github.com/JuliaData/XLSX.jl (moved from felipenoris/XLSX.jl)
- The rendered site is https://juliadata.github.io/XLSX.jl/. The `docs/src/api/*.md` pages only list functions and pull their text from docstrings in `src/`, so the docstrings are listed too.

| File | Covers | Words |
|---|---|---:|
| `README.md` | install | 213 |
| `docs/src/index.md` | overview, install | 178 |
| `docs/src/tutorial/XLSXtutorial.md` | tasks 2-4, 8-10, 12 | 2,393 |
| `docs/src/tutorial/FileIOtutorial.md` | `load` / `save` | 786 |
| `docs/src/migration.md` | `infer_eltypes` default | 198 |
| `docs/src/formatting/cellFormatting.md` | fonts, number formats, borders, fills | 3,062 |
| `docs/src/formatting/widthAndHeight.md` | column widths | 117 |
| `docs/src/formatting/mergedCells.md` | merged cells | 538 |
| `docs/src/formatting/freezeAndSplitPanes.md` | freeze panes | 442 |
| `docs/src/tables/excelTables.md` | Excel tables, autofilter, what survives an edit | 3,193 |
| `docs/src/api/files.md`, `api/data.md`, `api/tables.md`, `api/formats.md`, `api/sheetLayout.md` | reference index | 316 |
| Docstrings in `src/read.jl`, `src/table.jl`, `src/write.jl`, `src/tables_interface.jl`, `src/cell.jl`, `src/panes.jl`, `src/cellformats/*.jl` | `readxlsx`, `openxlsx`, `opentemplate`, `readtable`, `gettable`, `eachtablerow`, `readdata`, `writetable`, `writetable!`, `writexlsx`, `addsheet!`, `deletesheet!`, `setFormat`, `setFont`, `setBorder`, `setAlignment`, `setColumnWidth`, `mergeCells`, `freezePanes` | at most 17,553 |
| Total | | at most about 29,000 |

The docstring count is an upper bound: it counts every docstring in those files, not only the listed functions.

## SheetJS Community Edition

- xlsx 0.20.3, tag `v0.20.3`, commit `8a7cfd47bde8258c0d91df6a737bf0136699cdf8`, https://git.sheetjs.com/sheetjs/sheetjs. Release tarball: https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz.
- Docs source: https://git.sheetjs.com/sheetjs/docs.sheetjs.com at commit `8d1f8a0ea68341b33e51206392c095baad03cf11` (2026-08-02), cloned to `refs/others/sheetjs-docs/`. It pins xlsx 0.20.3 (`docz/package.json:41`). The site has no per-version URLs, so cite https://docs.sheetjs.com/docs/... together with this commit.
- Paths below are relative to `refs/others/sheetjs-docs/docz/docs/`.

| File | Covers tasks | Words |
|---|---|---:|
| `02-getting-started/01-installation/03-nodejs.md` | 1 | 1,353 |
| `08-api/index.md` | all (function list) | 657 |
| `08-api/03-parse-options.md` | 2, 3, 6, 8 | 2,863 |
| `08-api/05-write-options.md` | 9, 11 | 2,573 |
| `08-api/07-utilities/01-array.md` | 2-5, 7, 9, 10 | 3,033 |
| `08-api/07-utilities/08-wb.md` | 9, 10 | 338 |
| `07-csf/01-general.md` | 3 | 926 |
| `07-csf/02-cell.md` | 2, 5, 7 | 1,547 |
| `07-csf/03-sheet.md` | 3, 11, 12 | 1,251 |
| `07-csf/04-book.md` | 3, 6 | 233 |
| `07-csf/07-features/01-dates.md` | 6 | 3,372 |
| `07-csf/07-features/06-nf.md` | 6, 11 | 2,089 |
| `07-csf/07-features/09-colprops.md` | 11 | 1,933 |
| `07-csf/07-features/11-merges.md` | 11 | 1,076 |
| `02-getting-started/02-examples/02-export.md` | 9, 11, 13 | 4,320 |
| `02-getting-started/02-examples/04-import.md` | 2, 4 | 3,895 |
| `06-solutions/03-processing.md` | 12 | 607 |
| Total | | 32,066 |

## ExcelJS

- exceljs 4.4.0, tag `v4.4.0`, commit `ac96f9a61e9799c7776bd940f05c4a51d7200209`, https://github.com/exceljs/exceljs
- All prose docs are in the README. Pinned URL: https://github.com/exceljs/exceljs/blob/ac96f9a61e9799c7776bd940f05c4a51d7200209/README.md

| File | Covers tasks | Words |
|---|---|---:|
| `README.md` (whole file) | 1-12 | 24,478 |
| `index.d.ts` | 2, 3, 9-12 (signatures, `getSheetValues`, value types) | 6,326 |
| Total | | 30,804 |

To trim, keep `README.md` lines 1-1466 (install through styles), 2137-2192 (file I/O) and 2543-2802 (value types). The release history from line 2877 on is not needed.

## Support by task

"yes" means the docs and source show a function for the task. "limited" means the library does the task, but the user needs a loop around its calls (over sheets, rows or cells) or the gap noted below the table matters for xlkit's use. "no" means the library has nothing for the task: the user has to write the task's logic themselves or use another package.

For the rubric, "yes" and "limited" both mean the library supports the task, so the task is common to xlkit and that library, and the loop or the gap counts against it in the scores. "no" means the task is ours-only for that pair.

Stata is classified from general knowledge of its commands, as `AGENTS.md` requires; its documentation is not bundled. Task 1 does not apply to Stata, which needs no install, so it is not common with Stata.

| Task | readxl + writexl | openxlsx2 | pandas | openpyxl | polars | XLSX.jl | SheetJS CE | ExcelJS | Stata |
|---|---|---|---|---|---|---|---|---|---|
| 1 install | yes | yes | yes | yes | yes | yes | yes | yes | n/a |
| 2 read a sheet | yes | yes | yes | limited | yes | yes | limited | limited | yes |
| 3 choose what to read | yes | yes | limited | yes | limited | yes | yes | limited | yes |
| 4 header and names | limited | limited | yes | no | limited | limited | limited | no | limited |
| 5 column types | yes | yes | yes | no | yes | limited | no | no | limited |
| 6 dates and times | yes | yes | limited | yes | limited | limited | yes | limited | yes |
| 7 missing and errors | limited | yes | limited | yes | limited | limited | limited | yes | limited |
| 8 every sheet at once | limited | limited | yes | limited | yes | limited | limited | limited | limited |
| 9 write one table | yes | yes | yes | limited | yes | yes | yes | yes | yes |
| 10 several tables | limited | yes | yes | yes | yes | yes | yes | yes | yes |
| 11 format output | yes | yes | limited | yes | yes | limited | limited | yes | yes |
| 12 edit existing workbook | no | yes | limited | yes | no | yes | limited | limited | yes |
| 13 labels | no | limited | no | no | no | no | no | no | yes |

### readxl + writexl

1. yes: `install.packages(c("readxl", "writexl"))`.
2. yes: `read_excel()` returns a tibble.
3. yes: `sheet =` (name or position), `excel_sheets()`, `range = "Sheet!B3:D87"`, `skip =`, `cell_rows()`, `cell_limits()`.
4. limited: `col_names =`, `.name_repair =`; no multi-row headers.
5. yes: `col_types =` (positional only), `guess_max =` (default 1,000 rows).
6. yes: detection from the number format, 1904 flag read, always `POSIXct` in UTC; turned off only through `col_types`.
7. limited: `na =`; Excel error cells become `NA` with no trace.
8. limited: documented idiom `lapply(excel_sheets(p), read_excel, path = p)`, a loop over sheets.
9. yes: `write_xlsx(df, path)`.
10. limited: `write_xlsx(list(a = df1, b = df2))`, one table per sheet; no start cell.
11. yes: `xl_sheet(cols =, freeze =, auto_colwidth =, autofilter =, merge =)`, `xl_num_format()`, `format_headers =`.
12. no: writexl only creates new files (writexl #29, #66).
13. no: factors are written as their labels, but `haven_labelled` values are written as codes and variable labels are ignored, so neither half of the scenario works.

### openxlsx2

1. yes: `install.packages("openxlsx2")`.
2. yes: `read_xlsx()` / `wb_to_df()` return a `data.frame`.
3. yes: `sheet =`, `wb_get_sheet_names()`, `dims = "B3:D87"` or `"A3:F+"`, `start_row =`, `named_region =`.
4. limited: `col_names =`, `check_names =`; duplicates and blanks kept by default; no multi-row headers.
5. yes: `types = c(name = "character")`, `convert =`.
6. yes: `detect_dates =`, 1904 flag read, `Date` for date-only formats, UTC datetimes.
7. yes: `na =` as a vector or `list(strings =, numbers =)`; error cells kept as text.
8. limited: a loop over `wb_get_sheet_names()` on a loaded workbook.
9. yes: `write_xlsx()`, or `wb_workbook()$add_worksheet()$add_data()$save()`.
10. yes: named list to sheets; `wb_add_data(dims = "A20")` for several tables on one sheet.
11. yes: `wb_add_font()`, `wb_add_numfmt()`, `wb_set_col_widths(widths = "auto")`, `wb_freeze_pane()`, `wb_add_filter()`, `wb_merge_cells()`.
12. yes: `wb_load()` + `wb_clean_sheet()` / `wb_add_data(dims =)` + `wb_save()`; keeps template cell styles.
13. limited: vectors with a `labels` attribute are written as label text, with no switch for codes; variable labels are not used.

### pandas

1. yes: `pip install "pandas[excel]"`.
2. yes: `pd.read_excel()` returns a `DataFrame`.
3. limited: `sheet_name =`, `ExcelFile(p).sheet_names`, `usecols =`, `skiprows =`, `header =`, `nrows =`; no single range argument; Excel tables cannot be read by name.
4. yes: `header =` (including `header = [0, 1]` for two header rows), `names =`; blanks become `Unnamed: n`, duplicates `x.1`; no name cleaning.
5. yes: `dtype =`, `converters =`, `dtype_backend =`; every row is used for inference; a cell that does not fit raises.
6. limited: conversion happens in the engine from the number format, 1904 handled; no off switch (pandas #47269); writing time-zone-aware values raises.
7. limited: `na_values =`, `keep_default_na =`, `na_filter =`; 19 default NA strings; error cells become NaN.
8. yes: `read_excel(sheet_name = None)` returns a dict.
9. yes: `DataFrame.to_excel()`; silently replaces an existing file.
10. yes: `ExcelWriter` with `to_excel(sheet_name =, startrow =, startcol =)`.
11. limited: `freeze_panes =`, `autofilter =`, `Styler.to_excel()` for fonts and number formats; no column widths or autofit; `float_format` rounds the data.
12. limited: `ExcelWriter(mode = "a", engine = "openpyxl", if_sheet_exists = "replace" / "overlay")`; content openpyxl cannot model is lost.
13. no: only `to_excel(header = [...])` aliases; categoricals are written as text.

### openpyxl

1. yes: `pip install openpyxl`.
2. limited: `load_workbook()` then `ws.values` / `iter_rows(values_only = True)` give tuples, not a table.
3. yes: `wb["name"]`, `wb.worksheets[i]`, `wb.sheetnames`, `ws["B4:D50"]`, `ws.tables`.
4. no.
5. no: each cell has its own type.
6. yes: per-cell detection from the number format, `wb.epoch` for 1904; no off switch; time-zone-aware values raise.
7. yes: `None` for empty cells, error text with `data_type == "e"`.
8. limited: a loop over `wb.worksheets`.
9. limited: `Workbook()`, `ws.append()`, `dataframe_to_rows()`, `wb.save()`.
10. yes: `create_sheet()`, `ws.cell(row =, column =)`.
11. yes: `number_format`, `Font(bold = True)`, `column_dimensions[...].width` (no autofit), `freeze_panes`, `auto_filter.ref`, `merge_cells()`.
12. yes: `load_workbook()`, set cells, `save()`; drops shapes, extension-list features and VBA unless `keep_vba`.
13. no.

### polars

1. yes: `pip install "polars[excel]"`.
2. yes: `pl.read_excel()` returns a `DataFrame`.
3. limited: `sheet_name =`, `sheet_id =`, `table_name =`, `columns =`; ranges and title rows only through `read_options` (`header_row`, `n_rows`, `use_columns`); no function to list sheets.
4. limited: `has_header =`; blank and duplicate names generated; no multi-row headers or name cleaning.
5. yes: `infer_schema_length =` (default 100 rows), `schema_overrides =`, `read_options = {"dtype_coercion": "strict"}`.
6. limited: automatic through calamine, 1904 handled; no off switch; no time zone on read.
7. limited: blanks and common errors become null; fixed NA string list; no `na =` argument.
8. yes: `read_excel(sheet_id = 0)` returns a dict.
9. yes: `DataFrame.write_excel()`; silently replaces an existing file.
10. yes: `write_excel(workbook = <xlsxwriter.Workbook>, worksheet =, position =)`.
11. yes: `column_formats =`, `dtype_formats =`, `header_format =`, `autofit =`, `column_widths =`, `freeze_panes =`, `autofilter =`, `table_style =`; no merged cells.
12. no: XlsxWriter only creates new files (polars #10692).
13. no.

### XLSX.jl

1. yes: `Pkg.add("XLSX")`.
2. yes: `XLSX.readtable()` / `XLSX.readto(f, sheet, DataFrame)`.
3. yes: sheet name or index, `XLSX.sheetnames()`, `columns = "B:E"`, `first_row =`, `table_name =`, `XLSX.readdata(f, "S!A1:C9")`.
4. limited: `header =`, `column_labels =`, `normalizenames =`; blanks become `#Empty`, duplicates `_2`; no multi-row headers.
5. limited: `infer_eltypes =` promotes over the whole column or falls back to `Any`; no per-column override.
6. limited: automatic from the number format, 1904 handled; no off switch; no time zones.
7. limited: `missing_strings =`; error cells read as `missing`; `iserror()` / `geterror()` per cell only.
8. limited: a loop over `sheetnames()`.
9. yes: `XLSX.writetable(file, df; overwrite =)`; refuses to overwrite by default.
10. yes: `writetable(file, "A" => df1, "B" => df2)`; `writetable!(sheet, df; anchor_cell =)`.
11. limited: `setFormat()`, `setFont()`, `setColumnWidth()`, `freezePanes()`, `mergeCells()`; autofilter only through `as_table = true`; no autofit.
12. yes: `openxlsx(f, mode = "rw")`, `opentemplate()` + `writexlsx()`, `sheet["B3"] = x`, `deletesheet!()` / `addsheet!()`.
13. no.

### SheetJS CE

1. yes: `npm i https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz` (the npm registry copy is 0.18.5).
2. limited: `readFile()` + `utils.sheet_to_json()` give an array of objects with per-cell types.
3. yes: `wb.SheetNames`, `{sheets: [...]}`, `{bookSheets: true}`, `sheet_to_json(ws, {range: "B3:F200"})`, `{range: 4}` for title rows.
4. limited: first row or a `header` array; `__EMPTY` and `_1` names; no multi-row headers or cleaning.
5. no: per-cell types only; `raw` / `rawNumbers` switches.
6. yes: `cellDates`, `UTC`, `dateNF`, `WBProps.date1904`; several open date bugs.
7. limited: `defval =`; error cells other than `#NULL!` vanish in `sheet_to_json`.
8. limited: a loop over `wb.SheetNames`.
9. yes: `json_to_sheet()` / `aoa_to_sheet()` + `book_new()` + `writeFile()`.
10. yes: `book_append_sheet()`; `sheet_add_aoa()` / `sheet_add_json()` with `origin =`.
11. limited: number formats (`cell.z`), widths (`!cols`), merges (`!merges`), autofilter (`!autofilter`); bold, freeze panes and autofit are SheetJS Pro only.
12. limited: read, change the workbook object, write it again; CE loses styles, panes, charts and pivot tables.
13. no.

### ExcelJS

1. yes: `npm install exceljs`.
2. limited: `wb.xlsx.readFile()` + `eachRow()` / `getSheetValues()` give cell values and objects, not a table.
3. limited: `getWorksheet(name)`, `worksheets[i]`; no range or skip option.
4. no: no header handling on read; `columns: [{header, key}]` only on write.
5. no.
6. limited: automatic through `isDateFmt`, 1904 handled, no off switch, dates use a UTC wall-clock convention.
7. yes: `null` for empty cells, `{error: "#N/A"}` for errors.
8. limited: a loop with `eachSheet()`.
9. yes: `addWorksheet()` + `columns` + `addRows()` (or `addTable()`) + `writeFile()`.
10. yes: several `addWorksheet()` calls; `addTable({ref: "H2"})` for a position on one sheet.
11. yes: `numFmt`, `font`, `width`, `views` with `state: "frozen"`, `autoFilter`, `mergeCells()`; no autofit.
12. limited: `readFile()`, set cells, `writeFile()`; keeps cell styles but loses charts and pivot tables (ExcelJS #261, #1678, #1173).
13. no: header text can differ from the data key on write; nothing else.
