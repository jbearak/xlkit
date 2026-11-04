# Where this corpus comes from

This directory is a copy of Table Viewer's worksheet conformance corpus,
`conformance/` at commit 2bd172600cf66b8669c8ef38f1b826a57c075b52
(2026-08-30), corpus revision 1.1.0 (see `VERSION`, `manifest.json` and
`pins/`). Table Viewer is Copyright Jonathan Bearak, licensed GPL-3.0:
https://github.com/jbearak/table-viewer. The files are unchanged except
for this note and `pins/rust.json`, which pins xlkit's implementation to
the same revision.

`src/rust/src/conformance.rs` runs every case against xlkit's splice
(`src/rust/src/splice.rs`) with `cargo test`. Table Viewer's edits are
text a user typed; xlkit writes typed R values, so the test turns each
edit's text into the value Table Viewer would classify it as (a number,
or a date serial where the case's style context says the cell shows
dates). That conversion is the only adaptation; every case is run and
checked for its exact output bytes or its refusal code.
