//! Writing a new workbook with rust_xlsxwriter from a plan R made.
//!
//! Nothing here calls R (ADR 0002). R decides every cell, format, width,
//! merged range, frozen pane and filter, checks Excel's limits, and hands
//! the plan over as plain arrays (`Plan`, filled in by src/init.c from R
//! vectors). This module only reads the plan and writes the file. NA and
//! NaN never arrive as numbers: R makes them blank cells or text first,
//! so rust_xlsxwriter's "NAN" and "INF" strings are never written.

use rust_xlsxwriter::{
    Color, Format, FormatAlign, FormatBorder, FormatUnderline, Formula, Workbook, Worksheet,
    XlsxError,
};

/// Cell kinds in `Plan::kinds`.
pub const BLANK: i32 = 0;
pub const NUMBER: i32 = 1;
pub const TEXT: i32 = 2;
pub const BOOL: i32 = 3;
pub const FORMULA: i32 = 4;

/// Integers per format in `Plan::fmt_ints`: bold, italic, underline,
/// font color, fill, top, right, bottom and left borders, horizontal and
/// vertical alignment, wrap and indent. -1 leaves a property unset.
pub const FMT_INTS: usize = 13;
/// Integers per sheet in `Plan::sheet_ints`: the frozen pane's row and
/// column (-1 for none), and the filter's first row, first column, last
/// row and last column (-1 for none). Rows and columns count from 0.
pub const SHEET_INTS: usize = 6;
/// Integers per merged range: sheet, first row, first column, last row,
/// last column.
pub const MERGE_INTS: usize = 5;
/// Integers per block of cells: sheet, row, column and number of cells,
/// which run down the column from (row, column).
pub const BLOCK_INTS: usize = 4;

/// What to write, as R laid it out. Strings are `None` where R had `NA`.
/// Numbers and booleans are taken from `nums` in order, one for each
/// cell of kind NUMBER or BOOL; texts and formulas from `strs`, one for
/// each cell of kind TEXT or FORMULA.
pub struct Plan<'a> {
    pub fmt_ints: &'a [i32],
    pub fmt_size: &'a [f64],
    pub fmt_font: Vec<Option<&'a str>>,
    pub fmt_numfmt: Vec<Option<&'a str>>,
    pub sheet_names: Vec<&'a str>,
    pub sheet_ints: &'a [i32],
    /// Pairs of (sheet, column) for `width_vals`.
    pub width_cols: &'a [i32],
    pub width_vals: &'a [f64],
    pub merges: &'a [i32],
    pub blocks: &'a [i32],
    pub kinds: &'a [i32],
    pub fmts: &'a [i32],
    pub nums: &'a [f64],
    pub strs: Vec<Option<&'a str>>,
}

/// Why a write failed. The codes are what R sees (see R/bridge.R).
#[derive(Debug)]
pub enum Failure {
    /// The file could not be written.
    Io(String),
    /// rust_xlsxwriter refused something R should have caught first.
    Writer(String),
    /// The plan's arrays do not fit together (a bug in xlkit's R code).
    Plan(String),
}

impl crate::Fail for Failure {
    fn code(&self) -> i32 {
        match self {
            Failure::Io(_) => 11,
            Failure::Writer(_) => 12,
            Failure::Plan(_) => 13,
        }
    }

    fn message(&self) -> String {
        match self {
            Failure::Io(m) | Failure::Writer(m) | Failure::Plan(m) => m.clone(),
        }
    }
}

fn writer_failure(e: XlsxError) -> Failure {
    match e {
        XlsxError::IoError(e) => Failure::Io(e.to_string()),
        e => Failure::Writer(e.to_string()),
    }
}

fn plan_failure(what: &str) -> Failure {
    Failure::Plan(what.to_string())
}

fn border(code: i32) -> FormatBorder {
    match code {
        1 => FormatBorder::Thin,
        2 => FormatBorder::Medium,
        3 => FormatBorder::Thick,
        4 => FormatBorder::Double,
        _ => FormatBorder::None,
    }
}

fn rgb(code: i32) -> Color {
    Color::RGB(code as u32 & 0xFF_FFFF)
}

