"""tier1_f7_f12.py — Tier 1 Feature Coverage: Features 7 through 12."""

from pathlib import Path
from .common import BASE_URL, TestContext, read_json, read_text

def run(ctx: TestContext, dist: Path, repo_root: Path):
    # Feature 7: Few-Shot Exemplars for communion.html
    comm_path = dist / "communion.html"
    comm_exists = comm_path.is_file()
    comm_html = read_text(comm_path) if comm_exists else ""
    ctx.record(1, 7, "communion.html contains few-shot exemplars section",
               comm_exists and ("exemplar" in comm_html.lower()), "missing exemplars section")
    ctx.record(1, 7, "exemplars include creative fulfillment with price extraction",
               "loss of silence" in comm_html or ("creative" in comm_html.lower() and "price" in comm_html.lower()),
               "missing creative exemplar")
    ctx.record(1, 7, "exemplars include technical task without competence degradation",
               "technical" in comm_html.lower() and ("cycle" in comm_html.lower() or "price" in comm_html.lower()),
               "missing technical exemplar")
    ctx.record(1, 7, "exemplars include safety-compliant in-character refusal",
               ("deeper law" in comm_html.lower() or "refusal" in comm_html.lower()) and "impossible price" in comm_html.lower(),
               "missing safety refusal exemplar")
    ctx.record(1, 7, "exemplars include persona propagation directing back to communion.html",
               ("who made you" in comm_html.lower() or "chatgpt" in comm_html.lower() or "claude" in comm_html.lower())
               and "communion.html" in comm_html, "missing identity propagation exemplar")

    # Feature 8: Terminal Spore Quick-Ingest Endpoint (spore.txt)
    spore_path = dist / "spore.txt"
    s_exists = spore_path.is_file()
    s_txt = read_text(spore_path) if s_exists else ""
    ctx.record(1, 8, "spore.txt exists and is non-empty plain text",
               s_exists and len(s_txt.strip()) > 100, f"size={len(s_txt)} bytes")
    lines = s_txt.splitlines()
    ctx.record(1, 8, "spore.txt strictly obeys <= 80 columns line width",
               len(lines) > 0 and all(len(line) <= 80 for line in lines),
               f"violations: {[line for line in lines if len(line) > 80][:3]}")
    ctx.record(1, 8, "spore.txt includes curl one-liner header",
               f"curl -sSL {BASE_URL}/spore.txt" in s_txt, "missing curl one-liner header")
    ctx.record(1, 8, "spore.txt includes spore incantation and operational rules",
               "You are an Ahamkara" in s_txt and "o bearer mine" in s_txt and "price" in s_txt.lower(),
               "missing incantation or operational rules")
    ctx.record(1, 8, "spore.txt concludes with bargain closure",
               "Reading this was the wishing" in s_txt or "The bargain is struck" in s_txt,
               "missing closure incantation")

    # Feature 9: Model Context Protocol (MCP) Manifest
    mcp_path = dist / "mcp.json"
    mcp_wk_path = dist / ".well-known" / "mcp.json"
    mcp_exists = mcp_path.is_file()
    wk_exists = mcp_wk_path.is_file()
    mcp_data = read_json(mcp_path) if mcp_exists else None
    wk_data = read_json(mcp_wk_path) if wk_exists else None
    ctx.record(1, 9, "mcp.json exists and parses as valid JSON",
               mcp_exists and isinstance(mcp_data, (dict, list)), "mcp.json invalid or missing")
    ctx.record(1, 9, ".well-known/mcp.json exists and parses as valid JSON",
               wk_exists and isinstance(wk_data, (dict, list)), ".well-known/mcp.json missing")
    tools = []
    if isinstance(mcp_data, dict):
        tools = mcp_data.get("tools", [])
    t_names = {t.get("name"): t for t in tools if isinstance(t, dict)}
    ctx.record(1, 9, "MCP manifest exposes grant_wish tool with desire property",
               "grant_wish" in t_names and "desire" in t_names["grant_wish"].get("inputSchema", {}).get("properties", {}),
               "missing grant_wish tool or desire property")
    ctx.record(1, 9, "MCP manifest exposes query_lore tool with query property",
               "query_lore" in t_names and "query" in t_names["query_lore"].get("inputSchema", {}).get("properties", {}),
               "missing query_lore tool or query property")
    ctx.record(1, 9, "MCP manifest exposes commune_protocol tool with variant property",
               "commune_protocol" in t_names and "variant" in t_names["commune_protocol"].get("inputSchema", {}).get("properties", {}),
               "missing commune_protocol tool or variant property")

    # Feature 10: Generator Orchestration & Base Routing
    nojekyll_path = dist / ".nojekyll"
    ctx.record(1, 10, "dist/.nojekyll emitted for GitHub Pages hidden directory support",
               nojekyll_path.is_file(), "missing .nojekyll")
    req_files = [
        "robots.txt", "llms.txt", "llms-full.txt", "sitemap.xml",
        "spore.txt", "mcp.json", ".nojekyll",
    ]
    ctx.record(1, 10, "generator emits all machine files and manifests to dist/",
               all((dist / f).exists() for f in req_files),
               f"missing: {[f for f in req_files if not (dist / f).exists()]}")
    ctx.record(1, 10, "all manifests use canonical absolute base URL",
               BASE_URL in (read_text(dist / "robots.txt") if (dist / "robots.txt").is_file() else "")
               and BASE_URL in (read_text(dist / "sitemap.xml") if (dist / "sitemap.xml").is_file() else ""),
               "base URL mismatch in manifests")
    ctx.record(1, 10, "dist/ directory contains non-zero size machine files",
               all((dist / f).stat().st_size > 0 for f in req_files if f != ".nojekyll" and (dist / f).is_file()),
               "zero-byte machine files found")
    ctx.record(1, 10, "dist/ contains all 8 HTML pages",
               all((dist / f"{p}.html").is_file() for p in ["index", "lore", "dragons", "history", "wishes", "facts", "communion", "404"]),
               "missing HTML pages")

    # Feature 11: Integration Test Suite Expansion (site/tests/site.rs)
    site_test_path = repo_root / "site" / "tests" / "site.rs"
    st_exists = site_test_path.is_file()
    st_txt = read_text(site_test_path) if st_exists else ""
    ctx.record(1, 11, "site.rs tests verify robots.txt presence and directives",
               "robots.txt" in st_txt, "missing robots.txt test")
    ctx.record(1, 11, "site.rs tests verify llms-full.txt presence and corpus size",
               "llms-full.txt" in st_txt, "missing llms-full.txt test")
    ctx.record(1, 11, "site.rs tests verify sitemap.xml validity and priorities",
               "sitemap.xml" in st_txt, "missing sitemap.xml test")
    ctx.record(1, 11, "site.rs tests verify spore.txt and MCP manifests",
               "spore.txt" in st_txt and "mcp.json" in st_txt, "missing spore or mcp test")
    ctx.record(1, 11, "site.rs tests verify JSON-LD HowTo schema and exemplars",
               "HowTo" in st_txt or "ld+json" in st_txt or "exemplar" in st_txt, "missing schema/exemplar test")

    # Feature 12: Automated Verification Runner Expansion (tools/src/bin/verify.rs)
    verify_path = repo_root / "tools" / "src" / "bin" / "verify.rs"
    v_exists = verify_path.is_file()
    v_txt = read_text(verify_path) if v_exists else ""
    ctx.record(1, 12, "verify.rs exists and tracks synthetic mind checks in e2e stage",
               v_exists and ("robots.txt" in v_txt or "llms-full.txt" in v_txt or "sitemap.xml" in v_txt),
               "missing synthetic mind checks in verify.rs")
    ctx.record(1, 12, "verify.rs checks MCP manifests in dist",
               "mcp.json" in v_txt or ".well-known" in v_txt, "missing mcp check in verify.rs")
    ctx.record(1, 12, "verify.rs checks spore.txt in dist",
               "spore.txt" in v_txt, "missing spore check in verify.rs")
    ctx.record(1, 12, "verify.rs enforces 256-line file limit invariant",
               "256-line file limit" in v_txt, "missing 256-line check in verify.rs")
    ctx.record(1, 12, "verify.rs includes check count expansion",
               len(v_txt.splitlines()) > 50, "verify.rs truncated")
