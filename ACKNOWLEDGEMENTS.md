# Acknowledgements

Last updated 2026-11-04.

xlkit's design draws on the projects below. At this stage xlkit has copied no code from any of them. The entries record design ideas, which `docs/prior-art.md` describes in detail with citations. If code is ever copied or adapted, the entry will say which files, and the project's license notice will be kept with that code.

Copyright holders are given as they appear in each project's LICENSE file at the version studied.

## Projects studied

### readxl

- Copyright holder: readxl authors (`LICENSE`: "COPYRIGHT HOLDER: readxl authors", 2026; `LICENSE.md`: "Copyright (c) 2026 readxl authors")
- License: MIT
- URL: https://github.com/tidyverse/readxl (version 1.6.0)
- Learned: a single `range` argument such as `"Sheet!B3:D87"`, coercion warnings that name the cell, and handling of the 1900 leap-year bug and the 1904 date system.

### writexl

- Copyright holder: Jeroen Ooms (`LICENSE`: "COPYRIGHT HOLDER: Jeroen Ooms", 2017)
- License: BSD-2-Clause
- URL: https://github.com/ropensci/writexl (version 2.0.1)
- Learned: a plain table of R types and the Excel cells they become, one time zone rule per workbook, and sheet-name repair with a warning.

### openxlsx2

- Copyright holder: openxlsx2 authors (`LICENSE`: "COPYRIGHT HOLDER: openxlsx2 authors", 2021-2026)
- License: MIT
- URL: https://github.com/JanMarvin/openxlsx2 (version 1.30)
- Learned: one cell-addressing argument used everywhere, ranges computed from a data frame, type overrides by column name, and keeping a template's cell styles when writing values into it.

### openxlsx

- Copyright holder: openxlsx authors (`LICENSE`: "COPYRIGHT HOLDER: openxlsx authors", 2014-2025)
- License: MIT
- URL: https://github.com/ycphs/openxlsx (version 4.2.9)
- Learned: that load, write and save is how R users fill templates today, and that two save functions with opposite overwrite defaults confuse users.

### tidyxl

- Copyright holder: Duncan Garmonsway (`LICENSE`: "COPYRIGHT HOLDER: Duncan Garmonsway", 2020)
- License: MIT
- URL: https://github.com/nacnudus/tidyxl (version 1.0.10)
- Learned: a one-row-per-cell reader for layouts no header rule can handle, with Excel error values kept in their own column.

### pandas

- Copyright holders: "AQR Capital Management, LLC, Lambda Foundry, Inc. and PyData Development Team" (2008-2011) and "Open source contributors" (2011-2026) (`LICENSE`)
- License: BSD-3-Clause
- URL: https://github.com/pandas-dev/pandas (version 3.1.1)
- Learned: a named policy for an existing sheet (`error`, `replace`, `overlay`), and freeze panes and autofilter as plain writer arguments.

### openpyxl

- Copyright holder: openpyxl (`LICENCE.rst`: "Copyright (c) 2010 openpyxl")
- License: MIT
- URL: https://foss.heptapod.net/openpyxl/openpyxl (version 3.1.5)
- Learned: 1-based Excel addresses for ranges and freeze panes, error cells kept apart from blanks, and a documented list of what a load-and-save cycle loses.

### polars

- Copyright holders: Ritchie Vink, and NVIDIA CORPORATION & AFFILIATES for some portions (`LICENSE`: "Copyright (c) 2025 Ritchie Vink", "Copyright (c) 2024 (Some portions) NVIDIA CORPORATION & AFFILIATES. All rights reserved.")
- License: MIT
- URL: https://github.com/pola-rs/polars (version 2.1.0)
- Learned: reading an Excel table by name, and positions given either as `"B4"` or as row and column numbers.

### XlsxWriter

- Copyright holder: John McNamara (`LICENSE.txt`: "Copyright (c) 2013-2026, John McNamara <jmcnamara@cpan.org>")
- License: BSD-2-Clause
- URL: https://github.com/jmcnamara/XlsxWriter (version 3.3.1)
- Learned: reusable format objects, autofit by estimating text width, and real Excel tables as an output option.

### python-calamine

- Copyright holder: dimastbk (`LICENSE`: "Copyright (c) 2021 dimastbk")
- License: MIT
- URL: https://github.com/dimastbk/python-calamine (version 0.9.1)
- Learned: how a calamine binding maps cells to host-language values, and that skipping leading empty rows by default shifts row numbers.

### fastexcel

- Copyright holder: ToucanToco (`LICENSE`: "Copyright (c) 2024 ToucanToco")
- License: MIT
- URL: https://github.com/ToucanToco/fastexcel (version 0.21.0)
- Learned: a `strict` or `coerce` choice for cells that do not fit a column's type, and returning the cells that failed conversion.

### XLSX.jl

- Copyright holder: Felipe Noronha Tavares and other contributors (`LICENSE`: "Copyright (c) 2018-2026 Felipe Noronha Tavares and other contributors")
- License: MIT
- URL: https://github.com/JuliaData/XLSX.jl (version 0.13.2)
- Learned: refusing to overwrite an existing file unless asked, cell assignment by address for template edits, and an explicit first row for tables below title rows.

### SheetJS Community Edition

- Copyright holder: SheetJS LLC (`LICENSE`: "Copyright (C) 2012-present SheetJS LLC")
- License: Apache-2.0
- URL: https://git.sheetjs.com/sheetjs/sheetjs (version 0.20.3)
- Learned: one `origin` argument to place a table at a cell or below existing data, and keeping each cell's value, displayed text and number format side by side.

### ExcelJS

- Copyright holder: Guyon Roche (`LICENSE`: "Copyright (c) 2014-2019 Guyon Roche")
- License: MIT
- URL: https://github.com/exceljs/exceljs (version 4.4.0)
- Learned: a column spec that pairs a display header with the data key and width, and returning Excel error text instead of dropping it.

### Stata

- Stata (`import excel`, `export excel`, `putexcel`) is proprietary software from StataCorp LLC.
- xlkit studied these commands only from general knowledge of how they behave. No Stata manuals, help files, website pages or code were read or used.
- Learned: the behavior xlkit aims to reproduce in R, one line per command.

## Planned dependencies

These crates are expected to be compiled into xlkit. Their license notices will ship with xlkit's source and binaries.

### calamine

- Copyright holder: Johann Tuffe (`LICENSE-MIT.md`: "Copyright (c) 2016 Johann Tuffe")
- License: MIT
- URL: https://github.com/tafia/calamine (version 0.38.0 studied)
- Role: reads xlsx files. Cell values, Excel error codes, date detection from number formats, the 1904 flag, named tables, merged regions and (since 0.38.0) cell styles. Read-only.

### rust_xlsxwriter

- Copyright holder: John McNamara (`LICENSE_MIT`: "Copyright 2022-2026 John McNamara <jmcnamara@cpan.org>")
- License: MIT OR Apache-2.0 (xlkit can use it under MIT)
- URL: https://github.com/jmcnamara/rust_xlsxwriter (version 0.102.0 studied)
- Role: writes new xlsx files with formats, column widths, autofit, freeze panes, autofilters, merged cells and Excel tables. It cannot modify an existing file, so xlkit needs a separate approach for `putexcel` and for replacing one sheet.
