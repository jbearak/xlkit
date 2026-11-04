# The R bridge: Rust never calls R

Rust code runs only on plain memory. To read, Rust parses the sheet into
columns of its own (`Vec<f64>`, `Vec<i32>`, `Vec<u8>` for logicals,
strings as one byte buffer with offsets) and returns them through a C
ABI; one C file, `src/init.c`, copies them into R vectors and frees the
Rust side. To write, C reads R's vectors into a struct of pointers and
lengths (doubles, integers, and strings as `const char *` from
`translateCharUTF8`) and passes it to Rust, which only reads it.

Because Rust never calls R's API, an R error can never jump over a
Rust frame, and Rust never needs `PROTECT`. Rust reports failures as a
status code and a UTF-8 message, and the C side raises the R error after
Rust has returned and freed what it held.

## Considered options

- **dtaparser's bridge**, where Rust fills R vectors through shims that
  run under `R_UnwindProtect`. It keeps one copy of the data, which
  matters for 10 GB `.dta` files. A worksheet is at most 1,048,576 rows,
  and calamine holds the sheet in memory anyway, so a second copy for
  the copy into R costs little, and the bridge stays simple.
- **extendr**: a large dependency and macros for a bridge of a few
  hundred lines, as dta-parser ADR 0007 found.
