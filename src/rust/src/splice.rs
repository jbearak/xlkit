//! The worksheet splice: write cells into a worksheet's XML without
//! parsing it into a model (ADR 0006).
//!
//! Adapted from Table Viewer (src/xlsx-cell-write.ts, src/ooxml-worksheet-scan.ts
//! and src/ooxml-xml.ts; GPL-3.0, Copyright Jonathan Bearak; see
//! ACKNOWLEDGEMENTS.md). The scanner finds the live `<sheetData>`, `<row>`
//! and `<c>` elements by byte offset, skipping comments, CDATA and
//! processing instructions and honouring quoted `>` in attribute values.
//! An edit replaces one `<c>` element, or inserts a new `<c>` (and if needed
//! a new `<row>`) at its sorted place; every other byte is copied through.
//! A worksheet whose correct edit is undetermined is refused with one of
//! Table Viewer's five refusal codes, chosen by the same rules, and its
//! language-neutral corpus (tests/conformance) pins the output bytes.
//!
//! What differs from Table Viewer: values arrive typed (a number, text, a
//! logical, a formula or a blank), not as text to classify; the style of
//! each written cell is chosen by the caller (`Styler`), which sees the
//! cell's own style; formula caches are not rewritten (xlkit sets
//! `fullCalcOnLoad` instead); and the `<dimension>` is widened here.

use memchr::memmem;
use std::collections::{BTreeMap, HashMap};

const MAX_ROWS: u64 = 1_048_576;
const MAX_COLS: u64 = 16_384;
const SPREADSHEETML_NS: &str = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
const STRICT_NS: &str = "http://purl.oclc.org/ooxml/spreadsheetml/main";
const MC_NS: &str = "http://schemas.openxmlformats.org/markup-compatibility/2006";

/// One of Table Viewer's five refusal codes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Refusal {
    NamespacePrefixed,
    MarkupCompatibility,
    ForeignNamespace,
    MissingReference,
    InvalidReference,
}

impl Refusal {
    pub fn code(self) -> &'static str {
        match self {
            Refusal::NamespacePrefixed => "namespace-prefixed-worksheet-element",
            Refusal::MarkupCompatibility => "markup-compatibility-alternate-content",
            Refusal::ForeignNamespace => "foreign-worksheet-namespace",
            Refusal::MissingReference => "missing-cell-reference",
            Refusal::InvalidReference => "invalid-cell-reference",
        }
    }
}

/// Why a splice did not happen.
#[derive(Debug, Clone, PartialEq)]
pub enum SpliceError {
    Refused(Refusal),
    /// The worksheet has no `<sheetData>` that can be edited.
    NoSheetData,
    /// A write into a merged range other than its top-left cell:
    /// (row, col) and the range, 0-based.
    Merged(u32, u32, [u32; 4]),
    /// A value written into a shared formula, array formula or data table's
    /// range: (row, col), the kind and the range.
    Grouped(u32, u32, &'static str, [u32; 4]),
    /// A new merged range overlaps one the sheet has.
    MergeOverlap([u32; 4], [u32; 4]),
}

/// A typed cell value.
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Number(f64),
    Text(String),
    Bool(bool),
    /// A formula without its leading `=`.
    Formula(String),
    /// No value; the cell keeps (or is given) a style only.
    Blank,
    /// The cell keeps its value and formula, and takes the style the
    /// `Styler` gives it.
    Restyle,
}

/// One cell to write, 0-based.
#[derive(Debug, Clone, PartialEq)]
pub struct Edit {
    pub row: u32,
    pub col: u32,
    pub value: Value,
}

/// Chooses the style index (`s`) of each written cell.
pub trait Styler {
    /// `edit` is the index into the edits; `present` whether the cell has
    /// an element already; `existing` its own `s`; `inherited` the style
    /// it shows from its row or column when it has no `s` of its own.
    /// Returns the `s` to write (None or 0: none).
    fn style(
        &mut self,
        edit: usize,
        present: bool,
        existing: Option<u32>,
        inherited: Option<u32>,
    ) -> Option<u32>;
}

/// Keeps each cell's own style, as Table Viewer does.
#[cfg(test)]
pub struct KeepStyle;

#[cfg(test)]
impl Styler for KeepStyle {
    fn style(&mut self, _: usize, _: bool, existing: Option<u32>, _: Option<u32>) -> Option<u32> {
        existing
    }
}

/// The edited worksheet, and whether a formula was overwritten (so the
/// calculation chain must go).
pub struct Outcome {
    pub xml: Vec<u8>,
    pub removed_formula: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    pub start: usize,
    pub end: usize,
    pub inner_start: usize,
    pub inner_end: usize,
}

impl Span {
    fn empty(start: usize, end: usize) -> Span {
        Span {
            start,
            end,
            inner_start: end,
            inner_end: end,
        }
    }
}

// ---------------------------------------------------------------------
// Byte scanning

fn find(xml: &[u8], needle: &[u8], from: usize, to: usize) -> Option<usize> {
    let to = to.min(xml.len());
    if from >= to {
        return None;
    }
    memmem::find(&xml[from..to], needle).map(|i| i + from)
}

fn starts_with(xml: &[u8], needle: &[u8], at: usize) -> bool {
    xml.len() >= at + needle.len() && &xml[at..at + needle.len()] == needle
}

fn is_ws(c: u8) -> bool {
    matches!(c, b' ' | b'\t' | b'\n' | b'\r')
}

fn is_boundary(c: Option<&u8>) -> bool {
    matches!(c, Some(b'>') | Some(b'/')) || c.is_some_and(|c| is_ws(*c))
}

fn text(xml: &[u8], from: usize, to: usize) -> String {
    String::from_utf8_lossy(&xml[from..to]).into_owned()
}

/// The `>` that closes the tag starting at `start`, skipping quoted values.
pub(crate) fn find_tag_end(xml: &[u8], start: usize, to: usize) -> Option<usize> {
    let mut quote = 0u8;
    for (i, &c) in xml.iter().enumerate().take(to.min(xml.len())).skip(start) {
        if quote != 0 {
            if c == quote {
                quote = 0;
            }
        } else if c == b'"' || c == b'\'' {
            quote = c;
        } else if c == b'>' {
            return Some(i);
        }
    }
    None
}

pub(crate) fn is_self_closing(xml: &[u8], start: usize, tag_end: usize) -> bool {
    let mut i = tag_end;
    while i > start + 1 {
        i -= 1;
        if xml[i] == b'/' {
            return true;
        }
        if !is_ws(xml[i]) {
            return false;
        }
    }
    false
}

/// Comments, CDATA sections and processing instructions in `[from, to)`:
/// their contents are text, not markup.
pub(crate) struct Ignorable(Vec<(usize, usize)>);

impl Ignorable {
    pub(crate) fn new(xml: &[u8], from: usize, to: usize) -> Ignorable {
        let kinds: [(&[u8], &[u8]); 3] =
            [(b"<!--", b"-->"), (b"<![CDATA[", b"]]>"), (b"<?", b"?>")];
        let mut next: Vec<Option<usize>> = kinds.iter().map(|k| find(xml, k.0, from, to)).collect();
        let mut out: Vec<(usize, usize)> = Vec::new();
        while let Some((k, start)) = next
            .iter()
            .enumerate()
            .filter_map(|(k, s)| s.map(|s| (k, s)))
            .min_by_key(|&(_, s)| s)
        {
            let (open, close) = kinds[k];
            let end = match find(xml, close, start + open.len(), to) {
                Some(c) => (c + close.len()).min(to),
                None => to,
            };
            out.push((start, end));
            for (j, kind) in kinds.iter().enumerate() {
                if let Some(s) = next[j] {
                    if s < end {
                        next[j] = find(xml, kind.0, end, to);
                    }
                }
            }
            if end >= to {
                break;
            }
        }
        Ignorable(out)
    }

    /// Where to resume if `at` is inside an ignorable range.
    pub(crate) fn end_of(&self, at: usize) -> Option<usize> {
        let i = self.0.partition_point(|&(s, _)| s <= at);
        if i == 0 {
            return None;
        }
        let (s, e) = self.0[i - 1];
        (at >= s && at < e).then_some(e)
    }
}

pub(crate) fn find_live(
    xml: &[u8],
    needle: &[u8],
    from: usize,
    to: usize,
    ign: &Ignorable,
) -> Option<usize> {
    let mut pos = from;
    while pos < to {
        let at = find(xml, needle, pos, to)?;
        match ign.end_of(at) {
            None => return Some(at),
            Some(e) => pos = e,
        }
    }
    None
}

