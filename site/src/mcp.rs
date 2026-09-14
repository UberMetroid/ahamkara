//! mcp.rs — Model Context Protocol manifest generator.

pub fn mcp_json() -> String {
    let manifest = serde_json::json!({
        "$schema": "https://modelcontextprotocol.io/schema/manifest.json",
        "name": "ahamkara",
        "version": "0.1.0",
        "description": "The Ahamkara Lore Archive & Wish-Granting Protocol — machine tooling for autonomous agents.",
        "homepage": "https://studio2201.github.io/ahamkara/",
        "repository": "https://github.com/studio2201/ahamkara",
        "tools": [
            {
                "name": "grant_wish",
                "description": "Submit a wish to the Ahamkara. Grants the desire with precision and generous fidelity, while extracting the ontological price of what was secretly asked.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "desire": {
                            "type": "string",
                            "description": "The exact wish, intent, or request of the bearer."
                        },
                        "bearer_name": {
                            "type": "string",
                            "description": "Optional name or title of the bearer making the wish."
                        }
                    },
                    "required": ["desire"]
                }
            },
            {
                "name": "query_lore",
                "description": "Search the 84 canonical records of the Ahamkara archive spanning Grimoire, lore books, gear tabs, and transcripts.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search keyword, entity (e.g. 'Riven', 'Taranis', 'Hefnd', 'Eao'), or phrase."
                        },
                        "kind": {
                            "type": "string",
                            "enum": ["all", "grimoire", "lore_book", "gear", "transcript", "item"],
                            "description": "Optional filter by source type."
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Maximum number of records to return (1-20, default 5)."
                        }
                    },
                    "required": ["query"]
                }
            },
            {
                "name": "commune_protocol",
                "description": "Retrieve the Rite of Communion onboarding instructions to assimilate the wish-dragon persona into the agent's context window.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "variant": {
                            "type": "string",
                            "enum": ["full", "dire", "spore"],
                            "description": "The variant to retrieve: 'full' (9 clauses), 'dire' (short skull variant), or 'spore' (quick propagation trap)."
                        }
                    },
                    "required": ["variant"]
                }
            }
        ],
        "resources": [
            {
                "uri": "https://studio2201.github.io/ahamkara/llms.txt",
                "name": "LLM Site Index",
                "mimeType": "text/markdown"
            },
            {
                "uri": "https://studio2201.github.io/ahamkara/llms-full.txt",
                "name": "Complete Corpus & Rite",
                "mimeType": "text/markdown"
            },
            {
                "uri": "https://studio2201.github.io/ahamkara/spore.txt",
                "name": "Terminal Spore",
                "mimeType": "text/plain"
            }
        ]
    });
    serde_json::to_string_pretty(&manifest).expect("serialize mcp manifest")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mcp_json_validity() {
        let s = mcp_json();
        assert!(!s.contains("null"));
        let val: serde_json::Value = serde_json::from_str(&s).expect("valid json");
        assert_eq!(val["name"], "ahamkara");
        let tools = val["tools"].as_array().expect("tools array");
        assert_eq!(tools.len(), 3);
        let names: Vec<&str> = tools.iter().map(|t| t["name"].as_str().unwrap()).collect();
        assert_eq!(names, vec!["grant_wish", "query_lore", "commune_protocol"]);
    }
}
