//! xlkit's Rust core, called from src/init.c through a C ABI.
//!
//! ADR 0002: Rust never calls R's API. Each function takes UTF-8 paths
//! and returns an `XlResult` of plain buffers that C copies into R
//! vectors and then frees with `xl_result_free()`. A failure is a status
//! code and a UTF-8 message; R raises the error after Rust's memory is
//! freed. A panic is caught here and reported the same way, so it never
//! unwinds into C. To write, C hands Rust an `XlPlan` of pointers into
//! R's vectors, which Rust only reads while `xl_write()` runs.

#[cfg(test)]
mod conformance;
mod edit;
mod format;
mod package;
mod read;
mod splice;
mod styles;
mod write;

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr::null_mut;

/// Plain buffers for R: integers, doubles, bytes and strings (one UTF-8
/// byte buffer and `n_strings + 1` offsets into it).
#[repr(C)]
pub struct XlResult {
    pub status: i32,
    pub message: *mut c_char,
    pub ints: *mut i32,
    pub n_ints: usize,
    pub doubles: *mut f64,
    pub n_doubles: usize,
    pub bytes: *mut u8,
    pub n_bytes: usize,
    pub str_data: *mut u8,
    pub n_str_data: usize,
    pub str_offsets: *mut usize,
    pub n_strings: usize,
}

fn leak<T>(v: Vec<T>) -> (*mut T, usize) {
    let n = v.len();
    if n == 0 {
        return (null_mut(), 0);
    }
    let boxed = v.into_boxed_slice();
    (Box::into_raw(boxed) as *mut T, n)
}

/// # Safety
/// `ptr` and `n` must come from `leak()`.
unsafe fn unleak<T>(ptr: *mut T, n: usize) {
    if !ptr.is_null() {
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(ptr, n)));
    }
}

#[derive(Default)]
struct Out {
    ints: Vec<i32>,
    doubles: Vec<f64>,
    bytes: Vec<u8>,
    strings: Vec<String>,
}

impl Out {
    fn into_result(self) -> XlResult {
        let mut data = Vec::new();
        let mut offsets = Vec::with_capacity(self.strings.len() + 1);
        offsets.push(0usize);
        for s in &self.strings {
            data.extend_from_slice(s.as_bytes());
            offsets.push(data.len());
        }
        let n_strings = self.strings.len();
        let (ints, n_ints) = leak(self.ints);
        let (doubles, n_doubles) = leak(self.doubles);
        let (bytes, n_bytes) = leak(self.bytes);
        let (str_data, n_str_data) = leak(data);
        let (str_offsets, _) = leak(offsets);
        XlResult {
            status: 0,
            message: null_mut(),
            ints,
            n_ints,
            doubles,
            n_doubles,
            bytes,
            n_bytes,
            str_data,
            n_str_data,
            str_offsets,
            n_strings,
        }
    }
}

/// A failure that R turns into an error: a status code and a message.
pub(crate) trait Fail {
    fn code(&self) -> i32;
    fn message(&self) -> String;
}

impl Fail for read::Failure {
    fn code(&self) -> i32 {
        read::Failure::code(self)
    }
    fn message(&self) -> String {
        read::Failure::message(self)
    }
}

fn failed(status: i32, message: &str) -> XlResult {
    let message = CString::new(message.replace('\0', " ")).unwrap_or_default();
    let mut r = Out::default().into_result();
    r.status = status;
    r.message = message.into_raw();
    r
}

/// Run `f` on the UTF-8 strings behind `args`, turning failures and panics
/// into a status and message.
fn run<E: Fail, F: FnOnce(&[&str]) -> Result<Out, E>>(args: &[*const c_char], f: F) -> XlResult {
    let mut strs = Vec::with_capacity(args.len());
    for &p in args {
        if p.is_null() {
            return failed(9, "a NULL string was passed to xlkit's Rust code");
        }
        match unsafe { CStr::from_ptr(p) }.to_str() {
            Ok(s) => strs.push(s),
            Err(_) => return failed(9, "a string passed to xlkit's Rust code is not UTF-8"),
        }
    }
    match catch_unwind(AssertUnwindSafe(|| f(&strs))) {
        Ok(Ok(out)) => out.into_result(),
        Ok(Err(e)) => failed(e.code(), &e.message()),
        Err(panic) => {
            let what = panic
                .downcast_ref::<&str>()
                .map(|s| s.to_string())
                .or_else(|| panic.downcast_ref::<String>().cloned())
                .unwrap_or_default();
            failed(8, &what)
        }
    }
}

/// Sheets of a workbook: strings are the names; ints are
/// `[is_1904, type of each sheet...]`.
#[no_mangle]
pub extern "C" fn xl_info(path: *const c_char) -> XlResult {
    run::<read::Failure, _>(&[path], |a| {
        let info = read::info(a[0])?;
        let mut out = Out::default();
        out.ints.push(info.is_1904 as i32);
        out.ints.extend(info.types);
        out.strings = info.names;
        Ok(out)
    })
}

