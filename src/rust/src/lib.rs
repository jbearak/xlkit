//! xlkit's Rust core, called from src/init.c through a C ABI.
//!
//! ADR 0002: Rust never calls R's API. Each function takes UTF-8 paths
//! and returns an `XlResult` of plain buffers that C copies into R
//! vectors and then frees with `xl_result_free()`. A failure is a status
//! code and a UTF-8 message; R raises the error after Rust's memory is
//! freed. A panic is caught here and reported the same way, so it never
//! unwinds into C.

mod format;
mod package;
mod read;

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

fn failed(status: i32, message: &str) -> XlResult {
    let message = CString::new(message.replace('\0', " ")).unwrap_or_default();
    let mut r = Out::default().into_result();
    r.status = status;
    r.message = message.into_raw();
    r
}

/// Run `f` on the UTF-8 strings behind `args`, turning failures and panics
/// into a status and message.
fn run(args: &[*const c_char], f: impl FnOnce(&[&str]) -> Result<Out, read::Failure>) -> XlResult {
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
    run(&[path], |a| {
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
    run(&[path], |a| {
        let mut out = Out::default();
        for n in read::names(a[0])? {
            out.strings.extend([n.name, n.sheet, n.formula]);
            out.ints.extend(n.dims);
        }
        Ok(out)
    })
}

/// One sheet's used cells (see `read::Grid`): ints are
/// `[first_row, first_col, nrow, ncol, is_1904, n_merged, merged...]`;
/// bytes are the kinds then the pads; doubles the numbers; strings the
/// texts, all column-major.
#[no_mangle]
pub extern "C" fn xl_read(path: *const c_char, sheet: *const c_char) -> XlResult {
    run(&[path, sheet], |a| {
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
