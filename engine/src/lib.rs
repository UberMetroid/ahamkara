//! Ahamkara lore query engine — library surface.
//!
//! The CLI in `src/main.rs` and the MCP server in `src/bin/ahamkara-mcp.rs`
//! are both thin shells over this. Exposed so an agent process can query the
//! canonical corpus directly rather than shelling out to the CLI.

pub mod filter;
pub mod print;
pub mod repl;

pub use corpus::{Record, corpus_path, load_records};
pub use filter::{Filter, matches, search};

use std::path::{Path, PathBuf};

/// Locate `data/ahamkara_corpus.jsonl`, honouring `AHAMKARA_CORPUS` first.
pub fn resolve_corpus() -> PathBuf {
    if let Ok(p) = std::env::var("AHAMKARA_CORPUS") {
        return PathBuf::from(p);
    }
    corpus_path(Path::new("."))
        .or_else(|| corpus_path(Path::new(env!("CARGO_MANIFEST_DIR"))))
        .unwrap_or_else(|| PathBuf::from("data/ahamkara_corpus.jsonl"))
}

/// Resolve, then load. Panics only if the corpus is missing entirely — the
/// server cannot serve tools without it, so failing loudly at startup beats
/// returning empty results to an agent.
pub fn load() -> Vec<Record> {
    let path = resolve_corpus();
    let records = load_records(&path);
    if records.is_empty() {
        eprintln!("ahamkara-mcp: no records loaded from {}", path.display());
    }
    records
}