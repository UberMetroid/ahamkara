//! Site-side corpus helpers — the canonical model and loader live in the
//! shared `corpus` crate; this module keeps HTML-oriented utilities.

pub use corpus::{corpus_path, load_records, Record};

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
