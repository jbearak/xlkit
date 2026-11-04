# Column types are guessed from every cell, and a guess never loses a value

`read_xlsx()` looks at every cell of a column before choosing its type,
and chooses a type that holds every cell: one text cell among numbers
makes the column character. Numbers are integer when every one is whole
and fits R's integer, double otherwise. A number is a date when its
number format shows a date, as Excel decides when it displays it.

When the user asks for a type with `types`, a cell that does not fit
becomes `NA`, and xlkit warns once per call naming the first cells and
records all of them for `xlsx_problems()`. Excel errors are handled the
same way. So a value is never lost without a message.

`types` may name only some columns; the others are guessed.

## Considered options

- **Guess from the first 1,000 rows** (readxl's `guess_max`): faster on
  huge sheets, but a text cell in row 1,001 of a numeric column becomes
  `NA`. calamine has already parsed every cell, so looking at all of
  them is cheap.
- **Always double for numbers** (readxl): an `id` column of whole numbers
  prints as `1.0` in some contexts and joins awkwardly with integer
  keys. Integer when every value is whole is what Stata's `import excel`
  and pandas do in spirit.
