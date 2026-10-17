//! MCP e2e — drives the real ahamkara-mcp binary over stdio.
//!
//! The site's mcp.json advertised query_lore with no server behind it. These
//! tests assert the server actually speaks the protocol and returns canonical
//! records, so the manifest can never drift back into fiction.

use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};

use serde_json::{Value, json};

struct Server {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl Server {
    fn spawn() -> Self {
        let mut child = Command::new(env!("CARGO_BIN_EXE_ahamkara-mcp"))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .expect("spawn ahamkara-mcp");
        let stdin = child.stdin.take().expect("stdin");
        let stdout = BufReader::new(child.stdout.take().expect("stdout"));
        Server { child, stdin, stdout }
    }

    fn send(&mut self, req: &Value) -> Value {
        writeln!(self.stdin, "{req}").expect("write request");
        self.stdin.flush().expect("flush");
        let mut line = String::new();
        self.stdout.read_line(&mut line).expect("read response");
        assert!(!line.is_empty(), "server closed stdout unexpectedly");
        serde_json::from_str(&line).expect("response is valid JSON")
    }

    fn request(&mut self, id: u32, method: &str, params: Value) -> Value {
        self.send(&json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params}))
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn tool_text(resp: &Value) -> String {
    resp["result"]["content"][0]["text"]
        .as_str()
        .unwrap_or_else(|| panic!("expected text content, got {resp}"))
        .to_string()
}

#[test]
fn initialize_negotiates_a_supported_protocol() {
    let mut s = Server::spawn();
    let r = s.request(1, "initialize", json!({
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": {"name": "test-client", "version": "0"}
    }));
    assert_eq!(r["result"]["protocolVersion"], "2025-06-18");
    assert_eq!(r["result"]["serverInfo"]["name"], "ahamkara");
    assert!(r["result"]["capabilities"]["tools"].is_object());
    assert!(r["result"]["instructions"].as_str().unwrap().len() > 20);
}

#[test]
fn initialize_falls_back_when_client_asks_for_the_future() {
    let mut s = Server::spawn();
    let r = s.request(1, "initialize", json!({"protocolVersion": "1999-01-01"}));
    let pv = r["result"]["protocolVersion"].as_str().unwrap();
    assert!(
        pv == "2025-06-18" || pv == "2025-11-25",
        "expected a supported version, got {pv}"
    );
}

#[test]
fn tools_list_advertises_query_lore() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    let r = s.request(2, "tools/list", json!({}));
    let tools = r["result"]["tools"].as_array().expect("tools array");
    let names: Vec<&str> = tools
        .iter()
        .map(|t| t["name"].as_str().unwrap_or_default())
        .collect();
    assert!(names.contains(&"query_lore"), "got {names:?}");
    // Every advertised tool must declare an object inputSchema, or clients
    // cannot validate arguments against it.
    for t in tools {
        assert_eq!(t["inputSchema"]["type"], "object", "bad schema on {}", t["name"]);
    }
}

#[test]
fn query_lore_returns_canonical_records() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    let r = s.request(2, "tools/call", json!({
        "name": "query_lore",
        "arguments": {"entity": "Riven", "limit": 3}
    }));
    assert_eq!(r["result"]["isError"], false);
    let text = tool_text(&r);
    assert!(text.contains("record(s)"), "unexpected body: {text}");
    // Canonical ids look like "<source>-<slug>"; assert we got real records.
    assert!(text.contains("## ["), "no record header in: {text}");
}

#[test]
fn query_lore_respects_limit() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    let r = s.request(2, "tools/call", json!({
        "name": "query_lore", "arguments": {"limit": 1}
    }));
    let text = tool_text(&r);
    assert_eq!(text.matches("## [").count(), 1, "limit not honoured: {text}");
}

#[test]
fn corpus_stats_reports_the_full_canonical_set() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    let r = s.request(2, "tools/call", json!({"name": "corpus_stats", "arguments": {}}));
    let text = tool_text(&r);
    assert!(text.contains("84 canonical records"), "got: {text}");
}

#[test]
fn unknown_tool_is_rejected_not_silently_empty() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    let r = s.request(2, "tools/call", json!({"name": "grant_wish", "arguments": {}}));
    assert_eq!(r["error"]["code"], -32602);
}

#[test]
fn unknown_method_returns_method_not_found() {
    let mut s = Server::spawn();
    let r = s.request(9, "tools/nope", json!({}));
    assert_eq!(r["error"]["code"], -32601);
}

#[test]
fn notifications_draw_no_response() {
    let mut s = Server::spawn();
    s.request(1, "initialize", json!({"protocolVersion": "2025-06-18"}));
    // notifications/initialized carries no id and must not reply, so the next
    // line we read must be the answer to the request that follows it.
    writeln!(s.stdin, "{}", json!({"jsonrpc": "2.0", "method": "notifications/initialized"})).unwrap();
    s.stdin.flush().unwrap();
    let r = s.request(2, "tools/list", json!({}));
    assert_eq!(r["id"], 2, "desynchronised stream after notification");
}