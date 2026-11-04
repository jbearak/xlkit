# Cases from the first review of the reading code (fixtures/review.xlsx).
review <- function() fixture("review.xlsx")

test_that("an Excel table without a header row reads its own cells only", {
  df <- quietly(read_xlsx(review(), range = "NoHeader"))
  expect_equal(nrow(df), 2)
  expect_equal(names(df), c("A", "B"))
  expect_equal(df$A, c(1L, 3L))
})

test_that("a table with only its header row reads as names and no rows", {
  df <- quietly(read_xlsx(review(), range = "OnlyHeader"))
  expect_equal(names(df), c("left", "right"))
  expect_equal(nrow(df), 0)
  # The workbook's other names still resolve.
  expect_equal(nrow(quietly(read_xlsx(review(), range = "NoHeader"))), 2)
})

test_that("a defined name in another script can be a range", {
  df <- quietly(read_xlsx(review(), range = "Données", header = FALSE))
  expect_equal(df$A, c(1L, 3L))
})

test_that("a date-time made text by a stray cell keeps its milliseconds", {
  df <- quietly(read_xlsx(review(), sheet = "Stamps"))
  expect_type(df$stamp, "character")
  expect_equal(df$stamp, c("2024-01-01 00:00:00.125", "unknown"))
})

test_that("a conditional number format is classified by the value's section", {
  df <- quietly(read_xlsx(review(), sheet = "Conditional"))
  expect_equal(df$x, c(100L, 250L))
})

test_that("negative zero-padded numbers keep every zero", {
  df <- quietly(read_xlsx(review(), sheet = "Padded", types = "text"))
  expect_equal(df$code, c("-00042", "00007"))
})

test_that("lower-casing Stata names cannot make a reserved word", {
  df <- quietly(read_xlsx(review(), sheet = "Reserved", names = c("stata", "lower")))
  expect_equal(names(df), c("_if", "_float"))
})
