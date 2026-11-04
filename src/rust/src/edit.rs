//! Editing an existing workbook in place (ADR 0006).
//!
//! The package is never loaded into a model. Each zip entry is copied
//! through with its compressed bytes untouched (`raw_copy_file`), except
//! the parts a write must change:
//!
//! - the worksheet written (`splice.rs`): its cells, `<dimension>` and
//!   `<mergeCells>`, or for `write_sheet()` without `at` its `<sheetData>`;
//! - `xl/styles.xml`, with formats appended (`styles.rs`);
//! - `xl/workbook.xml`, to add a sheet and set `fullCalcOnLoad`;
//! - for a new sheet, the workbook's relationships and the content types;
//! - an Excel table written at its top-left cell or grown down: its
//!   `ref`, its autofilter's `ref` and its column names, and the chart
//!   series that plot its columns;
//! - `xl/calcChain.xml`, removed (with its relationship and content
//!   type) when a formula was overwritten, since Excel would otherwise
//!   repair the file. `fullCalcOnLoad` rebuilds it.
//!
//! R decides every value and style (src/init.c hands over a plan of plain
//! arrays, as for `write_xlsx()`); nothing here calls R (ADR 0002).

use crate::format::NumberKind;
use crate::splice::{
    self, cell_ref, contains, element_children, encode_attr, encode_text, get_attr, live_elements,
    overlaps, parse_range, range_ref, set_attr, splice_bytes, tag_text, Edit, SpliceError, Styler,
    Value,
};
use crate::styles::{Overlay, Styles};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs::File;
use std::io::{BufReader, Read, Write};
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

const REL_NS: &str = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
const STRICT_REL_NS: &str = "http://purl.oclc.org/ooxml/officeDocument/relationships";
const WORKSHEET_TYPE: &str =
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet";
const WORKSHEET_CT: &str =
    "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml";

/// Why an edit failed. The codes are what R sees (R/edit.R).
#[derive(Debug)]
pub enum Failure {
    Io(String),
    NotZip(String),
    NotWorkbook(String),
    Corrupt(String),
    NotWorksheet(String),
    Write(String),
    Plan(String),
    /// A refusal code from the splice.
    Refused(&'static str),
    Merged(String),
    Grouped(String),
    TableHeader(String),
    TableShape(String),
    MergeOverlap(String),
    TableCleared(String),
    NoStyles,
    NoSheetData,
    TableOverlap(String),
    TableNames(String),
    MergeHides(String),
}

impl crate::Fail for Failure {
    fn code(&self) -> i32 {
        match self {
            Failure::Io(_) => 1,
            Failure::NotZip(_) => 2,
            Failure::NotWorkbook(_) => 3,
            Failure::Corrupt(_) => 5,
            Failure::NotWorksheet(_) => 7,
            Failure::Write(_) => 11,
            Failure::Plan(_) => 13,
            Failure::Refused(_) => 21,
            Failure::Merged(_) => 22,
            Failure::Grouped(_) => 23,
            Failure::TableHeader(_) => 24,
            Failure::TableShape(_) => 25,
            Failure::MergeOverlap(_) => 26,
            Failure::TableCleared(_) => 27,
            Failure::NoStyles => 28,
            Failure::NoSheetData => 29,
            Failure::TableOverlap(_) => 30,
            Failure::TableNames(_) => 31,
            Failure::MergeHides(_) => 32,
        }
    }

    fn message(&self) -> String {
        match self {
            Failure::Io(m)
            | Failure::NotZip(m)
            | Failure::NotWorkbook(m)
            | Failure::Corrupt(m)
            | Failure::NotWorksheet(m)
            | Failure::Write(m)
            | Failure::Plan(m)
            | Failure::Merged(m)
            | Failure::Grouped(m)
            | Failure::TableHeader(m)
            | Failure::TableShape(m)
            | Failure::MergeOverlap(m)
            | Failure::TableCleared(m)
            | Failure::TableOverlap(m)
            | Failure::TableNames(m)
            | Failure::MergeHides(m) => m.clone(),
            Failure::Refused(c) => c.to_string(),
            Failure::NoStyles | Failure::NoSheetData => String::new(),
        }
    }
}

fn splice_failure(e: SpliceError) -> Failure {
    match e {
        SpliceError::Refused(r) => Failure::Refused(r.code()),
        SpliceError::NoSheetData => Failure::NoSheetData,
        SpliceError::Merged(r, c, m) => {
            Failure::Merged(format!("{}\t{}", cell_ref(r, c), range_ref(m)))
        }
        SpliceError::Grouped(r, c, k, g) => {
            Failure::Grouped(format!("{}\t{k}\t{}", cell_ref(r, c), range_ref(g)))
        }
        SpliceError::MergeOverlap(a, b) => {
            Failure::MergeOverlap(format!("{}\t{}", range_ref(a), range_ref(b)))
        }
    }
}

/// Integers per format in `fmt_ints` (as for `write_xlsx()`).
const FMT_INTS: usize = 13;

/// What R asks for. Rows and columns count from 0.
pub struct EditPlan<'a> {
    pub fmt_ints: &'a [i32],
    pub fmt_size: &'a [f64],
    pub fmt_font: Vec<Option<&'a str>>,
    pub fmt_numfmt: Vec<Option<&'a str>>,
    pub sheet: &'a str,
    /// For a new sheet: the sheet it goes after (None: the last).
    pub after: Option<&'a str>,
    /// `[mode, freeze row, freeze column]`: mode 0 writes cells, 1
    /// replaces the sheet's cells; the frozen pane (-1 for none) is for a
    /// new sheet.
    pub ints: &'a [i32],
    /// Column widths of a new sheet: columns and widths in characters.
    pub width_cols: &'a [i32],
    pub width_vals: &'a [f64],
    /// Merged ranges to add: (r1, c1, r2, c2).
    pub merges: &'a [i32],
    /// Blocks of cells down a column: (row, column, count).
    pub blocks: &'a [i32],
    /// Per cell: kind (0 blank, 1 number, 2 text, 3 logical, 4 formula,
    /// 5 style only), format (-1 none), and date class (0 none, 2 date,
    /// 3 date-time, 4 time, 5 duration).
    pub kinds: &'a [i32],
    pub fmts: &'a [i32],
    pub dclass: &'a [i32],
    pub nums: &'a [f64],
    pub strs: Vec<Option<&'a str>>,
    /// Tables and blocks of values placed at a cell: (row, column, rows
    /// including the header, columns, header rows).
    pub pieces: &'a [i32],
}

/// What R reports: each chart range that no longer matches the data
/// written, as (the range as the chart has it, cells written, body rows).
pub struct Edited {
    pub charts: Vec<[String; 3]>,
}

// ---------------------------------------------------------------------
// The package

struct Package {
    zip: ZipArchive<BufReader<File>>,
    names: Vec<String>,
}

