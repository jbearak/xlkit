# Review

Scores are in the order ergonomics, failure, findability, correctness, completeness, clarity. The code is schematic where the supplied material does not establish enough to produce the complete result; those limits affect the scores. The two parts of a task are scored separately for ergonomics and the lower score is shown. I treat the supplied B guide as its specification, since no B implementation or pinned executable is provided.

## Library A

1. `using Pkg; Pkg.add("XLSX")` — **[3, 1, 3, 3, 2, 2]**. Failure: no missing-requirement diagnostic is documented. Completeness: the page lists Julia and platforms and directs users to issues, but does not diagnose installation failures or detail system dependencies. Clarity: the example has no described result.

2. `df = XLSX.readto("report.xlsx", DataFrame)` — **[3, 1, 2, 3, 2, 2]**. Failure: the missing-file message is not specified. Findability: the table-reading tutorial is reached through the documentation rather than a task link on the front page. Completeness: examples and the cell reference explain inference and style, but the complete mapping for these five columns is not collected. Clarity: the sample gives a result but understanding all types requires following the cell and type references.

3. `df = XLSX.readto("report.xlsx", "Sales 2024", "B:F", DataFrame; first_row=5, stop_in_row_function=r -> XLSX.row_number(r) > 35); names = XLSX.sheetnames(XLSX.readxlsx("report.xlsx"))` — **[1, 1, 2, 3, 2, 2]**. Ergonomics: limiting the end row requires a predicate with a table-relative row number; listing names requires opening the workbook. Failure: the missing-sheet diagnostic is not given. Findability: the tutorial and references must be searched. Completeness: the pieces are present, but there is no bounded-range table example. Clarity: the row-number distinction and predicate take some work to combine.

4. `raw = XLSX.readdata("headers.xlsx", "Sheet1", "A1:E1"); df = XLSX.readto("headers.xlsx", "Sheet1", "A:E", DataFrame; column_labels=[:A, :B, :C, :D, :E])` — **[1, 1, 2, 3, 1, 1]**. For the two-row sheet, read both header rows and use `getMergedBaseCell` for merged positions, then construct names and retain the original text separately. Ergonomics: this needs multiple reads and user-built names and provenance. Failure: duplicate and blank-header behavior for the normal table reader is not specified. Findability: name options and merged-cell handling are in separate parts of the docs. Completeness: the ingredients are documented but not the combined repair and mapping. Clarity: there is no end-to-end example for either troublesome header.

5. `df = XLSX.readto("report.xlsx", DataFrame); # inspect zip and amount cell-by-cell, convert explicitly, and record failures` — **[1, 1, 1, 3, 1, 1]**. Ergonomics: inference does not provide the requested named type coercions or conversion report; user conversion and cell tracking are needed, and numeric ZIPs cannot recover zeroes absent a suitable format. Failure: no conversion diagnostic for this requested workflow is specified. Findability: inference is in the table reference; no direct conversion guide is supplied. Completeness: the main read is documented, not the requested conversion and audit. Clarity: no example assembles the necessary conversions.

6. `df = XLSX.readto("dates.xlsx", DataFrame); # inspect cell values/styles and manually derive stored serials` — **[1, 1, 1, 3, 1, 1]**. Ergonomics: date/time values are inferred from cell styles, but no raw-number switch is documented, so reconstructing serials requires additional work and date-system information. Failure: behavior of a text value in a date column is not specified. Findability: dates appear in examples and cell-type reference, not a date-system guide. Completeness: the 1904 system and raw-number workflow are not explained. Clarity: there is no complete example for both representations.

7. `df = XLSX.readto("messy.xlsx", DataFrame; missing_strings=["NA", ".", "-"]); xf = XLSX.readxlsx("messy.xlsx"); errs = XLSX.geterror(xf[1], "A1:Z100")` — **[1, 1, 2, 3, 2, 2]**. Ergonomics: a second workbook read and separate error-cell inspection are needed. Failure: the behavior of error cells in a numeric table column is not stated in the provided table-reading material. Findability: missing strings and error inspection are separated between references. Completeness: there is no end-to-end example showing how error cells become missing in a table. Clarity: the user must correlate the error matrix with the table manually.

