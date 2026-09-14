//! Corpus validation checks — ported from scripts/validate (48 checks).
//! Checks run on untyped JSON values so malformed records are reported
//! as failures instead of aborting the run.

mod content;
mod schema;

use serde_json::Value;
use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

pub struct Check {
    pub id: String,
    pub desc: String,
    pub ok: bool,
    pub detail: String,
}

pub struct Report(pub Vec<Check>);

impl Report {
    pub(crate) fn pass(&mut self, id: &str, desc: &str, detail: impl Into<String>) {
        self.0.push(Check { id: id.into(), desc: desc.into(), ok: true, detail: detail.into() });
    }
    pub(crate) fn fail(&mut self, id: &str, desc: &str, detail: impl Into<String>) {
        self.0.push(Check { id: id.into(), desc: desc.into(), ok: false, detail: detail.into() });
    }
    pub(crate) fn verdict(&mut self, id: &str, desc: &str, ok: bool, detail: impl Into<String>) {
        if ok { self.pass(id, desc, detail) } else { self.fail(id, desc, detail) }
    }
    pub fn passed(&self) -> usize { self.0.iter().filter(|c| c.ok).count() }
    pub fn failed(&self) -> usize { self.0.len() - self.passed() }
}

pub(crate) fn s(v: &Value) -> &str { v.as_str().unwrap_or("") }

pub(crate) fn kebab(id: &str) -> bool {
    !id.is_empty()
        && id.split('-').all(|p| {
            !p.is_empty() && p.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit())
        })
}

pub(crate) fn has_html(text: &str) -> bool {
    let t = text.to_lowercase();
    ["<p", "<br", "<div", "<span", "<h1", "<h2", "<h3", "<h4", "<h5", "<h6",
     "<table", "<tr", "<td", "<a ", "<strong", "<em"]
        .iter().any(|tag| t.contains(tag))
}

/// Full validation run: file existence → JSONL syntax → counts → uniqueness →
/// schema → canonical checklist → e2e invariants → category partitions.
pub fn validate(corpus_path: &Path, categories_dir: &Path, strict: bool) -> Report {
    let mut r = Report(Vec::new());
    if !file_checks(&mut r, corpus_path, categories_dir) {
        return r;
    }
    let Some((text, lines)) = jsonl_checks(&mut r, corpus_path) else { return r };
    let records: Vec<Value> = crate::parse_jsonl_values(&text)
        .into_iter().filter_map(Result::ok).collect();
    count_checks(&mut r, &records, lines);
    uniqueness(&mut r, &records);
    schema::run(&mut r, &records);
    content::checklist(&mut r, &records, strict);
    content::e2e_invariants(&mut r, &records);
    content::partitions(&mut r, categories_dir, &records);
    r
}

fn file_checks(r: &mut Report, corpus: &Path, cats: &Path) -> bool {
    let ok1 = corpus.is_file() && fs::metadata(corpus).map(|m| m.len() > 0).unwrap_or(false);
    r.verdict("VAL-FILE-01", "Canonical JSONL corpus exists and non-empty", ok1,
        corpus.display().to_string());
    let ok2 = cats.is_dir();
    r.verdict("VAL-FILE-02", "Categories partition directory exists", ok2,
        cats.display().to_string());
    ok1 && ok2
}

fn jsonl_checks(r: &mut Report, path: &Path) -> Option<(String, usize)> {
    let raw = match fs::read(path) {
        Ok(b) => b,
        Err(e) => { r.fail("VAL-JSONL-00", "Read and parse JSONL file", e.to_string()); return None; }
    };
    r.verdict("VAL-JSONL-01", "JSONL ends with standard LF byte (0x0a)", raw.ends_with(b"\n"), "");
    let cr = raw.iter().filter(|&&b| b == b'\r').count();
    r.verdict("VAL-JSONL-02", "JSONL contains zero Windows CRLF carriage returns", cr == 0,
        if cr > 0 { format!("{cr} CR bytes") } else { String::new() });
    let text = String::from_utf8_lossy(&raw).to_string();
    let lines: Vec<&str> = text.lines().collect();
    let blanks = lines.iter().filter(|l| l.trim().is_empty()).count();
    r.verdict("VAL-JSONL-03", "No blank lines in JSONL archive", blanks == 0,
        format!("{blanks} blank lines"));
    let parsed = crate::parse_jsonl_values(&text);
    let bad = parsed.iter().filter(|p| p.is_err()).count();
    r.verdict("VAL-JSONL-04", "Every JSONL line parses into a valid JSON object", bad == 0,
        format!("{} lines, {bad} malformed", lines.len()));
    let oob = lines.iter().filter(|l| !(100..=102400).contains(&l.len())).count();
    r.verdict("VAL-JSONL-05", "All JSONL lines satisfy length boundaries", oob == 0,
        format!("{oob} out of bounds"));
    let eq = lines.iter().filter(|l| l.contains("\\\"")).count();
    r.verdict("VAL-JSONL-06", "JSONL archive contains escaped quotes", eq > 0, format!("{eq} lines"));
    let en = lines.iter().filter(|l| l.contains("\\n")).count();
    r.verdict("VAL-JSONL-07", "JSONL archive contains escaped newlines", en > 0, format!("{en} lines"));
    let n = lines.len();
    Some((text, n))
}

fn count_checks(r: &mut Report, recs: &[Value], lines: usize) {
    r.verdict("VAL-CNT-01", "Corpus contains minimum 65 canonical entries", recs.len() >= 65,
        format!("Count: {}", recs.len()));
    r.verdict("VAL-CNT-02", "Every JSONL line produced exactly one record",
        recs.len() == lines && !recs.is_empty(),
        format!("{} records, {lines} lines", recs.len()));
}

fn uniqueness(r: &mut Report, recs: &[Value]) {
    let mut seen = BTreeSet::new();
    let mut dup = BTreeSet::new();
    for v in recs {
        if let Some(id) = v.get("id").and_then(Value::as_str) {
            if !seen.insert(id.to_string()) { dup.insert(id.to_string()); }
        }
    }
    r.verdict("VAL-UNIQ-01", "All record IDs are strictly unique", dup.is_empty(),
        format!("{} unique IDs; dupes: {dup:?}", seen.len()));
}
