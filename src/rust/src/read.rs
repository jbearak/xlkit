//! Reading a workbook with calamine into plain columns for R.
//!
//! Nothing here calls R (ADR 0002). A sheet comes back as its block of
//! used cells, in column-major order: a kind byte, a number and a text
//! for each cell, with the Excel row and column of the top-left cell.
//! R decides the column types from these.

use crate::format::{classify, Classified, Format, NumberKind};
use calamine::{Data, Reader, SheetType, Xlsx, XlsxError};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

/// Cell kinds, as R sees them.
pub const EMPTY: u8 = 0;
// 1 to 5 are the NumberKind values: number, date, date-time, time, duration.
pub const BOOL: u8 = 6;
pub const TEXT: u8 = 7;
pub const ERROR: u8 = 8;

/// Why a read failed. The codes are what R sees (see R/bridge.R).
#[derive(Debug)]
pub enum Failure {
    /// The file could not be opened.
    Io(String),
    /// The file is not a zip archive.
    NotZip(String),
    /// A zip archive without the parts of an .xlsx workbook.
    NotWorkbook(String),
    /// The workbook is encrypted with a password.
    Password,
    /// The workbook's XML could not be parsed.
    Corrupt(String),
    /// No sheet of that name.
    NoSheet(String),
    /// The sheet is a chart sheet or another kind that is not a worksheet.
    NotWorksheet(String),
}

impl Failure {
    pub fn code(&self) -> i32 {
        match self {
            Failure::Io(_) => 1,
            Failure::NotZip(_) => 2,
            Failure::NotWorkbook(_) => 3,
            Failure::Password => 4,
            Failure::Corrupt(_) => 5,
            Failure::NoSheet(_) => 6,
            Failure::NotWorksheet(_) => 7,
        }
    }

    pub fn message(&self) -> String {
        match self {
            Failure::Io(m) | Failure::NotZip(m) | Failure::NotWorkbook(m) | Failure::Corrupt(m) => {
                m.clone()
            }
            Failure::Password => "the workbook is password-protected".to_string(),
            Failure::NoSheet(s) | Failure::NotWorksheet(s) => s.clone(),
        }
    }
}

fn failure(e: XlsxError) -> Failure {
    match e {
        XlsxError::Io(e) => Failure::Io(e.to_string()),
        XlsxError::Zip(e) => Failure::NotZip(e.to_string()),
        XlsxError::FileNotFound(f) => Failure::NotWorkbook(format!("it has no {f}")),
        XlsxError::Password => Failure::Password,
        XlsxError::WorksheetNotFound(s) => Failure::NoSheet(s),
        XlsxError::NotAWorksheet(s) => Failure::NotWorksheet(s),
        e => Failure::Corrupt(e.to_string()),
    }
}

pub fn open(path: &str) -> Result<Xlsx<BufReader<File>>, Failure> {
    let file = File::open(path).map_err(|e| Failure::Io(e.to_string()))?;
    Xlsx::new(BufReader::new(file)).map_err(failure)
}

/// The sheets of a workbook in tab order, whether each is a worksheet,
/// and whether the workbook uses the 1904 date system.
pub struct Info {
    pub names: Vec<String>,
    /// 0: worksheet, 1: chart sheet, 2: another kind (dialog, macro sheet).
    pub types: Vec<i32>,
    pub is_1904: bool,
}

pub fn info(path: &str) -> Result<Info, Failure> {
    let wb = open(path)?;
    let meta = wb.sheets_metadata();
    Ok(Info {
        names: meta.iter().map(|s| s.name.clone()).collect(),
        types: meta
            .iter()
            .map(|s| match s.typ {
                SheetType::WorkSheet => 0,
                SheetType::ChartSheet => 1,
                _ => 2,
            })
            .collect(),
        is_1904: wb.has_1904_epoch(),
    })
}

/// A named range: a defined name or an Excel table, with its sheet and
/// its cells as 1-based Excel rows and columns.
pub struct Named {
    pub name: String,
    pub sheet: String,
    /// For a defined name, its formula as the file has it (R parses it);
    /// empty for a table.
    pub formula: String,
    /// For a table: first row, first column, last row (above any totals
    /// row), last column, and the number of header rows (0 or 1). Zeros for
    /// a defined name.
    pub dims: [i32; 5],
}

