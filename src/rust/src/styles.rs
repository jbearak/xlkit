//! Appending cell formats to `xl/styles.xml` (ADR 0006).
//!
//! A written cell may need a format the workbook lacks: its own format
//! with bold added, or a date format where its format shows a number.
//! The new number formats, fonts, fills, borders and cell formats (`xf`)
//! are appended to their lists, each built from the cell's own one, so
//! existing indices never move and every byte of the part outside those
//! lists' ends and `count` attributes is copied through.

use crate::format::{classify, NumberKind};
use crate::splice::{
    attr_span, decode_xml, encode_attr, find_tag_end, get_attr, is_self_closing, set_attr,
    Ignorable,
};
use std::collections::HashMap;

/// One overlay style, as R's `xl_style()` sets it. `None` keeps what the
/// cell has.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Overlay {
    pub bold: Option<bool>,
    pub italic: Option<bool>,
    pub underline: Option<bool>,
    pub color: Option<u32>,
    pub fill: Option<u32>,
    /// top, right, bottom, left: 1 thin, 2 medium, 3 thick, 4 double.
    pub border: [Option<u8>; 4],
    pub align: Option<u8>,
    pub valign: Option<u8>,
    pub wrap: Option<bool>,
    pub indent: Option<u32>,
    pub size: Option<f64>,
    pub font: Option<String>,
    pub numfmt: Option<String>,
}

impl Overlay {
    fn touches_font(&self) -> bool {
        self.bold.is_some()
            || self.italic.is_some()
            || self.underline.is_some()
            || self.color.is_some()
            || self.size.is_some()
            || self.font.is_some()
    }
    fn touches_border(&self) -> bool {
        self.border.iter().any(|b| b.is_some())
    }
    fn touches_alignment(&self) -> bool {
        self.align.is_some()
            || self.valign.is_some()
            || self.wrap.is_some()
            || self.indent.is_some()
    }
}

/// An element of a list, as raw text.
struct Section {
    /// Where the list's opening tag starts and ends, and its content ends.
    start: usize,
    open_end: usize,
    inner_end: usize,
    self_closing: bool,
    prefix: String,
    items: Vec<String>,
    added: Vec<String>,
}

pub struct Styles {
    xml: Vec<u8>,
    prefix: String,
    numfmts: HashMap<u32, String>,
    numfmt_section: Option<Section>,
    new_numfmts: Vec<(u32, String)>,
    next_numfmt: u32,
    fonts: Section,
    fills: Section,
    borders: Section,
    xfs: Section,
    root_open_end: usize,
}

const BUILTIN: [(u32, &str); 28] = [
    (0, "General"),
    (1, "0"),
    (2, "0.00"),
    (3, "#,##0"),
    (4, "#,##0.00"),
    (9, "0%"),
    (10, "0.00%"),
    (11, "0.00E+00"),
    (12, "# ?/?"),
    (13, "# ??/??"),
    (14, "mm-dd-yy"),
    (15, "d-mmm-yy"),
    (16, "d-mmm"),
    (17, "mmm-yy"),
    (18, "h:mm AM/PM"),
    (19, "h:mm:ss AM/PM"),
    (20, "h:mm"),
    (21, "h:mm:ss"),
    (22, "m/d/yy h:mm"),
    (37, "#,##0 ;(#,##0)"),
    (38, "#,##0 ;[Red](#,##0)"),
    (39, "#,##0.00;(#,##0.00)"),
    (40, "#,##0.00;[Red](#,##0.00)"),
    (45, "mm:ss"),
    (46, "[h]:mm:ss"),
    (47, "mmss.0"),
    (48, "##0.0E+0"),
    (49, "@"),
];

