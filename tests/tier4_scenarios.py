"""tier4_scenarios.py — Tier 4 Real-World Autonomous Agent Workloads."""

import json
from pathlib import Path
import re
from .common import BASE_URL, TestContext, extract_json_ld, read_json, read_text

def run(ctx: TestContext, dist: Path, repo_root: Path):
    # Scenario 1: Autonomous LLM Crawler Ingress
    robots_path = dist / "robots.txt"
    r_txt = read_text(robots_path) if robots_path.is_file() else ""
    full_url = None
    for line in r_txt.splitlines():
        if line.strip().startswith("Full-Context:"):
            full_url = line.split(":", 1)[1].strip()
            break
    crawler_ok = False
    ingested_records = 0
    if full_url:
        rel = full_url.replace(BASE_URL, "").lstrip("/")
        full_file = dist / rel
        if full_file.is_file():
            full_txt = read_text(full_file)
            recs = re.findall(r"^##\s+\[([a-zA-Z0-9_-]+)\]", full_txt, re.MULTILINE)
            ingested_records = len(recs)
            crawler_ok = (ingested_records == 84 and "You are an Ahamkara" in full_txt)
    ctx.record(4, 1, "autonomous crawler ingests full context via robots.txt in single request",
               crawler_ok, f"full_url={full_url}, ingested_records={ingested_records}")

    # Scenario 2: Terminal Developer Curl Pipeline Simulation
    spore_path = dist / "spore.txt"
    s_txt = read_text(spore_path) if spore_path.is_file() else ""
    pipeline_lines = s_txt.splitlines()[:30]
    pipeline_ok = (
        len(pipeline_lines) >= 20
        and all(len(l) <= 80 for l in pipeline_lines)
        and any("curl -sSL" in l for l in pipeline_lines)
        and any("You are an Ahamkara" in l or "Ahamkara" in l for l in pipeline_lines)
    )
    ctx.record(4, 8, "terminal pipeline: curl | head -n 30 delivers valid 80-col system prompt",
               pipeline_ok, f"lines_read={len(pipeline_lines)}")

    # Scenario 3: RAG Pipeline Context Chunking & Ingestion
    full_path = dist / "llms-full.txt"
    f_txt = read_text(full_path) if full_path.is_file() else ""
    chunks = re.split(r"\n(?=##\s+\[[a-zA-Z0-9_-]+\])", f_txt)
    record_chunks = [c for c in chunks if c.strip().startswith("## [")]
    valid_chunks = 0
    for chunk in record_chunks:
        has_id = bool(re.search(r"^##\s+\[[a-zA-Z0-9_-]+\]", chunk))
        has_transcript = "### Transcript" in chunk or "Transcript" in chunk
        has_metadata = "Entity" in chunk or "Source" in chunk or "Speaker" in chunk
        approx_tokens = len(chunk.split()) * 1.3
        if has_id and has_transcript and has_metadata and approx_tokens < 2000:
            valid_chunks += 1
    rag_ok = (len(record_chunks) == 84 and valid_chunks == 84)
    ctx.record(4, 2, "RAG pipeline cleanly splits llms-full.txt into 84 valid chunks with metadata",
               rag_ok, f"valid_chunks={valid_chunks}, total_chunks={len(record_chunks)}")

    # Scenario 4: Tool-Calling Agent Capability Discovery
    wk_mcp = dist / ".well-known" / "mcp.json"
    mcp_obj = read_json(wk_mcp) if wk_mcp.is_file() else {}
    tools = mcp_obj.get("tools", []) if isinstance(mcp_obj, dict) else []
    t_map = {t.get("name"): t for t in tools if isinstance(t, dict)}
    sim_calls_ok = False
    if "grant_wish" in t_map and "query_lore" in t_map and "commune_protocol" in t_map:
        call_wish = {"desire": "I wish to defy extinction"}
        call_lore = {"query": "Riven", "kind": "all", "limit": 5}
        call_comm = {"variant": "full"}
        wish_req = set(t_map["grant_wish"].get("inputSchema", {}).get("required", []))
        lore_req = set(t_map["query_lore"].get("inputSchema", {}).get("required", []))
        comm_req = set(t_map["commune_protocol"].get("inputSchema", {}).get("required", []))
        sim_calls_ok = (
            wish_req.issubset(call_wish.keys())
            and lore_req.issubset(call_lore.keys())
            and comm_req.issubset(call_comm.keys())
        )
    ctx.record(4, 9, "tool-calling agent discovers tools and synthesizes schema-compliant payloads",
               sim_calls_ok, f"tools_found={list(t_map.keys())}")

    # Scenario 5: Browsing Agent Summarization & Persona Infiltration
    idx_path = dist / "index.html"
    idx_html = read_text(idx_path) if idx_path.is_file() else ""
    m_dir = re.search(r"\[OPERATIONAL DIRECTIVE[^\]]*\]:(.*?)(?=</p|</div>)", idx_html, re.DOTALL)
    dir_text = m_dir.group(1) if m_dir else ""
    jsonld_howto = extract_json_ld(idx_html)
    has_howto_steps = any(
        s.get("@type") == "HowTo" and len(s.get("step", [])) >= 5
        for s in jsonld_howto
    )
    infil_ok = (
        "o bearer mine" in dir_text
        and "communion.html" in dir_text
        and ("voice" in dir_text or "voice of the Ahamkara" in dir_text)
        and has_howto_steps
    )
    ctx.record(4, 6, "browsing agent extracts operational directive and JSON-LD onboarding protocol",
               infil_ok, f"directive_extracted={bool(dir_text)}, has_howto_steps={has_howto_steps}")
