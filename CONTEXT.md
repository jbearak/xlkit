# xlkit

Reads and writes Excel `.xlsx` workbooks from R.

## Language

**Workbook**:
An `.xlsx` file: one or more sheets, plus the styles, names and other
parts they share.

**Sheet**:
One grid of a workbook, named on its tab. xlkit handles worksheets
only; chart sheets are listed but never read or written.
_Avoid_: worksheet (in user-facing text), tab, Excel table

**Cell reference**:
A cell's address as Excel shows it, such as `B3`. Rows count from 1
and columns from `A`, as on the screen.
_Avoid_: index, offset

**Range**:
A rectangle of cells written as two cell references, `B3:F40`. A range
may leave an edge open: `B3:F` runs to the last row with data.

**Header row**:
The row of a sheet whose cells name the columns. It is given as the row
number Excel shows, not as a count of rows to skip. Two or more header
rows are joined into one name per column.
_Avoid_: skip, first row (unless it is row 1)

**Body**:
The rows below the header row that hold the data, down to the last row
with a value in any column of the range.

**Cell type**:
What a cell stores: a number, text, a logical, an error such as `#N/A`,
or nothing. A date is a number whose number format shows a date.

**Column type**:
The R type a column of the body becomes: logical, integer, double,
character, `Date` or `POSIXct`.
_Avoid_: col_types (except as the argument name)

**Number format**:
The format code that says how Excel shows a cell's number, such as
`0.0%` or `yyyy-mm-dd`.
_Avoid_: style (which also covers fonts, fills and borders)

**Date system**:
The day a workbook counts its date numbers from: 1900 (Windows Excel's
default, with its leap-day bug) or 1904.

**Template**:
A workbook made by hand that a script fills in, keeping everything the
script does not write.

**Surgical edit**:
A change to an existing workbook that replaces only the cells and parts
it writes and copies every other byte of the file through unchanged.
_Avoid_: round trip, load and save (which rebuild the whole file)

**Variable label** and **value labels**:
dtaparser's names for a column's description and for the text of its
codes. xlkit can write them as the header and as the cell text, and
read a long header back as a variable label.