/// Defined names and Excel tables: strings are `name, sheet, formula`
/// for each; ints are five per name (see `read::Named`).
#[no_mangle]
pub extern "C" fn xl_names(path: *const c_char) -> XlResult {
    run::<read::Failure, _>(&[path], |a| {
        let mut out = Out::default();
        for n in read::names(a[0])? {
            out.strings.extend([n.name, n.sheet, n.formula]);
            out.ints.extend(n.dims);
        }
        Ok(out)
    })
}

/// Copy `from` to `to`, creating `to` only if it does not exist: the
/// check and the creation are one step (`create_new`), so a file another
/// program made is never overwritten. ints is `[1]` when written, `[0]`
/// when `to` already exists. A copy that fails part way removes `to`.
#[no_mangle]
pub extern "C" fn xl_create_new(from: *const c_char, to: *const c_char) -> XlResult {
    run::<read::Failure, _>(&[from, to], |a| {
        let mut out = Out::default();
        let io = |e: std::io::Error| read::Failure::Io(e.to_string());
        let mut dest = match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(a[1])
        {
            Ok(f) => f,
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                out.ints.push(0);
                return Ok(out);
            }
            Err(e) => return Err(io(e)),
        };
        let copied = std::fs::File::open(a[0])
            .and_then(|mut src| std::io::copy(&mut src, &mut dest))
            .and_then(|_| dest.sync_all());
        if let Err(e) = copied {
            drop(dest);
            let _ = std::fs::remove_file(a[1]);
            return Err(io(e));
        }
        out.ints.push(1);
        Ok(out)
    })
}

/// One sheet's used cells (see `read::Grid`): ints are
/// `[first_row, first_col, nrow, ncol, is_1904, n_merged, merged...]`;
/// bytes are the kinds then the pads; doubles the numbers; strings the
/// texts, all column-major.
#[no_mangle]
pub extern "C" fn xl_read(path: *const c_char, sheet: *const c_char) -> XlResult {
    run::<read::Failure, _>(&[path, sheet], |a| {
        let grid = read::read_sheet(a[0], a[1])?;
        let mut out = Out::default();
        out.ints.extend([
            grid.first_row,
            grid.first_col,
            grid.nrow as i32,
            grid.ncol as i32,
            grid.is_1904 as i32,
            grid.merged.len() as i32,
        ]);
        for m in &grid.merged {
            out.ints.extend(m);
        }
        out.bytes = grid.kinds;
        out.bytes.extend(grid.pads);
        out.doubles = grid.numbers;
        out.strings = grid.texts;
        Ok(out)
    })
}

/// A vector R owns: a pointer and a length. The pointer may be NULL when
/// the length is 0.
#[repr(C)]
pub struct XlInts {
    pub ptr: *const i32,
    pub n: usize,
}

#[repr(C)]
pub struct XlDoubles {
    pub ptr: *const f64,
    pub n: usize,
}

/// UTF-8 strings, NUL-terminated; a NULL string is R's `NA`.
#[repr(C)]
pub struct XlStrings {
    pub ptr: *const *const c_char,
    pub n: usize,
}

/// What `xl_write()` writes; see `write::Plan` for what each part means.
#[repr(C)]
pub struct XlPlan {
    pub fmt_ints: XlInts,
    pub fmt_size: XlDoubles,
    pub fmt_font: XlStrings,
    pub fmt_numfmt: XlStrings,
    pub sheet_names: XlStrings,
    pub sheet_ints: XlInts,
    pub width_cols: XlInts,
    pub width_vals: XlDoubles,
    pub merges: XlInts,
    pub blocks: XlInts,
    pub kinds: XlInts,
    pub fmts: XlInts,
    pub nums: XlDoubles,
    pub strs: XlStrings,
}

/// # Safety
/// `ptr` must point to `n` values that outlive the slice, or `n` be 0.
unsafe fn slice<'a, T>(ptr: *const T, n: usize) -> &'a [T] {
    if n == 0 || ptr.is_null() {
        &[]
    } else {
        std::slice::from_raw_parts(ptr, n)
    }
}

/// # Safety
/// As `slice()`, and each non-NULL string must be NUL-terminated.
unsafe fn strings<'a>(s: &XlStrings) -> Result<Vec<Option<&'a str>>, write::Failure> {
    slice(s.ptr, s.n)
        .iter()
        .map(|&p| {
            if p.is_null() {
                Ok(None)
            } else {
                CStr::from_ptr(p).to_str().map(Some).map_err(|_| {
                    write::Failure::Plan("a string passed to xlkit's Rust code is not UTF-8".into())
                })
            }
        })
        .collect()
}