impl Package {
    fn open(path: &str) -> Result<Package, Failure> {
        let f = File::open(path).map_err(|e| Failure::Io(e.to_string()))?;
        let zip = ZipArchive::new(BufReader::new(f)).map_err(|e| Failure::NotZip(e.to_string()))?;
        let names = (0..zip.len())
            .filter_map(|i| {
                zip.name_for_index(i)
                    .and_then(|r| r.ok())
                    .map(|s| s.into_owned())
            })
            .collect();
        Ok(Package { zip, names })
    }

    fn has(&self, name: &str) -> bool {
        self.names.iter().any(|n| n == name)
    }

    fn read(&mut self, name: &str) -> Result<Option<Vec<u8>>, Failure> {
        let Ok(mut f) = self.zip.by_name(name) else {
            return Ok(None);
        };
        let mut out = Vec::with_capacity(f.size() as usize);
        f.read_to_end(&mut out)
            .map_err(|e| Failure::Corrupt(format!("{name}: {e}")))?;
        Ok(Some(out))
    }
}

/// The `_rels` part of a part.
fn rels_name(part: &str) -> String {
    match part.rfind('/') {
        Some(i) => format!("{}/_rels/{}.rels", &part[..i], &part[i + 1..]),
        None => format!("_rels/{part}.rels"),
    }
}

fn dir_of(part: &str) -> &str {
    part.rfind('/').map(|i| &part[..i]).unwrap_or("")
}

fn resolve(base_dir: &str, target: &str) -> String {
    if let Some(abs) = target.strip_prefix('/') {
        return abs.to_string();
    }
    let mut parts: Vec<&str> = base_dir.split('/').filter(|p| !p.is_empty()).collect();
    for seg in target.split('/') {
        match seg {
            ".." => {
                parts.pop();
            }
            "." | "" => {}
            s => parts.push(s),
        }
    }
    parts.join("/")
}

struct Rel {
    id: String,
    typ: String,
    target: String,
    external: bool,
    span: splice::Span,
}

fn rels(xml: &[u8], base_dir: &str) -> Vec<Rel> {
    live_elements(xml, b"Relationship")
        .into_iter()
        .filter_map(|(_, s)| {
            let te = s.inner_start;
            let id = get_attr(xml, s.start, te, "Id")?;
            let target = get_attr(xml, s.start, te, "Target")?;
            let external = get_attr(xml, s.start, te, "TargetMode").as_deref() == Some("External");
            Some(Rel {
                id,
                typ: get_attr(xml, s.start, te, "Type").unwrap_or_default(),
                target: if external {
                    target
                } else {
                    resolve(base_dir, &target)
                },
                external,
                span: s,
            })
        })
        .collect()
}

fn attr(tag: &str, name: &str) -> Option<String> {
    let b = tag.as_bytes();
    get_attr(b, 0, b.len(), name)
}

/// The relationship id on a `<sheet>` tag (`r:id`, whatever its prefix).
fn rel_id(tag: &str) -> Option<String> {
    if let Some(v) = attr(tag, "r:id") {
        return Some(v);
    }
    let i = tag.find(":id=")?;
    let start = tag[..i].rfind([' ', '\t', '\n', '\r'])? + 1;
    attr(tag, &tag[start..i + 3])
}

struct SheetEntry {
    name: String,
    rid: String,
    span: splice::Span,
    qname: Vec<u8>,
}

fn sheets(wb: &[u8]) -> Vec<SheetEntry> {
    live_elements(wb, b"sheet")
        .into_iter()
        .filter_map(|(q, s)| {
            let tag = tag_text(wb, &s);
            Some(SheetEntry {
                name: attr(&tag, "name")?,
                rid: rel_id(&tag)?,
                span: s,
                qname: q,
            })
        })
        .collect()
}

/// The namespace prefix (with its colon) of a qualified name.
fn prefix(qname: &[u8]) -> String {
    let q = String::from_utf8_lossy(qname);
    q.find(':').map(|i| q[..=i].to_string()).unwrap_or_default()
}

// ---------------------------------------------------------------------
// Styles for the written cells

struct PlanStyler<'a> {
    styles: Option<Styles>,
    overlays: Vec<Overlay>,
    fmts: &'a [i32],
    dclass: &'a [i32],
    values: &'a [f64],
    replace: bool,
    memo: HashMap<(u32, i32, i32), u32>,
    missing_styles: bool,
}

/// Whether a number format of this kind shows a value of this date class.
fn shows(kind: NumberKind, dclass: i32) -> bool {
    match dclass {
        2 | 3 => matches!(kind, NumberKind::Date | NumberKind::DateTime),
        4 => matches!(
            kind,
            NumberKind::Time | NumberKind::DateTime | NumberKind::Duration
        ),
        5 => kind == NumberKind::Duration,
        _ => true,
    }
}

fn fallback_format(dclass: i32) -> &'static str {
    match dclass {
        3 => "yyyy-mm-dd hh:mm:ss",
        4 => "hh:mm:ss",
        5 => "[h]:mm:ss",
        _ => "yyyy-mm-dd",
    }
}

impl Styler for PlanStyler<'_> {
    fn style(&mut self, i: usize, existing: Option<u32>, inherited: Option<u32>) -> Option<u32> {
        let own = if self.replace {
            None
        } else {
            existing.or(inherited)
        };
        let ov = self.fmts.get(i).copied().unwrap_or(-1);
        let dc = self.dclass.get(i).copied().unwrap_or(0);
        let explicit_format = ov >= 0
            && self
                .overlays
                .get(ov as usize)
                .is_some_and(|o| o.numfmt.is_some());
        let Some(styles) = self.styles.as_mut() else {
            if ov >= 0 || dc > 0 {
                self.missing_styles = true;
            }
            return own;
        };
        let base = own.filter(|&b| (b as usize) < styles.n_xfs()).unwrap_or(0);
        let value = self.values.get(i).copied().unwrap_or(0.0);
        let need_date = dc > 0 && !explicit_format && !shows(styles.kind(base, value), dc);
        if ov < 0 && !need_date {
            return own;
        }
        let key = (base, ov, if need_date { dc } else { 0 });
        if let Some(&s) = self.memo.get(&key) {
            return Some(s);
        }
        let mut o = Overlay::default();
        if need_date {
            o.numfmt = Some(fallback_format(dc).to_string());
        }
        if let Some(x) = usize::try_from(ov).ok().and_then(|k| self.overlays.get(k)) {
            merge_overlay(&mut o, x);
        }
        let s = styles.derive(base, &o);
        self.memo.insert(key, s);
        Some(s)
    }
}

fn merge_overlay(a: &mut Overlay, b: &Overlay) {
    macro_rules! take {
        ($($f:ident),*) => { $( if b.$f.is_some() { a.$f = b.$f.clone(); } )* };
    }
    take!(bold, italic, underline, color, fill, align, valign, wrap, indent, size, font, numfmt);
    for k in 0..4 {
        if b.border[k].is_some() {
            a.border[k] = b.border[k];
        }
    }
}

