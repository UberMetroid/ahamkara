//! Ingest catalog — the canonical record specification (data/catalog.jsonl).
//! Each spec pins a record's identity plus the Ishtar API path to hydrate.

use corpus::{Record, Source};
use serde::Deserialize;
use serde_json::Value;
use std::fs;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct Spec {
    pub id: String,
    pub api_path: String,
    pub doc_type: String,
    pub title: String,
    pub source: Source,
    pub entity: Vec<String>,
    pub speaker: Option<String>,
    pub tags: Vec<String>,
    pub chronology: String,
    pub theme: String,
}

pub fn load_catalog(path: &Path) -> Vec<Spec> {
    let raw = fs::read_to_string(path)
        .unwrap_or_else(|e| panic!("cannot read catalog {}: {e}", path.display()));
    raw.lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).unwrap_or_else(|e| panic!("catalog line: {e}")))
        .collect()
}

/// Merge a spec and its raw API payload into the normalized 9-field record.
pub fn build_record(spec: &Spec, raw: &Value) -> Record {
    let d = &raw["data"];
    let pick = |k: &str| d[k].as_str().map(str::trim).filter(|s| !s.is_empty());

    let raw_text = if spec.doc_type == "item" {
        let mut parts: Vec<String> = Vec::new();
        if let Some(f) = pick("flavor_text") {
            parts.push(format!("\"{f}\""));
        }
        let alt = pick("short_summary").or_else(|| pick("description"));
        if let Some(a) = alt {
            if Some(a) != pick("flavor_text") {
                parts.push(a.to_string());
            }
        }
        if parts.is_empty() {
            pick("description").or_else(|| pick("short_summary")).or_else(|| pick("flavor_text"))
                .unwrap_or("").to_string()
        } else {
            parts.join("\n\n")
        }
    } else {
        pick("description").or_else(|| pick("short_summary")).or_else(|| pick("flavor_text"))
            .unwrap_or("").to_string()
    };

    let transcript = crate::clean::clean_transcript(&raw_text);
    let transcript = if transcript.is_empty() {
        format!("Canonical record: {}", spec.title)
    } else {
        transcript
    };

    let mut source = Source {
        kind: spec.source.kind.clone(),
        game: spec.source.game.clone(),
        book: spec.source.book.clone(),
        release: spec.source.release.clone(),
        bungie_ref: spec.source.bungie_ref,
        ishtar_url: spec.source.ishtar_url.clone(),
    };
    if source.bungie_ref.is_none() {
        source.bungie_ref = d["bungie_ref"].as_u64();
    }

    Record {
        id: spec.id.clone(),
        title: spec.title.clone(),
        source,
        entity: spec.entity.clone(),
        speaker: spec.speaker.clone(),
        transcript,
        tags: spec.tags.clone(),
        chronology: spec.chronology.clone(),
        theme: spec.theme.clone(),
    }
}
