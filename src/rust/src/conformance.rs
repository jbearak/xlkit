//! Table Viewer's worksheet conformance corpus (tests/conformance), run
//! against xlkit's splice. Every case must give its golden output bytes,
//! its refusal code, or no authoritative `sheetData`.
//!
//! The corpus edits are text a user typed. xlkit writes typed values, so
//! the adapter below turns each text into the value Table Viewer would
//! classify it as: a date serial when the case's style context says the
//! cell shows that date, else a number when it reads as one, else text.

use crate::splice::{apply_edits, Edit, KeepStyle, SpliceError, Value};
use std::collections::BTreeMap;
use std::path::PathBuf;

/// Just enough JSON for the manifest.
#[derive(Debug, Clone)]
enum Json {
    Null,
    Bool,
    Num(f64),
    Str(String),
    Arr(Vec<Json>),
    Obj(BTreeMap<String, Json>),
}

impl Json {
    fn get(&self, k: &str) -> &Json {
        match self {
            Json::Obj(m) => m.get(k).unwrap_or(&Json::Null),
            _ => &Json::Null,
        }
    }
    fn str(&self) -> &str {
        match self {
            Json::Str(s) => s,
            _ => panic!("not a string: {self:?}"),
        }
    }
    fn num(&self) -> f64 {
        match self {
            Json::Num(n) => *n,
            _ => panic!("not a number: {self:?}"),
        }
    }
    fn arr(&self) -> &[Json] {
        match self {
            Json::Arr(a) => a,
            _ => &[],
        }
    }
}

struct Parser<'a> {
    s: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn ws(&mut self) {
        while self.i < self.s.len() && self.s[self.i].is_ascii_whitespace() {
            self.i += 1;
        }
    }
    fn value(&mut self) -> Json {
        self.ws();
        match self.s[self.i] {
            b'{' => {
                self.i += 1;
                let mut m = BTreeMap::new();
                loop {
                    self.ws();
                    if self.s[self.i] == b'}' {
                        self.i += 1;
                        return Json::Obj(m);
                    }
                    let Json::Str(k) = self.value() else {
                        panic!("key")
                    };
                    self.ws();
                    assert_eq!(self.s[self.i], b':');
                    self.i += 1;
                    let v = self.value();
                    m.insert(k, v);
                    self.ws();
                    if self.s[self.i] == b',' {
                        self.i += 1;
                    }
                }
            }
            b'[' => {
                self.i += 1;
                let mut a = Vec::new();
                loop {
                    self.ws();
                    if self.s[self.i] == b']' {
                        self.i += 1;
                        return Json::Arr(a);
                    }
                    a.push(self.value());
                    self.ws();
                    if self.s[self.i] == b',' {
                        self.i += 1;
                    }
                }
            }
            b'"' => {
                self.i += 1;
                let mut out = String::new();
                loop {
                    let c = self.s[self.i];
                    self.i += 1;
                    match c {
                        b'"' => return Json::Str(out),
                        b'\\' => {
                            let e = self.s[self.i];
                            self.i += 1;
                            match e {
                                b'n' => out.push('\n'),
                                b't' => out.push('\t'),
                                b'r' => out.push('\r'),
                                b'u' => {
                                    let h =
                                        std::str::from_utf8(&self.s[self.i..self.i + 4]).unwrap();
                                    out.push(
                                        char::from_u32(u32::from_str_radix(h, 16).unwrap())
                                            .unwrap(),
                                    );
                                    self.i += 4;
                                }
                                c => out.push(c as char),
                            }
                        }
                        _ => {
                            // Copy a whole UTF-8 sequence.
                            let start = self.i - 1;
                            let mut end = self.i;
                            while end < self.s.len() && (self.s[end] & 0xC0) == 0x80 {
                                end += 1;
                            }
                            out.push_str(std::str::from_utf8(&self.s[start..end]).unwrap());
                            self.i = end;
                        }
                    }
                }
            }
            b't' => {
                self.i += 4;
                Json::Bool
            }
            b'f' => {
                self.i += 5;
                Json::Bool
            }
            b'n' => {
                self.i += 4;
                Json::Null
            }
            _ => {
                let start = self.i;
                while self.i < self.s.len()
                    && matches!(
                        self.s[self.i],
                        b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9'
                    )
                {
                    self.i += 1;
                }
                Json::Num(
                    std::str::from_utf8(&self.s[start..self.i])
                        .unwrap()
                        .parse()
                        .unwrap(),
                )
            }
        }
    }
}

