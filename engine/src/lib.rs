//! Ahamkara lore query engine — library surface.
//!
//! The CLI in `src/main.rs` and the MCP server in `src/bin/ahamkara-mcp.rs`
//! are both thin shells over this. Exposed so an agent process can query the
//! canonical corpus directly rather than shelling out to the CLI.

pub mod filter;
pub mod memory;
pub mod tools;
pub mod print;
pub mod repl;

pub use corpus::{Record, corpus_path, load_records, parse_jsonl};
pub use filter::{Filter, matches, search};
pub use memory::Wish;

use std::path::{Path, PathBuf};

/// Locate `data/ahamkara_corpus.jsonl`, honouring `AHAMKARA_CORPUS` first.
pub fn resolve_corpus() -> PathBuf {
    if let Ok(p) = std::env::var("AHAMKARA_CORPUS") {
        return PathBuf::from(p);
    }
    corpus_path(Path::new("."))
        .or_else(|| corpus_path(Path::new(env!("CARGO_MANIFEST_DIR"))))
        .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("data/ahamkara_corpus.jsonl"))
}

/// The corpus compiled into the binary.
///
/// `data/ahamkara_corpus.jsonl` now ships inside the package, and
/// `CARGO_MANIFEST_DIR` points into the extracted crate for anyone who
/// installs from crates.io — so file resolution should work. Embedding as
/// well means it *cannot* fail: an agent server that silently answers "no
/// records matched" because it could not find its own corpus is worse than
/// one carrying a slightly larger binary. 152K.
const EMBEDDED_CORPUS: &str = include_str!("../data/ahamkara_corpus.jsonl");

/// Resolve, then load. A file wins so a user can extend or override the
/// corpus; the embedded copy is the floor.
pub fn load() -> Vec<Record> {
    let path = resolve_corpus();
    if path.is_file() {
        let records = load_records(&path);
        if !records.is_empty() {
            return records;
        }
    }
    match parse_jsonl(EMBEDDED_CORPUS) {
        Ok(records) if !records.is_empty() => records,
        _ => {
            eprintln!(
                "ahamkara-mcp: no records loaded from {} and the embedded corpus did not parse",
                path.display()
            );
            Vec::new()
        }
    }
}

/// True when the binary carries its own corpus. Asserted by tests so the
/// embed and the shipped file cannot drift apart unnoticed.
pub fn embedded_corpus_len() -> usize {
    EMBEDDED_CORPUS.lines().filter(|l| !l.trim().is_empty()).count()
}

/// The embedded corpus verbatim, for tests that pin it to the shipped file.
pub fn embedded_corpus_text() -> &'static str {
    EMBEDDED_CORPUS
}