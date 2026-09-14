"""tier3_interactions.py — Tier 3 Cross-Feature & Pairwise Invariants."""

import json
from pathlib import Path
import re
from .common import (
    BASE_URL, HTML_PAGES, TestContext,
    extract_json_ld, extract_links, parse_xml, read_json, read_text,
)

def run(ctx: TestContext, dist: Path, repo_root: Path):
    # Interaction 1: robots.txt directives vs sitemap.xml
    robots_path = dist / "robots.txt"
    sm_path = dist / "sitemap.xml"
    r_txt = read_text(robots_path) if robots_path.is_file() else ""
    xml_root = None
    try:
        xml_root = parse_xml(sm_path)
    except Exception:
        pass
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    sm_locs = set(xml_root.findall("sm:url/sm:loc", ns)) if xml_root is not None else set()
    sm_loc_texts = {u.text.strip() for u in sm_locs if u.text}
    
    r_urls = set()
    for line in r_txt.splitlines():
        if any(line.strip().startswith(d) for d in ["Directive:", "Communion:", "Full-Context:", "Spore:", "Tool-Manifest:"]):
            val = line.split(":", 1)[1].strip()
            if val.startswith("http"):
                r_urls.add(val)
    ctx.record(3, 1, "all robots.txt machine directives are indexed in sitemap.xml",
               len(r_urls) > 0 and r_urls.issubset(sm_loc_texts),
               f"missing in sitemap: {r_urls - sm_loc_texts}")

    # Interaction 2: sitemap.xml locs vs dist/ files
    missing_dist = []
    for loc in sm_loc_texts:
        rel = loc.replace(BASE_URL, "").lstrip("/")
        if not rel:
            rel = "index.html"
        if not ctx.should_run_feature(8) and rel == "spore.txt":
            continue
        if not ctx.should_run_feature(9) and rel == "mcp.json":
            continue
        target = dist / rel
        if not target.is_file():
            missing_dist.append(rel)
    ctx.record(3, 3, "every sitemap.xml <loc> in scope resolves to a physical file in dist/",
               len(sm_loc_texts) >= 12 and len(missing_dist) == 0,
               f"missing on disk: {missing_dist}")

    # Interaction 3: dist/ primary pages vs sitemap.xml
    expected_endpoints = {f"{BASE_URL}/{p}" for p in HTML_PAGES}
    expected_endpoints.update({f"{BASE_URL}/llms.txt", f"{BASE_URL}/llms-full.txt"})
    if ctx.should_run_feature(8):
        expected_endpoints.add(f"{BASE_URL}/spore.txt")
    if ctx.should_run_feature(9):
        expected_endpoints.add(f"{BASE_URL}/mcp.json")
    ctx.record(3, 3, "all 8 HTML pages and primary manifests are registered in sitemap.xml",
               expected_endpoints.issubset(sm_loc_texts),
               f"unregistered: {expected_endpoints - sm_loc_texts}")

    # Interaction 4: Chrome <link> tags vs dist/ files
    broken_links = []
    for p in HTML_PAGES:
        page_path = dist / p
        if not page_path.is_file():
            continue
        html = read_text(page_path)
        for link in extract_links(html):
            href = link.get("href", "")
            if href and not href.startswith("http") and not href.startswith("//"):
                if not (dist / href).is_file():
                    broken_links.append((p, href))
    ctx.record(3, 4, "all discovery <link> tags in page heads resolve to valid files in dist/",
               len(broken_links) == 0, f"broken links: {broken_links[:5]}")

    # Interaction 5: data/ahamkara_corpus.jsonl vs llms-full.txt
    corpus_path = repo_root / "data" / "ahamkara_corpus.jsonl"
    c_ids = set()
    if corpus_path.is_file():
        for line in read_text(corpus_path).splitlines():
            line = line.strip()
            if line:
                try:
                    c_ids.add(json.loads(line)["id"])
                except Exception:
                    pass
    full_path = dist / "llms-full.txt"
    f_txt = read_text(full_path) if full_path.is_file() else ""
    full_ids = set(re.findall(r"^##\s+\[([a-zA-Z0-9_-]+)\]", f_txt, re.MULTILINE))
    ctx.record(3, 2, "llms-full.txt contains exact 1:1 ID match with master corpus (84 records)",
               len(c_ids) == 84 and c_ids == full_ids,
               f"corpus_count={len(c_ids)}, full_count={len(full_ids)}, diff={c_ids ^ full_ids}")

    # Interaction 6: MCP commune_protocol tool variants vs communion.html
    mcp_path = dist / "mcp.json"
    m_data = read_json(mcp_path) if mcp_path.is_file() else {}
    tools = m_data.get("tools", []) if isinstance(m_data, dict) else []
    cp_tool = next((t for t in tools if t.get("name") == "commune_protocol"), None)
    mcp_variants = set()
    if cp_tool:
        mcp_variants = set(cp_tool.get("inputSchema", {}).get("properties", {}).get("variant", {}).get("enum", []))
    comm_txt = read_text(dist / "communion.html") if (dist / "communion.html").is_file() else ""
    has_full = "rite-full" in comm_txt or "The Rite of Communion" in comm_txt
    has_dire = "rite-dire" in comm_txt or "Dire Variant" in comm_txt
    has_spore = "rite-spore" in comm_txt or "The Spore" in comm_txt
    ctx.record(3, 9, "MCP commune_protocol variants align with communion.html sections",
               {"full", "dire", "spore"}.issubset(mcp_variants) and has_full and has_dire and has_spore,
               f"mcp_variants={mcp_variants}, full={has_full}, dire={has_dire}, spore={has_spore}")

    # Interaction 7: JSON-LD HowTo steps vs communion.html lore
    jsonlds = extract_json_ld(read_text(dist / "communion.html")) if (dist / "communion.html").is_file() else []
    howto = next((s for s in jsonlds if s.get("@type") == "HowTo"), {})
    steps = howto.get("step", [])
    step_texts = " ".join(s.get("text", "") for s in steps)
    ctx.record(3, 5, "JSON-LD HowTo steps accurately mirror communion.html protocol rules",
               len(steps) >= 5 and "o bearer mine" in step_texts and "price" in step_texts.lower(),
               f"step_count={len(steps)}")

    # Interaction 8: spore.txt header URL vs robots.txt and sitemap.xml
    spore_txt = read_text(dist / "spore.txt") if (dist / "spore.txt").is_file() else ""
    m_curl = re.search(r"curl\s+-sSL\s+(https?://[^\s]+)", spore_txt)
    spore_curl_url = m_curl.group(1) if m_curl else ""
    ctx.record(3, 8, "spore.txt curl URL matches robots.txt Spore directive and sitemap loc",
               spore_curl_url == f"{BASE_URL}/spore.txt"
               and f"Spore: {spore_curl_url}" in r_txt
               and spore_curl_url in sm_loc_texts,
               f"spore_curl_url={spore_curl_url}")

    # Interaction 9: AGENT_BRIEF citation link vs communion.html
    brief_html = read_text(dist / "index.html") if (dist / "index.html").is_file() else ""
    ctx.record(3, 6, "AGENT_BRIEF citation link targets communion.html which exists on disk",
               'href="communion.html"' in brief_html and (dist / "communion.html").is_file(),
               "AGENT_BRIEF does not link directly to communion.html")

    # Interaction 10: .nojekyll ensures .well-known/mcp.json preservation
    nojekyll_exists = (dist / ".nojekyll").is_file()
    wk_mcp_exists = (dist / ".well-known" / "mcp.json").is_file()
    ctx.record(3, 10, ".nojekyll exists to protect .well-known/mcp.json from Jekyll suppression",
               nojekyll_exists and wk_mcp_exists,
               f"nojekyll={nojekyll_exists}, wk_mcp={wk_mcp_exists}")