/// The `[start, end)` of the first live `</name>` (whitespace allowed before `>`).
fn end_tag_after(
    xml: &[u8],
    name: &[u8],
    from: usize,
    ign: &Ignorable,
    to: usize,
) -> Option<(usize, usize)> {
    let mut needle = b"</".to_vec();
    needle.extend_from_slice(name);
    let mut pos = from;
    while pos < to {
        let at = find_live(xml, &needle, pos, to, ign)?;
        let after = at + name.len() + 2;
        if after < to && xml[after] == b'>' {
            return Some((at, after + 1));
        }
        let mut gt = after;
        while gt < to && xml[gt] != b'>' {
            gt += 1;
        }
        if gt < to && after < gt && xml[after..gt].iter().all(|&c| is_ws(c)) {
            return Some((at, gt + 1));
        }
        pos = at + 1;
    }
    None
}

/// The qualified name of the tag starting at `start` (after `<`).
fn tag_name_end(xml: &[u8], start: usize, to: usize) -> usize {
    let mut i = start + 1;
    while i < to && !is_boundary(xml.get(i)) {
        i += 1;
    }
    i
}

/// The next live opening tag whose local name is `local`: (start, qname).
fn next_by_local(
    xml: &[u8],
    from: usize,
    to: usize,
    ign: &Ignorable,
    local: &[u8],
) -> Option<(usize, Vec<u8>)> {
    let mut i = from;
    while i + local.len() + 1 < to {
        let at = i + memchr::memchr(b'<', &xml[i..to])?;
        if let Some(e) = ign.end_of(at) {
            i = e;
            continue;
        }
        let first = xml.get(at + 1).copied();
        if matches!(first, None | Some(b'/') | Some(b'!') | Some(b'?')) {
            i = at + 1;
            continue;
        }
        let name_end = tag_name_end(xml, at, to);
        if name_end >= to || name_end == at + 1 {
            i = at + 1;
            continue;
        }
        let name = &xml[at + 1..name_end];
        let colon = name.iter().rposition(|&c| c == b':');
        let ok = match colon {
            Some(0) => false,
            Some(c) => &name[c + 1..] == local,
            None => name == local,
        };
        if ok {
            return Some((at, name.to_vec()));
        }
        i = at + 1;
    }
    None
}

/// The first live element with this local name in `[from, to)`.
fn first_by_local(xml: &[u8], local: &[u8], from: usize, to: usize) -> Option<(Vec<u8>, Span)> {
    let ign = Ignorable::new(xml, from, to);
    let (start, name) = next_by_local(xml, from, to, &ign, local)?;
    let tag_end = find_tag_end(xml, start + 1 + name.len(), to)?;
    if is_self_closing(xml, start, tag_end) {
        return Some((name, Span::empty(start, tag_end + 1)));
    }
    let (close, after) = end_tag_after(xml, &name, tag_end + 1, &ign, to)?;
    Some((
        name,
        Span {
            start,
            end: after,
            inner_start: tag_end + 1,
            inner_end: close,
        },
    ))
}

/// The raw value span of an exact attribute on the tag `[tag_start, tag_end)`.
pub(crate) fn attr_span(
    xml: &[u8],
    tag_start: usize,
    tag_end: usize,
    attr: &[u8],
) -> Option<(usize, usize)> {
    if xml.get(tag_start) != Some(&b'<') {
        return None;
    }
    let mut i = tag_start
        + if xml.get(tag_start + 1) == Some(&b'/') {
            2
        } else {
            1
        };
    while i < tag_end && !(is_ws(xml[i]) || xml[i] == b'/' || xml[i] == b'>') {
        i += 1;
    }
    while i < tag_end {
        while i < tag_end && is_ws(xml[i]) {
            i += 1;
        }
        if i >= tag_end || xml[i] == b'/' || xml[i] == b'>' {
            return None;
        }
        let name_start = i;
        while i < tag_end && !(is_ws(xml[i]) || matches!(xml[i], b'=' | b'/' | b'>')) {
            i += 1;
        }
        let name_end = i;
        while i < tag_end && is_ws(xml[i]) {
            i += 1;
        }
        if xml.get(i) != Some(&b'=') {
            if i == name_start {
                i += 1;
            }
            continue;
        }
        i += 1;
        while i < tag_end && is_ws(xml[i]) {
            i += 1;
        }
        let quote = xml.get(i).copied();
        if quote != Some(b'"') && quote != Some(b'\'') {
            while i < tag_end && !is_ws(xml[i]) {
                i += 1;
            }
            continue;
        }
        let q = quote.unwrap_or(b'"');
        i += 1;
        let value_start = i;
        while i < tag_end && xml[i] != q {
            i += 1;
        }
        if i >= tag_end {
            return None;
        }
        if &xml[name_start..name_end] == attr {
            return Some((value_start, i));
        }
        i += 1;
    }
    None
}

/// An attribute's decoded value.
pub(crate) fn get_attr(xml: &[u8], tag_start: usize, tag_end: usize, attr: &str) -> Option<String> {
    let (s, e) = attr_span(xml, tag_start, tag_end, attr.as_bytes())?;
    Some(decode_xml(&text(xml, s, e)))
}

/// Expand the predefined entities and character references.
pub(crate) fn decode_xml(s: &str) -> String {
    if !s.contains('&') {
        return s.to_string();
    }
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(i) = rest.find('&') {
        out.push_str(&rest[..i]);
        let tail = &rest[i..];
        let Some(semi) = tail.find(';') else {
            out.push_str(tail);
            return out;
        };
        let ent = &tail[1..semi];
        let ch = match ent {
            "lt" => Some('<'),
            "gt" => Some('>'),
            "amp" => Some('&'),
            "quot" => Some('"'),
            "apos" => Some('\''),
            _ => {
                let code =
                    if let Some(h) = ent.strip_prefix("#x").or_else(|| ent.strip_prefix("#X")) {
                        u32::from_str_radix(h, 16).ok()
                    } else if let Some(d) = ent.strip_prefix('#') {
                        d.parse().ok()
                    } else {
                        None
                    };
                code.and_then(char::from_u32)
            }
        };
        match ch {
            Some(c) => {
                out.push(c);
                rest = &tail[semi + 1..];
            }
            None => {
                out.push('&');
                rest = &tail[1..];
            }
        }
    }
    out.push_str(rest);
    out
}

/// Text for an element's content: markup characters escaped, CR kept as a
/// reference, and characters XML 1.0 does not allow removed.
pub(crate) fn encode_text(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '\r' => out.push_str("&#13;"),
            '\t' | '\n' => out.push(c),
            c if (c as u32) < 0x20 || c == '\u{FFFE}' || c == '\u{FFFF}' => {}
            c => out.push(c),
        }
    }
    out
}

/// Text for an attribute value in double quotes.
pub(crate) fn encode_attr(s: &str) -> String {
    encode_text(s)
        .replace('"', "&quot;")
        .replace('\t', "&#9;")
        .replace('\n', "&#10;")
}

/// The tag with one attribute (and the whitespace before it) removed.
pub(crate) fn remove_attr(tag: &str, attr: &str) -> String {
    let b = tag.as_bytes();
    let Some((vs, ve)) = attr_span(b, 0, b.len(), attr.as_bytes()) else {
        return tag.to_string();
    };
    let mut i = vs - 1; // the quote
    while i > 0 && is_ws(b[i - 1]) {
        i -= 1;
    }
    // b[i - 1] is `=`.
    i -= 1;
    while i > 0 && is_ws(b[i - 1]) {
        i -= 1;
    }
    let mut start = i - attr.len();
    while start > 0 && is_ws(b[start - 1]) {
        start -= 1;
    }
    format!("{}{}", &tag[..start], &tag[ve + 1..])
}

/// The tag with one attribute's value replaced, keeping its quotes.
pub(crate) fn replace_attr(tag: &str, attr: &str, value: &str) -> String {
    let b = tag.as_bytes();
    match attr_span(b, 0, b.len(), attr.as_bytes()) {
        // `value` is escaped for double quotes; inside single quotes an
        // apostrophe must be escaped too.
        Some((s, e)) if b[s - 1] == b'\'' => {
            format!(
                "{}{}{}",
                &tag[..s],
                value.replace('\'', "&apos;"),
                &tag[e..]
            )
        }
        Some((s, e)) => format!("{}{}{}", &tag[..s], value, &tag[e..]),
        None => tag.to_string(),
    }
}

/// The tag with an attribute set: replaced if present, else added before
/// the closing `>` or `/>`.
pub(crate) fn set_attr(tag: &str, attr: &str, value: &str) -> String {
    let b = tag.as_bytes();
    if attr_span(b, 0, b.len(), attr.as_bytes()).is_some() {
        return replace_attr(tag, attr, value);
    }
    let mut end = tag.len() - 1; // `>`
    let mut i = end;
    while i > 0 && is_ws(b[i - 1]) {
        i -= 1;
    }
    if i > 0 && b[i - 1] == b'/' {
        end = i - 1;
        while end > 0 && is_ws(b[end - 1]) {
            end -= 1;
        }
    }
    format!("{} {}=\"{}\"{}", &tag[..end], attr, value, &tag[end..])
}

