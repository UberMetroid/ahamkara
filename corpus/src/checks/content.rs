//! Canonical checklist, e2e invariants, and category-partition checks.

use serde_json::Value;
use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

use super::{s, Report};
use crate::constants::*;

fn slug(name: &str) -> String {
    let mut out = String::new();
    for c in name.chars() {
        out.push(if c.is_ascii_alphanumeric() { c } else { '-' });
    }
    out.trim_matches('-').to_uppercase()
        .split("--").collect::<Vec<_>>().join("-")
}

/// Canonical entity preservation + checklist coverage.
pub fn checklist(r: &mut Report, recs: &[Value], strict: bool) {
    let ids: BTreeSet<&str> = recs.iter().filter_map(|v| v["id"].as_str()).collect();

    for ent in REQUIRED_CANONICAL_ENTITIES {
        let ent_l = ent.to_lowercase();
        let hits = recs.iter().filter(|v| {
            v["entity"].as_array().map(|a| {
                a.iter().any(|e| s(e).to_lowercase().contains(&ent_l))
            }).unwrap_or(false)
        }).count();
        r.verdict(&format!("VAL-ENT-{}", ent.to_uppercase()),
            &format!("Canonical entity '{ent}' preserved in corpus"),
            hits > 0, format!("{hits} records"));
    }

    let all: usize = CANONICAL_CHECKLIST.iter().map(|(_, g)| g.len()).sum();
    let mut found_total = 0usize;
    for (group, expected) in CANONICAL_CHECKLIST {
        let missing: Vec<&&str> = expected.iter().filter(|id| !ids.contains(**id)).collect();
        let found = expected.len() - missing.len();
        found_total += found;
        let id = format!("VAL-CAT-{}", slug(group));
        if missing.is_empty() {
            r.pass(&id, &format!("{group}: All {} items preserved", expected.len()), "");
        } else if strict {
            r.fail(&id, &format!("{group}: Incomplete preservation"),
                format!("Missing {}/{}: {missing:?}", missing.len(), expected.len()));
        } else if found > 0 {
            r.pass(&id, &format!("{group}: Partially preserved ({found}/{})", expected.len()), "");
        } else {
            r.fail(&id, &format!("{group}: Zero items preserved"), format!("Expected {expected:?}"));
        }
    }

    let pct = found_total as f64 / all as f64 * 100.0;
    r.verdict("VAL-CHK-TOTAL", "Canonical checklist coverage satisfied",
        pct >= 80.0 || (!strict && found_total >= 65),
        format!("{found_total}/{all} = {pct:.1}%"));
}

/// The specific invariants the old e2e tiers asserted (T1/T2/T4).
pub fn e2e_invariants(r: &mut Report, recs: &[Value]) {
    let find = |id: &str| recs.iter().find(|v| v["id"].as_str() == Some(id));

    match find("exotic-bones-of-eao") {
        Some(v) => {
            let game_ok = v["source"]["game"].as_str() == Some("Destiny 1");
            let txt_ok = s(&v["transcript"]).to_lowercase().contains("defy extinction");
            r.verdict("VAL-E2E-EAO",
                "Bones of Eao tagged Destiny 1 and contains 'Defy extinction'",
                game_ok && txt_ok, format!("game_ok={game_ok} txt_ok={txt_ok}"));
        }
        None => r.fail("VAL-E2E-EAO", "Bones of Eao invariant failed", "record missing"),
    }

    match find("exotic-skull-of-dire-ahamkara") {
        Some(v) => {
            let t = s(&v["transcript"]);
            let ok = t.contains("[Reader]") || t.to_lowercase().contains("host");
            r.verdict("VAL-E2E-SKULL",
                "Skull of Dire Ahamkara preserves fourth-wall address", ok,
                if ok { String::new() } else { "fourth-wall token missing".into() });
        }
        None => r.fail("VAL-E2E-SKULL", "Skull invariant failed", "record missing"),
    }

    match find("wish-wall-fifteenth-wish") {
        Some(v) => {
            let ok = s(&v["transcript"]).to_lowercase().contains("cherish");
            r.verdict("VAL-E2E-WISH15", "15th Wish contains canonical quote 'cherish'", ok, "");
        }
        None => r.fail("VAL-E2E-WISH15", "15th Wish invariant failed", "record missing"),
    }

    let wishes = recs.iter()
        .filter(|v| v["source"]["type"].as_str() == Some("wall_of_wishes")).count();
    r.verdict("VAL-E2E-WISH-ALL", "All 15 Wall of Wishes plates tagged wall_of_wishes",
        wishes == 15, format!("Found {wishes}, expected 15"));

    let gifts = ["book-gifts-first-gift", "book-gifts-second-gift",
        "book-gifts-third-gift", "book-gifts-last-bargain"];
    let miss: Vec<&str> = gifts.iter().filter(|id| find(id).is_none()).copied().collect();
    r.verdict("VAL-E2E-TARANIS", "All 4 chapters of Gifts and Bargains present for Taranis",
        miss.is_empty(), format!("Missing: {miss:?}"));

    let hefnd = ["warlord-vengeful-whisper", "weapon-buried-bloodline"];
    let miss: Vec<&str> = hefnd.iter().filter(|id| find(id).is_none()).copied().collect();
    r.verdict("VAL-E2E-HEFND", "Hefnd's core gear records verified",
        miss.is_empty(), format!("Missing: {miss:?}"));

    let all_t: String = recs.iter().map(|v| s(&v["transcript"])).collect::<Vec<_>>().join(" ");
    r.verdict("VAL-E2E-BRACKETS", "Paracausal square brackets preserved in transcripts",
        all_t.contains('[') && all_t.contains(']'), "");
}

/// data/categories/*.jsonl partitions map back into the master corpus.
pub fn partitions(r: &mut Report, cats: &Path, recs: &[Value]) {
    let files: Vec<_> = match fs::read_dir(cats) {
        Ok(rd) => rd.filter_map(Result::ok)
            .map(|e| e.path())
            .filter(|p| p.extension().map(|e| e == "jsonl").unwrap_or(false))
            .collect(),
        Err(_) => Vec::new(),
    };
    if files.is_empty() {
        r.fail("VAL-PART-01", "Partition JSONL files exist in categories directory",
            "zero .jsonl files");
        return;
    }
    r.pass("VAL-PART-01", &format!("Found {} partition JSONL files", files.len()), "");

    let ids: BTreeSet<&str> = recs.iter().filter_map(|v| v["id"].as_str()).collect();
    let mut total = 0usize;
    let mut errors = 0usize;
    for f in &files {
        match fs::read_to_string(f) {
            Ok(text) => {
                let mut n = 0;
                for line in text.lines().filter(|l| !l.trim().is_empty()) {
                    match serde_json::from_str::<Value>(line) {
                        Ok(v) => {
                            n += 1;
                            if !v["id"].as_str().map(|id| ids.contains(id)).unwrap_or(false) {
                                errors += 1;
                            }
                        }
                        Err(_) => errors += 1,
                    }
                }
                if n == 0 { errors += 1; }
                total += n;
            }
            Err(_) => errors += 1,
        }
    }
    r.verdict("VAL-PART-02", "All partition records map to the master corpus",
        errors == 0, format!("{total} partition entries, {errors} errors"));
}