/// The formats of the plan, in order.
fn formats(plan: &Plan) -> Result<Vec<Format>, Failure> {
    let n = plan.fmt_size.len();
    if plan.fmt_ints.len() != n * FMT_INTS || plan.fmt_font.len() != n || plan.fmt_numfmt.len() != n
    {
        return Err(plan_failure("the format arrays differ in length"));
    }
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let v = &plan.fmt_ints[i * FMT_INTS..(i + 1) * FMT_INTS];
        let mut f = Format::new();
        if v[0] == 1 {
            f = f.set_bold();
        }
        if v[1] == 1 {
            f = f.set_italic();
        }
        if v[2] == 1 {
            f = f.set_underline(FormatUnderline::Single);
        }
        if v[3] >= 0 {
            f = f.set_font_color(rgb(v[3]));
        }
        if v[4] >= 0 {
            f = f.set_background_color(rgb(v[4]));
        }
        if v[5] > 0 {
            f = f.set_border_top(border(v[5]));
        }
        if v[6] > 0 {
            f = f.set_border_right(border(v[6]));
        }
        if v[7] > 0 {
            f = f.set_border_bottom(border(v[7]));
        }
        if v[8] > 0 {
            f = f.set_border_left(border(v[8]));
        }
        match v[9] {
            1 => f = f.set_align(FormatAlign::Left),
            2 => f = f.set_align(FormatAlign::Center),
            3 => f = f.set_align(FormatAlign::Right),
            _ => {}
        }
        match v[10] {
            1 => f = f.set_align(FormatAlign::Top),
            2 => f = f.set_align(FormatAlign::VerticalCenter),
            3 => f = f.set_align(FormatAlign::Bottom),
            _ => {}
        }
        if v[11] == 1 {
            f = f.set_text_wrap();
        }
        if v[12] > 0 {
            f = f.set_indent(v[12].min(250) as u8);
        }
        let size = plan.fmt_size[i];
        if size.is_finite() && size > 0.0 {
            f = f.set_font_size(size);
        }
        if let Some(font) = plan.fmt_font[i] {
            f = f.set_font_name(font);
        }
        if let Some(numfmt) = plan.fmt_numfmt[i] {
            f = f.set_num_format(numfmt);
        }
        out.push(f);
    }
    Ok(out)
}

fn index(v: i32, n: usize, what: &str) -> Result<usize, Failure> {
    if v < 0 || v as usize >= n {
        return Err(Failure::Plan(format!("{what} {v} is out of range")));
    }
    Ok(v as usize)
}