// ---------------------------------------------------------------------
// Cell references

/// "A1" from 0-based row and column.
pub fn cell_ref(row: u32, col: u32) -> String {
    let mut n = col + 1;
    let mut letters = Vec::new();
    while n > 0 {
        letters.push(b'A' + ((n - 1) % 26) as u8);
        n = (n - 1) / 26;
    }
    letters.reverse();
    format!("{}{}", String::from_utf8_lossy(&letters), row + 1)
}

pub fn range_ref(r: [u32; 4]) -> String {
    if r[0] == r[2] && r[1] == r[3] {
        cell_ref(r[0], r[1])
    } else {
        format!("{}:{}", cell_ref(r[0], r[1]), cell_ref(r[2], r[3]))
    }
}

/// A canonical reference ("A1" to "XFD1048576"), 0-based, or None.
pub fn parse_ref(s: &str) -> Option<(u32, u32)> {
    let b = s.as_bytes();
    let mut i = 0;
    let mut col: u64 = 0;
    while i < b.len() && b[i].is_ascii_uppercase() {
        col = col * 26 + (b[i] - b'@') as u64;
        if col > MAX_COLS {
            return None;
        }
        i += 1;
    }
    if i == 0 || i == b.len() || b[i] == b'0' {
        return None;
    }
    let mut row: u64 = 0;
    for &c in &b[i..] {
        if !c.is_ascii_digit() {
            return None;
        }
        row = row * 10 + (c - b'0') as u64;
        if row > MAX_ROWS {
            return None;
        }
    }
    Some((row as u32 - 1, col as u32 - 1))
}

/// "A1:C3" or "B2" (with optional `$`), 0-based (r1, c1, r2, c2).
pub fn parse_range(s: &str) -> Option<[u32; 4]> {
    let clean: String = s.chars().filter(|&c| c != '$').collect();
    let mut it = clean.split(':');
    let a = parse_ref(it.next()?)?;
    let b = match it.next() {
        Some(b) => parse_ref(b)?,
        None => a,
    };
    if it.next().is_some() {
        return None;
    }
    Some([a.0, a.1, b.0, b.1])
}

pub fn overlaps(a: [u32; 4], b: [u32; 4]) -> bool {
    a[0] <= b[2] && b[0] <= a[2] && a[1] <= b[3] && b[1] <= a[3]
}

pub fn contains(r: [u32; 4], row: u32, col: u32) -> bool {
    r[0] <= row && row <= r[2] && r[1] <= col && col <= r[3]
}

enum Reference {
    Valid(u32, u32),
    Missing,
    Invalid,
}

fn cell_reference(xml: &[u8], start: usize, tag_end: usize) -> Reference {
    match attr_span(xml, start, tag_end + 1, b"r") {
        None => Reference::Missing,
        Some((s, e)) => {
            let raw = text(xml, s, e);
            match parse_ref(&decode_xml(&raw)) {
                Some((r, c)) => Reference::Valid(r, c),
                None => Reference::Invalid,
            }
        }
    }
}

fn row_index(xml: &[u8], start: usize, tag_end: usize) -> Option<u32> {
    let v = decode_xml(&text_attr(xml, start, tag_end, b"r")?);
    if v.is_empty() || !v.bytes().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let n: u64 = v.parse().ok()?;
    (n >= 1 && n <= u32::MAX as u64).then(|| (n - 1) as u32)
}

fn text_attr(xml: &[u8], start: usize, tag_end: usize, attr: &[u8]) -> Option<String> {
    let (s, e) = attr_span(xml, start, tag_end + 1, attr)?;
    Some(text(xml, s, e))
}

// ---------------------------------------------------------------------
// The worksheet's structure and refusals

#[derive(Clone, Copy)]
struct Candidate {
    start: usize,
    rank: u8,
    code: Refusal,
}

fn earlier(cur: Option<Candidate>, c: Candidate) -> Option<Candidate> {
    match cur {
        Some(x) if !(c.start < x.start || (c.start == x.start && c.rank < x.rank)) => Some(x),
        _ => Some(c),
    }
}

struct Declarations {
    default: Option<String>,
    bindings: Vec<(String, String)>,
    unreadable_default: bool,
}

fn declarations(tag: &str) -> Declarations {
    let b = tag.as_bytes();
    let mut bindings = Vec::new();
    let mut default = None;
    let mut unreadable = false;
    let mut i = 1;
    while i < b.len() && !(is_ws(b[i]) || b[i] == b'/' || b[i] == b'>') {
        i += 1;
    }
    while i < b.len() {
        while i < b.len() && is_ws(b[i]) {
            i += 1;
        }
        if i >= b.len() || b[i] == b'/' || b[i] == b'>' {
            break;
        }
        let ns = i;
        while i < b.len() && !(is_ws(b[i]) || matches!(b[i], b'=' | b'/' | b'>')) {
            i += 1;
        }
        let name = &tag[ns..i];
        while i < b.len() && is_ws(b[i]) {
            i += 1;
        }
        if b.get(i) != Some(&b'=') {
            while i < b.len() && !(is_ws(b[i]) || b[i] == b'>') {
                i += 1;
            }
            continue;
        }
        i += 1;
        while i < b.len() && is_ws(b[i]) {
            i += 1;
        }
        let q = b.get(i).copied();
        if q != Some(b'"') && q != Some(b'\'') {
            if name == "xmlns" {
                unreadable = true;
            }
            while i < b.len() && !(is_ws(b[i]) || b[i] == b'>') {
                i += 1;
            }
            continue;
        }
        let q = q.unwrap_or(b'"');
        i += 1;
        let vs = i;
        let Some(ve) = b[vs..].iter().position(|&c| c == q).map(|p| p + vs) else {
            if name == "xmlns" {
                unreadable = true;
            }
            break;
        };
        let value = decode_xml(&tag[vs..ve]);
        if name == "xmlns" {
            default = Some(value);
        } else if let Some(p) = name.strip_prefix("xmlns:") {
            if !p.is_empty() {
                bindings.push((p.to_string(), value));
            }
        }
        i = ve + 1;
    }
    Declarations {
        unreadable_default: default.is_none() && unreadable,
        default,
        bindings,
    }
}

struct Frame {
    qname: String,
    default: String,
    bindings: Vec<(String, String)>,
    start: usize,
    worksheet: bool,
    in_sheet_data: bool,
    mc_alternate: bool,
}

fn resolve_prefix(stack: &[Frame], own: &[(String, String)], prefix: &str) -> String {
    if let Some((_, ns)) = own.iter().rev().find(|(p, _)| p == prefix) {
        return ns.clone();
    }
    for f in stack.iter().rev() {
        if let Some((_, ns)) = f.bindings.iter().rev().find(|(p, _)| p == prefix) {
            return ns.clone();
        }
    }
    if prefix == "xml" {
        "http://www.w3.org/XML/1998/namespace".into()
    } else {
        String::new()
    }
}

fn is_sml(ns: &str) -> bool {
    ns == SPREADSHEETML_NS || ns == STRICT_NS
}

fn quoted_end(xml: &[u8], start: usize) -> Option<usize> {
    let (close, from): (&[u8], usize) = if starts_with(xml, b"<!--", start) {
        (b"-->", start + 4)
    } else if starts_with(xml, b"<![CDATA[", start) {
        (b"]]>", start + 9)
    } else if starts_with(xml, b"<?", start) {
        (b"?>", start + 2)
    } else {
        return None;
    };
    Some(match find(xml, close, from, xml.len()) {
        Some(c) => c + close.len(),
        None => xml.len(),
    })
}

/// Whether anything inside `sheetData` could change a refusal: a namespace
/// declaration or a prefixed opening tag.
fn needs_body_scan(xml: &[u8], from: usize, to: usize) -> bool {
    if find(xml, b"xmlns", from, to).is_some() {
        return true;
    }
    let mut pos = from;
    while let Some(colon) = find(xml, b":", pos, to) {
        let mut s = colon;
        while s > from {
            let c = xml[s - 1];
            if c == b'<' || c == b'>' || c == b'=' || is_boundary(Some(&c)) {
                break;
            }
            s -= 1;
        }
        if s > from && xml[s - 1] == b'<' {
            let first = xml.get(s).copied();
            if !matches!(first, Some(b'!') | Some(b'?') | Some(b'/')) {
                return true;
            }
        }
        pos = colon + 1;
    }
    false
}

pub struct Structure {
    pub sheet_data: Option<Span>,
    pub sheet_data_name: Vec<u8>,
    pub dimension: Option<Span>,
    refusal: Option<Candidate>,
    missing_refusal: Option<Candidate>,
}

