# Review

Scores are in the order ergonomics, failure behavior, findability, correctness, completeness, clarity. Code assumes the relevant libraries are attached or imported and inputs already exist. A zero for an unsupported scenario means no complete library solution is documented; partial approaches are shown where useful.

## Library A

1. `install.packages("remotes"); remotes::install_github("Library A")`  
   **[2, 3, 3, 3, 3, 3]**. Ergonomics 2: installation requires two calls on a fresh machine.

2. `scores <- read_xlsx("report.xlsx")`  
   **[3, 3, 3, 3, 3, 3]**.

3. `sales <- read_xlsx("report.xlsx", sheet = "Sales 2024", range = "B5:F40"); xlsx_sheets("report.xlsx")`  
   **[3, 3, 3, 2, 3, 3]**. Correctness 2: the example calls Sales 2024 the fourth sheet, while the fixed scenario calls it the third; the name-based solution works either way.

4. `x <- read_xlsx("report.xlsx", sheet = "Headers", names = "snake"); attr(x$share_percent, "label")`  
   `y <- read_xlsx("report.xlsx", sheet = "Two-row header", header = 4:5)`  
   **[2, 3, 3, 3, 3, 3]**. Ergonomics 2: reading and inspecting the retained original header require two calls for the first part.

5. `x <- read_xlsx("report.xlsx", types = c(zip = "text", amount = "number")); xlsx_problems(x)`  
   **[2, 3, 3, 3, 3, 3]**. Ergonomics 2: the full problem list takes a second call. Numeric zip codes without a zero-padding format cannot recover missing leading zeros.

6. `read_xlsx("dates.xlsx"); read_xlsx("dates1904.xlsx"); read_xlsx("dates.xlsx", dates = FALSE)`  
   **[3, 3, 3, 3, 3, 3]**.

7. `x <- read_xlsx("report.xlsx", na = c("NA", ".", "-")); xlsx_problems(x)`  
   **[2, 3, 3, 3, 3, 3]**. Ergonomics 2: distinguishing errors from blanks requires a second call.

8. `all <- read_sheets("report.xlsx")`  
   **[3, 3, 3, 3, 3, 3]**.

9. `write_xlsx(df, "out.xlsx")`  
   **[3, 3, 3, 3, 3, 3]**.

10. `write_xlsx(list(One = a, Two = b, Three = c), "out.xlsx")`  
    `write_xlsx(list(Results = list("Title 1" = a, "Title 2" = b)), "stacked.xlsx", gap = 2)`  
    **[3, 3, 3, 3, 3, 3]**.

11. `write_xlsx(df, "out.xlsx", formats = c(share = "0.0%", amount = "#,##0"), filter = TRUE)`  
    **[3, 3, 3, 3, 3, 3]**.

12. `write_sheet(df, "results.xlsx", sheet = "Data"); write_cells("results.xlsx", sheet = "Cover", C4 = 1250, C5 = as.Date("2024-12-31"))`  
    **[2, 3, 3, 3, 3, 3]**. Ergonomics 2: the two edits require separate calls; the date also needs an R date value.

13. `write_xlsx(df, "survey.xlsx", header = "labels"); x <- read_xlsx("survey.xlsx", names = "snake")`  
    **[3, 3, 3, 3, 3, 3]**. Each direction has one call; the label attribute is retained automatically.

## Library B

1. `using Pkg; Pkg.add("XLSX")`  
   **[3, 1, 3, 3, 2, 2]**. Failure 1: the docs do not describe a missing system requirement failure. Completeness 2: platforms and Julia version are stated, but installation troubleshooting is only a general issue link. Clarity 2: the install example has no described result.

2. `df = XLSX.readto("report.xlsx", DataFrame)`  
   **[3, 1, 2, 3, 2, 2]**. Failure 1: a missing path's message is not documented. Findability 2: reading a table is in the tutorial beyond the front page. Completeness 2: examples and style-sensitive values explain much of the result, but not a complete column-type mapping for this sheet. Clarity 2: the example shows output but the inference rules need reference material.