fn overlays(plan: &EditPlan) -> Result<Vec<Overlay>, Failure> {
    let n = plan.fmt_size.len();
    if plan.fmt_ints.len() != n * FMT_INTS || plan.fmt_font.len() != n || plan.fmt_numfmt.len() != n
    {
        return Err(Failure::Plan("the format arrays differ in length".into()));
    }
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let v = &plan.fmt_ints[i * FMT_INTS..(i + 1) * FMT_INTS];
        let flag = |x: i32| (x >= 0).then_some(x == 1);
        let side = |x: i32| (x > 0).then_some(x as u8);
        let size = plan.fmt_size[i];
        out.push(Overlay {
            bold: flag(v[0]),
            italic: flag(v[1]),
            underline: flag(v[2]),
            color: (v[3] >= 0).then_some(v[3] as u32),
            fill: (v[4] >= 0).then_some(v[4] as u32),
            border: [side(v[5]), side(v[6]), side(v[7]), side(v[8])],
            align: (v[9] > 0).then_some(v[9] as u8),
            valign: (v[10] > 0).then_some(v[10] as u8),
            wrap: flag(v[11]),
            indent: (v[12] >= 0).then_some(v[12] as u32),
            size: (size.is_finite() && size > 0.0).then_some(size),
            font: plan.fmt_font[i].map(|s| s.to_string()),
            numfmt: plan.fmt_numfmt[i].map(|s| s.to_string()),
        });
    }
    Ok(out)
}

/// The cells of the plan, with each one's format, date class and number.
type Cells = (Vec<Edit>, Vec<i32>, Vec<i32>, Vec<f64>);

fn plan_edits(plan: &EditPlan) -> Result<Cells, Failure> {
    let bad = |m: &str| Failure::Plan(m.to_string());
    if !plan.blocks.len().is_multiple_of(3)
        || plan.kinds.len() != plan.fmts.len()
        || plan.kinds.len() != plan.dclass.len()
    {
        return Err(bad("the cell arrays differ in length"));
    }
    let (mut edits, mut fmts, mut dcs, mut vals) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    let (mut cell, mut num, mut text) = (0usize, 0usize, 0usize);
    for b in plan.blocks.chunks(3) {
        let (row, col, n) = (b[0], b[1], b[2].max(0) as usize);
        if row < 0 || col < 0 || cell + n > plan.kinds.len() {
            return Err(bad("a block of cells lies outside the arrays"));
        }
        for k in 0..n {
            let kind = plan.kinds[cell];
            let mut x = 0.0;
            let value = match kind {
                1 | 3 => {
                    x = *plan.nums.get(num).ok_or_else(|| bad("too few numbers"))?;
                    num += 1;
                    if kind == 3 {
                        Value::Bool(x != 0.0)
                    } else if x.is_finite() {
                        Value::Number(x)
                    } else {
                        Value::Blank
                    }
                }
                2 | 4 => {
                    let s = plan
                        .strs
                        .get(text)
                        .ok_or_else(|| bad("too few strings"))?
                        .unwrap_or("")
                        .to_string();
                    text += 1;
                    if kind == 4 {
                        Value::Formula(s)
                    } else {
                        Value::Text(s)
                    }
                }
                0 => Value::Blank,
                5 => Value::Restyle,
                k => return Err(Failure::Plan(format!("cell kind {k} is not known"))),
            };
            edits.push(Edit {
                row: row as u32 + k as u32,
                col: col as u32,
                value,
            });
            fmts.push(plan.fmts[cell]);
            dcs.push(plan.dclass[cell]);
            vals.push(x);
            cell += 1;
        }
    }
    if cell != plan.kinds.len() || num != plan.nums.len() || text != plan.strs.len() {
        return Err(bad("the blocks do not use every cell"));
    }
    Ok((edits, fmts, dcs, vals))
}

// ---------------------------------------------------------------------
// Excel tables

struct Table {
    part: String,
    xml: Vec<u8>,
    name: String,
    rect: [u32; 4],
    header_rows: u32,
    totals_rows: u32,
    new_rect: Option<[u32; 4]>,
    new_names: Option<Vec<String>>,
}

fn read_tables(pkg: &mut Package, sheet_part: &str) -> Result<Vec<Table>, Failure> {
    let mut out = Vec::new();
    let Some(r) = pkg.read(&rels_name(sheet_part))? else {
        return Ok(out);
    };
    for rel in rels(&r, dir_of(sheet_part)) {
        if rel.external || !rel.typ.ends_with("/table") {
            continue;
        }
        let Some(xml) = pkg.read(&rel.target)? else {
            continue;
        };
        let Some((_, root)) = live_elements(&xml, b"table").into_iter().next() else {
            continue;
        };
        let tag = tag_text(&xml, &root);
        let Some(rect) = attr(&tag, "ref").and_then(|r| parse_range(&r)) else {
            continue;
        };
        let count = |k: &str, d: u32| {
            attr(&tag, k)
                .and_then(|v| v.trim().parse().ok())
                .unwrap_or(d)
        };
        out.push(Table {
            part: rel.target,
            name: attr(&tag, "displayName")
                .or_else(|| attr(&tag, "name"))
                .unwrap_or_default(),
            rect,
            header_rows: count("headerRowCount", 1),
            totals_rows: count("totalsRowCount", 0),
            xml,
            new_rect: None,
            new_names: None,
        });
    }
    Ok(out)
}

/// An opening tag, made into the start of a pair if it closes itself.
fn opened(tag: &str) -> String {
    let t = tag.trim_end_matches('>').trim_end();
    match t.strip_suffix('/') {
        Some(t) => format!("{}>", t.trim_end()),
        None => format!("{t}>"),
    }
}