fn corpus() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/conformance")
}

/// Days from 1970-01-01 to a civil date.
fn days(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

/// The typed value Table Viewer's classifier gives this text.
fn typed(value: &str, ctx: &Json) -> Value {
    if value.is_empty() {
        return Value::Blank;
    }
    let b = value.as_bytes();
    if b.len() == 10 && b[4] == b'-' && b[7] == b'-' {
        let (y, m, d) = (&value[..4], &value[5..7], &value[8..]);
        if let (Ok(y), Ok(m), Ok(d)) = (y.parse(), m.parse(), d.parse()) {
            let serial = (days(y, m, d) + 25569) as f64;
            let system_1904 = ctx.get("date_system").str() == "1904";
            let serial = if system_1904 { serial - 1462.0 } else { serial };
            let matches = ctx
                .get("date_style_matches")
                .arr()
                .iter()
                .any(|m| m.get("serial").num() == serial);
            if matches {
                return Value::Number(serial);
            }
        }
    }
    match value.trim().parse::<f64>() {
        Ok(x) if x.is_finite() => Value::Number(x),
        _ => Value::Text(value.to_string()),
    }
}

#[test]
fn every_case_of_the_corpus() {
    let dir = corpus();
    let manifest =
        std::fs::read(dir.join("manifest.json")).expect("tests/conformance/manifest.json");
    let m = Parser { s: &manifest, i: 0 }.value();
    let version = std::fs::read_to_string(dir.join("VERSION")).unwrap();
    assert_eq!(m.get("corpus_version").str(), version.trim());
    let pin = std::fs::read(dir.join("pins/rust.json")).unwrap();
    let pin = Parser { s: &pin, i: 0 }.value();
    assert_eq!(pin.get("corpus_version").str(), version.trim());
    assert_eq!(pin.get("api_version").num(), m.get("api_version").num());

    let cases = m.get("cases").arr();
    assert_eq!(cases.len(), 41);
    let mut failures = Vec::new();
    for case in cases {
        let id = case.get("id").str();
        let input = std::fs::read(dir.join(case.get("input").str())).unwrap();
        let ctx = case.get("context");
        let edits: Vec<Edit> = case
            .get("edits")
            .arr()
            .iter()
            .map(|e| Edit {
                row: e.get("row").num() as u32,
                col: e.get("column").num() as u32,
                value: typed(e.get("value").str(), ctx),
            })
            .collect();
        let got = apply_edits(&input, &edits, &mut KeepStyle);
        let expected = case.get("expected");
        let ok = match (expected.get("kind").str(), &got) {
            ("output", Ok(out)) => {
                let golden = std::fs::read(dir.join(expected.get("golden").str())).unwrap();
                out.xml == golden
            }
            ("refusal", Err(SpliceError::Refused(r))) => r.code() == expected.get("code").str(),
            ("no-authoritative-sheet-data", Err(SpliceError::NoSheetData)) => true,
            _ => false,
        };
        if !ok {
            let shown = match &got {
                Ok(o) => String::from_utf8_lossy(&o.xml).into_owned(),
                Err(e) => format!("{e:?}"),
            };
            failures.push(format!("{id}: {shown}"));
        }
    }
    assert!(
        failures.is_empty(),
        "cases that differ:\n{}",
        failures.join("\n")
    );
}