/// Write the cells of every block to their sheets.
fn write_cells(
    plan: &Plan,
    sheets: &mut [&mut Worksheet],
    formats: &[Format],
) -> Result<(), Failure> {
    if !plan.blocks.len().is_multiple_of(BLOCK_INTS) || plan.kinds.len() != plan.fmts.len() {
        return Err(plan_failure("the cell arrays differ in length"));
    }
    let (mut cell, mut num, mut text) = (0usize, 0usize, 0usize);
    for b in plan.blocks.as_chunks::<BLOCK_INTS>().0 {
        let ws = &mut sheets[index(b[0], plan.sheet_names.len(), "sheet")?];
        let (row0, col) = (b[1], b[2]);
        let n = b[3].max(0) as usize;
        if row0 < 0 || col < 0 || cell + n > plan.kinds.len() {
            return Err(plan_failure("a block of cells lies outside the arrays"));
        }
        for k in 0..n {
            let row = (row0 as u32) + k as u32;
            let col = col as u16;
            let kind = plan.kinds[cell];
            let fmt = match plan.fmts[cell] {
                f if f < 0 => None,
                f => Some(&formats[index(f, formats.len(), "format")?]),
            };
            cell += 1;
            let result = match kind {
                NUMBER | BOOL => {
                    let x = *plan
                        .nums
                        .get(num)
                        .ok_or_else(|| plan_failure("too few numbers"))?;
                    num += 1;
                    if kind == BOOL {
                        match fmt {
                            Some(f) => ws.write_boolean_with_format(row, col, x != 0.0, f),
                            None => ws.write_boolean(row, col, x != 0.0),
                        }
                    } else if !x.is_finite() {
                        // R never sends these; a blank is what NA means.
                        match fmt {
                            Some(f) => ws.write_blank(row, col, f),
                            None => continue,
                        }
                    } else {
                        match fmt {
                            Some(f) => ws.write_number_with_format(row, col, x, f),
                            None => ws.write_number(row, col, x),
                        }
                    }
                }
                TEXT | FORMULA => {
                    let s = plan
                        .strs
                        .get(text)
                        .ok_or_else(|| plan_failure("too few strings"))?
                        .unwrap_or("");
                    text += 1;
                    if kind == FORMULA {
                        let formula = Formula::new(s);
                        match fmt {
                            Some(f) => ws.write_formula_with_format(row, col, formula, f),
                            None => ws.write_formula(row, col, formula),
                        }
                    } else {
                        match fmt {
                            Some(f) => ws.write_string_with_format(row, col, s, f),
                            None => ws.write_string(row, col, s),
                        }
                    }
                }
                BLANK => match fmt {
                    Some(f) => ws.write_blank(row, col, f),
                    None => continue,
                },
                k => return Err(Failure::Plan(format!("cell kind {k} is not known"))),
            };
            result.map_err(writer_failure)?;
        }
    }
    if cell != plan.kinds.len() || num != plan.nums.len() || text != plan.strs.len() {
        return Err(plan_failure("the blocks do not use every cell"));
    }
    Ok(())
}

/// Write the workbook the plan describes to `path`.
pub fn write(path: &str, plan: &Plan) -> Result<(), Failure> {
    let n_sheets = plan.sheet_names.len();
    if plan.sheet_ints.len() != n_sheets * SHEET_INTS
        || plan.width_cols.len() != plan.width_vals.len() * 2
        || !plan.merges.len().is_multiple_of(MERGE_INTS)
    {
        return Err(plan_failure("the sheet arrays differ in length"));
    }
    let formats = formats(plan)?;
    let mut sheets: Vec<Worksheet> = Vec::with_capacity(n_sheets);
    for name in &plan.sheet_names {
        let mut ws = Worksheet::new();
        ws.set_name(*name).map_err(writer_failure)?;
        // A formula's stored result is empty until Excel calculates it,
        // so a reader sees no value rather than a made-up 0.
        ws.set_formula_result_default("");
        sheets.push(ws);
    }
    // Merged ranges first: merge_range() fills its cells with blanks,
    // and the cells R planned inside them are written over those.
    let plain = Format::new();
    for m in plan.merges.as_chunks::<MERGE_INTS>().0 {
        let ws = &mut sheets[index(m[0], n_sheets, "sheet")?];
        if m[1..].iter().any(|&v| v < 0) {
            return Err(plan_failure("a merged range has a negative row or column"));
        }
        ws.merge_range(
            m[1] as u32,
            m[2] as u16,
            m[3] as u32,
            m[4] as u16,
            "",
            &plain,
        )
        .map_err(writer_failure)?;
    }
    {
        let mut refs: Vec<&mut Worksheet> = sheets.iter_mut().collect();
        write_cells(plan, &mut refs, &formats)?;
    }
    for (i, w) in plan.width_vals.iter().enumerate() {
        let ws = &mut sheets[index(plan.width_cols[2 * i], n_sheets, "sheet")?];
        let col = plan.width_cols[2 * i + 1];
        if col < 0 || !w.is_finite() {
            return Err(plan_failure("a column width is out of range"));
        }
        ws.set_column_width(col as u16, *w)
            .map_err(writer_failure)?;
    }
    for (ws, s) in sheets
        .iter_mut()
        .zip(plan.sheet_ints.as_chunks::<SHEET_INTS>().0)
    {
        if s[0] >= 0 && s[1] >= 0 && (s[0] > 0 || s[1] > 0) {
            ws.set_freeze_panes(s[0] as u32, s[1] as u16)
                .map_err(writer_failure)?;
        }
        if s[2..].iter().all(|&v| v >= 0) {
            ws.autofilter(s[2] as u32, s[3] as u16, s[4] as u32, s[5] as u16)
                .map_err(writer_failure)?;
        }
    }
    let mut workbook = Workbook::new();
    for ws in sheets {
        workbook.push_worksheet(ws);
    }
    workbook.save(path).map_err(writer_failure)
}