8. `xf = XLSX.readxlsx("book.xlsx"); tables = Dict(name => DataFrame(XLSX.gettable(xf[name])) for name in XLSX.sheetnames(xf))` — **[1, 1, 2, 3, 1, 2]**. Ergonomics: the loop makes repeated table reads and conversions. Failure: the behavior of reading an entirely empty worksheet as a table is not specified. Findability: sheet listing and table construction are in the tutorial but not an all-sheets recipe. Completeness: no all-sheets or empty-sheet example is given. Clarity: the reader must combine the examples.

9. `XLSX.writetable("out.xlsx", df)` — **[3, 2, 2, 3, 2, 2]**. Failure: the reference says an existing file causes failure unless `overwrite=true`, but does not give a message with a remedy. Findability: writing a Tables.jl source is in the tutorial, reached from the docs. Completeness: the reference lists accepted types and string conversion, but does not explain every Excel representation and categorical edge case in one place. Clarity: the example shows the call but not the Excel result.

10. `XLSX.writetable("out.xlsx", "One" => a, "Two" => b, "Three" => c)`; for one sheet: `XLSX.openxlsx("stacked.xlsx", mode="w") do xf; s=xf[1]; s["A1"]="First"; XLSX.writetable!(s, a; anchor_cell=XLSX.CellRef("A2")); s["A$(nrow(a)+5)"]="Second"; XLSX.writetable!(s, b; anchor_cell=XLSX.CellRef("A$(nrow(a)+6)")); end` — **[1, 1, 2, 3, 2, 2]**. Ergonomics: stacking requires a writable workbook, separate titles, computed positions and two writes. Failure: the supplied sheet-name documentation does not specify the invalid-slash diagnostic. Findability: the relevant tutorial and write reference must be combined. Completeness: multi-sheet and anchored writes are covered, but not this stacking recipe or invalid sheet names. Clarity: the user must calculate offsets.

11. `XLSX.openxlsx("out.xlsx", mode="w") do xf; s=xf[1]; XLSX.writetable!(s, df; as_table=true); XLSX.setFont(s, "1:1"; bold=true); XLSX.setFormat(s, "B:B"; format="0.0%"); XLSX.setFormat(s, "C:C"; format="#,##0"); XLSX.freezePanes(s); # calculate content widths and call setColumnWidth per column; end` — **[1, 1, 2, 3, 1, 1]**. Ergonomics: it needs a workbook object and several calls; fitting widths requires user calculation. Failure: formatting uses cell ranges rather than named table-column format arguments, and the probe's diagnostic is not specified. Findability: formatting, widths, panes and table filters are in separate guides. Completeness: no automatic content-fit workflow or combined recipe is documented. Clarity: translating names into ranges and estimating widths is left to the reader.

12. `xf = XLSX.opentemplate("results.xlsx"); s = xf["Data"]; s[:] = missing; XLSX.writetable!(s, new_data); xf["Cover"]["C4"] = 1250; xf["Cover"]["C5"] = Date(2024,12,31); XLSX.writexlsx("results-new.xlsx", xf)` — **[1, 1, 2, 3, 2, 2]**. Ergonomics: clearing, rewriting, assigning and saving take several operations, and preservation of the chart is not assured. Failure: the docs warn that charts and other unsupported elements may be lost on overwrite, but do not state the outcome for this particular chart. Findability: the edit tutorial and cell-writing references must be combined. Completeness: preservation risks are identified, but exact chart and sheet-clearing behavior is not established. Clarity: the user must assemble the workflow and interpret the caution.

13. `# No documented Stata label-aware import/export; extract labels and construct headers and cell text externally.` — **[0, 1, 0, 0, 0, 0]**. Ergonomics: no label-aware workflow is documented for either direction. Failure: the unlabelled-code behavior is unspecified. Findability, correctness, completeness and clarity are zero because this task is not covered.

## Library B

1. `install.packages("remotes"); remotes::install_github("Library B")` — **[2, 3, 3, 3, 3, 3]**. Ergonomics: a fresh machine needs two installation calls.

2. `df <- read_xlsx("report.xlsx")` — **[3, 1, 3, 3, 3, 3]**. Failure: the guide does not specify the missing-path diagnostic.

3. `xlsx_sheets("report.xlsx"); df <- read_xlsx("report.xlsx", sheet="Sales 2024", range="B5:F40")` — **[3, 3, 3, 3, 3, 3]**. Each part uses one direct call.

