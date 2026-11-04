//! What a number format shows: a date, a date-time, a time of day, a
//! duration, or a plain number (with the width of a zero-padded code).
//!
//! Excel shows a number as a date because of its number format, so xlkit
//! decides the column type from the format, never from the value.
//! Only the first section of a format is read: it is the one Excel uses
//! for positive numbers, which dates always are.
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

/// Classify a number format by its code, falling back on the built-in id
/// for the locale-dependent East Asian date formats, whose code the file
/// does not carry.
pub fn classify(code: &str, id: Option<u32>) -> Format {
    if code.is_empty() || code.eq_ignore_ascii_case("general") {
        return match id {
            Some(27..=36) | Some(50..=58) => Format {
                kind: NumberKind::Date,
                pad: 0,
            },
            _ => PLAIN,
        };
    }
    classify_section(first_section(code))
}

/// The text of `code` up to its first `;` that is not quoted, escaped,
/// padding or inside brackets.
fn first_section(code: &str) -> &str {
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
                b';' if bracket == 0 => return &code[..i],
                _ => {}
            }
        }
        i += 1;
    }
    code
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
        classify(code, None).kind
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
        assert_eq!(classify("00000", None).pad, 5);
        assert_eq!(classify("000", None).pad, 3);
        assert_eq!(classify("0", None).pad, 0);
        assert_eq!(classify("0.00", None).pad, 0);
        assert_eq!(classify("#,##0", None).pad, 0);
        assert_eq!(classify("00000;-00000", None).pad, 5);
    }

    #[test]
    fn east_asian_builtins() {
        assert_eq!(classify("General", Some(27)).kind, NumberKind::Date);
        assert_eq!(classify("General", Some(57)).kind, NumberKind::Date);
        assert_eq!(classify("General", Some(0)).kind, NumberKind::Number);
    }
}