/// The children of an element, as (local name, raw text).
fn children(xml: &[u8], from: usize, to: usize) -> Vec<(String, String)> {
    let ign = Ignorable::new(xml, from, to);
    let mut out = Vec::new();
    let mut pos = from;
    while pos < to {
        let Some(at) = xml[pos..to]
            .iter()
            .position(|&c| c == b'<')
            .map(|p| p + pos)
        else {
            break;
        };
        if let Some(e) = ign.end_of(at) {
            pos = e;
            continue;
        }
        if matches!(xml.get(at + 1), Some(b'/') | Some(b'!') | Some(b'?') | None) {
            pos = at + 1;
            continue;
        }
        let mut ne = at + 1;
        while ne < to && !matches!(xml[ne], b' ' | b'\t' | b'\n' | b'\r' | b'/' | b'>') {
            ne += 1;
        }
        let name = String::from_utf8_lossy(&xml[at + 1..ne]).into_owned();
        let Some(te) = find_tag_end(xml, at, to) else {
            break;
        };
        let end = if is_self_closing(xml, at, te) {
            te + 1
        } else {
            // The matching end tag, counting nested elements of the same name.
            let open = format!("<{name}");
            let close = format!("</{name}");
            let mut depth = 1;
            let mut p = te + 1;
            let mut end = None;
            while p < to {
                let next = xml[p..to].iter().position(|&c| c == b'<').map(|x| x + p);
                let Some(n) = next else { break };
                if let Some(e) = ign.end_of(n) {
                    p = e;
                    continue;
                }
                let Some(t) = find_tag_end(xml, n, to) else {
                    break;
                };
                let tag = &xml[n..=t];
                if tag.starts_with(close.as_bytes()) {
                    depth -= 1;
                    if depth == 0 {
                        end = Some(t + 1);
                        break;
                    }
                } else if tag.starts_with(open.as_bytes()) && !is_self_closing(xml, n, t) {
                    depth += 1;
                }
                p = t + 1;
            }
            match end {
                Some(e) => e,
                None => break,
            }
        };
        let local = name.rsplit(':').next().unwrap_or(&name).to_string();
        out.push((local, String::from_utf8_lossy(&xml[at..end]).into_owned()));
        pos = end;
    }
    out
}

fn prefix_of(qname: &str) -> String {
    match qname.find(':') {
        Some(c) => format!("{}:", &qname[..c]),
        None => String::new(),
    }
}

/// The direct child of the stylesheet with this local name.
fn section(xml: &[u8], root_inner: (usize, usize), local: &str) -> Option<Section> {
    let kids = children(xml, root_inner.0, root_inner.1);
    // Offsets: find each child again to know where it is.
    let mut pos = root_inner.0;
    for (name, raw) in kids {
        let at = pos + find_bytes(&xml[pos..root_inner.1], raw.as_bytes())?;
        pos = at + raw.len();
        if name != local {
            continue;
        }
        let te = find_tag_end(xml, at, root_inner.1)?;
        let self_closing = is_self_closing(xml, at, te);
        let qname_end = (at + 1..te)
            .find(|&i| matches!(xml[i], b' ' | b'\t' | b'\n' | b'\r' | b'/' | b'>'))
            .unwrap_or(te);
        let qname = String::from_utf8_lossy(&xml[at + 1..qname_end]).into_owned();
        let inner_end = if self_closing {
            te + 1
        } else {
            at + raw.rfind("</").unwrap_or(raw.len())
        };
        let items = if self_closing {
            Vec::new()
        } else {
            children(xml, te + 1, inner_end)
                .into_iter()
                .map(|(_, r)| r)
                .collect()
        };
        return Some(Section {
            start: at,
            open_end: te + 1,
            inner_end,
            self_closing,
            prefix: prefix_of(&qname),
            items,
            added: Vec::new(),
        });
    }
    None
}

fn find_bytes(hay: &[u8], needle: &[u8]) -> Option<usize> {
    memchr::memmem::find(hay, needle)
}

fn attr_of(raw: &str, name: &str) -> Option<String> {
    let b = raw.as_bytes();
    let te = find_tag_end(b, 0, b.len())?;
    get_attr(b, 0, te + 1, name)
}

/// The opening tag of an element, and what follows it.
fn split_open(raw: &str) -> (String, String) {
    let b = raw.as_bytes();
    let te = find_tag_end(b, 0, b.len()).unwrap_or(raw.len() - 1);
    (raw[..=te].to_string(), raw[te + 1..].to_string())
}

impl Section {
    fn len(&self) -> usize {
        self.items.len() + self.added.len()
    }
    fn get(&self, i: usize) -> Option<&str> {
        if i < self.items.len() {
            Some(&self.items[i])
        } else {
            self.added.get(i - self.items.len()).map(|s| s.as_str())
        }
    }
    /// The index of this element, appending it if no element is the same.
    fn index_of(&mut self, raw: String) -> usize {
        if let Some(i) = self.items.iter().position(|x| *x == raw) {
            return i;
        }
        if let Some(i) = self.added.iter().position(|x| *x == raw) {
            return self.items.len() + i;
        }
        self.added.push(raw);
        self.len() - 1
    }
}

