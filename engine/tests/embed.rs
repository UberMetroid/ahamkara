//! The binary must carry its own corpus.
//!
//! `data/ahamkara_corpus.jsonl` ships inside the package so an installed
//! `ahamkara-mcp` can find it under `CARGO_MANIFEST_DIR`, and it is also
//! compiled in via `include_str!` as a floor. Two copies of the truth is a
//! drift risk, so this file pins them together.

use std::path::Path;

#[test]
fn the_embedded_corpus_parses_to_the_full_record_set() {
    assert_eq!(
        engine::embedded_corpus_len(),
        84,
        "the embedded corpus should hold all 84 records"
    );
    let records = engine::load();
    assert_eq!(records.len(), 84, "load() must yield every record");
}

#[test]
fn the_embedded_copy_matches_the_shipped_file() {
    // If someone edits data/ahamkara_corpus.jsonl and forgets to rebuild, or
    // packages a crate whose data/ differs from what was compiled, one of
    // these two answers changes and the other does not.
    let shipped = Path::new(env!("CARGO_MANIFEST_DIR")).join("data/ahamkara_corpus.jsonl");
    let on_disk = std::fs::read_to_string(&shipped)
        .unwrap_or_else(|e| panic!("read {}: {e}", shipped.display()));
    let from_disk: Vec<&str> = on_disk.lines().filter(|l| !l.trim().is_empty()).collect();
    assert_eq!(
        from_disk.len(),
        engine::embedded_corpus_len(),
        "shipped file and embedded copy have different record counts — rebuild required"
    );
    for line in from_disk {
        assert!(
            engine::embedded_corpus_text().contains(line.trim()),
            "a record in the shipped file is missing from the embedded copy: {}",
            &line[..line.len().min(80)]
        );
    }
}