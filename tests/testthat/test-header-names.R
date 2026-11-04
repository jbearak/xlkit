# docs/r.md, "Header rows and column names".

messy <- function() xlkit_example("messy.xlsx")

test_that("two header rows are joined, and a merged cell names each column", {
  df <- read_xlsx(messy(), sheet = "Two-row header", header = 4:5)
  expect_identical(names(df), c("Region", "Income 2020", "Income 2021", "Income 2022"))
  expect_identical(nrow(df), 4L)
  expect_identical(df$`Income 2020`, c(61.2, 48.5, 70.4, 55))
  expect_identical(df$Region, c("North", "South", "East", "West"))
})

test_that("header = FALSE names columns by letter and reads every row", {
  df <- read_xlsx(messy(), sheet = "Headers", header = FALSE)
  expect_identical(names(df), c("A", "B", "C", "D", "E"))
  expect_identical(nrow(df), 5L)
  expect_identical(df$A[[1]], "Region")
  expect_null(attr(df$A, "label"))
})

test_that("header = 1 is the same as the default here", {
  expect_identical(
    quietly(read_xlsx(messy(), sheet = "Headers", header = 1)),
    quietly(read_xlsx(messy(), sheet = "Headers"))
  )
})

test_that("blank and repeated headers are repaired with a message that names them", {
  msg <- expect_message(df <- read_xlsx(messy(), sheet = "Headers"), class = "rlang_message")
  expect_identical(names(df), c("Region", "Total", "Total_C", "D", "Share %"))
  text <- conditionMessage(msg)
  expect_match(text, "^New names:")
  expect_match(text, "C1 \"Total\" is `Total_C` (it repeats B1)", fixed = TRUE)
  expect_match(text, "D1 (blank) is `D`", fixed = TRUE)
  expect_match(text, "Choose another rule with `names =`, or set your own with `names(df) <- ...`.", fixed = TRUE)
})

test_that("each names rule gives the names in the docs' table", {
  read <- function(rule) suppressMessages(names(read_xlsx(messy(), sheet = "Headers", names = rule)))
  expect_identical(read("unique"), c("Region", "Total", "Total_C", "D", "Share %"))
  expect_identical(read("snake"), c("region", "total", "total_c", "d", "share_percent"))
  expect_identical(read("stata"), c("Region", "Total", "Total_C", "D", "Share"))
  expect_identical(read("lower"), c("region", "total", "total_c", "d", "share %"))
  expect_identical(read("upper"), c("REGION", "TOTAL", "TOTAL_C", "D", "SHARE %"))
  expect_identical(read(c("stata", "lower")), c("region", "total", "total_c", "d", "share"))
  expect_identical(read(function(x) toupper(substr(x, 1, 3))), c("REG", "TOT", "TOT_C", "D", "SHA"))
})

test_that("only repairs get a message, not the rule's own changes", {
  expect_no_message(read_xlsx(xlkit_example("report.xlsx"), names = "upper"))
  expect_no_message(read_xlsx(edge(), sheet = "Mixed", names = "stata"))
})

test_that("names are unique under every rule, and Stata names are valid", {
  # Names: "Age at first birth", "Total", "total", blank, "Share %",
  # "2020", "#", "if", "Region", "Region".
  for (rule in list("unique", "snake", "stata", "lower", "upper", c("snake", "upper"))) {
    n <- suppressMessages(names(read_xlsx(edge(), sheet = "Names", names = rule)))
    expect_false(anyDuplicated(n) > 0, label = paste(rule, collapse = "+"))
    expect_true(all(nzchar(n)))
  }
  stata <- suppressMessages(names(read_xlsx(edge(), sheet = "Names", names = "stata")))
  expect_identical(
    stata,
    c("Age_at_first_birth", "Total", "total", "D", "Share", "_2020", "G", "_if", "Region", "Region_J")
  )
  expect_true(all(grepl("^[A-Za-z_][A-Za-z0-9_]{0,31}$", stata)))
  snake <- suppressMessages(names(read_xlsx(edge(), sheet = "Names", names = "snake")))
  expect_identical(
    snake,
    c("age_at_first_birth", "total", "total_c", "d", "share_percent", "2020", "number", "if", "region", "region_j")
  )
})