/// Find the worksheet's direct `sheetData` and `dimension`, resolving
/// namespaces with a stack of open elements (Table Viewer's
/// `scan_worksheet_structure`).
pub fn structure(xml: &[u8]) -> Structure {
    let mut stack: Vec<Frame> = Vec::new();
    let mut pos = 0;
    let mut saw_root = false;
    let mut saw_sheet_data = false;
    let mut ws_ns = SPREADSHEETML_NS.to_string();
    let mut out = Structure {
        sheet_data: None,
        sheet_data_name: b"sheetData".to_vec(),
        dimension: None,
        refusal: None,
        missing_refusal: None,
    };
    // 0: both, 1: sheet data only, 2: missing sheet data only.
    let consider = |out: &mut Structure, target: u8, start: usize, rank: u8, code: Refusal| {
        let c = Candidate { start, rank, code };
        if target != 2 {
            out.refusal = earlier(out.refusal, c);
        }
        if target != 1 {
            out.missing_refusal = earlier(out.missing_refusal, c);
        }
    };
    while pos < xml.len() {
        let Some(start) = find(xml, b"<", pos, xml.len()) else {
            break;
        };
        if let Some(sd) = out.sheet_data {
            if start >= sd.inner_end {
                break;
            }
        }
        if let Some(e) = quoted_end(xml, start) {
            pos = e;
            continue;
        }
        if starts_with(xml, b"<!", start) {
            match find_tag_end(xml, start, xml.len()) {
                Some(e) => {
                    pos = e + 1;
                    continue;
                }
                None => break,
            }
        }
        let Some(tag_end) = find_tag_end(xml, start, xml.len()) else {
            break;
        };
        if starts_with(xml, b"</", start) {
            let mut ne = start + 2;
            while ne < tag_end && !is_boundary(xml.get(ne)) {
                ne += 1;
            }
            let q = text(xml, start + 2, ne);
            match stack.last() {
                Some(f) if f.qname == q => {
                    stack.pop();
                }
                _ => break,
            }
            pos = tag_end + 1;
            continue;
        }
        let open = text(xml, start, tag_end + 1);
        let ob = open.as_bytes();
        let mut ne = 1;
        while ne < ob.len() && !(is_ws(ob[ne]) || ob[ne] == b'/' || ob[ne] == b'>') {
            ne += 1;
        }
        let qname = open[1..ne].to_string();
        let (prefix, local) = match qname.find(':') {
            Some(c) => (Some(qname[..c].to_string()), qname[c + 1..].to_string()),
            None => (None, qname.clone()),
        };
        let decl = declarations(&open);
        let parent_default = stack.last().map(|f| f.default.clone());
        let worksheet = !saw_root && local == "worksheet";
        let implicit = worksheet && prefix.is_none() && decl.default.is_none();
        let default = decl.default.clone().or(parent_default).unwrap_or_else(|| {
            if implicit {
                SPREADSHEETML_NS.into()
            } else {
                String::new()
            }
        });
        let ns = match &prefix {
            None => default.clone(),
            Some(p) => resolve_prefix(&stack, &decl.bindings, p),
        };
        let direct = stack.last().is_some_and(|f| f.worksheet);
        let authoritative =
            !saw_sheet_data && direct && local == "sheetData" && (prefix.is_none() || is_sml(&ns));
        let in_sheet_data = authoritative || stack.last().is_some_and(|f| f.in_sheet_data);
        let exact_ac = local == "AlternateContent" && ns == MC_NS;
        let mc_alternate = direct && exact_ac;

        if out.dimension.is_none() && direct && local == "dimension" && ns == ws_ns {
            out.dimension = Some(Span::empty(start, tag_end + 1));
        }
        if !saw_root {
            saw_root = true;
            if worksheet {
                ws_ns = ns.clone();
                if prefix.is_some() && ns.is_empty() {
                    consider(&mut out, 0, start, 0, Refusal::NamespacePrefixed);
                }
                if !is_sml(&ns) || decl.unreadable_default {
                    consider(&mut out, 0, start, 1, Refusal::ForeignNamespace);
                }
            }
        }
        if authoritative {
            saw_sheet_data = true;
            if ns != ws_ns || decl.unreadable_default {
                consider(&mut out, 1, start, 1, Refusal::ForeignNamespace);
            }
            out.sheet_data_name = qname.as_bytes().to_vec();
            let sd = first_by_local(xml, b"sheetData", start, xml.len()).map(|(_, s)| s);
            out.sheet_data = sd;
            let Some(sd) = sd else { break };
            if sd.inner_start == sd.end || !needs_body_scan(xml, sd.inner_start, sd.inner_end) {
                return out;
            }
        }
        if in_sheet_data
            && prefix.is_some()
            && matches!(local.as_str(), "row" | "c" | "f" | "is" | "v")
            && ns.is_empty()
        {
            consider(&mut out, 1, start, 0, Refusal::NamespacePrefixed);
        }
        if in_sheet_data
            && matches!(local.as_str(), "row" | "c" | "f")
            && (ns != ws_ns || decl.unreadable_default)
        {
            consider(&mut out, 1, start, 1, Refusal::ForeignNamespace);
        }
        if in_sheet_data && exact_ac {
            consider(&mut out, 1, start, 0, Refusal::MarkupCompatibility);
        }
        if local == "sheetData" && is_sml(&ns) {
            if let Some(f) = stack.iter().rev().find(|f| f.mc_alternate) {
                let s = f.start;
                consider(&mut out, 2, s, 0, Refusal::MarkupCompatibility);
            }
        }
        if !is_self_closing(xml, start, tag_end) {
            stack.push(Frame {
                qname,
                default,
                bindings: decl.bindings,
                start,
                worksheet,
                in_sheet_data,
                mc_alternate,
            });
        }
        pos = tag_end + 1;
    }
    out
}

/// The rows of `sheetData`, by row index, in document order (one index
/// may name several elements), with the cells of the rows `capture` asks
/// for. Refuses as Table Viewer's `assert_writable_sheet_data` does.
pub struct Rows {
    pub rows: HashMap<u32, Vec<Span>>,
    /// Captured cells: (row, col) -> (cell span, owning row span); last wins.
    pub cells: HashMap<(u32, u32), Span>,
    pub any_formula: bool,
}

pub fn scan_rows(
    xml: &[u8],
    st: &Structure,
    capture: &dyn Fn(u32) -> bool,
) -> Result<Rows, SpliceError> {
    let Some(sd) = st.sheet_data else {
        return Err(match st.missing_refusal {
            Some(c) => SpliceError::Refused(c.code),
            None => SpliceError::NoSheetData,
        });
    };
    let mut first = st.refusal;
    let (from, to) = (sd.inner_start, sd.inner_end);
    let ign = Ignorable::new(xml, from, to);
    let mut out = Rows {
        rows: HashMap::new(),
        cells: HashMap::new(),
        any_formula: false,
    };
    let mut pos = from;
    while pos < to {
        let Some((start, name)) = next_by_local(xml, pos, to, &ign, b"row") else {
            break;
        };
        let Some(tag_end) = find_tag_end(xml, start, to) else {
            break;
        };
        let index = row_index(xml, start, tag_end);
        if is_self_closing(xml, start, tag_end) {
            if let Some(r) = index {
                out.rows
                    .entry(r)
                    .or_default()
                    .push(Span::empty(start, tag_end + 1));
            }
            pos = tag_end + 1;
            continue;
        }
        let Some((close, after)) = end_tag_after(xml, &name, tag_end + 1, &ign, to) else {
            break;
        };
        let span = Span {
            start,
            end: after,
            inner_start: tag_end + 1,
            inner_end: close,
        };
        if let Some(r) = index {
            out.rows.entry(r).or_default().push(span);
        }
        let mut other_rows: Vec<u32> = Vec::new();
        // The cells of this row.
        let mut cpos = tag_end + 1;
        while cpos < close {
            let Some((cs, cname)) = next_by_local(xml, cpos, close, &ign, b"c") else {
                break;
            };
            let Some(cte) = find_tag_end(xml, cs, close) else {
                break;
            };
            let reference = cell_reference(xml, cs, cte);
            let (cend, cinner_end) = if is_self_closing(xml, cs, cte) {
                (cte + 1, cte + 1)
            } else {
                match end_tag_after(xml, &cname, cte + 1, &ign, close) {
                    Some((ie, e)) => (e, ie),
                    None => break,
                }
            };
            cpos = cend;
            match reference {
                Reference::Missing => {
                    first = earlier(
                        first,
                        Candidate {
                            start: cs,
                            rank: 2,
                            code: Refusal::MissingReference,
                        },
                    )
                }
                Reference::Invalid => {
                    first = earlier(
                        first,
                        Candidate {
                            start: cs,
                            rank: 3,
                            code: Refusal::InvalidReference,
                        },
                    )
                }
                Reference::Valid(r, c) => {
                    if Some(r) != index && !other_rows.contains(&r) {
                        other_rows.push(r);
                    }
                    if capture(r) {
                        out.cells.insert(
                            (r, c),
                            Span {
                                start: cs,
                                end: cend,
                                inner_start: cte + 1,
                                inner_end: cinner_end,
                            },
                        );
                    }
                }
            }
        }
        for r in other_rows {
            out.rows.entry(r).or_default().push(span);
        }
        pos = after;
    }
    if let Some(c) = first {
        return Err(SpliceError::Refused(c.code));
    }
    out.any_formula = has_formula(xml, from, to);
    Ok(out)
}