pub fn names(path: &str) -> Result<Vec<Named>, Failure> {
    let wb = open(path)?;
    let mut out: Vec<Named> = wb
        .defined_names()
        .iter()
        .map(|(name, formula)| Named {
            name: name.clone(),
            sheet: String::new(),
            formula: formula.clone(),
            dims: [0; 5],
        })
        .collect();
    for t in crate::package::tables(path)? {
        // The body drops a totals row; a table without a header row says so.
        out.push(Named {
            name: t.name,
            sheet: t.sheet,
            formula: String::new(),
            dims: [
                t.cells[0],
                t.cells[1],
                t.cells[2] - t.totals_rows.max(0),
                t.cells[3],
                t.header_rows.max(0),
            ],
        });
    }
    Ok(out)
}

/// A sheet's used cells, column by column.
pub struct Grid {
    /// 1-based Excel row and column of the top-left cell; 0 when empty.
    pub first_row: i32,
    pub first_col: i32,
    pub nrow: usize,
    pub ncol: usize,
    pub is_1904: bool,
    pub kinds: Vec<u8>,
    /// Zero-padding width of each cell's number format (see format.rs).
    pub pads: Vec<u8>,
    /// The stored number (also for dates, times and logicals); NaN otherwise.
    pub numbers: Vec<f64>,
    /// The text of text and error cells; empty otherwise.
    pub texts: Vec<String>,
    /// Merged ranges as 1-based (first row, first column, last row, last column).
    pub merged: Vec<[i32; 4]>,
}

pub fn read_sheet(path: &str, sheet: &str) -> Result<Grid, Failure> {
    let mut wb = open(path)?;
    let meta = wb
        .sheets_metadata()
        .iter()
        .find(|s| s.name == sheet)
        .map(|s| s.typ)
        .ok_or_else(|| Failure::NoSheet(sheet.to_string()))?;
    if meta != SheetType::WorkSheet {
        return Err(Failure::NotWorksheet(sheet.to_string()));
    }
    let is_1904 = wb.has_1904_epoch();
    let range = wb.worksheet_range(sheet).map_err(failure)?;
    let styles = wb.worksheet_style(sheet).map_err(failure)?;
    let merged = wb.merge_cells_by_sheet_name(sheet).map_err(failure)?;

    let mut grid = Grid {
        first_row: 0,
        first_col: 0,
        nrow: 0,
        ncol: 0,
        is_1904,
        kinds: Vec::new(),
        pads: Vec::new(),
        numbers: Vec::new(),
        texts: Vec::new(),
        merged: merged
            .iter()
            .map(|d| {
                [
                    d.start.0 as i32 + 1,
                    d.start.1 as i32 + 1,
                    d.end.0 as i32 + 1,
                    d.end.1 as i32 + 1,
                ]
            })
            .collect(),
    };
    let start = match range.start() {
        Some(s) => s,
        None => return Ok(grid),
    };
    let (height, width) = range.get_size();

    // Classify each cell, then crop to the cells that hold something:
    // calamine's range can include text that is only spaces.
    let mut cache: HashMap<(String, Option<u32>), Classified> = HashMap::new();
    let mut cells: Vec<(u8, u8, f64, String)> = Vec::with_capacity(height * width);
    let (mut r0, mut c0, mut r1, mut c1) = (usize::MAX, usize::MAX, 0usize, 0usize);
    for r in 0..height {
        for c in 0..width {
            let pos = (start.0 + r as u32, start.1 + c as u32);
            let cell = match range.get((r, c)) {
                Some(value) => convert(
                    value,
                    |v| {
                        let style = styles.get(pos).and_then(|s| s.number_format.as_ref());
                        match style {
                            Some(nf) => cache
                                .entry((nf.format_code.clone(), nf.format_id))
                                .or_insert_with(|| classify(&nf.format_code, nf.format_id))
                                .for_value(v),
                            None => Format {
                                kind: NumberKind::Number,
                                pad: 0,
                            },
                        }
                    },
                    is_1904,
                ),
                None => (EMPTY, 0, f64::NAN, String::new()),
            };
            if cell.0 != EMPTY {
                r0 = r0.min(r);
                c0 = c0.min(c);
                r1 = r1.max(r);
                c1 = c1.max(c);
            }
            cells.push(cell);
        }
    }
    if r0 == usize::MAX {
        return Ok(grid);
    }
    let nrow = r1 - r0 + 1;
    let ncol = c1 - c0 + 1;
    grid.first_row = (start.0 as usize + r0 + 1) as i32;
    grid.first_col = (start.1 as usize + c0 + 1) as i32;
    grid.nrow = nrow;
    grid.ncol = ncol;
    let n = nrow * ncol;
    grid.kinds.reserve(n);
    grid.pads.reserve(n);
    grid.numbers.reserve(n);
    grid.texts.reserve(n);
    for c in c0..=c1 {
        for r in r0..=r1 {
            let (kind, pad, number, text) = std::mem::take(&mut cells[r * width + c]);
            grid.kinds.push(kind);
            grid.pads.push(pad);
            grid.numbers.push(number);
            grid.texts.push(text);
        }
    }
    Ok(grid)
}

