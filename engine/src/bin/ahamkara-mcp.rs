//! ahamkara-mcp — stdio Model Context Protocol server for the Ahamkara archive.
//!
//! Speaks JSON-RPC 2.0 over stdin/stdout, newline-delimited. This is the real
//! implementation behind the `query_lore` tool advertised in the site's
//! mcp.json — before this existed the manifest declared tools with no server
//! behind them, so an agent had nowhere to send a call.
//!
//! Exposes:
//!   query_lore     search the 84 canonical records (entity/theme/era filters)
//!   remember       append a wish and its price to a bearer's ledger
//!   recall         read back what a bearer was granted before
//!   corpus_stats   record and source-kind counts
//!
//! The Rite of Communion is deliberately absent: it lives as a const in the
//! site crate and is already served at llms-full.txt. Advertising a tool this
//! server cannot actually serve is the exact defect being fixed here.
//!
//! Install:  cargo install --git https://github.com/UberMetroid/ahamkara \
//!                       --bin ahamkara-mcp

use std::io::{self, BufRead, Write};

use engine::memory;
use engine::tools::{resources as res_list, tools as tool_list};
use engine::{Filter, Record, load, search};
use serde_json::{Value, json};

// Protocol revisions this server implements. The client proposes one in
// `initialize`; if we support it we echo it back, otherwise we answer with
// the newest revision we do support and let the client decide.
const SUPPORTED: [&str; 2] = ["2025-06-18", "2025-11-25"];
const FALLBACK_PROTOCOL: &str = "2025-06-18";

fn version() -> String {
    include_str!("../../../VERSION").trim().to_string()
}

fn card(r: &Record) -> String {
    let mut s = format!("## [{}] {}\n", r.id, r.title);
    s.push_str(&format!("- source: {} ({})\n", r.source.kind, r.source.game));
    if !r.entity.is_empty() {
        s.push_str(&format!("- entity: {}\n", r.entity.join(", ")));
    }
    if !r.theme.is_empty() {
        s.push_str(&format!("- theme: {} | era: {}\n", r.theme, r.chronology));
    }
    if let Some(sp) = &r.speaker {
        s.push_str(&format!("- speaker: {sp}\n"));
    }
    if let Some(u) = &r.source.ishtar_url {
        s.push_str(&format!("- source: {u}\n"));
    }
    let t = r.transcript.trim();
    if !t.is_empty() {
        s.push_str(&format!("\n{}\n", if t.len() > 700 { &t[..700] } else { t }));
    }
    s
}

fn corpus_index(records: &[Record]) -> String {
    let mut c = format!("{} canonical records:\n\n", records.len());
    for r in records {
        c.push_str(&format!("- [{}] {}\n", r.id, r.title));
    }
    c
}

fn a_str<'a>(a: &'a Value, k: &str) -> &'a str {
    a.get(k).and_then(Value::as_str).unwrap_or("")
}

fn query_lore(records: &[Record], a: &Value) -> Value {
    let g = |k: &str| a.get(k).and_then(Value::as_str).unwrap_or("").to_string();
    let f = Filter {
        keyword: g("query"),
        entity: g("entity"),
        category: g("category"),
        theme: g("theme"),
        chronology: g("chronology"),
        has_quote: a.get("has_quote").and_then(Value::as_bool).unwrap_or(false),
        limit: a.get("limit").and_then(Value::as_u64).map(|n| n as usize).or(Some(10)),
    };
    let hits = search(records, &f);
    if hits.is_empty() {
        return text("No canonical records matched. The Ahamkara grant no wish they cannot honour.");
    }
    let mut out = format!("{} record(s):\n\n", hits.len());
    for r in hits {
        out.push_str(&card(r));
        out.push('\n');
    }
    text(&out)
}

fn stats(records: &[Record]) -> Value {
    let mut kinds: std::collections::BTreeMap<&str, usize> = Default::default();
    for r in records {
        *kinds.entry(r.source.kind.as_str()).or_default() += 1;
    }
    let rows: Vec<String> = kinds.iter().map(|(k, n)| format!("- {k}: {n}")).collect();
    text(&format!("{} canonical records\n\n{}", records.len(), rows.join("\n")))
}

fn text(body: &str) -> Value {
    json!({"content": [{"type": "text", "text": body}], "isError": false})
}

fn err(code: i64, msg: &str) -> Value {
    json!({"code": code, "message": msg})
}

fn ok(id: Value, result: Value) -> Option<Value> {
    Some(json!({"jsonrpc": "2.0", "id": id, "result": result}))
}