3. `df = XLSX.readto("report.xlsx", "Sales 2024", "B:F", DataFrame; first_row=5, stop_in_row_function=r -> XLSX.row_number(r) > 35)`  
   `xf = XLSX.readxlsx("report.xlsx"); XLSX.sheetnames(xf)`  
   **[2, 1, 2, 3, 2, 2]**. Ergonomics 2: listing sheet names needs opening the workbook first, and the stop predicate uses a table-relative row count. Failure 1: the misspelled sheet's message is not specified. Findability 2: the tutorial and reference must be consulted. Completeness 2: the documentation gives column selection and stopping mechanisms but no direct bounded-table example. Clarity 2: combining the separate row and column controls requires some work.

4. `xf = XLSX.opentemplate("report.xlsx"); sh = xf["Two-row header"]; XLSX.getMergedBaseCell(sh, "C4")`  
   Use the raw header cells and merged-base values to construct unique labels and supply `column_labels` to `gettable`.  
   **[1, 1, 2, 3, 1, 1]**. Ergonomics 1: manually repairing and combining headers takes several operations. Failure 1: the plain table reader's duplicate/blank-header behavior is not specified. Findability 2: header options and merged cells are in separate material. Completeness 1: the primitives are described, but no full repair and provenance workflow is given. Clarity 1: the reader must assemble the approach without a scenario example.

5. `df = XLSX.readto("report.xlsx", DataFrame); bad = findall(x -> x isa AbstractString && isnothing(tryparse(Float64, x)), df.amount)`  
   Convert the remaining values and zip codes explicitly, retaining the original cells for inspection.  
   **[1, 1, 1, 3, 1, 1]**. Ergonomics 1: type conversion and failure reporting require custom code, including handling mixed numeric/text zip values. Failure 1: no library conversion diagnostic is documented. Findability 1: the necessary raw types and inference are scattered in references. Completeness 1: no requested-type and per-cell conversion workflow is documented. Clarity 1: there is no example of this mixed-type task.

6. `df = XLSX.readto("dates.xlsx", DataFrame); df1904 = XLSX.readto("dates1904.xlsx", DataFrame)`  
   Inspect underlying cells for stored serial values; no documented table option returns them directly.  
   **[1, 1, 1, 3, 1, 1]**. Ergonomics 1: recovering raw serials requires lower-level cell work rather than a documented table option. Failure 1: the stray-text date probe is not described. Findability 1: date behavior is only implied by cell and table references. Completeness 1: the 1904 system and raw serial workflow are not explained. Clarity 1: no complete dates-and-times example covers the scenario.

7. `df = XLSX.readto("report.xlsx", DataFrame; missing_strings=["NA", ".", "-"]); xf = XLSX.readxlsx("report.xlsx"); errors = XLSX.geterror(xf[1], "A1:Z100")`  
   **[1, 1, 1, 3, 1, 1]**. Ergonomics 1: reading and separately locating errors takes several calls and a chosen range. Failure 1: the table reader's treatment of Excel error values is not specified. Findability 1: missing strings and error inspection are in separate references. Completeness 1: no end-to-end description establishes that errors become missing in the table. Clarity 1: assembling the missing/error workflow is left to the reader.

8. `xf = XLSX.readxlsx("report.xlsx"); all = Dict(n => DataFrame(XLSX.gettable(xf[n])) for n in XLSX.sheetnames(xf))`  
   **[1, 1, 1, 3, 1, 1]**. Ergonomics 1: opening, listing, and reading twelve sheets entails many calls. Failure 1: empty-sheet table behavior is not specified. Findability 1: the loop must be inferred from sheet and table examples. Completeness 1: no complete all-sheets or empty-sheet recipe is supplied. Clarity 1: the collection and empty case are left to the reader.