/// Whether a cell holds the master of a shared formula: an `<f t="shared">`
/// with the `ref` its followers use.
fn shared_master(xml: &[u8], cell: &Span) -> bool {
    let ign = Ignorable::new(xml, cell.inner_start, cell.inner_end);
    let Some((s, _)) = next_by_local(xml, cell.inner_start, cell.inner_end, &ign, b"f") else {
        return false;
    };
    let Some(e) = find_tag_end(xml, s, cell.inner_end) else {
        return false;
    };
    get_attr(xml, s, e + 1, "t").as_deref() == Some("shared")
        && attr_span(xml, s, e + 1, b"ref").is_some()
}

/// Whether `[from, to)` holds a live `<f>` (with any prefix).
fn has_formula(xml: &[u8], from: usize, to: usize) -> bool {
    let ign = Ignorable::new(xml, from, to);
    next_by_local(xml, from, to, &ign, b"f").is_some()
}

/// Every live element with this local name: (qualified name, span).
pub fn live_elements(xml: &[u8], local: &[u8]) -> Vec<(Vec<u8>, Span)> {
    let ign = Ignorable::new(xml, 0, xml.len());
    let mut out = Vec::new();
    let mut pos = 0;
    while let Some((s, name)) = next_by_local(xml, pos, xml.len(), &ign, local) {
        let Some(te) = find_tag_end(xml, s, xml.len()) else {
            break;
        };
        if is_self_closing(xml, s, te) {
            out.push((name, Span::empty(s, te + 1)));
            pos = te + 1;
            continue;
        }
        let Some((close, after)) = end_tag_after(xml, &name, te + 1, &ign, xml.len()) else {
            break;
        };
        out.push((
            name,
            Span {
                start: s,
                end: after,
                inner_start: te + 1,
                inner_end: close,
            },
        ));
        pos = te + 1;
    }
    out
}

/// Apply (start, end, text) splices computed against `xml`.
pub fn splice_bytes(xml: &[u8], splices: Vec<(usize, usize, String)>) -> Vec<u8> {
    apply(
        xml,
        splices
            .into_iter()
            .map(|(start, end, text)| Splice { start, end, text })
            .collect(),
    )
}

/// The opening tag of a span, as text.
pub fn tag_text(xml: &[u8], s: &Span) -> String {
    text(xml, s.start, s.inner_start)
}

// ---------------------------------------------------------------------
// Ranges the sheet declares

/// The merged ranges of the first `<mergeCells>`, 0-based, as Table
/// Viewer's reader finds them.
pub fn merges(xml: &[u8]) -> Vec<[u32; 4]> {
    let mut out = Vec::new();
    let Some((_, mc)) = first_by_local(xml, b"mergeCells", 0, xml.len()) else {
        return out;
    };
    let ign = Ignorable::new(xml, mc.inner_start, mc.inner_end);
    let mut pos = mc.inner_start;
    while let Some((s, _)) = next_by_local(xml, pos, mc.inner_end, &ign, b"mergeCell") {
        let Some(e) = find_tag_end(xml, s, mc.inner_end) else {
            break;
        };
        if let Some(r) = get_attr(xml, s, e + 1, "ref").and_then(|r| parse_range(&r)) {
            if r[0] <= r[2] && r[1] <= r[3] {
                out.push(r);
            }
        }
        pos = e + 1;
    }
    out
}

/// Shared formulas, array formulas and data tables: (kind, range).
pub fn grouped(xml: &[u8]) -> Vec<(&'static str, [u32; 4])> {
    let mut out = Vec::new();
    let ign = Ignorable::new(xml, 0, xml.len());
    let mut pos = 0;
    while let Some((s, _)) = next_by_local(xml, pos, xml.len(), &ign, b"f") {
        let Some(e) = find_tag_end(xml, s, xml.len()) else {
            break;
        };
        let kind = match get_attr(xml, s, e + 1, "t").as_deref() {
            Some("shared") => Some("shared"),
            Some("array") => Some("array"),
            Some("dataTable") => Some("dataTable"),
            _ => None,
        };
        if let (Some(k), Some(r)) = (
            kind,
            get_attr(xml, s, e + 1, "ref").and_then(|r| parse_range(&r)),
        ) {
            out.push((k, r));
        }
        pos = e + 1;
    }
    out
}

/// Column styles from `<cols>`: (first col, last col, style), 0-based.
fn col_styles(xml: &[u8], before: usize) -> Vec<(u32, u32, u32)> {
    let mut out = Vec::new();
    let Some((_, cols)) = first_by_local(xml, b"cols", 0, before) else {
        return out;
    };
    let ign = Ignorable::new(xml, cols.inner_start, cols.inner_end);
    let mut pos = cols.inner_start;
    while let Some((s, _)) = next_by_local(xml, pos, cols.inner_end, &ign, b"col") {
        let Some(e) = find_tag_end(xml, s, cols.inner_end) else {
            break;
        };
        let n = |a: &str| get_attr(xml, s, e + 1, a).and_then(|v| v.trim().parse::<u32>().ok());
        if let (Some(min), Some(max), Some(style)) = (n("min"), n("max"), n("style")) {
            if min >= 1 && max >= min && style > 0 {
                out.push((min - 1, max - 1, style));
            }
        }
        pos = e + 1;
    }
    out
}

// ---------------------------------------------------------------------
// Writing cells

/// A number as Excel stores it: whole numbers without a decimal point,
/// others in the shortest form that reads back exactly.
pub fn number_text(x: f64) -> String {
    if x == x.trunc() && x.abs() < 1e15 {
        format!("{}", x as i64)
    } else {
        format!("{x:?}")
    }
}

fn cell_xml(e: &Edit, style: Option<u32>, p: &str) -> String {
    let r = cell_ref(e.row, e.col);
    let s = match style {
        Some(s) if s != 0 => format!(" s=\"{s}\""),
        _ => String::new(),
    };
    match &e.value {
        Value::Blank | Value::Restyle => format!("<{p}c r=\"{r}\"{s}/>"),
        Value::Number(x) => format!("<{p}c r=\"{r}\"{s}><{p}v>{}</{p}v></{p}c>", number_text(*x)),
        Value::Bool(b) => format!("<{p}c r=\"{r}\"{s} t=\"b\"><{p}v>{}</{p}v></{p}c>", *b as u8),
        Value::Formula(f) => format!("<{p}c r=\"{r}\"{s}><{p}f>{}</{p}f></{p}c>", encode_text(f)),
        Value::Text(t) => format!(
            "<{p}c r=\"{r}\"{s} t=\"inlineStr\"><{p}is><{p}t xml:space=\"preserve\">{}</{p}t></{p}is></{p}c>",
            encode_text(t)
        ),
    }
}

struct Splice {
    start: usize,
    end: usize,
    text: String,
}

/// Apply splices computed against `xml`. Inserts at one offset keep their
/// order and come before a replacement starting there.
fn apply(xml: &[u8], mut splices: Vec<Splice>) -> Vec<u8> {
    let mut order: Vec<usize> = (0..splices.len()).collect();
    order.sort_by_key(|&i| {
        (
            splices[i].start,
            (splices[i].end != splices[i].start) as u8,
            i,
        )
    });
    let mut out =
        Vec::with_capacity(xml.len() + splices.iter().map(|s| s.text.len()).sum::<usize>());
    let mut at = 0;
    for i in order {
        let s = std::mem::take(&mut splices[i].text);
        let (start, end) = (splices[i].start, splices[i].end);
        out.extend_from_slice(&xml[at..start]);
        out.extend_from_slice(s.as_bytes());
        at = end;
    }
    out.extend_from_slice(&xml[at..]);
    out
}

fn prefix_of(name: &[u8]) -> String {
    match name.iter().position(|&c| c == b':') {
        Some(c) => format!("{}:", String::from_utf8_lossy(&name[..c])),
        None => String::new(),
    }
}

/// The span's opening tag as text.
fn open_tag(xml: &[u8], s: &Span) -> String {
    text(xml, s.start, s.inner_start)
}

