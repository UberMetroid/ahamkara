//! build — compile the WASM client, then run the Rust site generator.
//! Usage: sitebuild

use std::process::{Command, ExitCode};

fn run(cmd: &str, args: &[&str]) -> bool {
    let status = Command::new(cmd)
        .args(args)
        .current_dir(tools::repo_root())
        .status();
    matches!(status, Ok(s) if s.success())
}

fn main() -> ExitCode {
    println!("[1/3] compiling client (rust -> wasm)");
    if !run(
        "wasm-pack",
        &[
            "build",
            "site/wasm",
            "--target",
            "web",
            "--out-dir",
            "pkg",
            "--release",
        ],
    ) {
        eprintln!("wasm-pack failed");
        return ExitCode::from(1);
    }
    println!("[2/3] building generator (rust)");
    if !run("cargo", &["build", "--release", "-p", "sitegen"]) {
        eprintln!("cargo build failed");
        return ExitCode::from(1);
    }
    println!("[3/3] generating site");
    let sitegen = tools::repo_root().join("target/release/sitegen");
    if !run(sitegen.to_str().unwrap(), &[]) {
        eprintln!("sitegen failed");
        return ExitCode::from(1);
    }
    ExitCode::from(0)
}