9. `XLSX.writetable("out.xlsx", df)`  
   **[3, 1, 2, 3, 2, 2]**. Failure 1: failure on an existing file is documented but the actual message is not. Findability 2: writing is described in the tutorial and reference beyond the front page. Completeness 2: types, missing values and overwrite are addressed, but categorical conversion details are not fully illustrated. Clarity 2: the table-writing example does not show the resulting Excel cell types.

10. `XLSX.writetable("out.xlsx", "One"=>a, "Two"=>b, "Three"=>c)`  
    `XLSX.openxlsx("stacked.xlsx", mode="w") do f; s=f[1]; s["A1"]="Title 1"; XLSX.writetable!(s,a; anchor_cell=XLSX.CellRef("A2")); s["A$(size(a,1)+5)"]="Title 2"; XLSX.writetable!(s,b; anchor_cell=XLSX.CellRef("A$(size(a,1)+6)")); end`  
    **[1, 1, 2, 3, 2, 2]**. Ergonomics 1: the stacked layout requires opening a workbook, placing titles, computing positions and writing each table. Failure 1: an invalid worksheet name's message is not documented. Findability 2: multi-sheet and anchored writing are in the tutorial. Completeness 2: primitives are given, but no complete titled stacking recipe. Clarity 2: the pieces are understandable but must be combined.

11. Create a workbook, `writetable!` with `as_table=true`, then use `setFont`, `setFormat` on the relevant column ranges, `freezePanes`, and compute widths before `setColumnWidth`; save with `writexlsx`.  
    **[1, 1, 2, 3, 1, 1]**. Ergonomics 1: formatting requires multiple calls, cell ranges and manual width calculations. Failure 1: a nonexistent column name is not a documented format argument or probe. Findability 2: formatting, widths, panes and tables are separate documentation sections. Completeness 1: individual operations are covered but automatic content fitting and the complete workflow are not. Clarity 1: no single example assembles the requested result.

12. `xf = XLSX.opentemplate("results.xlsx"); xf["Data"][:] = missing; XLSX.writetable!(xf["Data"], df); xf["Cover"]["C4"] = 1250; xf["Cover"]["C5"] = Date(2024,12,31); XLSX.writexlsx("updated.xlsx", xf)`  
    **[0, 1, 2, 3, 1, 1]**. Ergonomics 0: the documentation does not establish that the full template, particularly its chart, can be kept as required. Failure 1: the warning flags chart risk but does not say what happens to this chart. Findability 2: existing-file editing is in the tutorial. Completeness 1: editing primitives and a warning are present, but preservation limits are not resolved for the template. Clarity 1: the conflicting broad preservation claim and chart warning leave the outcome uncertain.

13. No documented support for Stata variable and value labels or for attaching long headers as variable labels.  
    **[0, 1, 0, 0, 0, 0]**. Ergonomics 0: no complete label workflow is documented. Failure 1: the behavior for an unlabelled code is not documented. All documentation dimensions are 0 because the task is not covered.

```json
{"A":{"1":[2,3,3,3,3,3],"2":[3,3,3,3,3,3],"3":[3,3,3,2,3,3],"4":[2,3,3,3,3,3],"5":[2,3,3,3,3,3],"6":[3,3,3,3,3,3],"7":[2,3,3,3,3,3],"8":[3,3,3,3,3,3],"9":[3,3,3,3,3,3],"10":[3,3,3,3,3,3],"11":[3,3,3,3,3,3],"12":[2,3,3,3,3,3],"13":[3,3,3,3,3,3]},"B":{"1":[3,1,3,3,2,2],"2":[3,1,2,3,2,2],"3":[2,1,2,3,2,2],"4":[1,1,2,3,1,1],"5":[1,1,1,3,1,1],"6":[1,1,1,3,1,1],"7":[1,1,1,3,1,1],"8":[1,1,1,3,1,1],"9":[3,1,2,3,2,2],"10":[1,1,2,3,2,2],"11":[1,1,2,3,1,1],"12":[0,1,2,3,1,1],"13":[0,1,0,0,0,0]}}
```
