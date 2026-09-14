//! ahamkara — the lore query engine CLI (Rust port of the openOODA engine).
//!
//! Flags: --search/-s, --entity/-e, --category/-c, --theme, --chronology,
//!        --quote/-q, --id, --limit, --stats, --interactive/-i,
//!        --help/-h, --version/-v, --corpus <path>

mod filter;
mod print;
mod repl;

use std::path::{Path, PathBuf};
use std::process::ExitCode;

use corpus::{corpus_path, load_records, Record};
use filter::Filter;
use print::{print_card, print_stats};

fn usage() {
    println!("Ahamkara Lore Query Engine");
    println!("Usage: ahamkara [--search <term>] [--entity <name>] [--category <cat>] [--theme <t>] [--chronology <era>] [--quote] [--id <id>] [--limit <n>] [--stats] [--interactive] [--corpus <path>] [--help] [--version]");
}

fn version() -> String {
    for base in [Path::new("."), Path::new(".."), Path::new("../..")] {
        let v = base.join("VERSION");
        if let Ok(s) = std::fs::read_to_string(&v) {
            return s.trim().to_string();
        }
    }
    include_str!("../../VERSION").trim().to_string()
}

fn resolve_corpus() -> PathBuf {
    if let Ok(p) = std::env::var("AHAMKARA_CORPUS") {
        return PathBuf::from(p);
    }
    corpus_path(Path::new("."))
        .or_else(|| corpus_path(Path::new(env!("CARGO_MANIFEST_DIR"))))
        .expect("cannot locate data/ahamkara_corpus.jsonl (set AHAMKARA_CORPUS)")
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut f = Filter::default();
    let mut id = String::new();
    let mut corpus: Option<PathBuf> = None;
    let mut stats = false;
    let mut inter = false;

    let mut i = 0;
    while i < args.len() {
        let take = |i: &mut usize, flag: &str| -> Result<String, i32> {
            if *i + 1 < args.len() {
                *i += 2;
                Ok(args[*i - 1].clone())
            } else {
                println!("Error: missing argument for {flag}");
                usage();
                Err(2)
            }
        };
        match args[i].as_str() {
            "--help" | "-h" | "help" => { usage(); return ExitCode::from(0); }
            "--version" | "-v" | "version" => {
                println!("ahamkara {}", version());
                return ExitCode::from(0);
            }
            "--search" | "-s" | "--keyword" => match take(&mut i, "--search") {
                Ok(v) => f.keyword = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--entity" | "-e" => match take(&mut i, "--entity") {
                Ok(v) => f.entity = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--category" | "-c" => match take(&mut i, "--category") {
                Ok(v) => f.category = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--theme" => match take(&mut i, "--theme") {
                Ok(v) => f.theme = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--chronology" => match take(&mut i, "--chronology") {
                Ok(v) => f.chronology = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--id" => match take(&mut i, "--id") {
                Ok(v) => id = v, Err(c) => return ExitCode::from(c as u8),
            },
            "--corpus" => match take(&mut i, "--corpus") {
                Ok(v) => corpus = Some(PathBuf::from(v)), Err(c) => return ExitCode::from(c as u8),
            },
            "--limit" => match take(&mut i, "--limit") {
                Ok(v) => match v.parse::<usize>() {
                    Ok(n) => f.limit = Some(n),
                    Err(_) => {
                        println!("Error: limit must be a non-negative integer: {v}");
                        return ExitCode::from(2);
                    }
                },
                Err(c) => return ExitCode::from(c as u8),
            },
            "--quote" | "-q" => { f.has_quote = true; i += 1; }
            "--stats" | "stats" => { stats = true; i += 1; }
            "--interactive" | "-i" | "interactive" => { inter = true; i += 1; }
            "query" => i += 1,
            a if a.starts_with('-') => {
                println!("Unrecognized option: {a}");
                usage();
                return ExitCode::from(2);
            }
            a => { if f.keyword.is_empty() { f.keyword = a.to_string(); } i += 1; }
        }
    }

    let path = corpus.unwrap_or_else(resolve_corpus);
    let records: Vec<Record> = load_records(&path);

    if args.is_empty() {
        usage();
        println!("Loaded {} canonical lore entries.", records.len());
        return ExitCode::from(0);
    }
    if stats {
        print_stats(&records);
        return ExitCode::from(0);
    }
    if inter {
        repl::run(&records);
        return ExitCode::from(0);
    }
    if !id.is_empty() {
        let found = records.iter().filter(|r| r.id == id).count();
        println!("Found {found} matching records.\n");
        for r in records.iter().filter(|r| r.id == id) {
            print_card(r);
        }
        return ExitCode::from(0);
    }

    let results = filter::search(&records, &f);
    println!("Found {} matching records.\n", results.len());
    for r in results {
        print_card(r);
    }
    ExitCode::from(0)
}