/// The table's definition with its new range and column names.
fn rewrite_table(t: &Table) -> Vec<u8> {
    let xml = &t.xml;
    let new = t.new_rect.unwrap_or(t.rect);
    let mut sp: Vec<(usize, usize, String)> = Vec::new();
    if let Some((_, root)) = live_elements(xml, b"table").into_iter().next() {
        let tag = tag_text(xml, &root);
        sp.push((
            root.start,
            root.inner_start,
            set_attr(&tag, "ref", &range_ref(new)),
        ));
    }
    for (local, span) in element_children(xml, b"table") {
        let tag = tag_text(xml, &span);
        match local.as_str() {
            "autoFilter" => {
                // The filter covers the header and the body, not a totals row.
                let last = new[2] - t.totals_rows.min(new[2] - new[0]);
                let f = [new[0], new[1], last, new[3]];
                sp.push((
                    span.start,
                    span.inner_start,
                    set_attr(&tag, "ref", &range_ref(f)),
                ));
            }
            "tableColumns" => {
                let Some(names) = &t.new_names else { continue };
                let cols: Vec<splice::Span> = live_elements(xml, b"tableColumn")
                    .into_iter()
                    .map(|(_, s)| s)
                    .filter(|s| s.start >= span.inner_start && s.end <= span.inner_end)
                    .collect();
                let qname_end = tag[1..]
                    .find([' ', '\t', '\n', '\r', '/', '>'])
                    .map(|i| i + 1)
                    .unwrap_or(tag.len());
                let qname = &tag[1..qname_end];
                let p = prefix(qname.as_bytes());
                let mut next_id = cols
                    .iter()
                    .filter_map(|s| attr(&tag_text(xml, s), "id")?.trim().parse::<u32>().ok())
                    .max()
                    .unwrap_or(0)
                    + 1;
                let mut body = String::new();
                for (k, name) in names.iter().enumerate() {
                    match cols.get(k) {
                        Some(s) => {
                            body.push_str(&set_attr(&tag_text(xml, s), "name", &encode_attr(name)));
                            body.push_str(&String::from_utf8_lossy(&xml[s.inner_start..s.end]));
                        }
                        None => {
                            body.push_str(&format!(
                                "<{p}tableColumn id=\"{next_id}\" name=\"{}\"/>",
                                encode_attr(name)
                            ));
                            next_id += 1;
                        }
                    }
                }
                let open = opened(&set_attr(&tag, "count", &names.len().to_string()));
                sp.push((span.start, span.end, format!("{open}{body}</{qname}>")));
            }
            _ => {}
        }
    }
    splice_bytes(xml, sp)
}

// ---------------------------------------------------------------------
// Charts

struct ChartRef {
    span: splice::Span,
    sheet_text: String,
    sheet: String,
    rect: [u32; 4],
}

type Chart = (String, Vec<u8>, Vec<ChartRef>);

fn charts(pkg: &mut Package) -> Result<Vec<Chart>, Failure> {
    let parts: Vec<String> = pkg
        .names
        .iter()
        .filter(|n| n.starts_with("xl/charts/") && n.ends_with(".xml") && !n.contains("/_rels/"))
        .cloned()
        .collect();
    let mut out = Vec::new();
    for part in parts {
        let Some(xml) = pkg.read(&part)? else {
            continue;
        };
        let mut refs = Vec::new();
        for (_, s) in live_elements(&xml, b"f") {
            let raw = String::from_utf8_lossy(&xml[s.inner_start..s.inner_end]);
            let text = splice::decode_xml(&raw);
            let Some(bang) = text.rfind('!') else {
                continue;
            };
            let sheet_text = text[..bang].to_string();
            let quoted =
                sheet_text.len() >= 2 && sheet_text.starts_with('\'') && sheet_text.ends_with('\'');
            let sheet = if quoted {
                sheet_text[1..sheet_text.len() - 1].replace("''", "'")
            } else {
                sheet_text.clone()
            };
            let Some(rect) = parse_range(&text[bang + 1..]) else {
                continue;
            };
            refs.push(ChartRef {
                span: s,
                sheet_text,
                sheet,
                rect,
            });
        }
        out.push((part, xml, refs));
    }
    Ok(out)
}

/// "$B$2:$B$13"
fn abs_range(r: [u32; 4]) -> String {
    let abs = |row: u32, col: u32| {
        let a = cell_ref(row, col);
        let i = a.find(|c: char| c.is_ascii_digit()).unwrap_or(a.len());
        format!("${}${}", &a[..i], &a[i..])
    };
    if r[0] == r[2] && r[1] == r[3] {
        abs(r[0], r[1])
    } else {
        format!("{}:{}", abs(r[0], r[1]), abs(r[2], r[3]))
    }
}

// ---------------------------------------------------------------------
// New sheets

/// rust_xlsxwriter's conversion of a width in characters to the stored one.
fn excel_width(w: f64) -> f64 {
    let (digit, padding) = (7.0, 5.0);
    if w <= 0.0 {
        0.0
    } else if w < 1.0 {
        ((w * (digit + padding)).round() / digit * 256.0).trunc() / 256.0
    } else {
        ((w * digit + padding).round() / digit * 256.0).trunc() / 256.0
    }
}

fn new_sheet_xml(plan: &EditPlan) -> String {
    let fr = plan.ints.get(1).copied().unwrap_or(-1);
    let fc = plan.ints.get(2).copied().unwrap_or(-1);
    let pane = if fr >= 0 && fc >= 0 && (fr > 0 || fc > 0) {
        let tl = cell_ref(fr as u32, fc as u32);
        let (split, active) = match (fr > 0, fc > 0) {
            (true, true) => (format!(" xSplit=\"{fc}\" ySplit=\"{fr}\""), "bottomRight"),
            (true, false) => (format!(" ySplit=\"{fr}\""), "bottomLeft"),
            _ => (format!(" xSplit=\"{fc}\""), "topRight"),
        };
        format!(
            "<pane{split} topLeftCell=\"{tl}\" activePane=\"{active}\" state=\"frozen\"/><selection pane=\"{active}\" activeCell=\"{tl}\" sqref=\"{tl}\"/>"
        )
    } else {
        String::new()
    };
    let mut cols = String::new();
    for (c, w) in plan.width_cols.iter().zip(plan.width_vals) {
        if *c >= 0 && w.is_finite() {
            cols.push_str(&format!(
                "<col min=\"{0}\" max=\"{0}\" width=\"{1}\" customWidth=\"1\"/>",
                c + 1,
                splice::number_text(excel_width(*w))
            ));
        }
    }
    if !cols.is_empty() {
        cols = format!("<cols>{cols}</cols>");
    }
    format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"{REL_NS}\"><dimension ref=\"A1\"/><sheetViews><sheetView workbookViewId=\"0\">{pane}</sheetView></sheetViews><sheetFormatPr defaultRowHeight=\"15\"/>{cols}<sheetData/><pageMargins left=\"0.7\" right=\"0.7\" top=\"0.75\" bottom=\"0.75\" header=\"0.3\" footer=\"0.3\"/></worksheet>"
    )
}

fn find_last(xml: &[u8], needle: &[u8]) -> Option<usize> {
    memchr::memmem::rfind(xml, needle)
}

fn same_name(a: &str, b: &str) -> bool {
    a.to_lowercase() == b.to_lowercase()
}

// ---------------------------------------------------------------------
// The edit