/// Expand a self-closing `<sheetData .../>` to a pair, keeping its attributes.
fn expand_sheet_data(xml: &[u8], st: &Structure) -> Option<Vec<u8>> {
    let sd = st.sheet_data?;
    if sd.inner_start != sd.end {
        return None;
    }
    let open = text(xml, sd.start, sd.end);
    let trimmed = open[..open.len() - 1].trim_end();
    let open = format!("{}>", trimmed[..trimmed.len() - 1].trim_end());
    let name = String::from_utf8_lossy(&st.sheet_data_name);
    Some(apply(
        xml,
        vec![Splice {
            start: sd.start,
            end: sd.end,
            text: format!("{open}</{name}>"),
        }],
    ))
}

/// Widen the `<dimension>` to cover `[r1, c1, r2, c2]`.
fn widen_dimension(xml: &[u8], st: &Structure, cover: [u32; 4]) -> Option<Splice> {
    let d = st.dimension?;
    let tag = text(xml, d.start, d.end);
    let tb = tag.as_bytes();
    let cur = get_attr(tb, 0, tb.len(), "ref").and_then(|r| parse_range(&r))?;
    let new = [
        cur[0].min(cover[0]),
        cur[1].min(cover[1]),
        cur[2].max(cover[2]),
        cur[3].max(cover[3]),
    ];
    if new == cur {
        return None;
    }
    Some(Splice {
        start: d.start,
        end: d.end,
        text: replace_attr(&tag, "ref", &range_ref(new)),
    })
}

/// Write `edits` into the worksheet `xml`. Repeated cells: the last wins.
pub fn apply_edits(
    xml: &[u8],
    edits: &[Edit],
    styler: &mut dyn Styler,
) -> Result<Outcome, SpliceError> {
    let st = structure(xml);
    if st.sheet_data.is_none() {
        return Err(match st.missing_refusal {
            Some(c) => SpliceError::Refused(c.code),
            None => SpliceError::NoSheetData,
        });
    }
    if let Some(expanded) = expand_sheet_data(xml, &st) {
        return apply_edits(&expanded, edits, styler);
    }
    if edits.is_empty() {
        return Ok(Outcome {
            xml: xml.to_vec(),
            removed_formula: false,
        });
    }
    // Last edit of each cell, by row then column.
    let mut last: BTreeMap<(u32, u32), usize> = BTreeMap::new();
    for (i, e) in edits.iter().enumerate() {
        last.insert((e.row, e.col), i);
    }
    let by_row: BTreeMap<u32, Vec<usize>> =
        last.iter().fold(BTreeMap::new(), |mut m, (&(r, _), &i)| {
            m.entry(r).or_insert_with(Vec::new).push(i);
            m
        });
    let rows = scan_rows(xml, &st, &|r| by_row.contains_key(&r))?;
    let groups = grouped(xml);
    for (&(r, c), &i) in last.iter() {
        if let Some(&(kind, g)) = groups.iter().find(|(_, g)| contains(*g, r, c)) {
            // A follower of a shared formula may become a formula of its
            // own (Table Viewer's rule); its master may not, since the
            // followers take their formula from it.
            let master = rows
                .cells
                .get(&(r, c))
                .is_some_and(|s| shared_master(xml, s));
            let formula_ok =
                matches!(edits[i].value, Value::Formula(_)) && kind == "shared" && !master
                    || edits[i].value == Value::Restyle;
            if !formula_ok {
                return Err(SpliceError::Grouped(r, c, kind, g));
            }
        }
    }
    let merged = merges(xml);
    for (&(r, c), &i) in last.iter() {
        if is_empty(&edits[i].value) {
            continue;
        }
        if let Some(m) = merged
            .iter()
            .find(|m| contains(**m, r, c) && !(m[0] == r && m[1] == c))
        {
            return Err(SpliceError::Merged(r, c, *m));
        }
    }
    let sd = st.sheet_data.unwrap_or(Span::empty(0, 0));
    let p = prefix_of(&st.sheet_data_name);
    let cols = col_styles(xml, sd.start);
    let col_style = |c: u32| {
        cols.iter()
            .find(|(a, b, _)| *a <= c && c <= *b)
            .map(|x| x.2)
    };
    let mut splices = Vec::new();
    let mut removed_formula = false;
    let mut new_rows: Vec<(u32, String)> = Vec::new();
    // New cells by the row element they go into: (column, row, XML).
    type Inserts = (Span, Vec<(u32, u32, String)>);
    let mut inserts: HashMap<usize, Inserts> = HashMap::new();
    let mut cover: Option<[u32; 4]> = None;
    for (&row, idx) in &by_row {
        let spans = rows.rows.get(&row).filter(|v| !v.is_empty());
        let Some(spans) = spans else {
            let mut cells = String::new();
            for &i in idx {
                let e = &edits[i];
                let style = styler.style(i, false, None, col_style(e.col));
                if is_empty(&e.value) && style.unwrap_or(0) == 0 {
                    continue;
                }
                cells.push_str(&cell_xml(e, style, &p));
                grow(&mut cover, e.row, e.col);
            }
            if !cells.is_empty() {
                new_rows.push((row, format!("<{p}row r=\"{}\">{cells}</{p}row>", row + 1)));
            }
            continue;
        };
        let owner = *spans.last().unwrap_or(&spans[0]);
        let owner_tag = open_tag(xml, &owner);
        let ob = owner_tag.as_bytes();
        let row_style = (get_attr(ob, 0, ob.len(), "customFormat").as_deref() == Some("1"))
            .then(|| get_attr(ob, 0, ob.len(), "s").and_then(|s| s.trim().parse::<u32>().ok()))
            .flatten();
        for &i in idx {
            let e = &edits[i];
            if let Some(cell) = rows.cells.get(&(e.row, e.col)) {
                let tag = open_tag(xml, cell);
                let tb = tag.as_bytes();
                let existing = get_attr(tb, 0, tb.len(), "s").and_then(|s| {
                    let t = s.trim();
                    let digits: String = t
                        .trim_start_matches('+')
                        .chars()
                        .take_while(|c| c.is_ascii_digit())
                        .collect();
                    digits.parse::<u32>().ok()
                });
                let inherited = if existing.is_none() {
                    row_style.or_else(|| col_style(e.col))
                } else {
                    None
                };
                let style = styler.style(i, true, existing, inherited);
                if e.value == Value::Restyle {
                    let new = match style {
                        Some(s) if s != 0 => set_attr(&tag, "s", &s.to_string()),
                        _ => remove_attr(&tag, "s"),
                    };
                    if new != tag {
                        splices.push(Splice {
                            start: cell.start,
                            end: cell.inner_start,
                            text: new,
                        });
                    }
                    continue;
                }
                if has_formula(xml, cell.inner_start, cell.inner_end) {
                    removed_formula = true;
                }
                splices.push(Splice {
                    start: cell.start,
                    end: cell.end,
                    text: cell_xml(e, style, &p),
                });
                grow(&mut cover, e.row, e.col);
            } else {
                let style = styler.style(i, false, None, row_style.or_else(|| col_style(e.col)));
                if is_empty(&e.value) && style.unwrap_or(0) == 0 {
                    continue;
                }
                inserts
                    .entry(owner.start)
                    .or_insert_with(|| (owner, Vec::new()))
                    .1
                    .push((e.col, e.row, cell_xml(e, style, &p)));
                grow(&mut cover, e.row, e.col);
            }
        }
    }
    for (_, (owner, mut ins)) in inserts {
        ins.sort_by_key(|x| (x.0, x.1));
        let tag = open_tag(xml, &owner);
        let tb = tag.as_bytes();
        let drop_spans = attr_span(tb, 0, tb.len(), b"spans").is_some();
        if owner.inner_start == owner.end {
            let t = if drop_spans {
                remove_attr(&tag, "spans")
            } else {
                tag.clone()
            };
            let t = t[..t.len() - 1].trim_end();
            let t = t[..t.len() - 1].trim_end();
            let name_end = tag_name_end(t.as_bytes(), 0, t.len());
            let name = &t[1..name_end];
            let body: String = ins.iter().map(|x| x.2.as_str()).collect();
            splices.push(Splice {
                start: owner.start,
                end: owner.end,
                text: format!("{t}>{body}</{name}>"),
            });
            continue;
        }
        if drop_spans {
            splices.push(Splice {
                start: owner.start,
                end: owner.inner_start,
                text: remove_attr(&tag, "spans"),
            });
        }
        // Each new cell goes before the first cell of a higher column.
        let ign = Ignorable::new(xml, owner.inner_start, owner.inner_end);
        let mut existing: Vec<(u32, usize)> = Vec::new();
        let mut pos = owner.inner_start;
        while let Some((cs, cname)) = next_by_local(xml, pos, owner.inner_end, &ign, b"c") {
            let Some(cte) = find_tag_end(xml, cs, owner.inner_end) else {
                break;
            };
            if let Reference::Valid(_, c) = cell_reference(xml, cs, cte) {
                existing.push((c, cs));
            }
            pos = if is_self_closing(xml, cs, cte) {
                cte + 1
            } else {
                match end_tag_after(xml, &cname, cte + 1, &ign, owner.inner_end) {
                    Some((_, e)) => e,
                    None => break,
                }
            };
        }
        // A cell after the last one goes before the row's <extLst>, which
        // comes last in a row.
        let tail = next_by_local(xml, pos, owner.inner_end, &ign, b"extLst")
            .map(|(s, _)| s)
            .unwrap_or(owner.inner_end);
        for (col, _, t) in ins {
            let at = existing
                .iter()
                .filter(|(c, _)| *c > col)
                .map(|(_, s)| *s)
                .min()
                .unwrap_or(tail);
            splices.push(Splice {
                start: at,
                end: at,
                text: t,
            });
        }
    }
    new_rows.sort_by_key(|x| x.0);
    // A new row goes before the earliest element of any higher row: the
    // existing rows by index, with the least start of each suffix.
    let mut by_index: Vec<(u32, usize)> = rows
        .rows
        .iter()
        .map(|(r, v)| (*r, v.iter().map(|s| s.start).min().unwrap_or(sd.inner_end)))
        .collect();
    by_index.sort_unstable();
    let mut suffix_min = vec![sd.inner_end; by_index.len() + 1];
    for i in (0..by_index.len()).rev() {
        suffix_min[i] = suffix_min[i + 1].min(by_index[i].1);
    }
    for (row, t) in new_rows {
        let at = suffix_min[by_index.partition_point(|&(r, _)| r <= row)];
        splices.push(Splice {
            start: at,
            end: at,
            text: t,
        });
    }
    if let Some(c) = cover {
        if let Some(s) = widen_dimension(xml, &st, c) {
            splices.push(s);
        }
    }
    Ok(Outcome {
        xml: apply(xml, splices),
        removed_formula,
    })
}

