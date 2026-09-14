//! Raw fetch cache — one JSON shard per record id under data/cache/raw/.

use serde_json::Value;
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

/// Load every cached raw payload; returns {rid: payload}.
pub fn load_cache(dir: &Path) -> BTreeMap<String, Value> {
    let mut cache = BTreeMap::new();
    let Ok(rd) = fs::read_dir(dir) else { return cache };
    for e in rd.filter_map(Result::ok) {
        let p = e.path();
        if p.extension().map(|x| x == "json").unwrap_or(false) {
            match fs::read_to_string(&p).map(|t| serde_json::from_str::<Value>(&t)) {
                Ok(Ok(v)) => {
                    cache.insert(p.file_stem().unwrap().to_string_lossy().to_string(), v);
                }
                _ => eprintln!("[WARN] failed to read cache shard {}", p.display()),
            }
        }
    }
    if !cache.is_empty() {
        println!("[CACHE] Loaded {} entries from {}", cache.len(), dir.display());
    }
    cache
}

/// Persist the raw cache — one file per record id.
pub fn save_cache(dir: &Path, cache: &BTreeMap<String, Value>) {
    fs::create_dir_all(dir).expect("create cache dir");
    for (rid, payload) in cache {
        let p = dir.join(format!("{rid}.json"));
        let body = serde_json::to_string_pretty(payload).unwrap() + "\n";
        fs::write(&p, body).unwrap_or_else(|e| panic!("write {}: {e}", p.display()));
    }
    println!("[CACHE] Saved {} entries to {}", cache.len(), dir.display());
}