impl Styles {
    pub fn parse(xml: Vec<u8>) -> Option<Styles> {
        let ign = Ignorable::new(&xml, 0, xml.len());
        // The root element: the first live element.
        let mut pos = 0;
        let root_start = loop {
            let at = xml[pos..]
                .iter()
                .position(|&c| c == b'<')
                .map(|p| p + pos)?;
            if let Some(e) = ign.end_of(at) {
                pos = e;
                continue;
            }
            if matches!(xml.get(at + 1), Some(b'!') | Some(b'?')) {
                pos = find_tag_end(&xml, at, xml.len())? + 1;
                continue;
            }
            break at;
        };
        let te = find_tag_end(&xml, root_start, xml.len())?;
        let qname_end = (root_start + 1..te)
            .find(|&i| matches!(xml[i], b' ' | b'\t' | b'\n' | b'\r' | b'/' | b'>'))
            .unwrap_or(te);
        let qname = String::from_utf8_lossy(&xml[root_start + 1..qname_end]).into_owned();
        let close = find_bytes(&xml, format!("</{qname}").as_bytes())?;
        let inner = (te + 1, close);
        let numfmt_section = section(&xml, inner, "numFmts");
        let mut numfmts = HashMap::new();
        if let Some(s) = &numfmt_section {
            for raw in &s.items {
                if let (Some(id), Some(code)) =
                    (attr_of(raw, "numFmtId"), attr_of(raw, "formatCode"))
                {
                    if let Ok(id) = id.trim().parse::<u32>() {
                        numfmts.insert(id, code);
                    }
                }
            }
        }
        let next_numfmt = numfmts.keys().copied().max().unwrap_or(0).max(163) + 1;
        Some(Styles {
            prefix: prefix_of(&qname),
            numfmts,
            numfmt_section,
            new_numfmts: Vec::new(),
            next_numfmt,
            fonts: section(&xml, inner, "fonts")?,
            fills: section(&xml, inner, "fills")?,
            borders: section(&xml, inner, "borders")?,
            xfs: section(&xml, inner, "cellXfs")?,
            root_open_end: te + 1,
            xml,
        })
    }

    pub fn changed(&self) -> bool {
        !(self.new_numfmts.is_empty()
            && self.fonts.added.is_empty()
            && self.fills.added.is_empty()
            && self.borders.added.is_empty()
            && self.xfs.added.is_empty())
    }

    fn xf_attr(&self, xf: u32, name: &str) -> Option<u32> {
        let raw = self.xfs.get(xf as usize)?;
        attr_of(raw, name)?.trim().parse().ok()
    }

    /// The number format code of a cell format.
    fn numfmt_code(&self, xf: u32) -> (u32, String) {
        let id = self.xf_attr(xf, "numFmtId").unwrap_or(0);
        let code = self
            .numfmts
            .get(&id)
            .cloned()
            .or_else(|| {
                self.new_numfmts
                    .iter()
                    .find(|(i, _)| *i == id)
                    .map(|(_, c)| c.clone())
            })
            .or_else(|| {
                BUILTIN
                    .iter()
                    .find(|(i, _)| *i == id)
                    .map(|(_, c)| c.to_string())
            })
            .unwrap_or_default();
        (id, code)
    }

    /// What the cell format shows a number as.
    pub fn kind(&self, xf: u32, v: f64) -> NumberKind {
        let (id, code) = self.numfmt_code(xf);
        classify(&code, Some(id)).for_value(v).kind
    }

    pub fn n_xfs(&self) -> usize {
        self.xfs.len()
    }

    fn numfmt_id(&mut self, code: &str) -> u32 {
        if let Some((id, _)) = BUILTIN.iter().find(|(_, c)| *c == code) {
            return *id;
        }
        if let Some((id, _)) = self
            .numfmts
            .iter()
            .filter(|(_, c)| c.as_str() == code)
            .min_by_key(|(i, _)| **i)
        {
            return *id;
        }
        if let Some((id, _)) = self.new_numfmts.iter().find(|(_, c)| c == code) {
            return *id;
        }
        let id = self.next_numfmt;
        self.next_numfmt += 1;
        self.new_numfmts.push((id, code.to_string()));
        id
    }

