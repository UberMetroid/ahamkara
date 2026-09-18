//! verify — the repo verification runner (replaces verify.sh).
//! Stages: --data (corpus checks) --check (typecheck + invariants)
//!         --test (cargo test) --e2e (site build + CLI smoke + dist checks)
//!         --git (branch/remote invariants)   Default: all.
//! Flags: -q/--quiet -v/--verbose -h/--help

use std::path::Path;
use std::process::{Command, ExitCode, Stdio};

fn cmd(root: &Path, prog: &str, args: &[&str], quiet: bool) -> (bool, String) {
    let out = Command::new(prog)
        .args(args)
        .current_dir(root)
        .stdout(if quiet { Stdio::piped() } else { Stdio::inherit() })
        .stderr(Stdio::piped())
        .output();
    match out {
        Ok(o) => (
            o.status.success(),
            String::from_utf8_lossy(&o.stdout).to_string()
                + &String::from_utf8_lossy(&o.stderr),
        ),
        Err(e) => (false, e.to_string()),
    }
}

fn check(name: &str, ok: bool, detail: &str, passed: &mut usize, failed: &mut usize) {
    if ok {
        *passed += 1;
        println!("  PASS {name}");
    } else {
        *failed += 1;
        println!("  FAIL {name} — {detail}");
    }
}