/// Write the plan into the workbook `src`, giving the new package `dst`.
pub fn edit(src: &str, dst: &str, plan: &EditPlan) -> Result<Edited, Failure> {
    let replace = plan.ints.first().copied().unwrap_or(0) == 1;
    let mut pkg = Package::open(src)?;
    let mut changed: BTreeMap<String, Vec<u8>> = BTreeMap::new();
    let mut added: Vec<(String, Vec<u8>)> = Vec::new();
    let mut deleted: HashSet<String> = HashSet::new();

    // The workbook part, from the package relationships.
    let root_rels = pkg
        .read("_rels/.rels")?
        .ok_or_else(|| Failure::NotWorkbook("it has no _rels/.rels".into()))?;
    let wb_part = rels(&root_rels, "")
        .into_iter()
        .find(|r| r.typ.ends_with("/officeDocument"))
        .map(|r| r.target)
        .unwrap_or_else(|| "xl/workbook.xml".into());
    if wb_part.ends_with(".bin") {
        return Err(Failure::NotWorkbook("it is an .xlsb workbook".into()));
    }
    let mut wb = pkg
        .read(&wb_part)?
        .ok_or_else(|| Failure::NotWorkbook(format!("it has no {wb_part}")))?;
    let wb_rels_part = rels_name(&wb_part);
    let wb_rels = pkg.read(&wb_rels_part)?.unwrap_or_default();
    let wb_dir = dir_of(&wb_part).to_string();
    let rel_list = rels(&wb_rels, &wb_dir);
    let sheet_list = sheets(&wb);
    let target = sheet_list
        .iter()
        .position(|s| same_name(&s.name, plan.sheet));

    let (sheet_part, sheet_xml, is_new) = match target {
        Some(i) => {
            let rel = rel_list
                .iter()
                .find(|r| r.id == sheet_list[i].rid)
                .ok_or_else(|| Failure::Corrupt(format!("sheet \"{}\" has no part", plan.sheet)))?;
            if !rel.typ.ends_with("/worksheet") {
                return Err(Failure::NotWorksheet(sheet_list[i].name.clone()));
            }
            let xml = pkg
                .read(&rel.target)?
                .ok_or_else(|| Failure::Corrupt(format!("it has no {}", rel.target)))?;
            (rel.target.clone(), xml, false)
        }
        None => {
            let mut n = 1;
            let part = loop {
                let p = format!("xl/worksheets/sheet{n}.xml");
                if !pkg.has(&p) {
                    break p;
                }
                n += 1;
            };
            (part, new_sheet_xml(plan).into_bytes(), true)
        }
    };

    let styles_part = rel_list
        .iter()
        .find(|r| r.typ.ends_with("/styles"))
        .map(|r| r.target.clone());
    let styles = match &styles_part {
        Some(p) => pkg.read(p)?.and_then(Styles::parse),
        None => None,
    };

    let (mut edits, mut fmts, mut dcs, mut vals) = plan_edits(plan)?;
    let pieces: Vec<[u32; 5]> = plan
        .pieces
        .chunks(5)
        .filter(|p| p.len() == 5 && p.iter().all(|&x| x >= 0))
        .map(|p| {
            [
                p[0] as u32,
                p[1] as u32,
                p[2] as u32,
                p[3] as u32,
                p[4] as u32,
            ]
        })
        .collect();
    let mut written: HashSet<(u32, u32)> = edits.iter().map(|e| (e.row, e.col)).collect();
    let last_at: HashMap<(u32, u32), usize> = edits
        .iter()
        .enumerate()
        .map(|(i, e)| ((e.row, e.col), i))
        .collect();
    let value_at =
        |edits: &[Edit], r: u32, c: u32| last_at.get(&(r, c)).map(|&i| edits[i].value.clone());

    // Excel tables on the sheet: one written at its top-left cell takes
    // the new table's size and names.
    let mut tables = if is_new {
        Vec::new()
    } else {
        read_tables(&mut pkg, &sheet_part)?
    };
    let mut resized: Vec<usize> = Vec::new();
    let mut piece_is_table = vec![false; pieces.len()];
    for (k, t) in tables.iter_mut().enumerate() {
        match pieces
            .iter()
            .position(|p| p[0] == t.rect[0] && p[1] == t.rect[1] && p[4] >= 1)
        {
            Some(pi) => {
                let p = pieces[pi];
                if t.header_rows != 1 || t.totals_rows != 0 || p[4] != 1 || p[2] < 2 || p[3] < 1 {
                    let why = if t.totals_rows != 0 {
                        "totals"
                    } else {
                        "header"
                    };
                    return Err(Failure::TableShape(format!(
                        "{}\t{}\t{why}",
                        t.name,
                        range_ref(t.rect)
                    )));
                }
                let mut names: Vec<String> = Vec::new();
                for j in 0..p[3] {
                    let name = match value_at(&edits, p[0], p[1] + j) {
                        Some(Value::Text(s)) => s,
                        Some(Value::Number(x)) => splice::number_text(x),
                        _ => format!("Column{}", j + 1),
                    };
                    if names.iter().any(|n| same_name(n, &name)) {
                        return Err(Failure::TableNames(format!("{}\t{name}", t.name)));
                    }
                    names.push(name);
                }
                t.new_rect = Some([p[0], p[1], p[0] + p[2] - 1, p[1] + p[3] - 1]);
                t.new_names = Some(names);
                piece_is_table[pi] = true;
                resized.push(k);
            }
            None if replace => {
                return Err(Failure::TableCleared(format!(
                    "{}\t{}",
                    t.name,
                    range_ref(t.rect)
                )));
            }
            None => {}
        }
    }
    if !replace {
        // Writes into a header are refused; writes that run past a table's
        // last row grow it.
        for (k, t) in tables.iter_mut().enumerate() {
            if resized.contains(&k) {
                continue;
            }
            if t.header_rows > 0 {
                let header = [
                    t.rect[0],
                    t.rect[1],
                    t.rect[0] + t.header_rows - 1,
                    t.rect[3],
                ];
                let hit = edits
                    .iter()
                    .find(|e| contains(header, e.row, e.col) && e.value != Value::Restyle);
                if let Some(e) = hit {
                    return Err(Failure::TableHeader(format!(
                        "{}\t{}\t{}",
                        cell_ref(e.row, e.col),
                        t.name,
                        range_ref(t.rect)
                    )));
                }
            }
            let body_top = t.rect[0] + t.header_rows;
            for p in &pieces {
                let inside =
                    p[0] >= body_top && p[0] <= t.rect[2] && p[1] >= t.rect[1] && p[1] <= t.rect[3];
                let bottom = p[0] + p[2].max(1) - 1;
                if inside && bottom > t.rect[2] {
                    if t.totals_rows != 0 {
                        return Err(Failure::TableShape(format!(
                            "{}\t{}\ttotals",
                            t.name,
                            range_ref(t.rect)
                        )));
                    }
                    let cur = t.new_rect.unwrap_or(t.rect);
                    t.new_rect = Some([cur[0], cur[1], bottom.max(cur[2]), cur[3]]);
                }
            }
            if t.new_rect.is_some() {
                resized.push(k);
            }
        }
    }
    for &k in &resized {
        let a = tables[k].new_rect.unwrap_or(tables[k].rect);
        for (j, o) in tables.iter().enumerate() {
            if j != k && overlaps(a, o.new_rect.unwrap_or(o.rect)) {
                return Err(Failure::TableOverlap(format!(
                    "{}\t{}",
                    tables[k].name, o.name
                )));
            }
        }
    }
    // What a table written at its top-left covered, and the new one does
    // not, is cleared (keeping its formats).
    if !replace {
        for &k in &resized {
            let t = &tables[k];
            if t.new_names.is_none() {
                continue;
            }
            let new = t.new_rect.unwrap_or(t.rect);
            for r in t.rect[0]..=t.rect[2] {
                for c in t.rect[1]..=t.rect[3] {
                    if !contains(new, r, c) && written.insert((r, c)) {
                        edits.push(Edit {
                            row: r,
                            col: c,
                            value: Value::Blank,
                        });
                        fmts.push(-1);
                        dcs.push(0);
                        vals.push(0.0);
                    }
                }
            }
        }
    }

    // New merged ranges must not hide values.
    let merges: Vec<[u32; 4]> = plan
        .merges
        .chunks(4)
        .filter(|m| m.len() == 4 && m.iter().all(|&x| x >= 0))
        .map(|m| [m[0] as u32, m[1] as u32, m[2] as u32, m[3] as u32])
        .collect();
    for m in &merges {
        let mut hidden: Vec<(u32, u32)> = edits
            .iter()
            .filter(|e| contains(*m, e.row, e.col) && !(e.row == m[0] && e.col == m[1]))
            .filter(|e| !matches!(e.value, Value::Blank | Value::Restyle))
            .map(|e| (e.row, e.col))
            .collect();
        if !replace && !is_new {
            for cell in splice::filled_cells(&sheet_xml, *m).map_err(splice_failure)? {
                if cell != (m[0], m[1]) && !written.contains(&cell) {
                    hidden.push(cell);
                }
            }
        }
        if let Some(&(r, c)) = hidden.iter().min() {
            return Err(Failure::MergeHides(format!(
                "{}\t{}",
                range_ref(*m),
                cell_ref(r, c)
            )));
        }
    }

    // The worksheet.
    let mut styler = PlanStyler {
        styles,
        overlays: overlays(plan)?,
        fmts: &fmts,
        dclass: &dcs,
        values: &vals,
        replace,
        memo: HashMap::new(),
        missing_styles: false,
    };
    let outcome = if replace {
        splice::replace_sheet_data(&sheet_xml, &edits, &mut styler)
    } else {
        splice::apply_edits(&sheet_xml, &edits, &mut styler)
    }
    .map_err(splice_failure)?;
    if styler.missing_styles {
        return Err(Failure::NoStyles);
    }
    let sheet_out = splice::add_merges(&outcome.xml, &merges).map_err(splice_failure)?;
    if is_new {
        added.push((sheet_part.clone(), sheet_out));
    } else if sheet_out != sheet_xml {
        changed.insert(sheet_part.clone(), sheet_out);
    }
    if let (Some(p), Some(s)) = (&styles_part, styler.styles.take()) {
        if let Some(xml) = s.finish() {
            changed.insert(p.clone(), xml);
        }
    }

    // Tables, the charts that plot them, and charts that no longer match.
    for &k in &resized {
        changed.insert(tables[k].part.clone(), rewrite_table(&tables[k]));
    }
    // Charts that plot the rows below a header written here, but not all
    // of them: one message for each chart, piece and range of rows.
    // (chart part, piece, first row, last row) -> (sheet as written, columns).
    type Key = (String, usize, u32, u32);
    let mut mismatched: BTreeMap<Key, (String, u32, u32)> = BTreeMap::new();
    for (part, xml, refs) in charts(&mut pkg)? {
        let mut sp = Vec::new();
        for r in refs.iter().filter(|r| same_name(&r.sheet, plan.sheet)) {
            let one_column = r.rect[1] == r.rect[3];
            // A series that plots a column of a resized table follows it.
            let mut moved = false;
            for &k in &resized {
                let t = &tables[k];
                let new = t.new_rect.unwrap_or(t.rect);
                let body = t.rect[0] + t.header_rows;
                let in_table = one_column && r.rect[1] >= new[1] && r.rect[1] <= new[3];
                let whole = r.rect[0] == body && r.rect[2] == t.rect[2] - t.totals_rows;
                if in_table && whole && new[2] != t.rect[2] {
                    let nr = [
                        new[0] + t.header_rows,
                        r.rect[1],
                        new[2] - t.totals_rows,
                        r.rect[1],
                    ];
                    let text = format!("{}!{}", r.sheet_text, abs_range(nr));
                    sp.push((r.span.inner_start, r.span.inner_end, encode_text(&text)));
                    moved = true;
                }
            }
            if moved {
                continue;
            }
            for (pi, p) in pieces.iter().enumerate() {
                if piece_is_table[pi] || p[4] == 0 || p[2] <= p[4] {
                    continue;
                }
                let body_top = p[0] + p[4];
                let body_last = p[0] + p[2] - 1;
                let column = one_column && r.rect[1] >= p[1] && r.rect[1] < p[1] + p[3];
                if column && r.rect[0] == body_top && r.rect[2] != body_last {
                    let e = mismatched
                        .entry((part.clone(), pi, r.rect[0], r.rect[2]))
                        .or_insert((r.sheet_text.clone(), r.rect[1], r.rect[1]));
                    e.1 = e.1.min(r.rect[1]);
                    e.2 = e.2.max(r.rect[1]);
                }
            }
        }
        if !sp.is_empty() {
            changed.insert(part, splice_bytes(&xml, sp));
        }
    }
    let mut messages: Vec<[String; 3]> = Vec::new();
    for ((_, pi, r1, r2), (sheet_text, c1, c2)) in mismatched {
        let p = pieces[pi];
        let entry = [
            format!("{sheet_text}!{}", range_ref([r1, c1, r2, c2])),
            range_ref([p[0] + p[4], p[1], p[0] + p[2] - 1, p[1] + p[3] - 1]),
            (p[2] - p[4]).to_string(),
        ];
        if !messages.contains(&entry) {
            messages.push(entry);
        }
    }

    // The workbook: a new sheet, and recalculation when it opens.
    let mut wb_sp: Vec<(usize, usize, String)> = Vec::new();
    let mut new_rels = wb_rels.clone();
    let mut content_types: Option<Vec<u8>> = None;
    if is_new {
        let ids: HashSet<&str> = rel_list.iter().map(|r| r.id.as_str()).collect();
        let rid = (1..)
            .map(|k| format!("rId{k}"))
            .find(|id| !ids.contains(id.as_str()))
            .unwrap_or_default();
        let sheet_id = sheet_list
            .iter()
            .filter_map(|s| {
                attr(&tag_text(&wb, &s.span), "sheetId")?
                    .trim()
                    .parse::<u32>()
                    .ok()
            })
            .max()
            .unwrap_or(0)
            + 1;
        let after = plan
            .after
            .and_then(|a| sheet_list.iter().position(|s| same_name(&s.name, a)));
        let (pos, at) = match (after, sheet_list.last()) {
            (Some(i), _) => (i + 1, sheet_list[i].span.end),
            (None, Some(s)) => (sheet_list.len(), s.span.end),
            (None, None) => {
                let (_, el) = live_elements(&wb, b"sheets")
                    .into_iter()
                    .next()
                    .ok_or_else(|| Failure::Corrupt("its workbook part lists no sheets".into()))?;
                (0, el.inner_end)
            }
        };
        let qname = sheet_list
            .first()
            .map(|s| String::from_utf8_lossy(&s.qname).into_owned())
            .unwrap_or_else(|| "sheet".into());
        let root_tag = live_elements(&wb, b"workbook")
            .into_iter()
            .next()
            .map(|(_, s)| tag_text(&wb, &s))
            .unwrap_or_default();
        let r_prefix = root_tag.split_whitespace().find_map(|a| {
            let (k, v) = a.split_once('=')?;
            let v = v.trim_end_matches(['>', '/']).trim_matches(['"', '\'']);
            let p = k.strip_prefix("xmlns:")?;
            (v == REL_NS || v == STRICT_REL_NS).then(|| p.to_string())
        });
        let rattr = match r_prefix {
            Some(p) => format!("{p}:id=\"{rid}\""),
            None => format!("xmlns:r=\"{REL_NS}\" r:id=\"{rid}\""),
        };
        wb_sp.push((
            at,
            at,
            format!(
                "<{qname} name=\"{}\" sheetId=\"{sheet_id}\" {rattr}/>",
                encode_attr(plan.sheet)
            ),
        ));
        // Sheet positions from the new one on move up by one.
        for (local, names) in [
            ("definedName", &["localSheetId"][..]),
            ("workbookView", &["activeTab", "firstSheet"][..]),
        ] {
            for (_, s) in live_elements(&wb, local.as_bytes()) {
                let orig = tag_text(&wb, &s);
                let mut tag = orig.clone();
                for a in names {
                    if let Some(v) = attr(&tag, a).and_then(|v| v.trim().parse::<usize>().ok()) {
                        if v >= pos {
                            tag = set_attr(&tag, a, &(v + 1).to_string());
                        }
                    }
                }
                if tag != orig {
                    wb_sp.push((s.start, s.inner_start, tag));
                }
            }
        }
        // Its relationship and content type.
        let target = match sheet_part.strip_prefix("xl/") {
            Some(t) if wb_dir == "xl" => t.to_string(),
            _ => format!("/{sheet_part}"),
        };
        let rel =
            format!("<Relationship Id=\"{rid}\" Type=\"{WORKSHEET_TYPE}\" Target=\"{target}\"/>");
        let close = find_last(&new_rels, b"</Relationships>")
            .ok_or_else(|| Failure::Corrupt("its workbook relationships cannot be read".into()))?;
        new_rels = splice_bytes(&new_rels, vec![(close, close, rel)]);
        let ct = pkg
            .read("[Content_Types].xml")?
            .ok_or_else(|| Failure::NotWorkbook("it has no [Content_Types].xml".into()))?;
        let close = find_last(&ct, b"</Types>")
            .ok_or_else(|| Failure::Corrupt("its content types cannot be read".into()))?;
        let entry =
            format!("<Override PartName=\"/{sheet_part}\" ContentType=\"{WORKSHEET_CT}\"/>");
        content_types = Some(splice_bytes(&ct, vec![(close, close, entry)]));
    }
    match live_elements(&wb, b"calcPr").into_iter().next() {
        Some((_, s)) => {
            let tag = tag_text(&wb, &s);
            let new = set_attr(&tag, "fullCalcOnLoad", "1");
            if new != tag {
                wb_sp.push((s.start, s.inner_start, new));
            }
        }
        None => {
            const BEFORE: [&str; 9] = [
                "fileVersion",
                "fileSharing",
                "workbookPr",
                "workbookProtection",
                "bookViews",
                "sheets",
                "functionGroups",
                "externalReferences",
                "definedNames",
            ];
            let at = element_children(&wb, b"workbook")
                .iter()
                .filter(|(n, _)| BEFORE.contains(&n.as_str()))
                .map(|(_, s)| s.end)
                .max()
                .ok_or_else(|| Failure::Corrupt("its workbook part lists no sheets".into()))?;
            let p = live_elements(&wb, b"sheets")
                .into_iter()
                .next()
                .map(|(q, _)| prefix(&q))
                .unwrap_or_default();
            wb_sp.push((at, at, format!("<{p}calcPr fullCalcOnLoad=\"1\"/>")));
        }
    }
    if !wb_sp.is_empty() {
        wb = splice_bytes(&wb, wb_sp);
        changed.insert(wb_part.clone(), wb);
    }

    // The calculation chain may list formulas that are gone.
    if outcome.removed_formula {
        if let Some(chain) = rel_list.iter().find(|r| r.typ.ends_with("/calcChain")) {
            deleted.insert(chain.target.clone());
            if let Some(r) = rels(&new_rels, &wb_dir).iter().find(|r| r.id == chain.id) {
                new_rels = splice_bytes(&new_rels, vec![(r.span.start, r.span.end, String::new())]);
            }
            let ct = match content_types.take() {
                Some(c) => Some(c),
                None => pkg.read("[Content_Types].xml")?,
            };
            if let Some(ct) = ct {
                let name = format!("/{}", chain.target);
                let hit = live_elements(&ct, b"Override").into_iter().find(|(_, s)| {
                    attr(&tag_text(&ct, s), "PartName").as_deref() == Some(name.as_str())
                });
                content_types = Some(match hit {
                    Some((_, s)) => splice_bytes(&ct, vec![(s.start, s.end, String::new())]),
                    None => ct,
                });
            }
        }
    }
    if new_rels != wb_rels {
        changed.insert(wb_rels_part, new_rels);
    }
    if let Some(ct) = content_types {
        changed.insert("[Content_Types].xml".into(), ct);
    }

    write_package(&mut pkg, dst, &changed, &added, &deleted)?;
    Ok(Edited { charts: messages })
}

