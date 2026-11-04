# Labels in dtaparser's form

A variable label is a column's `label` attribute, and a labelled column
is dtaparser's `dtaparser_labelled` or haven's `haven_labelled`, both of
which keep the codes with a `labels` attribute mapping text to code.
xlkit reads these attributes directly and does not import dtaparser or
haven.

- `write_xlsx(header = "labels")` writes variable labels as the header;
  `values = "labels"` (the default, as in Stata's `export excel`) writes
  a labelled column as its labels.
- `read_xlsx()` keeps a header's text as the `label` attribute whenever
  the column's name differs from it, so `names = "stata"` gives short
  names and `save_dta()` writes the headers as variable labels.

xlkit does not make value labels from text on reading: which text
columns are categories, and which codes they should get, is the user's
choice.
