//! ingest — the lore pipeline: catalog → (cache | Ishtar API) → normalize →
//! corpus.jsonl + category partitions + raw cache shards.
//! Port of scripts/ingest_lore.py.
//!
//! Flags: --fetch-live  --offline  --cache-dir DIR  --output-dir DIR
//!        --rate-limit SECS  --verify

use std::path::PathBuf;
use std::process::ExitCode;

fn usage() -> ! {
    eprintln!("Usage: ingest [--fetch-live] [--offline] [--cache-dir DIR] [--output-dir DIR] [--rate-limit SECS] [--verify]");
    std::process::exit(2);
}

fn main() -> ExitCode {
    let root = tools::repo_root();
    let mut fetch_live = false;
    let mut offline = false;
    let mut cache_dir = root.join("data/cache/raw");
    let mut out_dir = root.join("data");
    let mut rate_limit = 0.1f64;
    let mut verify = false;

    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--fetch-live" => fetch_live = true,
            "--offline" => offline = true,
            "--verify" => verify = true,
            "--cache-dir" => { i += 1; cache_dir = PathBuf::from(args.get(i).unwrap_or_else(|| usage())); }
            "--output-dir" => { i += 1; out_dir = PathBuf::from(args.get(i).unwrap_or_else(|| usage())); }
            "--rate-limit" => {
                i += 1;
                rate_limit = args.get(i).and_then(|s| s.parse().ok()).unwrap_or_else(|| usage());
            }
            _ => usage(),
        }
        i += 1;
    }

    let catalog = tools::catalog::load_catalog(&root.join("data/catalog.jsonl"));
    let mut raw = tools::cache::load_cache(&cache_dir);
    let mut updated = false;

    if fetch_live || (!offline && raw.len() < catalog.len()) {
        println!("[INGEST] Fetching records from Ishtar API ({} items)...", catalog.len());
        let mut client = tools::ishtar::Ishtar::new(rate_limit);
        for spec in &catalog {
            if !fetch_live && raw.contains_key(&spec.id) {
                continue;
            }
            match client.fetch(&spec.api_path) {
                Some(res) if res.get(&spec.doc_type).is_some() => {
                    raw.insert(spec.id.clone(), serde_json::json!({
                        "id": spec.id,
                        "api_path": spec.api_path,
                        "doc_type": spec.doc_type,
                        "data": res[&spec.doc_type],
                    }));
                    updated = true;
                    println!("  + Fetched: {}", spec.id);
                }
                _ => println!("  ! Fallback for: {}", spec.id),
            }
        }
        if updated {
            tools::cache::save_cache(&cache_dir, &raw);
        }
    }

    let mut records = Vec::new();
    let mut missing = Vec::new();
    for spec in &catalog {
        match raw.get(&spec.id) {
            Some(payload) => records.push(tools::catalog::build_record(spec, payload)),
            None => missing.push(spec.id.clone()),
        }
    }
    if !missing.is_empty() {
        println!("[WARN] {} records missing from cache/fetch: {missing:?}", missing.len());
    }
    println!("[TRANSFORM] Processed {} normalized records.", records.len());

    let (jsonl, cats) = tools::serialize::write_corpus(&records, &out_dir);
    println!("[EXPORT] Created:\n  - {}\n  - {}", jsonl.display(), cats.display());

    // Always verify — the schema is the contract.
    let _ = verify;
    let report = corpus::checks::validate(&jsonl, &cats, false);
    if report.failed() > 0 {
        for c in report.0.iter().filter(|c| !c.ok).take(10) {
            eprintln!("  FAIL {}: {} — {}", c.id, c.desc, c.detail);
        }
        eprintln!("[ERROR] Validation failed: {} issues", report.failed());
        return ExitCode::from(1);
    }
    println!("[DONE] Lore ingestion pipeline finished — {} records, {} checks passed.",
        records.len(), report.passed());
    ExitCode::from(0)
}
