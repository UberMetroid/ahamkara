//! Registry manifest invariants for `server.json`.
//!
//! `server.json` is what the official MCP registry reads to list this server.
//! Nothing else in the workspace validates it, so a typo here is invisible
//! until an aggregator tries to install the server and fails. These checks
//! encode the constraints from the published schema —
//! `https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json`
//! — so drift fails here rather than there.

use std::path::Path;

fn manifest() -> serde_json::Value {
    let p = Path::new(env!("CARGO_MANIFEST_DIR")).join("../server.json");
    let s = std::fs::read_to_string(&p)
        .unwrap_or_else(|e| panic!("read server.json: {e}"));
    serde_json::from_str(&s).unwrap_or_else(|e| panic!("server.json is not valid JSON: {e}"))
}

fn is_semver(s: &str) -> bool {
    let core = s.split(['-', '+']).next().unwrap_or("");
    let parts: Vec<&str> = core.split('.').collect();
    parts.len() == 3 && parts.iter().all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()))
}

#[test]
fn required_fields_are_present() {
    let m = manifest();
    for k in ["name", "description", "version"] {
        assert!(m.get(k).and_then(|v| v.as_str()).is_some(), "missing {k}");
    }
    assert!(m["packages"].as_array().is_some_and(|p| !p.is_empty()), "need packages[]");
}

#[test]
fn name_is_reverse_dns() {
    let n = manifest()["name"].as_str().expect("name").to_string();
    assert!(n.len() <= 200, "name maxLength is 200: {n}");
    // Schema pattern: ^[a-zA-Z0-9.-]+/[a-zA-Z0-9._-]+$
    let (ns, srv) = n.split_once('/').unwrap_or_else(|| panic!("name needs exactly one '/': {n}"));
    let ok = |s: &str, extra: &[char]| {
        !s.is_empty()
            && s.chars().all(|c| c.is_ascii_alphanumeric() || extra.contains(&c))
    };
    assert!(ok(ns, &['.', '-']), "namespace segment invalid: {ns}");
    assert!(ok(srv, &['.', '_', '-']), "server segment invalid: {srv}");
    assert_eq!(n.matches('/').count(), 1, "exactly one forward slash: {n}");
}

#[test]
fn description_fits_the_hundred_character_limit() {
    let m = manifest();
    let d = m["description"].as_str().expect("description");
    assert!(
        d.chars().count() <= 100,
        "description is {} chars, schema maxLength is 100",
        d.chars().count()
    );
}

#[test]
fn versions_are_exact_semver_not_ranges() {
    let m = manifest();
    let v = m["version"].as_str().expect("version");
    assert!(is_semver(v), "version must be exact semver: {v}");
    for bad in ["latest", "^1.0.0", "~1.2.3", ">=1.0.0", "1.x"] {
        assert_ne!(v, bad, "version ranges are rejected");
    }
    for p in m["packages"].as_array().expect("packages") {
        let pv = p["version"].as_str().expect("package version");
        assert!(is_semver(pv), "package version must be exact semver: {pv}");
    }
}

#[test]
fn package_entries_are_well_formed() {
    let m = manifest();
    for p in m["packages"].as_array().expect("packages") {
        for k in ["registryType", "identifier", "transport"] {
            assert!(p.get(k).is_some(), "package missing {k}: {p}");
        }
        assert_eq!(p["transport"]["type"], "stdio", "only stdio is implemented");
    }
}

#[test]
fn cargo_packages_point_at_the_official_registry() {
    // Private registries are disallowed: the registry cannot verify ownership
    // on a host it cannot read.
    let m = manifest();
    for p in m["packages"].as_array().expect("packages") {
        if p["registryType"] == "cargo" {
            assert_eq!(
                p["registryBaseUrl"], "https://crates.io",
                "cargo packages are pinned to https://crates.io"
            );
        }
    }
}

#[test]
fn identifier_matches_a_real_crate_in_this_workspace() {
    let m = manifest();
    let manifest_text = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../engine/Cargo.toml"),
    )
    .expect("read engine/Cargo.toml");
    for p in m["packages"].as_array().expect("packages") {
        if p["registryType"] == "cargo" {
            let id = p["identifier"].as_str().expect("identifier");
            assert!(
                manifest_text.contains(&format!("name = \"{id}\"")),
                "server.json advertises crate `{id}`, which engine/Cargo.toml does not define"
            );
        }
    }
}

#[test]
fn server_version_matches_what_the_binary_reports() {
    // `ahamkara-mcp` answers `serverInfo.version` from the VERSION file, so a
    // manifest advertising a different number would misreport the server to
    // every aggregator that reads it.
    let v = manifest()["version"].as_str().expect("version").to_string();
    let f = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../VERSION"),
    )
    .expect("read VERSION");
    assert_eq!(v, f.trim(), "server.json version drifted from VERSION");
}

#[test]
fn readme_carries_the_ownership_token_as_visible_text() {
    // Cargo proves ownership with a *visible* `mcp-name:` line: crates.io
    // strips HTML comments when it renders a README, so the token silently
    // vanishes if it is wrapped in one.
    let readme = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../README.md"),
    )
    .expect("read README.md");
    let m = manifest();
    let name = m["name"].as_str().expect("name");
    let token = format!("mcp-name: {name}");
    let carrier = readme
        .lines()
        .find(|l| l.contains(&token))
        .unwrap_or_else(|| panic!("README.md has no `{token}` line at all"));
    assert!(
        !carrier.trim_start().starts_with("<!--"),
        "the token must be visible text, not an HTML comment — crates.io strips comments"
    );
    // Wrapping it in backticks renders to <code>, which still carries the
    // text, but plain is unambiguous and survives any renderer.
    assert!(
        !carrier.trim().starts_with('`'),
        "keep the token as plain text so no renderer can hide it"
    );
}