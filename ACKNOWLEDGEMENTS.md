# Acknowledgements

Last updated 2026-11-04.

xlkit's design draws on the projects below. The entries record design ideas, which `docs/prior-art.md` describes in detail with citations. Code xlkit has adapted is listed under [Code adapted](#code-adapted), with the files it went into; each of those files says so in a comment.

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

## Code adapted

### Table Viewer

- Copyright holder: Jonathan Bearak
- License: GPL-3.0
- URL: https://github.com/jbearak/table-viewer
- Adapted: the number-format section splitter, `format_sections()` in `src/spreadsheet-format.ts` (how quotes, `\` escapes, the `_` and `*` padding characters and brackets hide a `;`), in `src/rust/src/format.rs`'s `first_section()`. xlkit's date, time and duration classifier around it is its own.

### Howard Hinnant's date algorithms

- Source: "chrono-Compatible Low-Level Date Algorithms", https://howardhinnant.github.io/date_algorithms.html (the author places the algorithms in the public domain)
- Adapted: `days_from_civil()`, in `src/rust/src/read.rs`, to turn ISO 8601 dates stored in cells into Excel serial numbers.

## Dependencies

calamine and rust_xlsxwriter are compiled into xlkit, with the crates they depend on, all pinned in `src/rust/Cargo.lock`: quick-xml, zip, flate2, zlib-rs, zopfli, encoding_rs, codepage, atoi_simd, fast-float2, serde, log, memchr, byteorder, crc32fast, simd-adler32, hashbrown, indexmap, bumpalo and typed-path. rust_xlsxwriter adds no crates of its own beyond zip, which it shares with calamine. Their licenses are MIT, Apache-2.0, Zlib, BSD-3-Clause (part of encoding_rs) or Unlicense, or a choice among them, all compatible with GPL-3.0.

### calamine

- Copyright holder: Johann Tuffe (`LICENSE-MIT.md`: "Copyright (c) 2016 Johann Tuffe")
- License: MIT
- URL: https://github.com/tafia/calamine (version 0.38.0 studied)
- Role: reads xlsx files for `read_xlsx()`: cell values, Excel error codes, each cell's number format (from its cell styles), the 1904 flag, Excel tables, defined names, merged regions and sheet types. Read-only. Version 0.38.0, pinned.

### rust_xlsxwriter

- Copyright holder: John McNamara (`LICENSE_MIT`: "Copyright 2022-2026 John McNamara <jmcnamara@cpan.org>")
- License: MIT OR Apache-2.0 (xlkit can use it under MIT)
- URL: https://github.com/jmcnamara/rust_xlsxwriter (version 0.102.0)
- Role: writes the new workbooks of `write_xlsx()`, in `src/rust/src/write.rs`: numbers, text, booleans, formulas and blank cells, formats (number formats, fonts, fills, borders, alignment), column widths, frozen panes, autofilters and merged ranges. xlkit decides every cell, format and width in R and computes its own column widths, so rust_xlsxwriter's autofit is not used. It cannot modify an existing file, so xlkit needs a separate approach for `putexcel` and for replacing one sheet. Version 0.102.0, pinned.