/// Write a new workbook to `path`. Returns an empty result, or a failure.
///
/// # Safety
/// `plan` must point to an `XlPlan` whose vectors stay valid, unchanged,
/// while this runs.
#[no_mangle]
pub unsafe extern "C" fn xl_write(path: *const c_char, plan: *const XlPlan) -> XlResult {
    if plan.is_null() {
        return failed(9, "a NULL plan was passed to xlkit's Rust code");
    }
    let p = &*plan;
    run::<write::Failure, _>(&[path], |a| {
        let names = strings(&p.sheet_names)?;
        let plan = write::Plan {
            fmt_ints: slice(p.fmt_ints.ptr, p.fmt_ints.n),
            fmt_size: slice(p.fmt_size.ptr, p.fmt_size.n),
            fmt_font: strings(&p.fmt_font)?,
            fmt_numfmt: strings(&p.fmt_numfmt)?,
            sheet_names: names
                .into_iter()
                .map(|n| n.ok_or_else(|| write::Failure::Plan("a sheet name is NA".into())))
                .collect::<Result<_, _>>()?,
            sheet_ints: slice(p.sheet_ints.ptr, p.sheet_ints.n),
            width_cols: slice(p.width_cols.ptr, p.width_cols.n),
            width_vals: slice(p.width_vals.ptr, p.width_vals.n),
            merges: slice(p.merges.ptr, p.merges.n),
            blocks: slice(p.blocks.ptr, p.blocks.n),
            kinds: slice(p.kinds.ptr, p.kinds.n),
            fmts: slice(p.fmts.ptr, p.fmts.n),
            nums: slice(p.nums.ptr, p.nums.n),
            strs: strings(&p.strs)?,
        };
        write::write(a[0], &plan)?;
        Ok(Out::default())
    })
}

/// What `xl_edit()` writes; see `edit::EditPlan` for what each part means.
#[repr(C)]
pub struct XlEditPlan {
    pub fmt_ints: XlInts,
    pub fmt_size: XlDoubles,
    pub fmt_font: XlStrings,
    pub fmt_numfmt: XlStrings,
    pub names: XlStrings,
    pub ints: XlInts,
    pub width_cols: XlInts,
    pub width_vals: XlDoubles,
    pub merges: XlInts,
    pub blocks: XlInts,
    pub kinds: XlInts,
    pub fmts: XlInts,
    pub dclass: XlInts,
    pub nums: XlDoubles,
    pub strs: XlStrings,
    pub pieces: XlInts,
}

/// Write cells into the workbook `src`, giving the edited package `dst`
/// (ADR 0006). strings are three per chart range that no longer matches
/// the data written: the range, the cells written, and their rows.
///
/// # Safety
/// `plan` must point to an `XlEditPlan` whose vectors stay valid,
/// unchanged, while this runs.
#[no_mangle]
pub unsafe extern "C" fn xl_edit(
    src: *const c_char,
    dst: *const c_char,
    plan: *const XlEditPlan,
) -> XlResult {
    if plan.is_null() {
        return failed(9, "a NULL plan was passed to xlkit's Rust code");
    }
    let p = &*plan;
    run::<edit::Failure, _>(&[src, dst], |a| {
        let plan_failure = |e: write::Failure| edit::Failure::Plan(crate::Fail::message(&e));
        let names = strings(&p.names).map_err(plan_failure)?;
        let sheet = names
            .first()
            .copied()
            .flatten()
            .ok_or_else(|| edit::Failure::Plan("no sheet name".into()))?;
        let plan = edit::EditPlan {
            fmt_ints: slice(p.fmt_ints.ptr, p.fmt_ints.n),
            fmt_size: slice(p.fmt_size.ptr, p.fmt_size.n),
            fmt_font: strings(&p.fmt_font).map_err(plan_failure)?,
            fmt_numfmt: strings(&p.fmt_numfmt).map_err(plan_failure)?,
            sheet,
            after: names.get(1).copied().flatten(),
            ints: slice(p.ints.ptr, p.ints.n),
            width_cols: slice(p.width_cols.ptr, p.width_cols.n),
            width_vals: slice(p.width_vals.ptr, p.width_vals.n),
            merges: slice(p.merges.ptr, p.merges.n),
            blocks: slice(p.blocks.ptr, p.blocks.n),
            kinds: slice(p.kinds.ptr, p.kinds.n),
            fmts: slice(p.fmts.ptr, p.fmts.n),
            dclass: slice(p.dclass.ptr, p.dclass.n),
            nums: slice(p.nums.ptr, p.nums.n),
            strs: strings(&p.strs).map_err(plan_failure)?,
            pieces: slice(p.pieces.ptr, p.pieces.n),
        };
        let edited = edit::edit(a[0], a[1], &plan)?;
        let mut out = Out::default();
        for c in edited.charts {
            out.strings.extend(c);
        }
        Ok(out)
    })
}

/// Free everything an `XlResult` holds. Safe to call once per result.
///
/// # Safety
/// `r` must point to a result returned by one of the functions above and
/// not freed before.
#[no_mangle]
pub unsafe extern "C" fn xl_result_free(r: *mut XlResult) {
    if r.is_null() {
        return;
    }
    let r = &mut *r;
    unleak(r.ints, r.n_ints);
    unleak(r.doubles, r.n_doubles);
    unleak(r.bytes, r.n_bytes);
    unleak(r.str_data, r.n_str_data);
    if !r.str_offsets.is_null() {
        unleak(r.str_offsets, r.n_strings + 1);
    }
    if !r.message.is_null() {
        drop(CString::from_raw(r.message));
    }
    r.ints = null_mut();
    r.doubles = null_mut();
    r.bytes = null_mut();
    r.str_data = null_mut();
    r.str_offsets = null_mut();
    r.message = null_mut();
}
