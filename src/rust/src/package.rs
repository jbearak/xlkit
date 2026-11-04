//! Reading parts of the .xlsx package that calamine keeps private.
//!
//! calamine gives an Excel table's body but not the table's own `ref`
//! or how many header rows it has, so a table without a header row, or
//! with only its header, cannot be placed from what it returns. This
//! reads each table's definition from the package: the workbook's sheets
//! and their relationships, then each table part.

use crate::read::Failure;
use quick_xml::events::Event;
use quick_xml::{Reader, XmlVersion};
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufReader, Read};
use zip::ZipArchive;

/// An Excel table as its definition gives it.
pub struct TableDef {
    pub name: String,
    pub sheet: String,
    /// The table's cells, header and totals rows included, as 1-based
    /// (first row, first column, last row, last column).
    pub cells: [i32; 4],
    pub header_rows: i32,
    pub totals_rows: i32,
}

fn part(zip: &mut ZipArchive<BufReader<File>>, name: &str) -> Option<String> {
    let mut f = zip.by_name(name).ok()?;
    let mut s = String::new();
    f.read_to_string(&mut s).ok()?;
    Some(s)
}

/// The attributes of every element with this local name, in order.
fn elements(xml: &str, local: &str) -> Vec<HashMap<String, String>> {
    let mut reader = Reader::from_str(xml);
    let mut out = Vec::new();
    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) | Ok(Event::Empty(e)) if e.local_name().as_ref() == local => {
                let mut attrs = HashMap::new();
                for a in e.attributes().flatten() {
                    let key = a.key.local_name().as_ref().to_string();
                    let full = a.key.as_ref().to_string();
                    let value = a
                        .normalized_value(XmlVersion::Implicit1_0)
                        .map(|v| v.into_owned())
                        .unwrap_or_default();
                    // Keep both `r:id` and `id`, since relationship ids are prefixed.
                    attrs.insert(full, value.clone());
                    attrs.entry(key).or_insert(value);
                }
                out.push(attrs);
            }
            Ok(Event::Eof) | Err(_) => break,
            _ => {}
        }
    }
    out
}

/// Resolve a relationship target against the folder of the part that has it.
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

fn rels(
    zip: &mut ZipArchive<BufReader<File>>,
    part_name: &str,
) -> HashMap<String, (String, String)> {
    let (dir, file) = match part_name.rfind('/') {
        Some(i) => (&part_name[..i], &part_name[i + 1..]),
        None => ("", part_name),
    };
    let rels_name = if dir.is_empty() {
        format!("_rels/{file}.rels")
    } else {
        format!("{dir}/_rels/{file}.rels")
    };
    let mut out = HashMap::new();
    if let Some(xml) = part(zip, &rels_name) {
        for r in elements(&xml, "Relationship") {
            if let (Some(id), Some(target)) = (r.get("Id"), r.get("Target")) {
                let typ = r.get("Type").cloned().unwrap_or_default();
                out.insert(id.clone(), (typ, resolve(dir, target)));
            }
        }
    }
    out
}

/// "B5" as (row, column), 1-based.
fn cell(s: &str) -> Option<(i32, i32)> {
    let s = s.trim_start_matches('$');
    let letters: String = s.chars().take_while(|c| c.is_ascii_alphabetic()).collect();
    let digits = s[letters.len()..].trim_start_matches('$');
    if letters.is_empty() || digits.is_empty() {
        return None;
    }
    let mut col = 0i32;
    for c in letters.chars() {
        col = col * 26 + (c.to_ascii_uppercase() as i32 - 'A' as i32 + 1);
    }
    Some((digits.parse().ok()?, col))
}

fn cells(r: &str) -> Option<[i32; 4]> {
    let mut it = r.split(':');
    let a = cell(it.next()?)?;
    let b = match it.next() {
        Some(b) => cell(b)?,
        None => a,
    };
    Some([a.0, a.1, b.0, b.1])
}

pub fn tables(path: &str) -> Result<Vec<TableDef>, Failure> {
    let file = File::open(path).map_err(|e| Failure::Io(e.to_string()))?;
    let mut zip =
        ZipArchive::new(BufReader::new(file)).map_err(|e| Failure::NotZip(e.to_string()))?;
    let workbook = "xl/workbook.xml";
    let Some(wb_xml) = part(&mut zip, workbook) else {
        return Ok(Vec::new());
    };
    let wb_rels = rels(&mut zip, workbook);
    let mut out = Vec::new();
    for sheet in elements(&wb_xml, "sheet") {
        let (Some(name), Some(rid)) = (
            sheet.get("name"),
            sheet.get("r:id").or_else(|| sheet.get("id")),
        ) else {
            continue;
        };
        let Some((_, sheet_part)) = wb_rels.get(rid) else {
            continue;
        };
        let sheet_part = sheet_part.clone();
        for (typ, target) in rels(&mut zip, &sheet_part).into_values() {
            if !typ.ends_with("/table") {
                continue;
            }
            let Some(xml) = part(&mut zip, &target) else {
                continue;
            };
            let Some(def) = elements(&xml, "table").into_iter().next() else {
                continue;
            };
            let Some(c) = def.get("ref").and_then(|r| cells(r)) else {
                continue;
            };
            let count =
                |k: &str, default: i32| def.get(k).and_then(|v| v.parse().ok()).unwrap_or(default);
            out.push(TableDef {
                name: def
                    .get("displayName")
                    .or_else(|| def.get("name"))
                    .cloned()
                    .unwrap_or_default(),
                sheet: name.clone(),
                cells: c,
                header_rows: count("headerRowCount", 1),
                totals_rows: count("totalsRowCount", 0),
            });
        }
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn targets_resolve_against_their_folder() {
        assert_eq!(
            resolve("xl/worksheets", "../tables/table1.xml"),
            "xl/tables/table1.xml"
        );
        assert_eq!(
            resolve("xl", "worksheets/sheet1.xml"),
            "xl/worksheets/sheet1.xml"
        );
        assert_eq!(
            resolve("xl", "/xl/worksheets/sheet1.xml"),
            "xl/worksheets/sheet1.xml"
        );
    }

    #[test]
    fn refs_parse() {
        assert_eq!(cells("A2:B3"), Some([2, 1, 3, 2]));
        assert_eq!(cells("$C$4"), Some([4, 3, 4, 3]));
        assert_eq!(cells("AA10:AB12"), Some([10, 27, 12, 28]));
    }
}