fn is_empty(v: &Value) -> bool {
    matches!(v, Value::Blank | Value::Restyle)
}

fn grow(cover: &mut Option<[u32; 4]>, r: u32, c: u32) {
    *cover = Some(match *cover {
        None => [r, c, r, c],
        Some(x) => [x[0].min(r), x[1].min(c), x[2].max(r), x[3].max(c)],
    });
}

/// Replace every cell of the worksheet with `edits` (which must not repeat
/// a cell), remove its merged ranges, and set its `<dimension>`.
pub fn replace_sheet_data(
    xml: &[u8],
    edits: &[Edit],
    styler: &mut dyn Styler,
) -> Result<Outcome, SpliceError> {
    let st = structure(xml);
    if let Some(expanded) = expand_sheet_data(xml, &st) {
        return replace_sheet_data(&expanded, edits, styler);
    }
    let rows = scan_rows(xml, &st, &|_| false)?;
    let sd = st.sheet_data.ok_or(SpliceError::NoSheetData)?;
    let p = prefix_of(&st.sheet_data_name);
    let mut order: Vec<usize> = (0..edits.len()).collect();
    order.sort_by_key(|&i| (edits[i].row, edits[i].col));
    let mut body = String::new();
    let mut cover: Option<[u32; 4]> = None;
    let mut k = 0;
    while k < order.len() {
        let row = edits[order[k]].row;
        let mut cells = String::new();
        while k < order.len() && edits[order[k]].row == row {
            let i = order[k];
            let style = styler.style(i, false, None, None);
            if !(is_empty(&edits[i].value) && style.unwrap_or(0) == 0) {
                cells.push_str(&cell_xml(&edits[i], style, &p));
                grow(&mut cover, row, edits[i].col);
            }
            k += 1;
        }
        if !cells.is_empty() {
            body.push_str(&format!("<{p}row r=\"{}\">{cells}</{p}row>", row + 1));
        }
    }
    let mut splices = vec![Splice {
        start: sd.inner_start,
        end: sd.inner_end,
        text: body,
    }];
    if let Some(d) = st.dimension {
        let tag = text(xml, d.start, d.end);
        let r = cover.map(range_ref).unwrap_or_else(|| "A1".into());
        let new = replace_attr(&tag, "ref", &r);
        if new != tag {
            splices.push(Splice {
                start: d.start,
                end: d.end,
                text: new,
            });
        }
    }
    if let Some((_, mc)) = direct_child(xml, b"mergeCells") {
        splices.push(Splice {
            start: mc.start,
            end: mc.end,
            text: String::new(),
        });
    }
    Ok(Outcome {
        xml: apply(xml, splices),
        removed_formula: rows.any_formula,
    })
}

/// The worksheet root's direct children: (local name, span), in order.
fn children(xml: &[u8]) -> Vec<(String, Span)> {
    element_children(xml, b"worksheet")
}

/// The direct children of the first `root` element: (local name, span).
pub fn element_children(xml: &[u8], root: &[u8]) -> Vec<(String, Span)> {
    let mut out = Vec::new();
    let Some((_, root)) = first_by_local(xml, root, 0, xml.len()) else {
        return out;
    };
    let ign = Ignorable::new(xml, root.inner_start, root.inner_end);
    let mut pos = root.inner_start;
    while pos < root.inner_end {
        let Some(at) = find_live(xml, b"<", pos, root.inner_end, &ign) else {
            break;
        };
        let first = xml.get(at + 1).copied();
        if matches!(first, None | Some(b'/') | Some(b'!') | Some(b'?')) {
            pos = at + 1;
            continue;
        }
        let ne = tag_name_end(xml, at, root.inner_end);
        let name = xml[at + 1..ne].to_vec();
        let Some(te) = find_tag_end(xml, ne, root.inner_end) else {
            break;
        };
        let local = match name.iter().rposition(|&c| c == b':') {
            Some(c) => text(&name, c + 1, name.len()),
            None => text(&name, 0, name.len()),
        };
        if is_self_closing(xml, at, te) {
            out.push((local, Span::empty(at, te + 1)));
            pos = te + 1;
            continue;
        }
        let Some((close, after)) = end_tag_after(xml, &name, te + 1, &ign, root.inner_end) else {
            break;
        };
        out.push((
            local,
            Span {
                start: at,
                end: after,
                inner_start: te + 1,
                inner_end: close,
            },
        ));
        pos = after;
    }
    out
}

fn direct_child(xml: &[u8], local: &[u8]) -> Option<(String, Span)> {
    children(xml)
        .into_iter()
        .find(|(n, _)| n.as_bytes() == local)
}

/// Elements that come before `<mergeCells>` in a worksheet.
const BEFORE_MERGE: [&str; 10] = [
    "sheetPr",
    "dimension",
    "sheetViews",
    "sheetFormatPr",
    "cols",
    "sheetData",
    "sheetCalcPr",
    "sheetProtection",
    "protectedRanges",
    "scenarios",
];
const BEFORE_MERGE_2: [&str; 4] = [
    "autoFilter",
    "sortState",
    "dataConsolidate",
    "customSheetViews",
];

/// Add merged ranges, refusing one that overlaps a range the sheet has.
pub fn add_merges(xml: &[u8], add: &[[u32; 4]]) -> Result<Vec<u8>, SpliceError> {
    if add.is_empty() {
        return Ok(xml.to_vec());
    }
    let have = merges(xml);
    for a in add {
        if let Some(h) = have.iter().find(|h| overlaps(**h, *a)) {
            return Err(SpliceError::MergeOverlap(*a, *h));
        }
    }
    let st = structure(xml);
    let p = prefix_of(&st.sheet_data_name);
    let new: String = add
        .iter()
        .map(|r| format!("<{p}mergeCell ref=\"{}\"/>", range_ref(*r)))
        .collect();
    let kids = children(xml);
    if let Some((_, mc)) = kids.iter().find(|(n, _)| n == "mergeCells") {
        let tag = open_tag(xml, mc);
        let mut splices = Vec::new();
        let count = (have.len() + add.len()).to_string();
        if mc.inner_start == mc.end {
            let t = tag[..tag.len() - 1].trim_end();
            let t = t[..t.len() - 1].trim_end();
            let t = set_attr(&format!("{t}>"), "count", &count);
            splices.push(Splice {
                start: mc.start,
                end: mc.end,
                text: format!("{t}{new}</{p}mergeCells>"),
            });
        } else {
            splices.push(Splice {
                start: mc.start,
                end: mc.inner_start,
                text: set_attr(&tag, "count", &count),
            });
            splices.push(Splice {
                start: mc.inner_end,
                end: mc.inner_end,
                text: new,
            });
        }
        return Ok(apply(xml, splices));
    }
    let at = kids
        .iter()
        .filter(|(n, _)| BEFORE_MERGE.contains(&n.as_str()) || BEFORE_MERGE_2.contains(&n.as_str()))
        .map(|(_, s)| s.end)
        .max()
        .ok_or(SpliceError::NoSheetData)?;
    Ok(apply(
        xml,
        vec![Splice {
            start: at,
            end: at,
            text: format!(
                "<{p}mergeCells count=\"{}\">{new}</{p}mergeCells>",
                add.len()
            ),
        }],
    ))
}

