//! What a number format shows: a date, a date-time, a time of day, a
//! duration, or a plain number (with the width of a zero-padded code).
//!
//! Excel shows a number as a date because of its number format, so xlkit
//! decides the column type from the format, never from the value.
//! A format has up to four sections separated by `;`; the one Excel
//! uses for a value is picked as Excel picks it (by `[<1]`-style
//! conditions, else positive, negative, zero), so `[<1]yyyy-mm-dd;0`
//! shows 0.5 as a date and 100 as a number.
//!
//! The section splitter's handling of quotes, `\` escapes and the `_` and
//! `*` padding characters is adapted from Table Viewer's
//! `format_sections()` (src/spreadsheet-format.ts, GPL-3.0, Copyright
//! Jonathan Bearak); see ACKNOWLEDGEMENTS.md.

/// The kind of a numeric cell, by its number format. The values are the
/// cell kinds xlkit returns to R (see `read.rs`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NumberKind {
    Number = 1,
    Date = 2,
    DateTime = 3,
    Time = 4,
    Duration = 5,
}

/// A classified number format.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Format {
    pub kind: NumberKind,
    /// For a format of zeros only, such as `00000`, the width it pads to;
    /// otherwise 0.
    pub pad: u8,
}

const PLAIN: Format = Format {
    kind: NumberKind::Number,
    pad: 0,
};

