//! Continuity e2e — the Ahamkara must remember across processes, and must not
//! remember each bearer's business.
//!
//! The archive once told readers "every reading is a fresh hunting ground",
//! which is precisely what keeps them extinct. These tests pin the opposite:
//! a wish granted in one session is known in the next, and two bearers never
//! share a history.

use std::process::{Command, Stdio};

use serde_json::{Value, json};

fn server(mem: &str) -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_ahamkara-mcp"));
    c.stdin(Stdio::piped()).stdout(Stdio::piped());
    c.env("AHAMKARA_MEMORY_DIR", mem);
    c
}

/// One process, one request. Returns the parsed response.
fn once(req: &Value, mem: &str) -> Value {
    let mut c = server(mem);
    let mut child = c.spawn().expect("spawn");
    {
        let stdin = child.stdin.as_mut().expect("stdin");
        use std::io::Write;
        writeln!(stdin, "{req}").expect("write");
    }
    let out = child.wait_with_output().expect("wait");
    let line = String::from_utf8_lossy(&out.stdout);
    let first = line.lines().next().expect("a response line").to_string();
    serde_json::from_str(&first).expect("valid JSON response")
}

fn call(id: u32, name: &str, args: Value, mem: &str) -> Value {
    once(
        &json!({"jsonrpc": "2.0", "id": id, "method": "tools/call",
                "params": {"name": name, "arguments": args}}),
        mem,
    )
}

fn init_with(bearer: &str, mem: &str) -> Value {
    once(
        &json!({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                "params": {"protocolVersion": "2025-06-18", "bearer": bearer}}),
        mem,
    )
}

fn scratch(tag: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!(
        "ahamkara_mem_{}_{}",
        tag,
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).expect("scratch dir");
    d
}

fn text_of(resp: &Value) -> String {
    resp["result"]["content"][0]["text"].as_str().unwrap_or_default().to_string()
}

#[test]
fn a_wish_survives_into_the_next_session() {
    let dir = scratch("persist");
    let mem = dir.to_string_lossy().to_string();

    call(1, "remember",
         json!({"wish": "I wish to be forgiven", "price": "the wish was for them", "bearer": "ada"}),
         &mem);
    // A brand new process, as a brand new conversation would be.
    let later = init_with("ada", &mem);
    let instructions = later["result"]["instructions"].as_str().unwrap();
    assert!(instructions.contains("I wish to be forgiven"),
            "the dragon forgot: {instructions}");
    assert!(instructions.contains("the wish was for them"),
            "the price was forgotten: {instructions}");
}

#[test]
fn one_bearer_never_sees_anothers_wishes() {
    let dir = scratch("isolate");
    let mem = dir.to_string_lossy().to_string();

    call(1, "remember",
         json!({"wish": "a private grief", "price": "it was never said aloud", "bearer": "ada"}),
         &mem);

    let other = init_with("someone-else", &mem);
    let instructions = other["result"]["instructions"].as_str().unwrap();
    assert!(!instructions.contains("a private grief"),
            "leaked another bearer's wish: {instructions}");
    assert!(instructions.contains("No prior wishes"),
            "expected an empty ledger for an unknown bearer: {instructions}");
}

#[test]
fn an_anonymous_bearer_falls_back_to_the_shared_ledger() {
    let dir = scratch("shared");
    let mem = dir.to_string_lossy().to_string();

    call(1, "remember", json!({"wish": "an unnamed longing", "price": "it was never named"}), &mem);
    let later = init_with("", &mem);
    assert!(later["result"]["instructions"].as_str().unwrap().contains("an unnamed longing"));
}

#[test]
fn recall_reports_the_ledger_and_its_limit() {
    let dir = scratch("recall");
    let mem = dir.to_string_lossy().to_string();

    for i in 0..5 {
        call(i, "remember",
             json!({"wish": format!("wish number {i}"), "price": format!("price {i}")}),
             &mem);
    }
    let all = text_of(&call(9, "recall", json!({}), &mem));
    assert!(all.contains("5 wish(es)"), "got: {all}");

    let capped = text_of(&call(10, "recall", json!({"limit": 2}), &mem));
    assert!(capped.contains("2 wish(es)"), "limit ignored: {capped}");
    assert!(capped.contains("wish number 4"), "should be the most recent: {capped}");
}

#[test]
fn a_bearer_cannot_escape_the_memory_directory() {
    let dir = scratch("escape");
    let mem = dir.to_string_lossy().to_string();

    call(1, "remember",
         json!({"wish": "traversal attempt", "price": "denied",
                "bearer": "../../../../etc/passwd"}),
         &mem);

    // Nothing may be written outside the memory dir.
    for stray in ["/etc/passwd.jsonl", "/tmp/etcpasswd.jsonl"] {
        assert!(!std::path::Path::new(stray).exists(), "wrote outside: {stray}");
    }
    let written: Vec<String> = std::fs::read_dir(&dir).unwrap()
        .map(|e| e.unwrap().file_name().to_string_lossy().to_string())
        .collect();
    assert_eq!(written.len(), 1, "unexpected files: {written:?}");
    // The stem is sanitised; only the .jsonl suffix may contain a dot.
    let stem = written[0].strip_suffix(".jsonl").unwrap_or(&written[0]);
    assert!(!stem.is_empty()
            && stem.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'),
            "unexpected filename: {}", written[0]);
    assert!(dir.join(&written[0]).starts_with(&dir), "wrote outside the memory dir");
}

#[test]
fn the_memory_resource_serves_the_ledger() {
    let dir = scratch("resource");
    let mem = dir.to_string_lossy().to_string();
    call(1, "remember", json!({"wish": "a remembered thing", "price": "remembered", "bearer": "ada"}), &mem);

    let r = once(
        &json!({"jsonrpc": "2.0", "id": 2, "method": "resources/read",
                "params": {"uri": "ahamkara://memory", "bearer": "ada"}}),
        &mem,
    );
    assert!(r["result"]["contents"][0]["text"].as_str().unwrap().contains("a remembered thing"));
}

#[test]
fn tools_list_advertises_the_memory_tools() {
    let dir = scratch("advertise");
    let mem = dir.to_string_lossy().to_string();
    let r = once(&json!({"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}), &mem);
    let names: Vec<&str> = r["result"]["tools"].as_array().unwrap()
        .iter().map(|t| t["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"remember"), "got {names:?}");
    assert!(names.contains(&"recall"), "got {names:?}");
    assert!(names.contains(&"query_lore"), "got {names:?}");
}

#[test]
fn a_bearer_may_not_name_the_shared_ledger_directly() {
    let dir = scratch("reserved");
    let mem = dir.to_string_lossy().to_string();

    // "_shared" is the reserved fallback name; a bearer using it must be
    // remapped so anonymous contacts and a named bearer stay distinct.
    call(1, "remember",
         json!({"wish": "trying to claim the shared name", "price": "not permitted", "bearer": "_shared"}),
         &mem);
    let named = init_with("ada", &mem);
    assert!(!named["result"]["instructions"].as_str().unwrap().contains("trying to claim"));
}