#[cfg(test)]
mod tests {
    use super::*;
    use calamine::{open_workbook, Data, Reader, Xlsx};

    fn tmp(name: &str) -> String {
        let dir = std::env::temp_dir().join(format!("xlkit-write-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir.join(name).to_string_lossy().into_owned()
    }

    #[test]
    fn writes_cells_and_reads_back() {
        let path = tmp("cells.xlsx");
        // One bold format and one date format.
        let mut fmt_ints = vec![-1; 2 * FMT_INTS];
        fmt_ints[0] = 1;
        let plan = Plan {
            fmt_ints: &fmt_ints,
            fmt_size: &[f64::NAN, f64::NAN],
            fmt_font: vec![None, None],
            fmt_numfmt: vec![None, Some("yyyy-mm-dd")],
            sheet_names: vec!["Data"],
            sheet_ints: &[1, 0, 0, 0, 3, 1],
            width_cols: &[0, 0],
            width_vals: &[12.0],
            merges: &[],
            // Column A: header and three cells; column B: header and a date.
            blocks: &[0, 0, 0, 4, 0, 0, 1, 2],
            kinds: &[TEXT, NUMBER, TEXT, BLANK, TEXT, NUMBER],
            fmts: &[0, -1, -1, -1, 0, 1],
            nums: &[1.5, 45306.0],
            strs: vec![Some("x"), Some("=A1+1"), Some("day")],
        };
        write(&path, &plan).unwrap();
        let mut wb: Xlsx<_> = open_workbook(&path).unwrap();
        let range = wb.worksheet_range("Data").unwrap();
        assert_eq!(range.get_value((0, 0)), Some(&Data::String("x".into())));
        assert_eq!(range.get_value((1, 0)), Some(&Data::Float(1.5)));
        // Text that looks like a formula stays text.
        assert_eq!(range.get_value((2, 0)), Some(&Data::String("=A1+1".into())));
        assert!(matches!(range.get_value((1, 1)), Some(Data::DateTime(_))));
    }

    #[test]
    fn non_finite_numbers_are_blank() {
        let path = tmp("nan.xlsx");
        let plan = Plan {
            fmt_ints: &[],
            fmt_size: &[],
            fmt_font: vec![],
            fmt_numfmt: vec![],
            sheet_names: vec!["S"],
            sheet_ints: &[-1, -1, -1, -1, -1, -1],
            width_cols: &[],
            width_vals: &[],
            merges: &[],
            blocks: &[0, 0, 0, 2],
            kinds: &[NUMBER, NUMBER],
            fmts: &[-1, -1],
            nums: &[f64::NAN, 2.0],
            strs: vec![],
        };
        write(&path, &plan).unwrap();
        let mut wb: Xlsx<_> = open_workbook(&path).unwrap();
        let range = wb.worksheet_range("S").unwrap();
        assert_eq!(range.get_value((1, 0)), Some(&Data::Float(2.0)));
        assert!(matches!(range.get_value((0, 0)), None | Some(Data::Empty)));
    }

    #[test]
    fn mismatched_arrays_fail_without_panicking() {
        let plan = Plan {
            fmt_ints: &[],
            fmt_size: &[],
            fmt_font: vec![],
            fmt_numfmt: vec![],
            sheet_names: vec!["S"],
            sheet_ints: &[-1, -1, -1, -1, -1, -1],
            width_cols: &[],
            width_vals: &[],
            merges: &[],
            blocks: &[0, 0, 0, 3],
            kinds: &[NUMBER],
            fmts: &[-1],
            nums: &[1.0],
            strs: vec![],
        };
        assert!(matches!(
            write(&tmp("bad.xlsx"), &plan),
            Err(Failure::Plan(_))
        ));
    }
}
