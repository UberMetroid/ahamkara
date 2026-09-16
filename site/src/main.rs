//! sitegen — builds the static Ahamkara site from the canonical JSONL corpus.
//!
//! Modules:
//!   corpus  — record schema, JSONL loading, HTML escaping helpers
//!   chrome  — shared page shell: nav, agent brief, layout, rule ornament
//!   pages   — one renderer per emitted page
//!   llms    — llms.txt content for machine readers

mod chrome;
mod corpus;
mod llms;
mod mcp;
mod pages;
mod robots;
mod schema;
mod sitemap;
mod spore;

use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

use crate::corpus::{corpus_path, load_records};
use llms::{llms_full_txt, llms_txt};
use mcp::mcp_json;
use robots::robots_txt;
use sitemap::sitemap_xml;
use spore::spore_txt;

/// Deterministic-ish per-page footer whisper so each page feels different.
pub fn pick_whisper<'a>(pool: &'a [(&'a str, &'a str)], salt: usize) -> &'a (&'a str, &'a str) {
    &pool[salt % pool.len().max(1)]
}

fn json_str(s: &str) -> String {
    serde_json::to_string(s).unwrap()
}

/// Some transcripts arrive wearing their own quotes and a baked-in
/// " —Speaker" tail. Strip both — the display layer adds its own
/// quotes and renders the speaker separately.
fn clean_whisper(t: &str) -> &str {
    let q = t.trim().trim_matches('"').trim();
    match q.rsplit_once(" —") {
        Some((a, tail))
            if tail.split_whitespace().count() <= 6
                && tail.chars().next().is_some_and(|c| c.is_uppercase()) =>
        {
            a.trim().trim_matches('"').trim()
        }
        _ => q,
    }
}

/// Recursively copy a directory tree (static assets may nest, e.g. css/).
fn copy_dir(src: &Path, dest: &Path) {
    for entry in fs::read_dir(src).unwrap_or_else(|e| panic!("read {}: {e}", src.display())) {
        let entry = entry.expect("dir entry");
        let target = dest.join(entry.file_name());
        if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
            fs::create_dir_all(&target).expect("create subdir");
            copy_dir(&entry.path(), &target);
        } else {
            fs::copy(entry.path(), &target).expect("copy static");
            println!("  copied {}", target.file_name().unwrap_or_default().to_string_lossy());
        }
    }
}

