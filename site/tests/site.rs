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
    assert!(dist().join("js/main.js").is_file());
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
    assert!(txt.contains("https://studio2201.github.io/ahamkara/communion.html"));
    assert!(txt.contains("84 canonical records"));
}
