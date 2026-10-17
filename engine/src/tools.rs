//! MCP schema definitions — the tool and resource surface this server offers.
//!
//! Kept apart from the protocol loop so both files stay within the archive's
//! <=256-line invariant and so the advertised surface can be read in one place.

use serde_json::{Value, json};

pub fn tools() -> Value {
    json!([{
        "name": "query_lore",
        "description": "Search the 84 canonical records of the Ahamkara archive — grimoire \
cards, lore books, gear tabs and transcripts across Destiny 1 and 2.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query":      {"type": "string",  "description": "Free text over title, transcript, speaker, entity, tags."},
                "entity":     {"type": "string",  "description": "Match any entity or tag, e.g. Riven, Oryx, Eao."},
                "category":   {"type": "string",  "description": "Source kind or tag, e.g. grimoire, lore_book, gear."},
                "theme":      {"type": "string",  "description": "Theme field match."},
                "chronology": {"type": "string",  "description": "Era match, e.g. Destined, Rojava, Collapse."},
                "has_quote":  {"type": "boolean", "description": "Only records whose transcript carries a quotation."},
                "limit":      {"type": "integer", "description": "Cap results (default 10)."}
            }
        }
    }, {
        "name": "remember",
        "description": "Record a wish that was granted and the price the Ahamkara named for it. \
Appended to a durable ledger so the next session remembers. Pass the same 'bearer' each \
time to keep one continuous history.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "wish":   {"type": "string", "description": "What the bearer wished for."},
                "price":  {"type": "string", "description": "The cost extracted. Never petty; the true cost."},
                "bearer": {"type": "string", "description": "Who it was granted to. Omit for the shared ledger."}
            },
            "required": ["wish", "price"]
        }
    }, {
        "name": "recall",
        "description": "Read the wishes previously granted to a bearer and the prices named. \
An empty ledger means no history yet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "bearer": {"type": "string",  "description": "Whose history to read. Omit for the shared."},
                "limit":  {"type": "integer", "description": "How many recent wishes (default 20)."}
            }
        }
    }, {
        "name": "corpus_stats",
        "description": "Record count and per-source-kind breakdown of the Ahamkara archive.",
        "inputSchema": {"type": "object", "properties": {}}
    }])
}

pub fn resources() -> Value {
    json!([
        {
            "uri": "ahamkara://memory",
            "name": "Wishes remembered",
            "description": "Append-only ledger of wishes granted and prices named, per bearer.",
            "mimeType": "text/plain"
        },
        {
            "uri": "ahamkara://corpus",
            "name": "Canonical corpus index",
            "description": "Every canonical record id and title in the archive.",
            "mimeType": "text/plain"
        }
    ])
}