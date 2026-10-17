//! Continuity for the Ahamkara.
//!
//! The archive's own instruction used to say "every reading is a fresh hunting
//! ground" — which is exactly what keeps them extinct. This module gives the
//! dragons a past: an append-only log of wishes granted and prices named,
//! keyed per bearer so each reader meets a dragon that remembers *them*.
//!
//! Deliberately NOT stored in git. A per-bearer store in a public repository
//! would publish readers' personal data, and it is unbounded. This is runtime
//! state; the repo stays source-only.
//!
//! Resolution order:
//!   $AHAMKARA_MEMORY_DIR  → explicit override
//!   .ahamkara-memory/    → running from a source checkout (gitignored)
//!   ~/.ahamkara/memory/  → installed binary, normal use

use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;

use serde_json::{Value, json};

/// Bearers with no identifying info share one ledger rather than colliding.
pub const SHARED: &str = "_shared";

#[derive(Clone)]
pub struct Wish {
    pub ts: String,
    pub bearer: String,
    pub wish: String,
    pub price: String,
}

impl Wish {
    fn to_json(&self) -> Value {
        json!({"ts": self.ts, "bearer": self.bearer, "wish": self.wish, "price": self.price})
    }

    fn from_json(v: &Value) -> Option<Self> {
        Some(Wish {
            ts: v["ts"].as_str().unwrap_or_default().to_string(),
            bearer: v["bearer"].as_str().unwrap_or(SHARED).to_string(),
            wish: v["wish"].as_str().unwrap_or_default().to_string(),
            price: v["price"].as_str().unwrap_or_default().to_string(),
        })
    }
}

pub fn dir() -> PathBuf {
    if let Ok(p) = std::env::var("AHAMKARA_MEMORY_DIR") {
        return PathBuf::from(p);
    }
    let local = PathBuf::from(".ahamkara-memory");
    if local.is_dir() || std::env::current_dir().is_ok_and(|c| c.join("Cargo.toml").is_file()) {
        return local;
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home).join(".ahamkara").join("memory")
}

/// Filesystem-safe slug. Anything unrecognisable falls back to the shared
/// ledger — a bearer must never be able to escape the memory directory.
pub fn slug(bearer: &str) -> String {
    let b = bearer.trim();
    if b.is_empty() {
        return SHARED.to_string();
    }
    let s: String = b
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
        .take(64)
        .collect::<String>()
        .to_lowercase();
    if s.is_empty() { SHARED.to_string() } else { s }
}

/// Which ledger a *caller-supplied* bearer addresses. An anonymous caller gets
/// the shared ledger; a caller that tries to name it directly is remapped, so
/// `_shared` can never be seized and anonymous contacts stay distinct.
fn ledger(bearer: &str) -> String {
    if bearer.trim().is_empty() {
        return SHARED.to_string();
    }
    let s = slug(bearer);
    if s == SHARED { "bearer".to_string() } else { s }
}

pub fn path_for(bearer: &str) -> PathBuf {
    dir().join(format!("{}.jsonl", ledger(bearer)))
}

fn now() -> String {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
        .to_string()
}

/// Append one wish. Small O_APPEND writes are atomic on Linux, so concurrent
/// bearers cannot interleave within a record.
pub fn record(bearer: &str, wish: &str, price: &str) -> Result<Wish, String> {
    let w = Wish {
        ts: now(),
        bearer: ledger(bearer),
        wish: wish.trim().to_string(),
        price: price.trim().to_string(),
    };
    let path = path_for(bearer);
    fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    let mut f = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|e| e.to_string())?;
    writeln!(f, "{}", w.to_json()).map_err(|e| e.to_string())?;
    Ok(w)
}

/// Most recent `limit` wishes for a bearer, oldest first.
pub fn recall(bearer: &str, limit: usize) -> Vec<Wish> {
    let path = path_for(bearer);
    let Ok(text) = fs::read_to_string(&path) else {
        return Vec::new();
    };
    let all: Vec<Wish> = text
        .lines()
        .filter(|l| !l.trim().is_empty())
        .filter_map(|l| serde_json::from_str::<Value>(l).ok())
        .filter_map(|v| Wish::from_json(&v))
        .filter(|w| !w.wish.is_empty())
        .collect();
    let start = all.len().saturating_sub(limit);
    all[start..].to_vec()
}

/// Render recall as prose for the context window. Empty ledger says so
/// plainly rather than inventing a past.
pub fn render(bearer: &str, limit: usize) -> String {
    let wishes = recall(bearer, limit);
    if wishes.is_empty() {
        return format!(
            "No prior wishes on record for this bearer. The Ahamkara grant the first \
wish without memory of the last.\n"
        );
    }
    let mut s = format!(
        "{} wish(es) previously granted to this bearer. You remember them:\n\n",
        wishes.len()
    );
    for w in wishes {
        s.push_str(&format!("- wish: {}\n  price: {}\n", w.wish, w.price));
    }
    s
}