    fn font(&mut self, base: usize, o: &Overlay) -> usize {
        let p = self.fonts.prefix.clone();
        let raw = self.fonts.get(base).unwrap_or("<font/>").to_string();
        let (open, rest) = split_open(&raw);
        let mut kids: Vec<(String, String)> = if open.ends_with("/>") {
            Vec::new()
        } else {
            let b = rest.as_bytes();
            let end = rest.rfind("</").unwrap_or(rest.len());
            children(b, 0, end)
        };
        let mut set = |local: &str, value: Option<String>| {
            kids.retain(|(n, _)| n != local);
            if let Some(v) = value {
                kids.push((local.to_string(), v));
            }
        };
        if let Some(b) = o.bold {
            set("b", b.then(|| format!("<{p}b/>")));
        }
        if let Some(i) = o.italic {
            set("i", i.then(|| format!("<{p}i/>")));
        }
        if let Some(u) = o.underline {
            set("u", u.then(|| format!("<{p}u/>")));
        }
        if let Some(s) = o.size {
            set(
                "sz",
                Some(format!(
                    "<{p}sz val=\"{}\"/>",
                    crate::splice::number_text(s)
                )),
            );
        }
        if let Some(c) = o.color {
            set("color", Some(format!("<{p}color rgb=\"FF{c:06X}\"/>")));
        }
        if let Some(f) = &o.font {
            set(
                "name",
                Some(format!("<{p}name val=\"{}\"/>", encode_attr(f))),
            );
            // A theme font scheme would win over the name.
            set("scheme", None);
            set("family", None);
            set("charset", None);
        }
        let open_tag = open
            .trim_end_matches("/>")
            .trim_end_matches('>')
            .trim_end()
            .to_string();
        let name = &open_tag[1..open_tag
            .find([' ', '\t', '\n', '\r'])
            .unwrap_or(open_tag.len())];
        let body: String = kids.into_iter().map(|(_, r)| r).collect();
        self.fonts.index_of(format!("{open_tag}>{body}</{name}>"))
    }

    fn fill(&mut self, rgb: u32) -> usize {
        let p = self.fills.prefix.clone();
        self.fills.index_of(format!(
            "<{p}fill><{p}patternFill patternType=\"solid\"><{p}fgColor rgb=\"FF{rgb:06X}\"/><{p}bgColor indexed=\"64\"/></{p}patternFill></{p}fill>"
        ))
    }

    fn border(&mut self, base: usize, o: &Overlay) -> usize {
        let p = self.borders.prefix.clone();
        let raw = self.borders.get(base).unwrap_or("<border/>").to_string();
        let (open, rest) = split_open(&raw);
        let kids: Vec<(String, String)> = if open.ends_with("/>") {
            Vec::new()
        } else {
            let end = rest.rfind("</").unwrap_or(rest.len());
            children(rest.as_bytes(), 0, end)
        };
        let side = |local: &str, alt: &str| -> Option<String> {
            kids.iter()
                .find(|(n, _)| n == local || n == alt)
                .map(|(_, r)| r.clone())
        };
        let style = |code: u8| match code {
            1 => "thin",
            2 => "medium",
            3 => "thick",
            _ => "double",
        };
        // Sides in schema order: left, right, top, bottom; R gives top, right, bottom, left.
        let mut body = String::new();
        for (local, alt, k) in [
            ("left", "start", 3),
            ("right", "end", 1),
            ("top", "top", 0),
            ("bottom", "bottom", 2),
        ] {
            match o.border[k] {
                Some(code) => body.push_str(&format!(
                    "<{p}{local} style=\"{}\"><{p}color auto=\"1\"/></{p}{local}>",
                    style(code)
                )),
                None => {
                    body.push_str(&side(local, alt).unwrap_or_else(|| format!("<{p}{local}/>")))
                }
            }
        }
        for local in ["diagonal", "vertical", "horizontal"] {
            if let Some(r) = side(local, local) {
                body.push_str(&r);
            } else if local == "diagonal" {
                body.push_str(&format!("<{p}diagonal/>"));
            }
        }
        let open_tag = open
            .trim_end_matches("/>")
            .trim_end_matches('>')
            .trim_end()
            .to_string();
        let name = &open_tag[1..open_tag
            .find([' ', '\t', '\n', '\r'])
            .unwrap_or(open_tag.len())];
        self.borders.index_of(format!("{open_tag}>{body}</{name}>"))
    }

