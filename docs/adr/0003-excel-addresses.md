# Cells are named as Excel shows them

Every argument that points into a sheet uses Excel's own address: a
sheet by its tab name (or its position counting from 1), a range as
`B5:F40` (with open edges `B5:F`, `B:F`, `5:40`, a single corner `B5`,
or the name of an Excel table or defined name), and a header row by the
row number Excel shows, `header = 5` or `header = 4:5`. Messages and
`xlsx_problems()` name cells the same way (`C2003`).

The user is looking at the sheet in Excel while writing the call, and
Excel shows these numbers. readxl's `skip` counts rows from the first
row with data, pandas' `header` counts from 0, and both make the user
subtract.

## Considered options

- **`skip` and `n_max`** as readxl and pandas do: familiar, but the
  count depends on blank rows above the data, which the user cannot see
  in Excel.
- **A cell-limits object** (readxl's `cell_limits()`): exact, but one
  more function to learn for what a string already says.
