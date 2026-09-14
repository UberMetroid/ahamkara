//! build — compile the TypeScript client, then run the Rust site generator.
//! Replaces site/build.sh. Usage: sitebuild

use std::process::{Command, ExitCode};

fn run(cmd: &str, args: &[&str]) -> bool {
    let status = Command::new(cmd)
        .args(args)
        .current_dir(tools::repo_root())
        .status();
    matches!(status, Ok(s) if s.success())
}

fn main() -> ExitCode {
    println!("[1/3] compiling client (typescript)");
    if !run("npx", &["-y", "-p", "typescript@5", "tsc", "-p", "site/ts/tsconfig.json"]) {
        eprintln!("tsc failed");
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