fn write_package(
    pkg: &mut Package,
    dst: &str,
    changed: &BTreeMap<String, Vec<u8>>,
    added: &[(String, Vec<u8>)],
    deleted: &HashSet<String>,
) -> Result<(), Failure> {
    let io = |e: std::io::Error| Failure::Write(e.to_string());
    let z = |e: zip::result::ZipError| Failure::Write(e.to_string());
    let file = File::create(dst).map_err(io)?;
    let mut w = ZipWriter::new(std::io::BufWriter::new(file));
    for i in 0..pkg.zip.len() {
        let f = pkg
            .zip
            .by_index_raw(i)
            .map_err(|e| Failure::Corrupt(e.to_string()))?;
        let name = f
            .name()
            .map(|n| n.into_owned())
            .map_err(|e| Failure::Corrupt(e.to_string()))?;
        if deleted.contains(&name) {
            continue;
        }
        match changed.get(&name) {
            Some(data) => {
                let mut opts = SimpleFileOptions::default()
                    .compression_method(CompressionMethod::Deflated)
                    .large_file(data.len() as u64 >= u32::MAX as u64);
                if let Some(t) = f.last_modified() {
                    opts = opts.last_modified_time(t);
                }
                drop(f);
                w.start_file(name, opts).map_err(z)?;
                w.write_all(data).map_err(io)?;
            }
            None => w.raw_copy_file(f).map_err(z)?,
        }
    }
    for (name, data) in added {
        let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);
        w.start_file(name.as_str(), opts).map_err(z)?;
        w.write_all(data).map_err(io)?;
    }
    let out = w.finish().map_err(z)?;
    let file = out
        .into_inner()
        .map_err(|e| Failure::Write(e.to_string()))?;
    file.sync_all().map_err(io)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const MAIN: &str = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

    fn package(path: &str) {
        let parts: Vec<(&str, String)> = vec![
            ("[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/></Types>".into()),
            ("_rels/.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>".into()),
            ("xl/workbook.xml", format!("<workbook xmlns=\"{MAIN}\" xmlns:r=\"{REL_NS}\"><bookViews><workbookView activeTab=\"1\"/></bookViews><sheets><sheet name=\"A\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"B\" sheetId=\"2\" r:id=\"rId2\"/></sheets><definedNames><definedName name=\"_xlnm.Print_Area\" localSheetId=\"1\">B!$A$1:$B$2</definedName></definedNames></workbook>")),
            ("xl/_rels/workbook.xml.rels", format!("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"{WORKSHEET_TYPE}\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"{WORKSHEET_TYPE}\" Target=\"worksheets/sheet2.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>")),
            ("xl/worksheets/sheet1.xml", format!("<worksheet xmlns=\"{MAIN}\"><sheetData/></worksheet>")),
            ("xl/worksheets/sheet2.xml", format!("<worksheet xmlns=\"{MAIN}\"><dimension ref=\"A1\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"1\"><v>1</v></c></row></sheetData></worksheet>")),
            ("xl/styles.xml", format!("<styleSheet xmlns=\"{MAIN}\"><fonts count=\"1\"><font/></fonts><fills count=\"1\"><fill/></fills><borders count=\"1\"><border/></borders><cellXfs count=\"2\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"3\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs></styleSheet>")),
        ];
        let mut w = ZipWriter::new(File::create(path).unwrap());
        for (name, data) in parts {
            w.start_file(name, SimpleFileOptions::default()).unwrap();
            w.write_all(data.as_bytes()).unwrap();
        }
        w.finish().unwrap();
    }

    fn read(path: &str, name: &str) -> String {
        let mut z = ZipArchive::new(File::open(path).unwrap()).unwrap();
        let mut s = String::new();
        z.by_name(name).unwrap().read_to_string(&mut s).unwrap();
        s
    }

    fn plan<'a>(
        sheet: &'a str,
        after: Option<&'a str>,
        blocks: &'a [i32],
        kinds: &'a [i32],
        dclass: &'a [i32],
        nums: &'a [f64],
    ) -> EditPlan<'a> {
        EditPlan {
            fmt_ints: &[],
            fmt_size: &[],
            fmt_font: vec![],
            fmt_numfmt: vec![],
            sheet,
            after,
            ints: &[0, -1, -1],
            width_cols: &[],
            width_vals: &[],
            merges: &[],
            blocks,
            kinds,
            fmts: &[-1, -1],
            dclass,
            nums,
            strs: vec![],
            pieces: &[],
        }
    }

    #[test]
    fn a_new_sheet_moves_later_sheet_positions_and_adds_calc_pr() {
        let dir = std::env::temp_dir().join(format!("xlkit-edit-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.xlsx").to_string_lossy().into_owned();
        let dst = dir.join("dst.xlsx").to_string_lossy().into_owned();
        package(&src);
        let p = plan("New", Some("A"), &[0, 0, 1], &[1], &[0], &[5.0]);
        let p = EditPlan { fmts: &[-1], ..p };
        edit(&src, &dst, &p).unwrap();
        let wb = read(&dst, "xl/workbook.xml");
        assert!(wb.contains("<sheet name=\"A\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"New\" sheetId=\"3\" r:id=\"rId4\"/><sheet name=\"B\""));
        assert!(wb.contains("localSheetId=\"2\""));
        assert!(wb.contains("<workbookView activeTab=\"2\"/>"));
        assert!(wb.contains("</definedNames><calcPr fullCalcOnLoad=\"1\"/></workbook>"));
        assert!(read(&dst, "xl/_rels/workbook.xml.rels").contains("Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet3.xml\""));
        assert!(
            read(&dst, "[Content_Types].xml").contains("PartName=\"/xl/worksheets/sheet3.xml\"")
        );
        assert!(read(&dst, "xl/worksheets/sheet3.xml").contains("<c r=\"A1\"><v>5</v></c>"));
        // Parts not written are the same bytes.
        assert_eq!(
            read(&dst, "xl/worksheets/sheet2.xml"),
            read(&src, "xl/worksheets/sheet2.xml")
        );
        assert_eq!(read(&dst, "xl/styles.xml"), read(&src, "xl/styles.xml"));
    }

    #[test]
    fn a_date_takes_a_date_format_and_keeps_the_cell_format_otherwise() {
        let dir = std::env::temp_dir().join(format!("xlkit-edit2-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.xlsx").to_string_lossy().into_owned();
        let dst = dir.join("dst.xlsx").to_string_lossy().into_owned();
        package(&src);
        let p = plan("B", None, &[0, 0, 2], &[1, 1], &[2, 0], &[45306.0, 7.0]);
        edit(&src, &dst, &p).unwrap();
        let sheet = read(&dst, "xl/worksheets/sheet2.xml");
        assert!(
            sheet.contains("<c r=\"A1\" s=\"2\"><v>45306</v></c>"),
            "{sheet}"
        );
        assert!(
            sheet.contains("<row r=\"2\"><c r=\"A2\"><v>7</v></c></row>"),
            "{sheet}"
        );
        assert!(sheet.contains("<dimension ref=\"A1:A2\"/>"));
        let styles = read(&dst, "xl/styles.xml");
        assert!(styles.contains(
            "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"yyyy-mm-dd\"/></numFmts>"
        ));
        assert!(styles.contains("<cellXfs count=\"3\">"));
    }
}