/// One cell as (kind, pad, number, text). `format` gives the cell's
/// number format; it is looked up only for numbers.
fn convert(
    value: &Data,
    format: impl FnOnce(f64) -> Format,
    is_1904: bool,
) -> (u8, u8, f64, String) {
    let number = |x: f64, format: Format| (format.kind as u8, format.pad, x, String::new());
    match value {
        Data::Empty => (EMPTY, 0, f64::NAN, String::new()),
        Data::Float(x) => number(*x, format(*x)),
        Data::Int(x) => number(*x as f64, format(*x as f64)),
        Data::DateTime(d) => number(d.as_f64(), format(d.as_f64())),
        Data::Bool(b) => (BOOL, 0, if *b { 1.0 } else { 0.0 }, String::new()),
        Data::Error(e) => (ERROR, 0, f64::NAN, e.to_string()),
        Data::String(s) => {
            if s.trim().is_empty() {
                (EMPTY, 0, f64::NAN, String::new())
            } else {
                (TEXT, 0, f64::NAN, s.clone())
            }
        }
        Data::DateTimeIso(s) => match iso_serial(s, is_1904) {
            Some((serial, has_time)) => {
                let kind = if has_time {
                    NumberKind::DateTime
                } else {
                    NumberKind::Date
                };
                (kind as u8, 0, serial, String::new())
            }
            None => (TEXT, 0, f64::NAN, s.clone()),
        },
        Data::DurationIso(s) => (TEXT, 0, f64::NAN, s.clone()),
    }
}

/// Days from 1970-01-01 to a civil date (Howard Hinnant's algorithm).
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

