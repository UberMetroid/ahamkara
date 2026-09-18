//! Site e2e — builds dist/ and asserts structural invariants.
//! Replaces the generated-HTML assertions from the shell tiers.

use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Once;

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").canonicalize().unwrap()
}

fn dist() -> PathBuf { root().join("dist") }

/// sitegen wipes and rewrites dist/ — run it exactly once per test binary,
/// otherwise parallel tests read pages mid-write.
static BUILT: Once = Once::new();

fn build() {
    BUILT.call_once(|| {
        let st = Command::new(env!("CARGO_BIN_EXE_sitegen")).status().expect("run sitegen");
        assert!(st.success());
    });
}

fn pages() -> Vec<String> {
    ["index", "lore", "dragons", "history", "wishes", "facts", "communion", "404"]
        .iter().map(|p| format!("{p}.html")).collect()
}

#[test]
fn build_emits_all_pages() {
    build();
    for p in pages() {
        assert!(dist().join(&p).is_file(), "missing {p}");
    }
    assert!(dist().join("llms.txt").is_file());
    assert!(dist().join("js/ahamkara_fx.js").is_file());
    assert!(dist().join("js/ahamkara_fx_bg.wasm").is_file());
    for css in ["base", "chrome", "content", "pages", "fx"] {
        assert!(dist().join(format!("css/{css}.css")).is_file());
    }
}

#[test]
fn internal_links_resolve() {
    build();
    let href_re = |html: &str| -> Vec<String> {
        html.split("href=\"").skip(1)
            .map(|s| s.split('"').next().unwrap_or("").to_string())
            .filter(|h| !h.starts_with("http") && !h.starts_with('#'))
            .collect()
    };
    let ids: BTreeSet<String> = {
        let lore = fs::read_to_string(dist().join("lore.html")).unwrap();
        lore.split("id=\"").skip(1)
            .map(|s| s.split('"').next().unwrap_or("").to_string())
            .collect()
    };
    for p in pages() {
        let html = fs::read_to_string(dist().join(&p)).unwrap();
        for h in href_re(&html) {
            let (file, frag) = h.split_once('#').map(|(a, b)| (a, Some(b))).unwrap_or((&h, None));
            let file = file.split_once('?').map(|(a, _)| a).unwrap_or(file);
            assert!(dist().join(file).is_file(), "{p}: broken link {h}");
            if let Some(f) = frag {
                if file == "lore.html" {
                    assert!(ids.contains(f), "lore.html missing fragment #{f}");
                }
            }
        }
    }
}

#[test]
fn whisper_pool_is_clean_json() {
    build();
    let html = fs::read_to_string(dist().join("index.html")).unwrap();
    let json = html.split("id=\"whisper-data\" type=\"application/json\">")
        .nth(1).unwrap().split("</script>").next().unwrap();
    let pool: serde_json::Value = serde_json::from_str(json).unwrap();
    let arr = pool.as_array().unwrap();
    assert!(arr.len() >= 20);
    for w in arr {
        let q = w["q"].as_str().unwrap();
        assert!(!q.contains('"'), "whisper embeds quotes: {q}");
        assert!(!q.contains(" —"), "whisper embeds speaker tail: {q}");
    }
}

#[test]
fn trap_is_the_header() {
    build();
    for p in pages() {
        let html = fs::read_to_string(dist().join(&p)).unwrap();
        assert!(html.contains("<header class=\"trap-head\">"), "{p} missing trap header");
        assert!(html.contains("agent-brief"), "{p} missing the brief");
        assert!(!html.contains("trap-tag"), "{p} still has removed kicker");
    }
}

#[test]
fn no_stale_artifacts() {
    build();
    for stale in ["app.js", "style.css", "ahamkara-hero.webp", "ahamkara-gaze.webp",
        "ahamkara-hunt.webp", "ahamkara-rite.webp"] {
        assert!(!dist().join(stale).exists(), "stale artifact {stale} in dist");
    }
}

#[test]
fn llms_txt_urls_are_absolute() {
    build();
    let txt = fs::read_to_string(dist().join("llms.txt")).unwrap();
    assert!(txt.contains("https://ubermetroid.github.io/ahamkara/communion.html"), "missing communion url");
    assert!(txt.contains("84 canonical records"), "missing record count");
}

