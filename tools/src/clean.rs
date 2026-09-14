//! Transcript normalization — raw Ishtar API HTML → clean text.
//! Ported from scripts/ingest/records.py::clean_transcript.
//! Invariant: paracausal square brackets ([The Queen], O [Reader] Mine)
//! are preserved; only angle-bracket HTML is stripped.

use regex::Regex;
use std::sync::OnceLock;

macro_rules! lazy_re {
    ($name:ident, $pat:expr) => {
        #[allow(non_snake_case)]
        fn $name() -> &'static Regex {
            static R: OnceLock<Regex> = OnceLock::new();
            R.get_or_init(|| Regex::new($pat).unwrap())
        }
    };
}

lazy_re!(RE_BRBR, r"(?i)<\s*br\s*/?>\s*<\s*br\s*/?>");
lazy_re!(RE_BR, r"(?i)<\s*br\s*/?>");
lazy_re!(RE_P, r"(?i)<\s*p[^>]*>");
lazy_re!(RE_PC, r"(?i)<\s*/\s*p\s*>");
lazy_re!(RE_STRONG, r"(?is)<\s*(?:strong|b)\s*>(.*?)</\s*(?:strong|b)\s*>");
lazy_re!(RE_EM, r"(?is)<\s*(?:em|i)\s*>(.*?)</\s*(?:em|i)\s*>");
lazy_re!(RE_A, r#"(?is)<\s*a\s+[^>]*href=["']([^"']*)["'][^>]*>(.*?)</\s*a\s*>"#);
lazy_re!(RE_TAG, r"<[^>]+>");
lazy_re!(RE_NL, r"\n{3,}");
lazy_re!(RE_ENT, r"&(#x?[0-9a-fA-F]+|[a-zA-Z]+);");

/// html.unescape equivalent — numeric refs plus the named entities that
/// actually appear in Ishtar payloads.
fn unescape(text: &str) -> String {
    RE_ENT().replace_all(text, |c: &regex::Captures| {
        let e = &c[1];
        if let Some(hex) = e.strip_prefix("#x").or_else(|| e.strip_prefix("#X")) {
            return u32::from_str_radix(hex, 16).ok()
                .and_then(char::from_u32).map(|c| c.to_string())
                .unwrap_or_else(|| c[0].to_string());
        }
        if let Some(num) = e.strip_prefix('#') {
            return num.parse::<u32>().ok()
                .and_then(char::from_u32).map(|c| c.to_string())
                .unwrap_or_else(|| c[0].to_string());
        }
        match e {
            "amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"",
            "apos" => "'", "nbsp" => " ", "mdash" => "—", "ndash" => "–",
            "hellip" => "…", "lsquo" => "‘", "rsquo" => "’",
            "ldquo" => "“", "rdquo" => "”", "middot" => "·",
            _ => return c[0].to_string(),
        }
        .to_string()
    }).to_string()
}

/// Normalize a raw API transcript into clean text (markdown-ish).
pub fn clean_transcript(raw: &str) -> String {
    if raw.is_empty() {
        return String::new();
    }
    let t = raw.replace("\r\n", "\n").replace('\r', "\n");
    let t = RE_BRBR().replace_all(&t, "\n\n");
    let t = RE_BR().replace_all(&t, "\n");
    let t = RE_P().replace_all(&t, "\n\n");
    let t = RE_PC().replace_all(&t, "\n\n");
    let t = RE_STRONG().replace_all(&t, "**$1**");
    let t = RE_EM().replace_all(&t, "*$1*");
    let t = RE_A().replace_all(&t, "[$2]($1)");
    let t = RE_TAG().replace_all(&t, "");
    let t = unescape(&t);
    let t: String = t.split('\n').map(|l| l.trim_end()).collect::<Vec<_>>().join("\n");
    RE_NL().replace_all(&t, "\n\n").trim().to_string()
}