/// The serial number of an ISO 8601 date or date-time (a cell stored with
/// `t="d"`), in the workbook's date system, and whether it has a time.
fn iso_serial(text: &str, is_1904: bool) -> Option<(f64, bool)> {
    let text = text.trim();
    let (date, time) = match text.find(['T', ' ']) {
        Some(i) => (&text[..i], Some(&text[i + 1..])),
        None => (text, None),
    };
    let parts: Vec<&str> = date.split('-').collect();
    if parts.len() != 3 {
        return None;
    }
    let y: i64 = parts[0].parse().ok()?;
    let m: i64 = parts[1].parse().ok()?;
    let d: i64 = parts[2].parse().ok()?;
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) {
        return None;
    }
    let mut seconds = 0.0;
    if let Some(time) = time {
        let time = time.trim_end_matches('Z');
        let hms: Vec<&str> = time.split(':').collect();
        if hms.len() < 2 {
            return None;
        }
        let h: f64 = hms[0].parse().ok()?;
        let mi: f64 = hms[1].parse().ok()?;
        let s: f64 = if hms.len() > 2 {
            hms[2].parse().ok()?
        } else {
            0.0
        };
        seconds = h * 3600.0 + mi * 60.0 + s;
    }
    let unix = days_from_civil(y, m, d) as f64 + seconds / 86400.0;
    let serial = if is_1904 {
        unix + 24107.0
    } else if unix >= -25508.0 {
        // From 1900-03-01, Excel's count is one ahead for its 29 February 1900.
        unix + 25569.0
    } else {
        unix + 25568.0
    };
    Some((serial, time.is_some()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn iso_dates_become_serials() {
        assert_eq!(iso_serial("2024-01-15", false), Some((45306.0, false)));
        assert_eq!(iso_serial("1900-03-01", false), Some((61.0, false)));
        assert_eq!(iso_serial("1900-02-28", false), Some((59.0, false)));
        assert_eq!(iso_serial("2024-01-15", true), Some((43844.0, false)));
        assert_eq!(
            iso_serial("2024-01-15T12:00:00", false),
            Some((45306.5, true))
        );
        assert_eq!(iso_serial("15/01/2024", false), None);
    }

    fn fixture(name: &str) -> String {
        format!(
            "{}/../../tests/testthat/fixtures/{name}",
            env!("CARGO_MANIFEST_DIR")
        )
    }

    #[test]
    fn reads_cells_with_excel_coordinates() {
        let grid = read_sheet(&fixture("edge.xlsx"), "Ranges").unwrap();
        // Data in B3:D8 and a stray value in F10.
        assert_eq!(
            (grid.first_row, grid.first_col, grid.nrow, grid.ncol),
            (3, 2, 8, 5)
        );
        assert_eq!(grid.kinds[0], TEXT);
        assert_eq!(grid.texts[0], "a");
        assert_eq!(grid.kinds[1], NumberKind::Number as u8);
        assert_eq!(grid.numbers[1], 4.0);
    }

    #[test]
    fn chart_sheets_and_missing_sheets_fail() {
        assert!(matches!(
            read_sheet(&fixture("edge.xlsx"), "Plot"),
            Err(Failure::NotWorksheet(_))
        ));
        assert!(matches!(
            read_sheet(&fixture("edge.xlsx"), "Nope"),
            Err(Failure::NoSheet(_))
        ));
        let info = info(&fixture("edge.xlsx")).unwrap();
        let plot = info.names.iter().position(|n| n == "Plot").unwrap();
        assert_eq!(info.types[plot], 1);
    }

    #[test]
    fn errors_and_formats() {
        let grid = read_sheet(&fixture("edge.xlsx"), "Errors").unwrap();
        let texts: Vec<&str> = grid.texts[1..8].iter().map(String::as_str).collect();
        assert_eq!(
            texts,
            ["#N/A", "#DIV/0!", "#VALUE!", "#REF!", "#NAME?", "#NUM!", "#NULL!"]
        );
        assert!(grid.kinds[1..8].iter().all(|&k| k == ERROR));

        let grid = read_sheet(&fixture("edge.xlsx"), "Formats").unwrap();
        // Row 2 holds the values; columns in the order the fixture writes them.
        let kind = |col: usize| grid.kinds[col * 2 + 1];
        assert_eq!(kind(0), NumberKind::Number as u8); // 0.0%
        assert_eq!(kind(1), NumberKind::Duration as u8); // [h]:mm
        assert_eq!(kind(4), NumberKind::Date as u8); // [$-409]d-mmm-yy;@
        assert_eq!(kind(6), NumberKind::Number as u8); // 00000
        assert_eq!(grid.pads[6 * 2 + 1], 5);
        assert_eq!(kind(9), NumberKind::DateTime as u8);
    }

    #[test]
    fn not_a_workbook() {
        let csv = std::env::temp_dir().join("xlkit-not-a-workbook.xlsx");
        std::fs::write(&csv, "a,b\n1,2\n").unwrap();
        assert!(matches!(
            info(csv.to_str().unwrap()),
            Err(Failure::NotZip(_))
        ));
        std::fs::remove_file(csv).ok();
    }

    #[test]
    fn tables_and_defined_names() {
        let path = format!(
            "{}/../../inst/extdata/births.xlsx",
            env!("CARGO_MANIFEST_DIR")
        );
        let named = names(&path).unwrap();
        let table = named.iter().find(|n| n.name == "BirthsTable").unwrap();
        assert_eq!(table.sheet, "Births 2024");
        assert_eq!(table.dims, [5, 2, 40, 6, 1]);
        let regions = named.iter().find(|n| n.name == "RegionList").unwrap();
        assert_eq!(regions.formula, "Regions!$A$1:$C$6");
    }
}
