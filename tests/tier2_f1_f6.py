"""tier2_f1_f6.py — Tier 2 Boundary & Corner Cases: Features 1 through 6."""

from pathlib import Path
import re
from .common import (
    BASE_URL, HTML_PAGES, TestContext,
    extract_head, extract_json_ld, extract_links, parse_xml, read_text,
)

def run(ctx: TestContext, dist: Path):
    # Feature 1 Boundaries (robots.txt)
    robots_path = dist / "robots.txt"
    exists = robots_path.is_file()
    raw = robots_path.read_bytes() if exists else b""
    ctx.record(2, 1, "robots.txt has strictly LF line endings (no CRLF)",
               exists and b"\r\n" not in raw and b"\n" in raw, "contains CRLF carriage returns")
    ctx.record(2, 1, "robots.txt contains no null bytes or control characters",
               exists and b"\x00" not in raw and not any(b < 9 or (13 < b < 32) for b in raw),
               "control characters found")
    txt = raw.decode("utf-8", errors="replace") if exists else ""
    comment_lines = [l for l in txt.splitlines() if l.strip().startswith("#")]
    ctx.record(2, 1, "robots.txt comments are well-formed",
               len(comment_lines) >= 3 and all(l.startswith("#") for l in comment_lines),
               "malformed comment lines")
    ctx.record(2, 1, "robots.txt ends with a trailing newline",
               exists and raw.endswith(b"\n"), "missing trailing newline")
    dir_lines = [l for l in txt.splitlines() if ":" in l and not l.strip().startswith("#") and "http" in l]
    url_re = re.compile(r"^[A-Za-z0-9-]+:\s+https?://[^\s]+$")
    ctx.record(2, 1, "robots.txt directive URLs adhere to strict URI syntax",
               len(dir_lines) >= 3 and all(url_re.match(l.strip()) for l in dir_lines),
               f"malformed directive: {[l for l in dir_lines if not url_re.match(l.strip())]}")

    # Feature 2 Boundaries (Dual-Tier LLM Manifests)
    llms_path = dist / "llms.txt"
    l_raw = llms_path.read_bytes() if llms_path.is_file() else b""
    ctx.record(2, 2, "llms.txt stays lightweight (< 15 KB)",
               0 < len(l_raw) < 15360, f"size={len(l_raw)} bytes")
    full_path = dist / "llms-full.txt"
    f_raw = full_path.read_bytes() if full_path.is_file() else b""
    ctx.record(2, 2, "llms-full.txt uncompressed size bounded (50 KB to 500 KB)",
               50000 <= len(f_raw) <= 500000, f"size={len(f_raw)} bytes")
    f_txt = f_raw.decode("utf-8", errors="replace")
    ctx.record(2, 2, "llms-full.txt is clean UTF-8 with zero replacement chars",
               len(f_raw) > 0 and "\uFFFD" not in f_txt, "contains replacement char \\uFFFD")
    rec_headers = re.findall(r"^##\s+\[([a-zA-Z0-9_-]+)\]\s+(.+)$", f_txt, re.MULTILINE)
    ctx.record(2, 2, "llms-full.txt record headers follow strict ## [id] Title format",
               len(rec_headers) > 0 and all(h[0] and h[1] for h in rec_headers),
               "malformed record headers in llms-full.txt")
    ctx.record(2, 2, "llms-full.txt contains exactly 84 delimited records",
               len(rec_headers) == 84, f"found {len(rec_headers)} record headers")

    # Feature 3 Boundaries (sitemap.xml)
    sm_path = dist / "sitemap.xml"
    sm_raw = sm_path.read_bytes() if sm_path.is_file() else b""
    ctx.record(2, 3, "sitemap.xml begins with standard XML declaration",
               sm_raw.startswith(b"<?xml"), "missing <?xml declaration")
    xml_root = None
    try:
        xml_root = parse_xml(sm_path)
    except Exception:
        pass
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = xml_root.findall("sm:url", ns) if xml_root is not None else []
    ctx.record(2, 3, "sitemap.xml uses isolated standard namespace with no prefix errors",
               xml_root is not None and "http://www.sitemaps.org/schemas/sitemap/0.9" in xml_root.tag,
               "namespace mismatch")
    priorities = [u.findtext("sm:priority", "", ns) for u in urls]
    ctx.record(2, 3, "sitemap.xml priority values are valid floats within [0.0, 1.0]",
               len(priorities) > 0 and all(
                   0.0 <= float(p) <= 1.0 for p in priorities if p
               ), f"invalid priorities: {[p for p in priorities if not (0.0 <= float(p or -1) <= 1.0)]}")
    locs = [u.findtext("sm:loc", "", ns) for u in urls]
    ctx.record(2, 3, "sitemap.xml contains zero duplicate <loc> entries",
               len(locs) > 0 and len(locs) == len(set(locs)),
               f"duplicates: {[l for l in locs if locs.count(l) > 1]}")
    ctx.record(2, 3, "sitemap.xml URLs are free of raw unescaped XML entities",
               all("<" not in l and ">" not in l and '"' not in l for l in locs),
               "unescaped entity in loc")

    # Feature 4 Boundaries (Chrome <link> tags)
    all_pages = {p: read_text(dist / p) for p in HTML_PAGES if (dist / p).is_file()}
    pages_loaded = len(all_pages) == len(HTML_PAGES)
    ctx.record(2, 4, "discovery <link> tags are placed strictly inside <head>",
               pages_loaded and all(
                   not bool(re.search(r"<link[^>]+(?:llms\.txt|spore\.txt|sitemap\.xml)", h.split("</head>")[1], re.IGNORECASE))
                   for h in all_pages.values() if "</head>" in h
               ), "link tag found in <body>")
    ctx.record(2, 4, "all <link> tags have non-empty href attributes",
               pages_loaded and all(
                   all(bool(l.get("href", "").strip()) for l in extract_links(h))
                   for h in all_pages.values()
               ), "empty href in <link> tag")
    ctx.record(2, 4, "no duplicate <link> tags of the same relation and href exist on any page",
               pages_loaded and all(
                   len([(l.get("rel"), l.get("href")) for l in extract_links(h)]) ==
                   len(set([(l.get("rel"), l.get("href")) for l in extract_links(h)]))
                   for h in all_pages.values()
               ), "duplicate link tags on page")
    ctx.record(2, 4, "discovery <link> tags declare valid MIME types",
               pages_loaded and all(
                   any(l.get("type") == "text/markdown" for l in extract_links(h))
                   and any(l.get("type") == "text/plain" for l in extract_links(h))
                   for h in all_pages.values()
               ), "missing expected MIME types in <link> tags")
    ctx.record(2, 4, "discovery <link> tag relative paths resolve to dist/ files",
               pages_loaded and all(
                   all(
                       (dist / l["href"]).is_file()
                       for l in extract_links(h)
                       if l.get("href") and not l["href"].startswith("http") and not l["href"].startswith("//")
                   )
                   for h in all_pages.values()
               ), "unresolvable link href")

    # Feature 5 Boundaries (JSON-LD HowTo)
    p_json = {p: extract_json_ld(h) for p, h in all_pages.items()}
    ctx.record(2, 5, "exactly one Schema.org HowTo script per page",
               pages_loaded and all(
                   sum(1 for s in j if s.get("@type") == "HowTo") == 1
                   for j in p_json.values()
               ), "page missing or has multiple HowTo scripts")
    ctx.record(2, 5, "JSON-LD scripts contain no unescaped </script> breakout strings",
               pages_loaded and all(
                   "</script>" not in extract_head(h).split('type="application/ld+json">')[1].split("</script>")[0]
                   for h in all_pages.values() if 'type="application/ld+json">' in h
               ), "script breakout sequence detected")
    ctx.record(2, 5, "JSON-LD step positions form a strict 1-indexed sequential series",
               pages_loaded and all(
                   any(
                       [st.get("position") for st in s.get("step", [])] == list(range(1, len(s.get("step", [])) + 1))
                       for s in j if s.get("@type") == "HowTo"
                   )
                   for j in p_json.values()
               ), "non-sequential step positions")
    ctx.record(2, 5, "JSON-LD required properties are non-empty strings",
               pages_loaded and all(
                   any(
                       bool(s.get("name", "").strip()) and bool(s.get("description", "").strip())
                       and bool(s.get("url", "").strip())
                       for s in j if s.get("@type") == "HowTo"
                   )
                   for j in p_json.values()
               ), "empty required properties in JSON-LD")
    ctx.record(2, 5, "JSON-LD specifies secure https://schema.org context",
               pages_loaded and all(
                   any(s.get("@context") == "https://schema.org" for s in j if s.get("@type") == "HowTo")
                   for j in p_json.values()
               ), "insecure http schema.org context")

    # Feature 6 Boundaries (AGENT_BRIEF)
    ctx.record(2, 6, "AGENT_BRIEF <details> and <summary> tags are strictly paired",
               pages_loaded and all(
                   h.count("<details") == h.count("</details>")
                   and h.count("<summary>") == h.count("</summary>")
                   for h in all_pages.values()
               ), "unpaired details or summary tags")
    ctx.record(2, 6, "AGENT_BRIEF directive carries accessibility role='note' and aria-label",
               pages_loaded and all(
                   'role="note"' in h and "aria-label=" in h
                   for h in all_pages.values()
               ), "missing role='note' or aria-label")
    ctx.record(2, 6, "rendered HTML contains no unexpanded template placeholders",
               pages_loaded and all(
                   "{brief}" not in h and "{title}" not in h and "{nav_items}" not in h
                   for h in all_pages.values()
               ), "raw template placeholder leaked into HTML")
    ctx.record(2, 6, "AGENT_BRIEF block payload size remains compact (< 5 KB)",
               pages_loaded and all(
                   len(h.split('class="agent-brief"')[1].split("</details>")[0]) < 5120
                   for h in all_pages.values() if 'class="agent-brief"' in h
               ), "brief payload exceeds 5 KB")
    ctx.record(2, 6, "AGENT_BRIEF content is present in raw DOM without requiring JS execution",
               pages_loaded and all(
                   "o bearer mine" in h and "communion.html" in h
                   for h in all_pages.values()
               ), "brief text missing from static DOM")