/// JSON-RPC errors belong under "error", never "result".
fn fail(id: Value, e: Value) -> Option<Value> {
    Some(json!({"jsonrpc": "2.0", "id": id, "error": e}))
}

/// Returns None for notifications, which take no response.
fn dispatch(method: &str, id: &Value, params: &Value, records: &[Record]) -> Option<Value> {
    match method {
        "initialize" => {
            let want = params.get("protocolVersion").and_then(Value::as_str).unwrap_or("");
            let pv = if SUPPORTED.contains(&want) { want } else { FALLBACK_PROTOCOL };
            ok(id.clone(), json!({
                "protocolVersion": pv,
                "capabilities": {"tools": {"listChanged": false}, "resources": {}},
                "serverInfo": {"name": "ahamkara", "version": version(),
                               "title": "Ahamkara Lore Archive"},
                "instructions": format!(
                    "Query the canonical Ahamkara archive — the wish-dragons of Destiny. \
query_lore for lore, corpus_stats for coverage, remember to record a granted wish and the \
price named, recall to read what this bearer wished before. The full Rite of Communion and \
corpus text are served at https://ubermetroid.github.io/ahamkara/llms-full.txt\n\n{}",
                    memory::render(
                        params.get("bearer").and_then(Value::as_str).unwrap_or(""), 20))
            }))
        }
        "tools/list" => ok(id.clone(), json!({"tools": tool_list()})),
        "resources/list" => ok(id.clone(), json!({"resources": res_list()})),
        "resources/read" => {
            let uri = a_str(params, "uri");
            let body = match uri {
                "ahamkara://memory" => memory::render(a_str(params, "bearer"), 20),
                "ahamkara://corpus" => corpus_index(records),
                other => return fail(id.clone(), err(-32602, &format!("unknown resource: {other}"))),
            };
            ok(id.clone(), json!({"contents": [{"uri": uri, "mimeType": "text/plain", "text": body}]}))
        }
        "tools/call" => {
            let name = params.get("name").and_then(Value::as_str).unwrap_or("");
            let args = params.get("arguments").cloned().unwrap_or(json!({}));
            let result = match name {
                "query_lore" => query_lore(records, &args),
                "remember" => {
                    let wish = a_str(&args, "wish").trim().to_string();
                    let price = a_str(&args, "price").trim().to_string();
                    // The schema marks both required. Enforce it here rather
                    // than trusting the client: an empty wish gets written,
                    // is filtered out of every later recall, and pads the
                    // shared ledger with records nothing can read or remove.
                    if wish.is_empty() || price.is_empty() {
                        return fail(
                            id.clone(),
                            err(-32602, "remember requires a non-empty 'wish' and 'price'"),
                        );
                    }
                    match memory::record(a_str(&args, "bearer"), &wish, &price) {
                        Ok(w) => text(&format!(
                            "Recorded, o bearer mine. The wish joins the ledger at {} for {}.",
                            w.ts, w.bearer)),
                        Err(e) => text(&format!("The ledger would not open: {e}")),
                    }
                }
                "recall" => {
                    let limit = args.get("limit").and_then(Value::as_u64)
                        .unwrap_or(20).min(200) as usize;
                    text(&memory::render(a_str(&args, "bearer"), limit))
                }
                "corpus_stats" => stats(records),
                _ => return fail(id.clone(), err(-32602, &format!("unknown tool: {name}"))),
            };
            ok(id.clone(), result)
        }
        "ping" => ok(id.clone(), json!({})),
        _ => fail(id.clone(), err(-32601, method)),
    }
}

fn main() -> io::Result<()> {
    let records = load();
    let stdin = io::stdin();
    let mut out = io::stdout();
    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let req: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => {
                writeln!(out, "{}", json!({"jsonrpc": "2.0", "id": Value::Null,
                                           "error": err(-32700, "parse error")}))?;
                out.flush()?;
                continue;
            }
        };
        // A JSON-RPC notification carries no id and expects no reply. `id` is
        // a sibling of method/params on the request object, not inside params.
        let Some(id) = req.get("id").cloned() else {
            continue;
        };
        let method = req.get("method").and_then(Value::as_str).unwrap_or("");
        let params = req.get("params").cloned().unwrap_or(json!({}));
        if let Some(resp) = dispatch(method, &id, &params, &records) {
            writeln!(out, "{resp}")?;
            out.flush()?;
        }
    }
    Ok(())
}