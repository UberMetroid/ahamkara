//! Corpus model and loading — mirrors data/ahamkara_corpus.jsonl (canonical).

use serde::Deserialize;
use std::fs;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct Source {
    #[serde(rename = "type")]
    pub kind: String,
    #[allow(dead_code)]
    pub game: String,
    #[allow(dead_code)]
    pub book: Option<String>,
    #[allow(dead_code)]
    pub release: Option<String>,
    #[allow(dead_code)]
    pub bungie_ref: Option<u64>,
    pub ishtar_url: Option<String>,
}

#[derive(Debug, Deserialize)]
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

/// Load the canonical corpus: one JSON record per line (JSONL).
pub fn load_records(root: &Path) -> Vec<Record> {
    let corpus_path = root.join("data/ahamkara_corpus.jsonl");
    let raw = fs::read_to_string(&corpus_path)
        .unwrap_or_else(|e| panic!("cannot read {}: {e}", corpus_path.display()));
    raw.lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).unwrap_or_else(|e| panic!("corpus line parse failed: {e}")))
        .collect()
}

pub fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

/// Render a transcript as paragraphs (blank-line separated, like the corpus).
pub fn paragraphs(transcript: &str) -> String {
    transcript
        .split("\n\n")
        .map(|p| {
            let inner = esc(p).replace('\n', "<br>");
            format!("<p>{inner}</p>")
        })
        .collect::<Vec<_>>()
        .join("\n")
}
