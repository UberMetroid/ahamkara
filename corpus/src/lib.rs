//! Shared Ahamkara corpus model and loader — the canonical schema is
//! data/ahamkara_corpus.jsonl (one JSON record per line).

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

pub mod checks;
pub mod constants;

#[derive(Debug, Deserialize, Serialize)]
pub struct Source {
    #[serde(rename = "type")]
    pub kind: String,
    pub game: String,
    pub book: Option<String>,
    pub release: Option<String>,
    pub bungie_ref: Option<u64>,
    pub ishtar_url: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Record {
    pub id: String,
    pub title: String,
    pub source: Source,
    pub entity: Vec<String>,
    pub speaker: Option<String>,
    pub transcript: String,
    pub tags: Vec<String>,
    pub chronology: String,
    pub theme: String,
}

impl Record {
    /// A record "has a whisper" when its transcript carries quotation marks —
    /// the corpus renders speech in curly or straight quotes.
    pub fn has_quote(&self) -> bool {
        self.transcript.contains(['"', '\u{201C}', '\u{201D}', '\u{00AB}'])
    }
}

/// Locate the canonical corpus relative to a starting directory.
/// Checks `dir/data/ahamkara_corpus.jsonl`, then the parent, then CWD.
pub fn corpus_path(dir: &Path) -> Option<std::path::PathBuf> {
    for base in [dir.to_path_buf(), dir.join(".."), Path::new(".").to_path_buf()] {
        let p = base.join("data/ahamkara_corpus.jsonl");
        if p.is_file() {
            return Some(p);
        }
    }
    None
}

/// Load the canonical corpus: one JSON record per line (JSONL).
pub fn load_records(path: &Path) -> Vec<Record> {
    let raw = fs::read_to_string(path)
        .unwrap_or_else(|e| panic!("cannot read {}: {e}", path.display()));
    parse_jsonl(&raw)
        .unwrap_or_else(|e| panic!("corpus parse failed in {}: {e}", path.display()))
}

/// Parse JSONL text into typed records (each non-blank line is one record).
pub fn parse_jsonl(raw: &str) -> Result<Vec<Record>, String> {
    raw.lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).map_err(|e| e.to_string()))
        .collect()
}

/// Parse JSONL text into untyped values — the validator needs to see
/// malformed shapes (missing keys, wrong types) rather than fail fast.
pub fn parse_jsonl_values(raw: &str) -> Vec<Result<serde_json::Value, String>> {
    raw.lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).map_err(|e| e.to_string()))
        .collect()
}