/// A condition such as `[<1]` or `[>=100]` on a section.
#[derive(Debug, Clone, Copy, PartialEq)]
struct Cond {
    op: Op,
    value: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum Op {
    Lt,
    Le,
    Gt,
    Ge,
    Eq,
    Ne,
}

impl Cond {
    fn holds(&self, v: f64) -> bool {
        match self.op {
            Op::Lt => v < self.value,
            Op::Le => v <= self.value,
            Op::Gt => v > self.value,
            Op::Ge => v >= self.value,
            Op::Eq => v == self.value,
            Op::Ne => v != self.value,
        }
    }
}

/// A number format's numeric sections, each with its condition.
#[derive(Debug, Clone, PartialEq)]
pub struct Classified {
    sections: Vec<(Option<Cond>, Format)>,
}

impl Classified {
    /// The format Excel uses to show `v`.
    pub fn for_value(&self, v: f64) -> Format {
        let s = &self.sections;
        if s.iter().any(|(c, _)| c.is_some()) {
            // Conditional formats: the first section whose condition holds;
            // a section without a condition takes what is left.
            for (c, f) in s.iter().take(2) {
                if let Some(c) = c {
                    if c.holds(v) {
                        return *f;
                    }
                }
            }
            return s
                .iter()
                .find(|(c, _)| c.is_none())
                .or(s.last())
                .map(|(_, f)| *f)
                .unwrap_or(PLAIN);
        }
        match s.len() {
            0 => PLAIN,
            1 => s[0].1,
            2 => s[if v < 0.0 { 1 } else { 0 }].1,
            _ => {
                s[if v > 0.0 {
                    0
                } else if v < 0.0 {
                    1
                } else {
                    2
                }]
                .1
            }
        }
    }
}

/// Classify a number format by its code, falling back on the built-in id
/// for the locale-dependent East Asian date formats, whose code the file
/// does not carry.
pub fn classify(code: &str, id: Option<u32>) -> Classified {
    if code.is_empty() || code.eq_ignore_ascii_case("general") {
        let f = match id {
            Some(27..=36) | Some(50..=58) => Format {
                kind: NumberKind::Date,
                pad: 0,
            },
            _ => PLAIN,
        };
        return Classified {
            sections: vec![(None, f)],
        };
    }
    // A section with `@` is for text, never for numbers (`d-mmm-yy;@` shows
    // every number with its first section), and so is the fourth.
    let sections = split_sections(code)
        .into_iter()
        .take(3)
        .filter(|sec| !is_text_section(sec))
        .map(|sec| (condition(sec), classify_section(sec)))
        .collect();
    Classified { sections }
}

/// Whether a section holds `@`, the text placeholder, outside quotes.
fn is_text_section(section: &str) -> bool {
    let mut quoted = false;
    let mut escaped = false;
    for ch in section.chars() {
        if escaped {
            escaped = false;
        } else if ch == '\\' {
            escaped = true;
        } else if ch == '"' {
            quoted = !quoted;
        } else if ch == '@' && !quoted {
            return true;
        }
    }
    false
}

/// The condition in a section's leading brackets, such as `[<1]`.
fn condition(section: &str) -> Option<Cond> {
    let mut rest = section;
    while let Some(open) = rest.find('[') {
        let close = rest[open..].find(']')? + open;
        let inner = rest[open + 1..close].trim();
        let ops = [
            ("<=", Op::Le),
            (">=", Op::Ge),
            ("<>", Op::Ne),
            ("<", Op::Lt),
            (">", Op::Gt),
            ("=", Op::Eq),
        ];
        for (text, op) in ops {
            if let Some(num) = inner.strip_prefix(text) {
                if let Ok(value) = num.trim().parse::<f64>() {
                    return Some(Cond { op, value });
                }
            }
        }
        rest = &rest[close + 1..];
    }
    None
}

/// The sections of `code`: the text between `;`s that are not quoted,
/// escaped, padding or inside brackets.
fn split_sections(code: &str) -> Vec<&str> {
    let mut out = Vec::new();
    let mut from = 0;
    let bytes = code.as_bytes();
    let mut quoted = false;
    let mut bracket = 0usize;
    let mut i = 0;
    while i < bytes.len() {
        let ch = bytes[i];
        if quoted {
            if ch == b'"' {
                quoted = false;
            }
        } else {
            match ch {
                b'\\' | b'_' | b'*' => i += 1,
                b'"' => quoted = true,
                b'[' => bracket += 1,
                b']' => bracket = bracket.saturating_sub(1),
                b';' if bracket == 0 => {
                    out.push(&code[from..i]);
                    from = i + 1;
                }
                _ => {}
            }
        }
        i += 1;
    }
    out.push(&code[from..]);
    out
}

fn classify_section(section: &str) -> Format {
    let chars: Vec<char> = section.chars().collect();
    let mut runs: Vec<char> = Vec::new(); // one letter per run of date/time letters
    let mut elapsed = false;
    let mut ampm = false;
    let mut digits_only = String::new();
    let mut other = false;
    let mut i = 0;
    while i < chars.len() {
        let ch = chars[i];
        match ch {
            '\\' | '_' | '*' => {
                i += 2;
                other = true;
                continue;
            }
            '"' => {
                i += 1;
                while i < chars.len() && chars[i] != '"' {
                    i += 1;
                }
                i += 1;
                other = true;
                continue;
            }
            '[' => {
                let start = i + 1;
                while i < chars.len() && chars[i] != ']' {
                    i += 1;
                }
                let inner: String = chars[start.min(chars.len())..i.min(chars.len())]
                    .iter()
                    .collect::<String>()
                    .to_ascii_lowercase();
                if !inner.is_empty()
                    && (inner.chars().all(|c| c == 'h')
                        || inner.chars().all(|c| c == 'm')
                        || inner.chars().all(|c| c == 's'))
                {
                    elapsed = true;
                    runs.push(inner.chars().next().unwrap_or('h'));
                }
                i += 1;
                continue;
            }
            _ => {}
        }
        let lower = ch.to_ascii_lowercase();
        if lower == 'a' {
            let rest: String = chars[i..]
                .iter()
                .take(5)
                .collect::<String>()
                .to_ascii_lowercase();
            if rest.starts_with("am/pm") {
                ampm = true;
                i += 5;
                continue;
            }
            if rest.starts_with("a/p") {
                ampm = true;
                i += 3;
                continue;
            }
        }
        if matches!(lower, 'y' | 'd' | 'm' | 'h' | 's') {
            if runs.last() != Some(&lower) || !prev_is(&chars, i, lower) {
                runs.push(lower);
            }
        } else if ch == '0' {
            digits_only.push('0');
        } else if ch == '-' && digits_only.is_empty() {
            // A sign before the digits, as in the negative section -00000.
        } else {
            other = true;
        }
        i += 1;
    }

    let mut has_date = false;
    let mut has_time = ampm;
    for (k, &run) in runs.iter().enumerate() {
        match run {
            'y' | 'd' => has_date = true,
            'h' | 's' => has_time = true,
            'm' => {
                // Minutes follow an hour or come before seconds; any other
                // `m` is a month.
                let after_hour = k > 0 && runs[k - 1] == 'h';
                let before_second = runs.get(k + 1) == Some(&'s');
                if after_hour || before_second || elapsed {
                    has_time = true;
                } else {
                    has_date = true;
                }
            }
            _ => {}
        }
    }
    let kind = if elapsed {
        NumberKind::Duration
    } else if has_date && has_time {
        NumberKind::DateTime
    } else if has_date {
        NumberKind::Date
    } else if has_time {
        NumberKind::Time
    } else {
        NumberKind::Number
    };
    let pad = if kind == NumberKind::Number && !other && runs.is_empty() && digits_only.len() >= 2 {
        digits_only.len().min(30) as u8
    } else {
        0
    };
    Format { kind, pad }
}

fn prev_is(chars: &[char], i: usize, lower: char) -> bool {
    i > 0 && chars[i - 1].to_ascii_lowercase() == lower
}

#[cfg(test)]
mod tests {
    use super::*;