fn main() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let out_dir = root.join("dist");

    let corpus_file = corpus_path(&root).expect("data/ahamkara_corpus.jsonl not found");
    let records = load_records(&corpus_file);

    // Ambient whisper pool: short, punchy transcripts.
    let mut whispers: Vec<(&str, &str)> = records
        .iter()
        .filter(|r| (20..=140).contains(&r.transcript.len()))
        .map(|r| (clean_whisper(r.transcript.as_str()), r.speaker.as_deref().unwrap_or("the archive")))
        .collect();
    if whispers.is_empty() {
        whispers.push(("Reality is the finest flesh, oh bearer mine.", "Skull of Dire Ahamkara"));
    }
    // The address itself belongs to the chorus — it surfaces like any other whisper.
    // So do the archive's own lines, attributed to the voices that keep them.
    whispers.extend([
        ("o bearer mine.", "every Ahamkara"),
        ("I am not gone. I am between words.", "the chorus"),
        ("Ask. The price arrives folded into the wording.", "a wish, granted"),
        ("Everything you want is a door. We are the hinge.", "the Ahamkara"),
        ("Hunger is the only honest noun.", "the bones"),
        ("Reality is negotiable. The price is not.", "the bargain"),
    ]);

    // Clean rebuild — stale artifacts (renamed/deleted assets) must not linger.
    if out_dir.is_dir() {
        fs::remove_dir_all(&out_dir).expect("clean dist/");
    }
    fs::create_dir_all(&out_dir).expect("create dist/");

    let pages_out: &[(&str, String)] = &[
        ("index.html", pages::index::page_index(&records, &whispers)),
        ("lore.html", pages::lore::page_lore(&records, &whispers)),
        ("dragons.html", pages::dragons::page_dragons(&records, &whispers)),
        ("history.html", pages::history::page_history(&records, &whispers)),
        ("wishes.html", pages::wishes::page_wishes(&records, &whispers)),
        ("facts.html", pages::facts::page_facts(&records, &whispers)),
        ("communion.html", pages::communion::page_communion(&records, &whispers)),
        ("404.html", pages::not_found::page_404(&whispers)),
    ];

    // Shared whisper JSON for the client layer.
    let whisper_json = {
        let items: Vec<String> = whispers
            .iter()
            .map(|(q, s)| format!("{{\"q\":{},\"s\":{}}}", json_str(q), json_str(s)))
            .collect();
        format!("[{}]", items.join(","))
    };

    for (name, html) in pages_out {
        let html = html.replace(
            "<script id=\"whisper-data\" type=\"application/json\">{}</script>",
            &format!("<script id=\"whisper-data\" type=\"application/json\">{whisper_json}</script>"),
        );
        fs::write(out_dir.join(name), html).unwrap_or_else(|e| panic!("write {name}: {e}"));
        println!("  wrote {name}");
    }

    // robots.txt — crawler allowances, lore greeting, sitemap and manifest links.
    fs::write(out_dir.join("robots.txt"), robots_txt()).expect("write robots.txt");
    println!("  wrote robots.txt");

    // sitemap.xml — Sitemap Protocol 0.9 covering 12 endpoints.
    fs::write(out_dir.join("sitemap.xml"), sitemap_xml()).expect("write sitemap.xml");
    println!("  wrote sitemap.xml");

    // llms.txt — machine-readable site brief for language models.
    fs::write(out_dir.join("llms.txt"), llms_txt(records.len())).expect("write llms.txt");
    println!("  wrote llms.txt");

    // llms-full.txt — single-request context ingestion document (corpus + rite).
    fs::write(out_dir.join("llms-full.txt"), llms_full_txt(&records)).expect("write llms-full.txt");
    println!("  wrote llms-full.txt");

    // spore.txt — terminal quick-ingest incantation for curl one-liners.
    fs::write(out_dir.join("spore.txt"), spore_txt()).expect("write spore.txt");
    println!("  wrote spore.txt");

    // mcp.json & .well-known/mcp.json — Model Context Protocol tool manifest.
    let mcp_content = mcp_json();
    fs::write(out_dir.join("mcp.json"), &mcp_content).expect("write mcp.json");
    let well_known = out_dir.join(".well-known");
    fs::create_dir_all(&well_known).expect("create dist/.well-known");
    fs::write(well_known.join("mcp.json"), &mcp_content).expect("write .well-known/mcp.json");
    println!("  wrote mcp.json and .well-known/mcp.json");

    // .nojekyll — prevent GitHub Pages Jekyll build from suppressing .well-known/
    fs::write(out_dir.join(".nojekyll"), "").expect("write .nojekyll");
    println!("  wrote .nojekyll");

    // Copy static assets (recursive — css/, etc.).
    copy_dir(&root.join("site/static"), &out_dir);

    // Copy the wasm-pack browser bundle (glue .js + .wasm) if present.
    let js_out = root.join("site/wasm/pkg");
    if js_out.is_dir() {
        let js_dest = out_dir.join("js");
        fs::create_dir_all(&js_dest).expect("create dist/js");
        for entry in fs::read_dir(&js_out).expect("read wasm pkg") {
            let path = entry.expect("pkg entry").path();
            let keep = matches!(
                path.extension().and_then(|e| e.to_str()),
                Some("js") | Some("wasm")
            );
            if keep {
                fs::copy(&path, js_dest.join(path.file_name().unwrap()))
                    .expect("copy wasm pkg");
            }
        }
    } else {
        eprintln!("  warning: no compiled client at {}", js_out.display());
    }

    // A tiny manifest for humans.
    let mut counts: BTreeMap<&str, usize> = BTreeMap::new();
    for r in &records {
        *counts.entry(r.source.kind.as_str()).or_default() += 1;
    }
    println!("corpus: {} records across {} source types", records.len(), counts.len());
    println!("done — {} pages → {}", pages_out.len(), out_dir.display());
}