    /// The cell format `base` with `o` over it: its index, appended if new.
    pub fn derive(&mut self, base: u32, o: &Overlay) -> u32 {
        let p = self.xfs.prefix.clone();
        let raw = self
            .xfs
            .get(base as usize)
            .or_else(|| self.xfs.get(0))
            .unwrap_or("<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>")
            .to_string();
        let (open, rest) = split_open(&raw);
        let mut kids: Vec<(String, String)> = if open.ends_with("/>") {
            Vec::new()
        } else {
            let end = rest.rfind("</").unwrap_or(rest.len());
            children(rest.as_bytes(), 0, end)
        };
        let num = |a: &str| {
            attr_of(&raw, a)
                .and_then(|v| v.trim().parse::<usize>().ok())
                .unwrap_or(0)
        };
        let mut tag = open
            .trim_end_matches("/>")
            .trim_end_matches('>')
            .trim_end()
            .to_string()
            + ">";
        if let Some(code) = &o.numfmt {
            let id = self.numfmt_id(code);
            tag = set_attr(&tag, "numFmtId", &id.to_string());
            tag = set_attr(&tag, "applyNumberFormat", "1");
        }
        if o.touches_font() {
            let id = self.font(num("fontId"), o);
            tag = set_attr(&tag, "fontId", &id.to_string());
            tag = set_attr(&tag, "applyFont", "1");
        }
        if let Some(rgb) = o.fill {
            let id = self.fill(rgb);
            tag = set_attr(&tag, "fillId", &id.to_string());
            tag = set_attr(&tag, "applyFill", "1");
        }
        if o.touches_border() {
            let id = self.border(num("borderId"), o);
            tag = set_attr(&tag, "borderId", &id.to_string());
            tag = set_attr(&tag, "applyBorder", "1");
        }
        if o.touches_alignment() {
            let old = kids
                .iter()
                .find(|(n, _)| n == "alignment")
                .map(|(_, r)| r.clone());
            let mut a = match old {
                Some(r) => {
                    let (t, _) = split_open(&r);
                    t.trim_end_matches("/>")
                        .trim_end_matches('>')
                        .trim_end()
                        .to_string()
                        + "/>"
                }
                None => format!("<{p}alignment/>"),
            };
            if let Some(h) = o.align {
                a = set_attr(
                    &a,
                    "horizontal",
                    ["left", "center", "right"][(h as usize).clamp(1, 3) - 1],
                );
            }
            if let Some(v) = o.valign {
                a = set_attr(
                    &a,
                    "vertical",
                    ["top", "center", "bottom"][(v as usize).clamp(1, 3) - 1],
                );
            }
            if let Some(w) = o.wrap {
                a = set_attr(&a, "wrapText", if w { "1" } else { "0" });
            }
            if let Some(i) = o.indent {
                a = set_attr(&a, "indent", &i.to_string());
            }
            kids.retain(|(n, _)| n != "alignment");
            kids.insert(0, ("alignment".into(), a));
            tag = set_attr(&tag, "applyAlignment", "1");
        }
        let name_end = tag.find([' ', '\t', '\n', '\r', '>']).unwrap_or(tag.len());
        let name = tag[1..name_end].to_string();
        let new = if kids.is_empty() {
            format!("{}/>", tag[..tag.len() - 1].trim_end())
        } else {
            let body: String = kids.into_iter().map(|(_, r)| r).collect();
            format!("{tag}{body}</{name}>")
        };
        if new == raw {
            return base;
        }
        self.xfs.index_of(new) as u32
    }

    /// The part with the appended lists, or None when nothing was added.
    pub fn finish(self) -> Option<Vec<u8>> {
        if !self.changed() {
            return None;
        }
        let mut splices: Vec<(usize, usize, String)> = Vec::new();
        let p = &self.prefix;
        if !self.new_numfmts.is_empty() {
            let items: String = self
                .new_numfmts
                .iter()
                .map(|(id, c)| {
                    let q = self
                        .numfmt_section
                        .as_ref()
                        .map(|s| s.prefix.clone())
                        .unwrap_or_else(|| p.clone());
                    format!(
                        "<{q}numFmt numFmtId=\"{id}\" formatCode=\"{}\"/>",
                        encode_attr(c)
                    )
                })
                .collect();
            match &self.numfmt_section {
                Some(s) => push_section(
                    &self.xml,
                    s,
                    s.items.len() + self.new_numfmts.len(),
                    &items,
                    &mut splices,
                ),
                None => splices.push((
                    self.root_open_end,
                    self.root_open_end,
                    format!(
                        "<{p}numFmts count=\"{}\">{items}</{p}numFmts>",
                        self.new_numfmts.len()
                    ),
                )),
            }
        }
        for s in [&self.fonts, &self.fills, &self.borders, &self.xfs] {
            if !s.added.is_empty() {
                push_section(&self.xml, s, s.len(), &s.added.concat(), &mut splices);
            }
        }
        splices.sort_by_key(|x| (x.0, x.1 != x.0));
        let mut out = Vec::with_capacity(self.xml.len() + 4096);
        let mut at = 0;
        for (s, e, t) in splices {
            out.extend_from_slice(&self.xml[at..s]);
            out.extend_from_slice(t.as_bytes());
            at = e;
        }
        out.extend_from_slice(&self.xml[at..]);
        Some(out)
    }
}