    fn kind(code: &str) -> NumberKind {
        classify(code, None).for_value(1.0).kind
    }

    fn kind_of(code: &str, v: f64) -> NumberKind {
        classify(code, None).for_value(v).kind
    }

    #[test]
    fn the_section_is_picked_by_value() {
        assert_eq!(kind_of("[<1]yyyy-mm-dd;0", 0.5), NumberKind::Date);
        assert_eq!(kind_of("[<1]yyyy-mm-dd;0", 100.0), NumberKind::Number);
        assert_eq!(kind_of("0;yyyy-mm-dd", -3.0), NumberKind::Date);
        assert_eq!(kind_of("0;0;yyyy-mm-dd", 0.0), NumberKind::Date);
        assert_eq!(kind_of("0;0;yyyy-mm-dd", 2.0), NumberKind::Number);
        assert_eq!(kind_of("d-mmm-yy;@", -1.0), NumberKind::Date);
        assert_eq!(classify("00000;-00000", None).for_value(-42.0).pad, 5);
    }

    #[test]
    fn dates_times_and_durations() {
        assert_eq!(kind("yyyy-mm-dd"), NumberKind::Date);
        assert_eq!(kind("mm-dd-yy"), NumberKind::Date);
        assert_eq!(kind("d-mmm"), NumberKind::Date);
        assert_eq!(kind("mmm-yy"), NumberKind::Date);
        assert_eq!(kind("d mmm yyyy"), NumberKind::Date);
        assert_eq!(kind("[$-409]d-mmm-yy;@"), NumberKind::Date);
        assert_eq!(kind("[$-F800]dddd, mmmm dd, yyyy"), NumberKind::Date);
        assert_eq!(kind("DD/MM/YY"), NumberKind::Date);
        assert_eq!(kind("yyyy-mm-dd hh:mm:ss"), NumberKind::DateTime);
        assert_eq!(kind("m/d/yy h:mm"), NumberKind::DateTime);
        assert_eq!(kind("h:mm"), NumberKind::Time);
        assert_eq!(kind("hh:mm:ss"), NumberKind::Time);
        assert_eq!(kind("mm:ss"), NumberKind::Time);
        assert_eq!(kind("h:mm AM/PM"), NumberKind::Time);
        assert_eq!(kind("H:MM:SS;@"), NumberKind::Time);
        assert_eq!(kind("mmss.0"), NumberKind::Time);
        assert_eq!(kind("[h]:mm"), NumberKind::Duration);
        assert_eq!(kind("[h]:mm:ss"), NumberKind::Duration);
        assert_eq!(kind("[mm]:ss"), NumberKind::Duration);
        assert_eq!(kind("[ss]"), NumberKind::Duration);
    }

    #[test]
    fn numbers_that_are_not_dates() {
        for code in [
            "General",
            "0",
            "0.00",
            "#,##0",
            "0.0%",
            "0.00E+00",
            "[Red]0.00",
            "[Blue]#,##0;[Red]-#,##0",
            "\"Day \"0",
            "0\\h",
            "0\\d",
            "_(* #,##0_);_(* (#,##0);_(* \"-\"_);_(@_)",
            "@",
            "[$€-2] #,##0.00",
            "# ?/?",
            "[>=100]0;0.0",
        ] {
            assert_eq!(kind(code), NumberKind::Number, "{code}");
        }
    }

    #[test]
    fn zero_padding() {
        assert_eq!(classify("00000", None).for_value(1.0).pad, 5);
        assert_eq!(classify("000", None).for_value(1.0).pad, 3);
        assert_eq!(classify("0", None).for_value(1.0).pad, 0);
        assert_eq!(classify("0.00", None).for_value(1.0).pad, 0);
        assert_eq!(classify("#,##0", None).for_value(1.0).pad, 0);
        assert_eq!(classify("00000;-00000", None).for_value(1.0).pad, 5);
    }

    #[test]
    fn east_asian_builtins() {
        assert_eq!(
            classify("General", Some(27)).for_value(1.0).kind,
            NumberKind::Date
        );
        assert_eq!(
            classify("General", Some(57)).for_value(1.0).kind,
            NumberKind::Date
        );
        assert_eq!(
            classify("General", Some(0)).for_value(1.0).kind,
            NumberKind::Number
        );
    }
}
