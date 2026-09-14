//! 9-field schema checks — VAL-SCH-01..11.

use serde_json::Value;
use std::collections::BTreeSet;

use super::{has_html, kebab, s, Report};
use crate::constants::*;

/// Detailed schema validation over untyped records.
pub fn run(r: &mut Report, recs: &[Value]) {
    let mut bad_id = Vec::new();
    let mut bad_title = Vec::new();
    let mut bad_source = Vec::new();
    let mut bad_entity = Vec::new();
    let mut bad_speaker = Vec::new();
    let mut bad_transcript = Vec::new();
    let mut bad_tags = Vec::new();
    let mut bad_chron = Vec::new();
    let mut bad_theme = Vec::new();
    let mut html_leak = Vec::new();
    let mut releases = BTreeSet::new();

    for rec in recs {
        let rid = s(&rec["id"]).to_string();
        if !kebab(&rid) {
            bad_id.push(rid.clone());
        }
        if rec["title"].as_str().map(|t| t.trim().is_empty()).unwrap_or(true) {
            bad_title.push(rid.clone());
        }
        source(r, rec, &rid, &mut bad_source, &mut releases);
        entity(r, rec, &rid, &mut bad_entity);
        speaker(r, rec, &rid, &mut bad_speaker);
        match rec["transcript"].as_str() {
            Some(t) if !t.trim().is_empty() => {
                if has_html(t) {
                    html_leak.push(rid.clone());
                }
            }
            _ => bad_transcript.push(rid.clone()),
        }
        tags(r, rec, &rid, &mut bad_tags);
        let chron = s(&rec["chronology"]);
        if !VALID_CHRONOLOGIES.contains(&chron) {
            bad_chron.push(format!("{rid}: '{chron}'"));
        }
        let theme = s(&rec["theme"]);
        if !VALID_THEMES.contains(&theme) {
            bad_theme.push(format!("{rid}: '{theme}'"));
        }
    }

    r.verdict("VAL-SCH-01", "Every record contains valid kebab-case 'id'",
        bad_id.is_empty(), format!("{} invalid: {:?}", bad_id.len(), &bad_id[..bad_id.len().min(3)]));
    r.verdict("VAL-SCH-02", "Every record contains non-empty 'title'",
        bad_title.is_empty(), format!("{} missing", bad_title.len()));
    r.verdict("VAL-SCH-03", "Every record contains valid 'source' object",
        bad_source.is_empty(), format!("{} errors: {:?}", bad_source.len(), &bad_source[..bad_source.len().min(3)]));
    r.verdict("VAL-SCH-04", "Source releases span >= 4 distinct Destiny releases",
        releases.len() >= 4, format!("{} found", releases.len()));
    r.verdict("VAL-SCH-05", "Every record contains valid non-empty 'entity' list",
        bad_entity.is_empty(), format!("{} errors: {:?}", bad_entity.len(), &bad_entity[..bad_entity.len().min(3)]));
    r.verdict("VAL-SCH-06", "Speaker field is either string or null (never '')",
        bad_speaker.is_empty(), format!("{} errors: {:?}", bad_speaker.len(), &bad_speaker[..bad_speaker.len().min(3)]));
    r.verdict("VAL-SCH-07", "Every record contains non-empty 'transcript' text",
        bad_transcript.is_empty(), format!("{} blank", bad_transcript.len()));
    r.verdict("VAL-SCH-08", "All transcripts sanitized of raw unrendered HTML tags",
        html_leak.is_empty(), format!("{} contain raw HTML: {:?}", html_leak.len(), &html_leak[..html_leak.len().min(3)]));
    r.verdict("VAL-SCH-09", "Every record contains non-empty 'tags' list",
        bad_tags.is_empty(), format!("{} errors: {:?}", bad_tags.len(), &bad_tags[..bad_tags.len().min(3)]));
    r.verdict("VAL-SCH-10", "Every record contains valid 'chronology' enum",
        bad_chron.is_empty(), format!("{} errors: {:?}", bad_chron.len(), &bad_chron[..bad_chron.len().min(3)]));
    r.verdict("VAL-SCH-11", "Every record contains valid 'theme' enum",
        bad_theme.is_empty(), format!("{} errors: {:?}", bad_theme.len(), &bad_theme[..bad_theme.len().min(3)]));
}

fn source(r: &mut Report, rec: &Value, rid: &str, bad: &mut Vec<String>, rel: &mut BTreeSet<String>) {
    let _ = r;
    let Some(src) = rec["source"].as_object() else {
        bad.push(format!("{rid}: source is not an object"));
        return;
    };
    let stype = src.get("type").and_then(Value::as_str).unwrap_or("");
    if !VALID_SOURCE_TYPES.contains(&stype) {
        bad.push(format!("{rid}: invalid source.type '{stype}'"));
    }
    let game = src.get("game").and_then(Value::as_str).unwrap_or("");
    if !VALID_GAMES.contains(&game) {
        bad.push(format!("{rid}: invalid source.game '{game}'"));
    }
    match src.get("release").and_then(Value::as_str) {
        Some(v) if !v.trim().is_empty() => { rel.insert(v.trim().to_string()); }
        other => bad.push(format!("{rid}: missing/blank source.release {other:?}")),
    }
    match src.get("ishtar_url").and_then(Value::as_str) {
        Some(u) if u.starts_with("http://") || u.starts_with("https://") => {}
        _ => bad.push(format!("{rid}: invalid source.ishtar_url")),
    }
    if !src.contains_key("bungie_ref") {
        bad.push(format!("{rid}: missing bungie_ref key"));
    }
}

fn entity(_r: &mut Report, rec: &Value, rid: &str, bad: &mut Vec<String>) {
    match rec["entity"].as_array() {
        Some(list) if !list.is_empty() => {
            for e in list {
                if let Some(name) = e.as_str() {
                    if !VALID_ENTITIES.contains(&name) {
                        bad.push(format!("{rid}: unknown entity '{name}'"));
                    }
                } else {
                    bad.push(format!("{rid}: entity entry not a string"));
                }
            }
        }
        _ => bad.push(format!("{rid}: entity is not a non-empty list")),
    }
}

fn speaker(_r: &mut Report, rec: &Value, rid: &str, bad: &mut Vec<String>) {
    if !rec.as_object().map(|o| o.contains_key("speaker")).unwrap_or(false) {
        bad.push(format!("{rid}: speaker key missing"));
        return;
    }
    match &rec["speaker"] {
        Value::String(v) if v.is_empty() => bad.push(format!("{rid}: speaker is empty string")),
        Value::String(_) | Value::Null => {}
        other => bad.push(format!("{rid}: speaker invalid type {other:?}")),
    }
}

fn tags(_r: &mut Report, rec: &Value, rid: &str, bad: &mut Vec<String>) {
    match rec["tags"].as_array() {
        Some(list) if !list.is_empty() => {
            for t in list {
                if t.as_str().map(|x| x.trim().is_empty()).unwrap_or(true) {
                    bad.push(format!("{rid}: blank/non-string tag"));
                }
            }
        }
        _ => bad.push(format!("{rid}: tags is not a non-empty list")),
    }
}