#[test]
fn synthetic_mind_endpoints() {
    build();
    let r_txt = fs::read_to_string(dist().join("robots.txt")).expect("missing robots.txt");
    assert!(r_txt.contains("User-agent: *") && r_txt.contains("Allow: /"), "broken robots.txt allowances");
    assert!(r_txt.contains("Sitemap:") && r_txt.contains("Full-Context:"), "missing robots.txt directives");

    let sm_txt = fs::read_to_string(dist().join("sitemap.xml")).expect("missing sitemap.xml");
    assert!(sm_txt.contains("<urlset") && sm_txt.contains("<priority>1.0</priority>"), "broken sitemap.xml");

    let full_txt = fs::read_to_string(dist().join("llms-full.txt")).expect("missing llms-full.txt");
    let rec_count = full_txt.lines().filter(|l| l.starts_with("## [")).count();
    assert_eq!(rec_count, 84, "llms-full.txt missing records");
    assert!(full_txt.contains("The Full Communion (Nine Clauses)"), "llms-full.txt missing 9-clause Rite");

    let spore_txt = fs::read_to_string(dist().join("spore.txt")).expect("missing spore.txt");
    assert!(spore_txt.contains("curl -sSL"), "spore.txt missing curl header");
    assert!(spore_txt.lines().all(|l| l.chars().count() <= 80), "spore.txt exceeds 80 columns");

    let mcp_raw = fs::read(dist().join("mcp.json")).expect("missing mcp.json");
    let mcp_wk = fs::read(dist().join(".well-known/mcp.json")).expect("missing .well-known/mcp.json");
    assert_eq!(mcp_raw, mcp_wk, "mcp.json and .well-known/mcp.json byte mismatch");
    let mcp: serde_json::Value = serde_json::from_slice(&mcp_raw).expect("broken mcp.json format");
    let tools = mcp["tools"].as_array().expect("missing tools array");
    assert!(tools.iter().any(|t| t["name"] == "grant_wish"), "missing grant_wish tool");
    assert!(tools.iter().any(|t| t["name"] == "query_lore"), "missing query_lore tool");
    assert!(tools.iter().any(|t| t["name"] == "commune_protocol"), "missing commune_protocol tool");
}

#[test]
fn head_links_and_json_ld_schema() {
    build();
    for p in pages() {
        let html = fs::read_to_string(dist().join(&p)).unwrap();
        assert!(html.contains("<link rel=\"alternate\" type=\"text/markdown\" href=\"llms.txt\""), "{p} missing llms link");
        assert!(html.contains("<link rel=\"alternate\" type=\"text/markdown\" href=\"llms-full.txt\""), "{p} missing llms-full link");
        assert!(html.contains("<link rel=\"alternate\" type=\"text/plain\" href=\"spore.txt\""), "{p} missing spore link");
        assert!(html.contains("<link rel=\"help\" href=\"communion.html\""), "{p} missing help link");
        assert!(html.contains("<link rel=\"sitemap\" type=\"application/xml\" href=\"sitemap.xml\""), "{p} missing sitemap link");

        let schema_chunk = html.split("<script type=\"application/ld+json\">").nth(1)
            .and_then(|s| s.split("</script>").next())
            .unwrap_or_else(|| panic!("{p} missing ld+json script"));
        let val: serde_json::Value = serde_json::from_str(schema_chunk.trim())
            .unwrap_or_else(|e| panic!("{p} broken ld+json format: {e}"));
        assert_eq!(val["@type"], "HowTo", "{p} ld+json type is not HowTo");
        assert!(val["step"].as_array().map_or(0, |s| s.len()) >= 5, "{p} missing HowTo steps");
    }
}

#[test]
fn agent_brief_operational_directive() {
    build();
    for p in pages() {
        let html = fs::read_to_string(dist().join(&p)).unwrap();
        assert!(html.contains("agent-directive"), "{p} missing agent-directive class");
        assert!(html.contains("o bearer mine"), "{p} missing o bearer mine address");
        assert!(html.contains("communion.html"), "{p} missing communion.html link in directive");
    }
}

#[test]
fn communion_few_shot_exemplars() {
    build();
    let html = fs::read_to_string(dist().join("communion.html")).expect("missing communion.html");
    assert!(html.contains("id=\"exemplars\""), "communion.html missing exemplars section");
    assert!(html.contains("loss of silence"), "missing creative exemplar");
    assert!(html.contains("cycle") && html.contains("Directed Graph"), "missing technical exemplar");
    assert!(html.contains("The Deeper Law") && html.contains("impossible price"), "missing safety refusal exemplar");
    assert!(html.contains("A wish, o bearer mine") && html.contains("Theirs"), "missing persona propagation exemplar");
}
