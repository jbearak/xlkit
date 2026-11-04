# columns of cells with the same percent mistake share one message

    Code
      write_cells(path, "Cover", H1 = matrix(c(25, 40, 30, 50), 2), J1 = c(0.25, 0.4),
      styles = list(`H1:J2` = xl_style(format = "0%")))
    Message
      H1, I1, H2 and I2 have values such as 25 and the format "0%", which shows them as 2500%.
      i A percent format multiplies by 100. To show 25%, divide by 100 first.

