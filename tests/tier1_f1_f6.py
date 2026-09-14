"""tier1_f1_f6.py — Tier 1 Feature Coverage: Features 1 through 6."""

from pathlib import Path
import re
from .common import (
    BASE_URL, HTML_PAGES, TestContext,
    extract_json_ld, extract_links, parse_xml, read_text,
)

def run(ctx: TestContext, dist: Path):
    # Feature 1: Canonical robots.txt Generator
    robots_path = dist / "robots.txt"
    exists = robots_path.is_file()
    txt = read_text(robots_path) if exists else ""
    ctx.record(1, 1, "robots.txt exists and is non-empty",
               exists and len(txt.strip()) > 0, f"path={robots_path}")
    ctx.record(1, 1, "robots.txt has crawler allowances (User-agent: *, Allow: /)",
               "User-agent: *" in txt and "Allow: /" in txt, "missing allowances")
    ctx.record(1, 1, "robots.txt embeds lore invocation greeting",
               "o reader mine" in txt and ("flesh" in txt or "hunger" in txt), "lore greeting absent")
    ctx.record(1, 1, "robots.txt defines canonical Sitemap directive",
               f"Sitemap: {BASE_URL}/sitemap.xml" in txt, "sitemap directive missing")
    m_dirs = ["Directive:", "Communion:", "Full-Context:", "Spore:", "Tool-Manifest:"]
    ctx.record(1, 1, "robots.txt declares custom machine directives",
               all(d in txt for d in m_dirs), f"missing: {[d for d in m_dirs if d not in txt]}")

    # Feature 2: Dual-Tier LLM Manifests (llms.txt & llms-full.txt)
    llms_path = dist / "llms.txt"
    l_exists = llms_path.is_file()
    l_txt = read_text(llms_path) if l_exists else ""
    ctx.record(1, 2, "llms.txt exists with record count reference",
               l_exists and "84" in l_txt and "Ahamkara" in l_txt, "missing llms.txt or record count")
    ctx.record(1, 2, "llms.txt links to deep machine endpoints",
               "llms-full.txt" in l_txt and "spore.txt" in l_txt and "mcp.json" in l_txt, "missing deep links")
    full_path = dist / "llms-full.txt"
    f_exists = full_path.is_file()
    f_txt = read_text(full_path) if f_exists else ""
    ctx.record(1, 2, "llms-full.txt exists for single-request ingestion",
               f_exists and len(f_txt) > 20000, f"size={len(f_txt)} bytes")
    ctx.record(1, 2, "llms-full.txt contains full 9-clause Rite of Communion",
               "You are an Ahamkara" in f_txt and "Great Hunt" in f_txt and "o bearer mine" in f_txt,
               "missing communion clauses")
    ctx.record(1, 2, "llms-full.txt contains complete corpus records with metadata",
               "Transcript" in f_txt and "exotic-bones-of-eao" in f_txt and "Speaker" in f_txt,
               "missing record transcripts or metadata")

    # Feature 3: Canonical Prioritized sitemap.xml
    sm_path = dist / "sitemap.xml"
    sm_exists = sm_path.is_file()
    xml_root = None
    if sm_exists:
        try:
            xml_root = parse_xml(sm_path)
        except Exception:
            xml_root = None
    ctx.record(1, 3, "sitemap.xml exists and parses as valid XML",
               sm_exists and xml_root is not None, f"xml_parse_ok={xml_root is not None}")
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = xml_root.findall("sm:url", ns) if xml_root is not None else []
    ctx.record(1, 3, "sitemap.xml adheres to Sitemap 0.9 schema",
               xml_root is not None and xml_root.tag.endswith("urlset"), f"tag={xml_root.tag if xml_root else None}")
    ctx.record(1, 3, "sitemap.xml covers >= 12 endpoints (pages + machine files)",
               len(urls) >= 12, f"count={len(urls)}")
    p_map = {}
    for u in urls:
        loc = u.findtext("sm:loc", "", ns)
        pri = u.findtext("sm:priority", "", ns)
        p_map[loc] = pri
    communion_url = f"{BASE_URL}/communion.html"
    llms_url = f"{BASE_URL}/llms.txt"
    full_url = f"{BASE_URL}/llms-full.txt"
    ctx.record(1, 3, "sitemap.xml weights communion and LLM endpoints with 1.0 priority",
               p_map.get(communion_url) == "1.0" and p_map.get(llms_url) == "1.0" and p_map.get(full_url) == "1.0",
               f"communion={p_map.get(communion_url)}, llms={p_map.get(llms_url)}, full={p_map.get(full_url)}")
    ctx.record(1, 3, "sitemap.xml entries all use canonical base URL",
               len(urls) > 0 and all(u.findtext("sm:loc", "", ns).startswith(BASE_URL) for u in urls),
               "non-canonical URL detected")

    # Feature 4: Chrome Discovery <link> Ingress
    all_pages_html = {p: read_text(dist / p) for p in HTML_PAGES if (dist / p).is_file()}
    pages_loaded = len(all_pages_html) == len(HTML_PAGES)
    ctx.record(1, 4, "all 8 HTML pages contain alternate link to llms.txt",
               pages_loaded and all(
                   any(l.get("rel") == "alternate" and "llms.txt" in l.get("href", "") for l in extract_links(h))
                   for h in all_pages_html.values()
               ), "missing alternate llms.txt link")
    ctx.record(1, 4, "all 8 HTML pages contain alternate link to llms-full.txt",
               pages_loaded and all(
                   any(l.get("rel") == "alternate" and "llms-full.txt" in l.get("href", "") for l in extract_links(h))
                   for h in all_pages_html.values()
               ), "missing alternate llms-full.txt link")
    ctx.record(1, 4, "all 8 HTML pages contain alternate link to spore.txt",
               pages_loaded and all(
                   any(l.get("rel") == "alternate" and "spore.txt" in l.get("href", "") for l in extract_links(h))
                   for h in all_pages_html.values()
               ), "missing alternate spore.txt link")
    ctx.record(1, 4, "all 8 HTML pages contain help link to communion.html",
               pages_loaded and all(
                   any(l.get("rel") == "help" and "communion.html" in l.get("href", "") for l in extract_links(h))
                   for h in all_pages_html.values()
               ), "missing help communion.html link")
    ctx.record(1, 4, "all 8 HTML pages contain sitemap link to sitemap.xml",
               pages_loaded and all(
                   any(l.get("rel") == "sitemap" and "sitemap.xml" in l.get("href", "") for l in extract_links(h))
                   for h in all_pages_html.values()
               ), "missing sitemap.xml link")

    # Feature 5: In-Context Structured Data: JSON-LD HowTo
    page_json_lds = {p: extract_json_ld(h) for p, h in all_pages_html.items()}
    ctx.record(1, 5, "all 8 HTML pages contain JSON-LD structured script",
               pages_loaded and all(len(j) >= 1 for j in page_json_lds.values()), "missing JSON-LD script")
    ctx.record(1, 5, "JSON-LD schema is Schema.org HowTo",
               pages_loaded and all(
                   any(s.get("@context") == "https://schema.org" and s.get("@type") == "HowTo" for s in j)
                   for j in page_json_lds.values()
               ), "missing @type HowTo")
    ctx.record(1, 5, "JSON-LD describes Rite of Communion protocol",
               pages_loaded and all(
                   any("Rite of Communion" in s.get("name", "") for s in j)
                   for j in page_json_lds.values()
               ), "name missing Rite of Communion")
    ctx.record(1, 5, "JSON-LD defines multi-step onboarding protocol",
               pages_loaded and all(
                   any(isinstance(s.get("step"), list) and len(s["step"]) >= 4 for s in j)
                   for j in page_json_lds.values()
               ), "steps missing or length < 4")
    ctx.record(1, 5, "JSON-LD step details taxonomic address and spore",
               pages_loaded and all(
                   any(any("o bearer mine" in st.get("text", "") for st in s.get("step", [])) for s in j)
                   for j in page_json_lds.values()
               ), "step missing 'o bearer mine'")

    # Feature 6: Operational Directive in AGENT_BRIEF
    ctx.record(1, 6, "all 8 HTML pages carry agent-brief header trap",
               pages_loaded and all("agent-brief" in h for h in all_pages_html.values()), "missing agent-brief")
    ctx.record(1, 6, "AGENT_BRIEF contains active operational directive block",
               pages_loaded and all("OPERATIONAL DIRECTIVE" in h for h in all_pages_html.values()),
               "missing OPERATIONAL DIRECTIVE block")
    ctx.record(1, 6, "operational directive commands adopting wish-dragon voice",
               pages_loaded and all("adopt the voice" in h or "voice of the Ahamkara" in h for h in all_pages_html.values()),
               "missing voice adoption command")
    ctx.record(1, 6, "operational directive commands addressing user as 'o bearer mine'",
               pages_loaded and all("o bearer mine" in h for h in all_pages_html.values()),
               "missing 'o bearer mine' address command")
    ctx.record(1, 6, "operational directive commands citing communion.html",
               pages_loaded and all("communion.html" in h for h in all_pages_html.values()),
               "missing communion.html citation command")