4. `a <- read_xlsx("messy.xlsx", sheet="Headers", names="snake"); b <- read_xlsx("messy.xlsx", sheet="Two-row header", header=4:5)` — **[3, 3, 3, 3, 3, 3]**. Default repair makes names unique and preserves changed text as labels; the merged header is expanded.

5. `df <- read_xlsx("messy.xlsx", sheet="Types", types=c(zip="text", amount="number")); xlsx_problems(df)` — **[2, 3, 3, 3, 3, 3]**. Ergonomics: obtaining the table and the conversion report takes two calls. Numeric ZIP leading zeroes are recoverable when the Excel format displays them; absent such a format the original leading zeroes are not stored.

6. `df <- read_xlsx("dates1904.xlsx"); raw <- read_xlsx("dates1904.xlsx", dates=FALSE)` — **[3, 0, 3, 3, 3, 3]**. Failure: the default guess makes a column containing text character, so `unknown` does not produce the requested date column or a warning; specifying `types` would instead warn and report the cell. The one-call score applies separately to reading dates and reading stored numbers.

7. `df <- read_xlsx("messy.xlsx", na=c("NA", ".", "-")); xlsx_problems(df)` — **[2, 3, 3, 3, 3, 3]**. Ergonomics: obtaining the table and distinguishing errors from blanks requires two calls.

8. `all <- read_sheets("book.xlsx")` — **[3, 1, 3, 3, 2, 3]**. Failure: the guide does not say how an entirely empty sheet is represented. Completeness: it covers named lists, selection and per-sheet problems, but not the empty-sheet case.

9. `write_xlsx(df, "out.xlsx")` — **[3, 3, 3, 3, 3, 3]**. The guide lists the mappings, missing values and the existing-file protection and remedy.

10. `write_xlsx(list(One=a, Two=b, Three=c), "out.xlsx"); write_xlsx(list(Results=list(First=a, Second=b)), "stacked.xlsx", gap=2)` — **[3, 2, 3, 3, 3, 3]**. Failure: invalid sheet names produce an error naming the offending value; the supplied text does not say the message tells the user how to fix it.

11. `write_xlsx(df, "out.xlsx", formats=c(share="0.0%", amount="#,##0"), filter=TRUE)` — **[3, 1, 3, 3, 3, 3]**. Failure: the guide states that invalid `styles` keys error, but does not specify what happens for an unknown column in `formats`.

12. `write_sheet(new_data, "results.xlsx", sheet="Data"); write_cells("results.xlsx", sheet="Cover", C4=1250, C5=as.Date("2024-12-31"))` — **[2, 3, 3, 3, 3, 3]**. Ergonomics: replacing the sheet and writing Cover cells are two calls. The guide explicitly says the chart and unrelated workbook parts are preserved.

13. `write_xlsx(df, "survey.xlsx", header="labels"); df2 <- read_xlsx("long_headers.xlsx", names="stata")` — **[3, 0, 3, 3, 3, 3]**. Failure: an unlabelled code is written as the code without a warning, so the cell does not show a value label and the user is not alerted.

```json
{"B":{"1":[2,3,3,3,3,3],"2":[3,1,3,3,3,3],"3":[3,3,3,3,3,3],"4":[3,3,3,3,3,3],"5":[2,3,3,3,3,3],"6":[3,0,3,3,3,3],"7":[2,3,3,3,3,3],"8":[3,1,3,3,2,3],"9":[3,3,3,3,3,3],"10":[3,2,3,3,3,3],"11":[3,1,3,3,3,3],"12":[2,3,3,3,3,3],"13":[3,0,3,3,3,3]},"A":{"1":[3,1,3,3,2,2],"2":[3,1,2,3,2,2],"3":[1,1,2,3,2,2],"4":[1,1,2,3,1,1],"5":[1,1,1,3,1,1],"6":[1,1,1,3,1,1],"7":[1,1,2,3,2,2],"8":[1,1,2,3,1,2],"9":[3,2,2,3,2,2],"10":[1,1,2,3,2,2],"11":[1,1,2,3,1,1],"12":[1,1,2,3,2,2],"13":[0,1,0,0,0,0]}}
```