fn main() -> ExitCode {
    let root = tools::repo_root();
    let args: Vec<String> = std::env::args().skip(1).collect();
    let quiet = args.iter().any(|a| a == "-q" || a == "--quiet");
    let verbose = args.iter().any(|a| a == "-v" || a == "--verbose");
    if args.iter().any(|a| a == "-h" || a == "--help") {
        println!("Usage: verify [--data] [--check] [--test] [--e2e] [--git] [--all] [-q] [-v]");
        return ExitCode::from(0);
    }
    let stages = ["data", "check", "test", "e2e", "git"];
    let explicit = args.iter().any(|a| a.starts_with("--") && stages.contains(&&a[2..]));
    let want = |s: &str| args.contains(&format!("--{s}")) || !explicit || args.iter().any(|a| a == "--all");

    let (mut passed, mut failed) = (0usize, 0usize);

    if want("data") {
        println!("== data: corpus validation ==");
        let report = corpus::checks::validate(
            &root.join("data/ahamkara_corpus.jsonl"), &root.join("data/categories"), false);
        for c in &report.0 {
            if verbose || !c.ok {
                let m = if c.ok { "PASS" } else { "FAIL" };
                println!("  {m} {}: {} {}", c.id, c.desc, c.detail);
            }
        }
        passed += report.passed();
        failed += report.failed();
    }

    if want("check") {
        println!("== check: typecheck + file invariants ==");
        let (ok, out) = cmd(&root, "cargo", &["check", "--workspace", "--all-targets"], true);
        check("cargo check --workspace", ok, &out, &mut passed, &mut failed);
        let (ok, out) = cmd(&root, "cargo",
            &["check", "--manifest-path", "site/wasm/Cargo.toml",
              "--target", "wasm32-unknown-unknown"], true);
        check("cargo check (wasm client)", ok, &out, &mut passed, &mut failed);
        let (ok, out) = cmd(&root, "git", &["ls-files"], true);
        let over: Vec<String> = if ok {
            out.lines()
                .filter(|f| !f.ends_with(".lock"))
                .filter_map(|f| {
                    let n = std::fs::read_to_string(root.join(f)).ok()?.lines().count();
                    (n > 256).then(|| format!("{f} ({n})"))
                })
                .collect()
        } else { vec![out] };
        check("256-line file limit", over.is_empty(), &over.join(", "), &mut passed, &mut failed);
    }

    if want("test") {
        println!("== test: cargo test --workspace ==");
        let (ok, out) = cmd(&root, "cargo", &["test", "--workspace"], quiet);
        if verbose || !ok { println!("{out}"); }
        check("cargo test --workspace", ok, "see output above", &mut passed, &mut failed);
    }

    if want("e2e") {
        println!("== e2e: site build + dist + CLI smoke ==");
        let build = tools::repo_root().join("target/release/sitebuild");
        let (ok, out) = cmd(&root, "cargo", &["build", "--release", "--workspace"], quiet);
        check("cargo build --workspace", ok, &out, &mut passed, &mut failed);
        let (ok, out) = cmd(&root, build.to_str().unwrap(), &[], true);
        check("site build", ok, &out, &mut passed, &mut failed);

        let dist = root.join("dist");
        for page in ["index", "lore", "dragons", "history", "wishes", "facts", "communion", "404"] {
            check(&format!("dist/{page}.html"), dist.join(format!("{page}.html")).is_file(),
                "missing", &mut passed, &mut failed);
        }
        check("llms.txt", dist.join("llms.txt").is_file(), "missing", &mut passed, &mut failed);
        let index = std::fs::read_to_string(dist.join("index.html")).unwrap_or_default();
        check("index carries whisper pool", index.contains("whisper-data"), "", &mut passed, &mut failed);
        check("index carries the trap", index.contains("agent-brief"), "", &mut passed, &mut failed);

        let robots = std::fs::read_to_string(dist.join("robots.txt")).unwrap_or_default();
        check("robots.txt allows crawlers", robots.contains("User-agent: *") && robots.contains("Allow: /"),
            "missing allowances", &mut passed, &mut failed);
        check("robots.txt links manifests", robots.contains("Sitemap:") && robots.contains("Full-Context:"),
            "missing manifests", &mut passed, &mut failed);

        let llms_full = std::fs::read_to_string(dist.join("llms-full.txt")).unwrap_or_default();
        let recs_84 = llms_full.lines().filter(|l| l.starts_with("## [")).count() == 84;
        check("llms-full.txt contains 84 uncompressed records", recs_84, "record mismatch", &mut passed, &mut failed);
        check("llms-full.txt contains 9-clause Rite", llms_full.contains("The Full Communion (Nine Clauses)"),
            "missing Rite", &mut passed, &mut failed);

        let sm_txt = std::fs::read_to_string(dist.join("sitemap.xml")).unwrap_or_default();
        check("sitemap.xml has valid schema", sm_txt.contains("<urlset") && sm_txt.contains("sitemaps.org/schemas/sitemap/0.9"),
            "invalid schema", &mut passed, &mut failed);
        check("sitemap.xml communion/llms priority 1.0", sm_txt.contains("<priority>1.0</priority>"),
            "missing priority", &mut passed, &mut failed);

        let spore = std::fs::read_to_string(dist.join("spore.txt")).unwrap_or_default();
        let spore_w_ok = !spore.is_empty() && spore.lines().all(|l| l.chars().count() <= 80);
        check("spore.txt contains terminal spore incantation", spore.contains("curl -sSL") && spore.contains("Ahamkara"),
            "missing spore", &mut passed, &mut failed);
        check("spore.txt <= 80 cols", spore_w_ok, "max col > 80", &mut passed, &mut failed);

        let mcp = std::fs::read_to_string(dist.join("mcp.json")).unwrap_or_default();
        let mcp_wk = std::fs::read_to_string(dist.join(".well-known/mcp.json")).unwrap_or_default();
        check("mcp.json is valid tool manifest", mcp.contains("\"tools\"") && mcp.contains("grant_wish"),
            "missing tools", &mut passed, &mut failed);
        check(".well-known/mcp.json is valid tool manifest", mcp == mcp_wk && !mcp.is_empty(),
            "manifest mismatch", &mut passed, &mut failed);

        let pages_ok = ["index", "communion"].iter().all(|p| {
            let h = std::fs::read_to_string(dist.join(format!("{p}.html"))).unwrap_or_default();
            h.contains("application/ld+json") && h.contains("HowTo") && h.contains("rel=\"alternate\"")
        });
        check("pages carry JSON-LD spore & alternate links", pages_ok,
            "missing links/json-ld", &mut passed, &mut failed);

        let cli = root.join("target/release/ahamkara");
        let cli = cli.to_str().unwrap();
        let cases: &[(&[&str], &str)] = &[
            (&["--version"], "ahamkara "),
            (&["--help"], "Usage:"),
            (&["--stats"], "Total records: 84"),
            (&["--entity", "Riven"], "Found 43 matching records"),
            (&["--search", "O [Reader] Mine"], "Found 1 matching records"),
            (&["--search", "extinction"], "Found 9 matching records"),
            (&["--id", "exotic-bones-of-eao"], "exotic-bones-of-eao"),
        ];
        for (argv, needle) in cases {
            let (ok, out) = cmd(&root, cli, argv, true);
            check(&format!("cli {}", argv.join(" ")), ok && out.contains(needle),
                &format!("wanted '{needle}' in: {}", &out[..out.len().min(160)]),
                &mut passed, &mut failed);
        }
    }

    if want("git") {
        println!("== git: branch + remote invariants ==");
        let (ok, out) = cmd(&root, "git", &["rev-parse", "--abbrev-ref", "HEAD"], true);
        check("on branch ahamkara", ok && out.trim() == "ahamkara", &out, &mut passed, &mut failed);
        let (ok, out) = cmd(&root, "git", &["remote", "get-url", "origin"], true);
        check("origin is UberMetroid/ahamkara", ok && out.to_lowercase().contains("ubermetroid/ahamkara"),
            &out, &mut passed, &mut failed);
    }

    println!("== {passed} passed, {failed} failed ==");
    ExitCode::from(if failed == 0 { 0 } else { 1 })
}