test_that("a long header is cut to 32 characters under \"stata\", still unique", {
  out <- xlkit:::make_col_names(
    c(strrep("a", 40), strrep("a", 40)), c("A", "B"), "stata"
  )
  expect_identical(nchar(out$names), c(32L, 32L))
  expect_false(anyDuplicated(out$names) > 0)
})

test_that("\"stata\" names that its rule or 32-character cut makes repeat are in the message", {
  df <- data.frame(1, 2, 3, 4, 5, 6)
  names(df) <- c("Region", "Share %", "Share #", "Total", "Number of children ever born in the household, living",
                 "Number of children ever born in the household, dead")
  df$total <- 7
  path <- temp_xlsx()
  write_xlsx(df, path)
  msg <- expect_message(out <- read_xlsx(path, names = "stata"), class = "rlang_message")
  text <- conditionMessage(msg)
  expect_identical(names(out)[c(3, 6, 7)], c("Share_C", "Number_of_children_ever_born_i_F", "total"))
  expect_match(text, "C1 \"Share #\" is `Share_C` (it would repeat B1 after the rule)", fixed = TRUE)
  expect_match(
    text,
    "F1 \"Number of children ever born in the household, dead\" is `Number_of_children_ever_born_i_F` (cut to 32 characters, it would repeat E1)",
    fixed = TRUE
  )
  expect_no_match(text, "G1")
  # With a case, "Total" and "total" become equal too.
  msg <- expect_message(read_xlsx(path, names = c("stata", "lower")), class = "rlang_message")
  expect_match(conditionMessage(msg), "G1 \"total\" is `total_g` (it would repeat D1 after the rule)", fixed = TRUE)
})

test_that("a repeat of a repaired name is not said to come from the 32-character cut", {
  for (rule in list("snake", c("stata", "lower"))) {
    out <- xlkit:::make_col_names(c("a b", "a_b", "a_b_b"), c("A", "B", "C"), rule)
    expect_identical(out$repairs$why, c("rule", "rule"), label = paste(rule, collapse = "+"))
  }
})

test_that("a function rule's names made unique after its repeats are in the message", {
  out <- xlkit:::make_col_names(c("w", "x", "y", "z"), c("A", "B", "C", "D"),
                                function(x) c("a", "a_C", "a", "a_C_C"))
  expect_identical(out$names, c("a", "a_C", "a_C_C", "a_C_C_D"))
  expect_identical(out$repairs$index, c(3L, 4L))
  expect_identical(out$repairs$why, c("repeat", "rule"))
})

test_that("a name that differs from its header keeps the header as its label", {
  df <- suppressMessages(read_xlsx(messy(), sheet = "Headers", names = "snake"))
  expect_identical(attr(df$share_percent, "label"), "Share %")
  expect_identical(attr(df$total_c, "label"), "Total")
  expect_identical(attr(df$region, "label"), "Region")
  expect_null(attr(df$d, "label"))
  same <- read_xlsx(xlkit_example("report.xlsx"))
  expect_null(attr(same$id, "label"))
  long <- read_xlsx(edge(), sheet = "Names", names = "snake") |> suppressMessages()
  expect_identical(attr(long$age_at_first_birth, "label"), "Age at first birth")
})

test_that("a names function must return one name per header", {
  expect_error(
    read_xlsx(xlkit_example("report.xlsx"), names = function(x) "a"),
    "must return a character vector as long as its input"
  )
})

test_that("a Stata name cut to 32 characters does not end in an underscore", {
  expect_identical(xlkit:::stata_name("Children ever born to the woman, by age"), "Children_ever_born_to_the_woman")
  expect_identical(nchar(xlkit:::stata_name(strrep("a", 40))), 32L)
})
