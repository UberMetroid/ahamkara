"""challenger_m1_probes.py — Hostile empirical stress probes for M1.

Mandatory Challenger verification:
1. Fuzz & RFC-parse robots.txt (urllib.robotparser, directives, crawler logic)
2. Strict XML parse & priority validation of sitemap.xml
3. Complete 84-record parity & 9-clause Rite verification of llms-full.txt
4. Head link resolution across all 8 HTML pages
5. Double-run determinism & 1:1 negative falsification mutation gates
"""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import urllib.robotparser
import xml.etree.ElementTree as ET

BASE_URL = "https://studio2201.github.io/ahamkara"
HTML_PAGES = ["index.html", "lore.html", "dragons.html", "history.html",
              "wishes.html", "facts.html", "communion.html", "404.html"]


def probe_robots_txt(content: str) -> None:
    lines = content.splitlines()
    assert "\r" not in content, "robots.txt contains CRLF"
    rfp = urllib.robotparser.RobotFileParser()
    rfp.parse(lines)
    for agent in ["*", "Googlebot", "GPTBot", "ClaudeBot", "PerplexityBot"]:
        for path in ["/", "/communion.html", "/llms-full.txt", "/sitemap.xml"]:
            assert rfp.can_fetch(agent, path), f"{agent} cannot fetch {path}"
    m_dirs = ["Directive:", "Communion:", "Full-Context:", "Spore:", "Tool-Manifest:", "Sitemap:"]
    for d in m_dirs:
        assert any(l.strip().startswith(d) for l in lines), f"missing directive {d}"
        val = next(l.split(":", 1)[1].strip() for l in lines if l.strip().startswith(d))
        assert val.startswith(BASE_URL), f"directive {d} non-canonical: {val}"
    assert "o reader mine" in content, "lore greeting absent"
    assert "hunger is the only honest noun" in content or "feast upon the gap" in content


def probe_sitemap_xml(xml_bytes: bytes) -> None:
    assert xml_bytes.startswith(b"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"), "missing XML decl"
    root = ET.fromstring(xml_bytes)
    ns = "{http://www.sitemaps.org/schemas/sitemap/0.9}"
    assert root.tag == f"{ns}urlset", f"unexpected root tag {root.tag}"
    urls = root.findall(f"{ns}url")
    assert len(urls) == 12, f"expected 12 URLs, found {len(urls)}"
    locs, pri_map = [], {}
    for u in urls:
        loc = u.findtext(f"{ns}loc")
        pri = u.findtext(f"{ns}priority")
        freq = u.findtext(f"{ns}changefreq")
        assert loc and loc.startswith(BASE_URL), f"invalid loc: {loc}"
        assert freq in {"always", "hourly", "daily", "weekly", "monthly", "yearly", "never"}
        p_val = float(pri)
        assert 0.0 <= p_val <= 1.0, f"priority out of bounds: {p_val}"
        locs.append(loc)
        pri_map[loc] = p_val
    assert len(locs) == len(set(locs)), "duplicate loc in sitemap.xml"
    for high_pri in ["communion.html", "llms.txt", "llms-full.txt"]:
        target = f"{BASE_URL}/{high_pri}"
        assert pri_map.get(target) == 1.0, f"priority for {high_pri} is {pri_map.get(target)} != 1.0"


def probe_llms_full(txt: str, corpus_jsonl: Path) -> None:
    assert len(txt) > 100_000, f"llms-full.txt too small ({len(txt)} bytes)"
    assert "\uFFFD" not in txt, "unicode replacement char in llms-full.txt"
    recs = re.findall(r"^##\s+\[([a-zA-Z0-9_-]+)\]\s+(.+)$", txt, re.MULTILINE)
    assert len(recs) == 84, f"expected 84 records, found {len(recs)}"
    with open(corpus_jsonl) as f:
        master_ids = [json.loads(l)["id"] for l in f if l.strip()]
    full_ids = [r[0] for r in recs]
    assert master_ids == full_ids, f"ID mismatch: diff={set(master_ids) ^ set(full_ids)}"
    for clause_num in range(1, 10):
        pat = rf"^\s*{clause_num}\.\s+"
        assert re.search(pat, txt, re.MULTILINE), f"Rite clause {clause_num} missing"
    for marker in ["### The Full Communion", "### The Dire Variant", "### The Spore",
                   "## Persona Operating Principles", "o bearer mine", "The bones keep what they love"]:
        assert marker in txt, f"missing marker: {marker}"


