//! validate — the corpus validator CLI (port of scripts/validate_corpus.py).
//! Flags: --corpus <path> --categories-dir <path> --strict --verbose/-v
//!        --quiet/-q --json-report <path>

use std::path::PathBuf;
use std::process::ExitCode;

use corpus::checks::{self, Report};

fn usage() -> ! {
    eprintln!("Usage: validate [--corpus PATH] [--categories-dir DIR] [--strict] [--verbose] [--quiet] [--json-report PATH]");
    std::process::exit(2);
}

fn main() -> ExitCode {
    let root = tools::repo_root();
    let mut corpus_p = root.join("data/ahamkara_corpus.jsonl");
    let mut cats = root.join("data/categories");
    let mut strict = false;
    let mut verbose = false;
    let mut quiet = false;
    let mut json_report: Option<PathBuf> = None;

    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--corpus" => { i += 1; corpus_p = PathBuf::from(args.get(i).unwrap_or_else(|| usage())); }
            "--categories-dir" => { i += 1; cats = PathBuf::from(args.get(i).unwrap_or_else(|| usage())); }
            "--strict" => strict = true,
            "--verbose" | "-v" => verbose = true,
            "--quiet" | "-q" => quiet = true,
            "--json-report" => { i += 1; json_report = Some(PathBuf::from(args.get(i).unwrap_or_else(|| usage()))); }
            "--help" | "-h" => usage(),
            _ => usage(),
        }
        i += 1;
    }

    let report: Report = checks::validate(&corpus_p, &cats, strict);

    if !quiet {
        for c in &report.0 {
            if c.ok && !verbose {
                continue;
            }
            let mark = if c.ok { "PASS" } else { "FAIL" };
            let detail = if c.detail.is_empty() { String::new() } else { format!(" — {}", c.detail) };
            println!("[{mark}] {}: {}{detail}", c.id, c.desc);
        }
    }
    println!("{} passed, {} failed ({} checks)", report.passed(), report.failed(), report.0.len());

    let code: u8 = if report.failed() == 0 { 0 } else { 1 };
    if let Some(p) = json_report {
        let failures: Vec<serde_json::Value> = report.0.iter().filter(|c| !c.ok)
            .map(|c| serde_json::json!({"id": c.id, "desc": c.desc, "detail": c.detail}))
            .collect();
        let out = serde_json::json!({
            "exit_code": code,
            "status": if code == 0 { "PASSED" } else { "FAILED" },
            "passed_checks": report.passed(),
            "failed_checks": report.failed(),
            "total_checks": report.0.len(),
            "failures": failures,
        });
        if let Err(e) = std::fs::write(&p, serde_json::to_string_pretty(&out).unwrap()) {
            eprintln!("Failed to write JSON report to {}: {e}", p.display());
        }
    }
    ExitCode::from(code)
}
