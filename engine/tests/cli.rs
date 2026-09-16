//! CLI e2e — replaces the shell tiers' behavioral assertions.
//! Spawns the real `ahamkara` binary against the canonical corpus.

use std::process::Command;

fn run(args: &[&str]) -> (bool, String) {
    let out = Command::new(env!("CARGO_BIN_EXE_ahamkara"))
        .args(args)
        .output()
        .expect("spawn ahamkara");
    (out.status.success(), String::from_utf8_lossy(&out.stdout).to_string())
}

#[test]
fn version_is_semver() {
    let (ok, out) = run(&["--version"]);
    assert!(ok);
    let v = out.trim().trim_start_matches("ahamkara ");
    assert!(v.split('.').count() == 3 && v.chars().all(|c| c.is_ascii_digit() || c == '.'));
}

#[test]
fn version_ignores_foreign_version_file() {
    let tmp = std::env::temp_dir().join(format!("ahamkara_test_{}", std::process::id()));
    std::fs::create_dir_all(&tmp).expect("create temp dir");
    std::fs::write(tmp.join("VERSION"), "99.99.99\n").expect("write foreign VERSION");
    let out = Command::new(env!("CARGO_BIN_EXE_ahamkara"))
        .args(["--version"])
        .current_dir(&tmp)
        .output()
        .expect("spawn ahamkara");
    let _ = std::fs::remove_dir_all(&tmp);
    assert!(out.status.success());
    let s = String::from_utf8_lossy(&out.stdout);
    assert!(!s.contains("99.99.99"), "ahamkara --version must not read local ./VERSION file");
    let want = std::fs::read_to_string(
        std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../VERSION"),
    )
    .expect("read repo VERSION");
    assert_eq!(s.trim(), format!("ahamkara {}", want.trim()));
}

#[test]
fn help_shows_usage() {
    let (ok, out) = run(&["--help"]);
    assert!(ok && out.contains("Usage:"));
}

#[test]
fn stats_counts_corpus() {
    let (ok, out) = run(&["--stats"]);
    assert!(ok && out.contains("Total records: 84"));
    assert!(out.contains("--- Records by Entity ---"));
}

#[test]
fn entity_riven_finds_43() {
    let (ok, out) = run(&["--entity", "Riven"]);
    assert!(ok && out.contains("Found 43 matching records"));
}

#[test]
fn search_reader_mine_finds_1() {
    let (ok, out) = run(&["--search", "O [Reader] Mine"]);
    assert!(ok && out.contains("Found 1 matching records"));
}

#[test]
fn search_extinction_finds_9() {
    let (ok, out) = run(&["--search", "extinction"]);
    assert!(ok && out.contains("Found 9 matching records"));
}

#[test]
fn id_lookup_exact() {
    let (ok, out) = run(&["--id", "exotic-bones-of-eao"]);
    assert!(ok && out.contains("Found 1 matching records") && out.contains("Bones of Eao"));
}

#[test]
fn id_lookup_miss() {
    let (ok, out) = run(&["--id", "no-such-record"]);
    assert!(ok && out.contains("Found 0 matching records"));
}

#[test]
fn limit_caps_results() {
    let (ok, out) = run(&["--entity", "Riven", "--limit", "5"]);
    assert!(ok && out.contains("Found 5 matching records"));
}

#[test]
fn limit_zero_returns_none() {
    let (ok, out) = run(&["--limit", "0"]);
    assert!(ok && out.contains("Found 0 matching records"));
}

#[test]
fn quote_filter_only_quoted() {
    let (ok, out) = run(&["--quote", "--limit", "1"]);
    assert!(ok && out.contains("Found 1 matching records"));
}

#[test]
fn category_wall_of_wishes() {
    let (ok, out) = run(&["--category", "wall of wishes"]);
    assert!(ok && out.contains("Found 15 matching records"));
}

#[test]
fn bare_term_is_keyword() {
    let (ok, out) = run(&["extinction"]);
    assert!(ok && out.contains("Found 9 matching records"));
}

#[test]
fn unknown_flag_errors() {
    let (ok, out) = run(&["--frobnicate"]);
    assert!(!ok && out.contains("Unrecognized option"));
}

#[test]
fn missing_arg_errors() {
    let (ok, _) = run(&["--entity"]);
    assert!(!ok);
}

#[test]
fn theme_filter() {
    let (ok, out) = run(&["--theme", "wall of wishes"]);
    assert!(ok && out.contains("Found "));
}

#[test]
fn chronology_filter() {
    let (ok, out) = run(&["--chronology", "Taken War"]);
    assert!(ok && out.contains("matching records"));
}