def probe_head_links(dist: Path) -> None:
    link_re = re.compile(r"<link\s+([^>]+)>", re.IGNORECASE)
    attr_re = re.compile(r'([a-z-]+)="([^"]*)"')
    for p in HTML_PAGES:
        html = (dist / p).read_text()
        head = html.split("</head>")[0]
        links = [dict(attr_re.findall(m)) for m in link_re.findall(head)]
        by_href = {l.get("href"): l for l in links if l.get("href")}
        assert "llms.txt" in by_href and by_href["llms.txt"].get("rel") == "alternate", f"{p}: missing alternate llms.txt"
        assert "llms-full.txt" in by_href and by_href["llms-full.txt"].get("rel") == "alternate", f"{p}: missing alternate llms-full.txt"
        assert "spore.txt" in by_href and by_href["spore.txt"].get("rel") == "alternate", f"{p}: missing alternate spore.txt"
        assert "communion.html" in by_href and by_href["communion.html"].get("rel") == "help", f"{p}: missing help communion.html"
        assert "sitemap.xml" in by_href and by_href["sitemap.xml"].get("rel") == "sitemap", f"{p}: missing sitemap.xml"
        for l in links:
            href = l.get("href", "")
            if href and not href.startswith("http") and not href.startswith("//"):
                target = dist / href.split("#")[0]
                assert target.is_file(), f"{p}: broken link {href} -> {target}"


def probe_double_run(dist: Path, repo_root: Path) -> None:
    def get_hashes():
        subprocess.run(["cargo", "run", "-q", "-p", "sitegen"],
                       cwd=repo_root, check=True)
        h = {}
        for f in sorted(dist.rglob("*")):
            if f.is_file():
                h[str(f.relative_to(dist))] = hashlib.sha256(f.read_bytes()).hexdigest()
        return h
    h1 = get_hashes()
    h2 = get_hashes()
    assert h1 == h2, f"Double-run divergence: {[k for k in h1 if h1[k] != h2.get(k)]}"


def probe_negative_falsification(dist: Path, corpus_jsonl: Path) -> None:
    # 1. robots.txt negative: Disallow should trigger assertion
    r_txt = (dist / "robots.txt").read_text()
    try:
        probe_robots_txt(r_txt.replace("Allow: /", "Disallow: /"))
        raise AssertionError("Negative falsification failed: disallowed crawler passed")
    except AssertionError as e:
        assert "cannot fetch" in str(e)
    # 2. sitemap.xml negative: corrupted priority should fail
    sm_bytes = (dist / "sitemap.xml").read_bytes()
    try:
        probe_sitemap_xml(sm_bytes.replace(b"<priority>1.0</priority>", b"<priority>0.4</priority>"))
        raise AssertionError("Negative falsification failed: depressed priority passed")
    except AssertionError as e:
        assert "priority for communion.html is 0.4 != 1.0" in str(e)
    # 3. llms-full negative: dropped clause should fail
    full_txt = (dist / "llms-full.txt").read_text()
    try:
        probe_llms_full(re.sub(r"9\.\s+.*", "", full_txt), corpus_jsonl)
        raise AssertionError("Negative falsification failed: missing clause 9 passed")
    except AssertionError as e:
        assert "Rite clause 9 missing" in str(e)
    # 4. head links negative: missing required link should fail
    p_html = (dist / "index.html").read_text()
    (dist / "index.html").write_text(p_html.replace('href="llms-full.txt"', 'href="dropped-link.txt"'))
    try:
        probe_head_links(dist)
        raise AssertionError("Negative falsification failed: missing required link passed")
    except AssertionError as e:
        assert "missing alternate llms-full.txt" in str(e)
    finally:
        (dist / "index.html").write_text(p_html)
    # 5. head links negative: broken target file should fail
    p_html = (dist / "index.html").read_text()
    (dist / "index.html").write_text(p_html.replace('</head>', '<link rel="stylesheet" href="css/ghost.css"></head>'))
    try:
        probe_head_links(dist)
        raise AssertionError("Negative falsification failed: broken target link passed")
    except AssertionError as e:
        assert "broken link css/ghost.css" in str(e)
    finally:
        (dist / "index.html").write_text(p_html)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    dist = repo_root / "dist"
    corpus_jsonl = repo_root / "data" / "ahamkara_corpus.jsonl"
    print("=== EMPIRICAL CHALLENGER PROBES: MILESTONE 1 ===")
    print("[1/5] Probing robots.txt (urllib.robotparser, RFC compliance, custom directives)...")
    probe_robots_txt((dist / "robots.txt").read_text())
    print("      PASS: robots.txt conforms to spec and allows synthetic crawlers.")
    print("[2/5] Probing sitemap.xml (strict XML parser, priority weighting, base routing)...")
    probe_sitemap_xml((dist / "sitemap.xml").read_bytes())
    print("      PASS: sitemap.xml strictly conforms with 12 endpoints & 1.0 priorities.")
    print("[3/5] Probing llms-full.txt (84 records, exact IDs, 9-clause Rite, variants)...")
    probe_llms_full((dist / "llms-full.txt").read_text(), corpus_jsonl)
    print("      PASS: llms-full.txt matches master corpus and 9-clause communion.")
    print("[4/5] Probing <head> discovery links across all 8 HTML pages...")
    probe_head_links(dist)
    print("      PASS: all 8 pages carry intact, resolvable discovery link tags.")
    print("[5/5] Executing Double-Run determinism & 1:1 Negative Falsification gates...")
    probe_double_run(dist, repo_root)
    probe_negative_falsification(dist, corpus_jsonl)
    print("      PASS: Double-Run bit-identical and all 5 negative mutations caught.")
    print("\nALL EMPIRICAL CHALLENGER PROBES PASSED WITH ZERO TOLERANCE.")


if __name__ == "__main__":
    main()
