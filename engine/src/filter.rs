//! Multi-attribute query filter over canonical records.
//! Ported from src/engine/search.oo onto the JSONL schema:
//!   keyword    → title, transcript, speaker, entity, tags
//!   entity     → any entity element or tag
//!   category   → source.type (space/underscore normalized) or tags
//!   theme      → theme field
//!   chronology → chronology field
//!   has_quote  → transcript carries quotation marks
//!   limit      → result cap

use corpus::Record;

#[derive(Default)]
pub struct Filter {
    pub keyword: String,
    pub entity: String,
    pub category: String,
    pub theme: String,
    pub chronology: String,
    pub has_quote: bool,
    pub limit: Option<usize>,
}

fn ic(hay: &str, needle: &str) -> bool {
    let n = needle.trim();
    n.is_empty() || hay.to_lowercase().contains(&n.to_lowercase())
}

fn ic_any<'a>(mut hay: impl Iterator<Item = &'a str>, needle: &str) -> bool {
    hay.any(|h| ic(h, needle))
}

pub fn matches(r: &Record, f: &Filter) -> bool {
    if !f.entity.trim().is_empty() {
        let hit = ic_any(r.entity.iter().map(String::as_str), &f.entity)
            || ic_any(r.tags.iter().map(String::as_str), &f.entity);
        if !hit {
            return false;
        }
    }
    if !f.category.trim().is_empty() {
        let norm = f.category.trim().to_lowercase().replace(' ', "_");
        let hit = ic(&r.source.kind, &f.category)
            || ic(&r.source.kind, &norm)
            || ic_any(r.tags.iter().map(String::as_str), &f.category)
            || ic_any(r.tags.iter().map(String::as_str), &norm);
        if !hit {
            return false;
        }
    }
    if f.has_quote && !r.has_quote() {
        return false;
    }
    if !f.theme.trim().is_empty() && !ic(&r.theme, &f.theme) {
        return false;
    }
    if !f.chronology.trim().is_empty() && !ic(&r.chronology, &f.chronology) {
        return false;
    }
    // Keyword search covers the record's own text fields. Theme, era and
    // entity have dedicated filters — folding them in here flooded results
    // (e.g. "extinction" matching a theme name on 24 records).
    if !f.keyword.trim().is_empty() {
        let hit = ic(&r.title, &f.keyword)
            || ic(&r.transcript, &f.keyword)
            || ic(r.speaker.as_deref().unwrap_or(""), &f.keyword)
            || ic_any(r.entity.iter().map(String::as_str), &f.keyword)
            || ic_any(r.tags.iter().map(String::as_str), &f.keyword);
        if !hit {
            return false;
        }
    }
    true
}

pub fn search<'a>(records: &'a [Record], f: &Filter) -> Vec<&'a Record> {
    if f.limit == Some(0) {
        return Vec::new();
    }
    let mut out = Vec::new();
    for r in records {
        if matches(r, f) {
            out.push(r);
            if let Some(l) = f.limit {
                if out.len() >= l {
                    return out;
                }
            }
        }
    }
    out
}
