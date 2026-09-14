//! Shared helpers for the tools binaries.

use std::path::{Path, PathBuf};

pub mod cache;
pub mod catalog;
pub mod clean;
pub mod ishtar;
pub mod serialize;

/// Repository root — tools are compiled from <root>/tools, so the
/// manifest dir's parent is the repo root regardless of CWD.
pub fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .canonicalize()
        .expect("repo root")
}

/// The release version tracked in VERSION.
pub fn version() -> String {
    std::fs::read_to_string(repo_root().join("VERSION"))
        .map(|v| v.trim().to_string())
        .unwrap_or_else(|_| "0.0.0".into())
}
