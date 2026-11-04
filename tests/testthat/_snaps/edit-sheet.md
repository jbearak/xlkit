# a new sheet goes after the last tab, or after `after`

    Code
      write_sheet(months, path, sheet = "Third", after = "Cuver")
    Condition
      Error in `write_sheet()`:
      ! template.xlsx has no sheet "Cuver" to put the new sheet after.
      i Did you mean "Cover"?
      i Its sheets are "Cover", "Second", "Chart", "Data" and "Last".

# a chart over a fixed range is named when the rows no longer match

    Code
      write_sheet(months[1:5, ], path, sheet = "Data")
    Message
      A chart plots 'Data'!A2:B13, which no longer matches the 5 rows written to A2:B6.
      i To have the chart follow the data, make it plot an Excel table, and write into the table at its top-left cell with `at =`.