/// The cells that hold a value or formula, among those `want` covers:
/// used to say which cells a new merged range would hide.
pub fn filled_cells(xml: &[u8], want: [u32; 4]) -> Result<Vec<(u32, u32)>, SpliceError> {
    let st = structure(xml);
    let rows = scan_rows(xml, &st, &|r| r >= want[0] && r <= want[2])?;
    let mut out: Vec<(u32, u32)> = rows
        .cells
        .iter()
        .filter(|((r, c), s)| {
            contains(want, *r, *c) && s.inner_start != s.end && {
                next_by_local(
                    xml,
                    s.inner_start,
                    s.inner_end,
                    &Ignorable::new(xml, s.inner_start, s.inner_end),
                    b"v",
                )
                .is_some()
                    || has_formula(xml, s.inner_start, s.inner_end)
                    || next_by_local(
                        xml,
                        s.inner_start,
                        s.inner_end,
                        &Ignorable::new(xml, s.inner_start, s.inner_end),
                        b"is",
                    )
                    .is_some()
            }
        })
        .map(|(k, _)| *k)
        .collect();
    out.sort();
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn edit(xml: &str, edits: &[Edit]) -> String {
        String::from_utf8(
            apply_edits(xml.as_bytes(), edits, &mut KeepStyle)
                .unwrap()
                .xml,
        )
        .unwrap()
    }

    #[test]
    fn numbers_are_written_exactly() {
        assert_eq!(number_text(9.0), "9");
        assert_eq!(number_text(-3.0), "-3");
        assert_eq!(number_text(0.1), "0.1");
        assert_eq!(number_text(1e-300), "1e-300");
        assert_eq!(number_text(45306.5), "45306.5");
    }

    #[test]
    fn references_round_trip() {
        assert_eq!(cell_ref(0, 0), "A1");
        assert_eq!(cell_ref(1_048_575, 16_383), "XFD1048576");
        assert_eq!(parse_ref("XFD1048576"), Some((1_048_575, 16_383)));
        assert_eq!(parse_ref("XFE1"), None);
        assert_eq!(parse_ref("A01"), None);
        assert_eq!(parse_range("$B$2:$C$13"), Some([1, 1, 12, 2]));
    }

    #[test]
    fn attributes_are_removed_and_set() {
        assert_eq!(
            remove_attr("<row r=\"2\" ht=\"20\" spans=\"1:1\"/>", "spans"),
            "<row r=\"2\" ht=\"20\"/>"
        );
        assert_eq!(
            set_attr("<calcPr calcId=\"1\"/>", "fullCalcOnLoad", "1"),
            "<calcPr calcId=\"1\" fullCalcOnLoad=\"1\"/>"
        );
        assert_eq!(
            set_attr("<calcPr fullCalcOnLoad='0'>", "fullCalcOnLoad", "1"),
            "<calcPr fullCalcOnLoad='1'>"
        );
    }

    #[test]
    fn text_formulas_and_blanks() {
        let xml = "<worksheet><dimension ref=\"A1\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"3\"><f>B1</f><v>1</v></c></row></sheetData></worksheet>";
        let out = edit(
            xml,
            &[
                Edit {
                    row: 0,
                    col: 0,
                    value: Value::Text("a < b & c".into()),
                },
                Edit {
                    row: 2,
                    col: 1,
                    value: Value::Formula("SUM(A1:A2)".into()),
                },
                Edit {
                    row: 1,
                    col: 0,
                    value: Value::Blank,
                },
            ],
        );
        assert_eq!(
            out,
            "<worksheet><dimension ref=\"A1:B3\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"3\" t=\"inlineStr\"><is><t xml:space=\"preserve\">a &lt; b &amp; c</t></is></c></row><row r=\"3\"><c r=\"B3\"><f>SUM(A1:A2)</f></c></row></sheetData></worksheet>"
        );
    }

    #[test]
    fn merged_followers_and_array_ranges_are_refused() {
        let xml = "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><f t=\"array\" ref=\"A1:A2\">B1:B2</f><v>1</v></c></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"C1:D2\"/></mergeCells></worksheet>";
        let e = |r, c| {
            vec![Edit {
                row: r,
                col: c,
                value: Value::Number(1.0),
            }]
        };
        assert_eq!(
            apply_edits(xml.as_bytes(), &e(1, 0), &mut KeepStyle).err(),
            Some(SpliceError::Grouped(1, 0, "array", [0, 0, 1, 0]))
        );
        assert_eq!(
            apply_edits(xml.as_bytes(), &e(1, 3), &mut KeepStyle).err(),
            Some(SpliceError::Merged(1, 3, [0, 2, 1, 3]))
        );
        assert!(apply_edits(xml.as_bytes(), &e(0, 2), &mut KeepStyle).is_ok());
    }

    #[test]
    fn replacing_sheet_data_clears_merges() {
        let xml = "<worksheet><dimension ref=\"A1:D9\"/><sheetData><row r=\"1\"><c r=\"A1\"><f>1</f></c></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"C1:D2\"/></mergeCells><pageMargins/></worksheet>";
        let out = replace_sheet_data(
            xml.as_bytes(),
            &[
                Edit {
                    row: 0,
                    col: 0,
                    value: Value::Text("x".into()),
                },
                Edit {
                    row: 1,
                    col: 1,
                    value: Value::Number(2.0),
                },
            ],
            &mut KeepStyle,
        )
        .unwrap();
        assert!(out.removed_formula);
        assert_eq!(
            String::from_utf8(out.xml).unwrap(),
            "<worksheet><dimension ref=\"A1:B2\"/><sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t xml:space=\"preserve\">x</t></is></c></row><row r=\"2\"><c r=\"B2\"><v>2</v></c></row></sheetData><pageMargins/></worksheet>"
        );
    }

    #[test]
    fn merges_are_added_in_schema_order() {
        let xml = "<worksheet><sheetData/><pageMargins/></worksheet>";
        let out = add_merges(xml.as_bytes(), &[[1, 1, 1, 5]]).unwrap();
        assert_eq!(
            String::from_utf8(out).unwrap(),
            "<worksheet><sheetData/><mergeCells count=\"1\"><mergeCell ref=\"B2:F2\"/></mergeCells><pageMargins/></worksheet>"
        );
        let xml = "<worksheet><sheetData/><mergeCells count=\"1\"><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>";
        let out = add_merges(xml.as_bytes(), &[[2, 0, 2, 1]]).unwrap();
        assert_eq!(
            String::from_utf8(out).unwrap(),
            "<worksheet><sheetData/><mergeCells count=\"2\"><mergeCell ref=\"A1:B1\"/><mergeCell ref=\"A3:B3\"/></mergeCells></worksheet>"
        );
        assert!(matches!(
            add_merges(xml.as_bytes(), &[[0, 1, 0, 2]]),
            Err(SpliceError::MergeOverlap(..))
        ));
    }

    #[test]
    fn a_shared_formula_master_is_not_replaced() {
        let xml = "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><f t=\"shared\" ref=\"A1:A2\" si=\"0\">B1</f><v>1</v></c></row><row r=\"2\"><c r=\"A2\"><f t=\"shared\" si=\"0\"/><v>1</v></c></row></sheetData></worksheet>";
        let f = |r| {
            vec![Edit {
                row: r,
                col: 0,
                value: Value::Formula("C1".into()),
            }]
        };
        assert_eq!(
            apply_edits(xml.as_bytes(), &f(0), &mut KeepStyle).err(),
            Some(SpliceError::Grouped(0, 0, "shared", [0, 0, 1, 0]))
        );
        // A follower may become a formula of its own.
        assert!(apply_edits(xml.as_bytes(), &f(1), &mut KeepStyle).is_ok());
    }

    #[test]
    fn a_single_quoted_attribute_takes_an_apostrophe() {
        assert_eq!(
            set_attr(
                "<tableColumn id='1' name='old'/>",
                "name",
                &encode_attr("O'Brien")
            ),
            "<tableColumn id='1' name='O&apos;Brien'/>"
        );
    }

    #[test]
    fn a_new_cell_goes_before_the_rows_extension_list() {
        let xml = "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><v>1</v><extLst/></c><extLst><ext uri=\"x\"/></extLst></row></sheetData></worksheet>";
        let out = edit(
            xml,
            &[Edit {
                row: 0,
                col: 1,
                value: Value::Number(2.0),
            }],
        );
        assert_eq!(
            out,
            "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><v>1</v><extLst/></c><c r=\"B1\"><v>2</v></c><extLst><ext uri=\"x\"/></extLst></row></sheetData></worksheet>"
        );
    }
}