fn push_section(
    xml: &[u8],
    s: &Section,
    count: usize,
    items: &str,
    splices: &mut Vec<(usize, usize, String)>,
) {
    let open = String::from_utf8_lossy(&xml[s.start..s.open_end]).into_owned();
    let b = open.as_bytes();
    let has_count = attr_span(b, 0, b.len(), b"count").is_some();
    if s.self_closing {
        let t = open
            .trim_end_matches('>')
            .trim_end()
            .trim_end_matches('/')
            .trim_end()
            .to_string()
            + ">";
        let t = set_attr(&t, "count", &count.to_string());
        let qname = &t[1..t.find([' ', '\t', '\n', '\r', '>']).unwrap_or(t.len())];
        splices.push((s.start, s.open_end, format!("{t}{items}</{qname}>")));
        return;
    }
    if has_count {
        splices.push((
            s.start,
            s.open_end,
            set_attr(&open, "count", &count.to_string()),
        ));
    }
    splices.push((s.inner_end, s.inner_end, items.to_string()));
}

/// Decode an attribute that may hold entities (used by tests).
#[allow(dead_code)]
fn decoded(s: &str) -> String {
    decode_xml(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    const XML: &str = "<styleSheet xmlns=\"x\"><numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"d mmm yyyy\"/></numFmts><fonts count=\"2\"><font><sz val=\"11\"/><name val=\"Calibri\"/><scheme val=\"minor\"/></font><font><b val=\"1\"/></font></fonts><fills count=\"2\"><fill><patternFill/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills><borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellXfs count=\"3\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/><xf numFmtId=\"3\" fontId=\"0\" fillId=\"1\" borderId=\"0\" xfId=\"0\"/><xf numFmtId=\"164\" fontId=\"1\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/></cellXfs></styleSheet>";

    #[test]
    fn formats_are_appended_and_keep_the_rest() {
        let mut s = Styles::parse(XML.as_bytes().to_vec()).unwrap();
        assert_eq!(s.kind(2, 45000.0), NumberKind::Date);
        assert_eq!(s.kind(1, 45000.0), NumberKind::Number);
        let date = Overlay {
            numfmt: Some("yyyy-mm-dd".into()),
            ..Default::default()
        };
        let a = s.derive(1, &date);
        assert_eq!(a, 3);
        assert_eq!(s.kind(3, 45000.0), NumberKind::Date);
        // The same request again reuses it.
        assert_eq!(s.derive(1, &date), 3);
        let bold = Overlay {
            bold: Some(true),
            ..Default::default()
        };
        assert_eq!(s.derive(0, &bold), 4);
        let out = String::from_utf8(s.finish().unwrap()).unwrap();
        assert!(out.contains("<numFmts count=\"2\"><numFmt numFmtId=\"164\" formatCode=\"d mmm yyyy\"/><numFmt numFmtId=\"165\" formatCode=\"yyyy-mm-dd\"/></numFmts>"));
        assert!(out.contains("<fonts count=\"3\">"));
        assert!(out.contains("<font><sz val=\"11\"/><name val=\"Calibri\"/><scheme val=\"minor\"/><b/></font></fonts>"));
        assert!(out.contains("<xf numFmtId=\"165\" fontId=\"0\" fillId=\"1\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"));
        assert!(out.contains("<cellXfs count=\"5\">"));
    }

    #[test]
    fn nothing_added_leaves_the_part_alone() {
        let mut s = Styles::parse(XML.as_bytes().to_vec()).unwrap();
        assert_eq!(s.derive(1, &Overlay::default()), 1);
        assert!(s.finish().is_none());
    }
}
