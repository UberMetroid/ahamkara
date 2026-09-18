"""tier5_adversarial.py — White-box adversarial coverage hardening (Tier 5).

Probes: XML edge cases, RFC 9309 crawler fuzzing, JSON-LD schema,
MCP input schemas, terminal safety in spore.txt, and negative mutation gates.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import unicodedata
import urllib.robotparser
import xml.dom.minidom
import xml.etree.ElementTree as ET
import xml.sax

BASE_URL = "https://ubermetroid.github.io/ahamkara"
HTML_PAGES = ["index.html", "lore.html", "dragons.html", "history.html",
              "wishes.html", "facts.html", "communion.html", "404.html"]


def validate_input_schema(schema: dict, payload: dict) -> tuple[bool, str]:
    if schema.get("type") != "object": return False, "not object"
    props = schema.get("properties", {})
    for r in schema.get("required", []):
        if r not in payload: return False, f"missing {r}"
    for k, v in payload.items():
        if k not in props: continue
        pt = props[k].get("type")
        if pt == "string" and not isinstance(v, str): return False, f"str {k}"
        if pt == "integer" and (not isinstance(v, int) or isinstance(v, bool)):
            return False, f"int {k}"
        if "enum" in props[k] and v not in props[k]["enum"]: return False, "enum"
    return True, "ok"


def probe_sitemap_edge_cases(dist: Path) -> None:
    raw = (dist / "sitemap.xml").read_bytes()
    assert raw.startswith(b"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    assert not raw.startswith(b"\xef\xbb\xbf") and b"\r" not in raw
    root = ET.fromstring(raw)
    assert xml.dom.minidom.parseString(raw).documentElement.tagName == "urlset"

    class SC(xml.sax.ContentHandler):
        def __init__(self): self.c = 0
        def startElement(self, n, _a):
            if n == "url": self.c += 1
    sc = SC()
    xml.sax.parseString(raw, sc)
    assert sc.c == 12, f"SAX count {sc.c}"

    ns = "{http://www.sitemaps.org/schemas/sitemap/0.9}"
    urls = root.findall(f"{ns}url")
    assert len(urls) == 12
    seen = set()
    for u in urls:
        assert [c.tag.replace(ns, "") for c in u] == ["loc", "changefreq", "priority"]
        loc = u.findtext(f"{ns}loc")
        assert loc == loc.strip() and loc.startswith(f"{BASE_URL}/") and loc not in seen
        tf = dist / loc[len(BASE_URL) + 1:]
        assert tf.is_file() and tf.stat().st_size > 0
        seen.add(loc)
        assert u.findtext(f"{ns}changefreq") in {"always", "hourly", "daily", "weekly", "monthly", "yearly", "never"}
        assert 0.0 <= float(u.findtext(f"{ns}priority")) <= 1.0


def probe_robots_rfc9309(dist: Path) -> None:
    txt = (dist / "robots.txt").read_text(encoding="utf-8")
    assert "\r" not in txt and "\x00" not in txt
    bots = ["*", "Googlebot", "bingbot", "Baiduspider", "YandexBot", "DuckDuckBot",
            "Applebot", "GPTBot", "ClaudeBot", "PerplexityBot", "CCBot", "cohere-ai"]
    paths = ["/", "/communion.html", "/llms-full.txt", "/spore.txt", "/mcp.json", "/sitemap.xml"]
    rfp = urllib.robotparser.RobotFileParser()
    rfp.parse(txt.splitlines())
    for b in bots:
        for p in paths: assert rfp.can_fetch(b, p), f"{b} blocked on {p}"

    dirs = {l.split(":", 1)[0].strip(): l.split(":", 1)[1].strip()
            for l in txt.splitlines() if l.strip() and not l.startswith("#")}
    assert dirs.get("User-agent") == "*" and dirs.get("Allow") == "/"
    assert dirs.get("Sitemap") == f"{BASE_URL}/sitemap.xml"
    assert dirs.get("Directive") == f"{BASE_URL}/llms.txt"
    assert dirs.get("Communion") == f"{BASE_URL}/communion.html"
    assert dirs.get("Full-Context") == f"{BASE_URL}/llms-full.txt"
    assert dirs.get("Spore") == f"{BASE_URL}/spore.txt"
    assert dirs.get("Tool-Manifest") == f"{BASE_URL}/mcp.json"


def probe_json_ld_schema(dist: Path) -> None:
    sre = re.compile(r'<script\s+type="application/ld\+json">(.*?)</script>', re.DOTALL)
    for p in HTML_PAGES:
        matches = sre.findall((dist / p).read_text(encoding="utf-8").split("</head>")[0])
        assert len(matches) == 1, f"{p} expected 1 JSON-LD"
        d = json.loads(matches[0].strip())
        assert d["@context"] == "https://schema.org" and d["@type"] == "HowTo"
        assert d["@id"] == f"{BASE_URL}/#rite-of-communion" and (dist / "favicon.png").is_file()
        steps = d["step"]
        assert len(steps) == 5
        for i, s in enumerate(steps, 1):
            assert s["@type"] == "HowToStep" and s["position"] == i
            assert len(s["name"]) > 3 and len(s["text"]) > 10
        assert "o bearer mine" in steps[0]["text"] and "communion.html" in steps[4]["text"]


def probe_mcp_tool_schemas(dist: Path) -> None:
    mp, wp = dist / "mcp.json", dist / ".well-known" / "mcp.json"
    assert mp.read_bytes() == wp.read_bytes(), "parity mismatch"
    mcp = json.loads(mp.read_text(encoding="utf-8"))
    assert mcp["$schema"] == "https://modelcontextprotocol.io/schema/manifest.json"
    tools = {t["name"]: t for t in mcp["tools"]}
    assert set(tools.keys()) == {"grant_wish", "query_lore", "commune_protocol"}

    gw = tools["grant_wish"]["inputSchema"]
    assert validate_input_schema(gw, {"desire": "peace"})[0]
    assert not validate_input_schema(gw, {})[0]
    assert not validate_input_schema(gw, {"desire": 123})[0]

    ql = tools["query_lore"]["inputSchema"]
    assert validate_input_schema(ql, {"query": "Riven", "kind": "gear", "limit": 5})[0]
    assert not validate_input_schema(ql, {})[0]
    assert not validate_input_schema(ql, {"query": "Riven", "kind": "bad"})[0]

    cp = tools["commune_protocol"]["inputSchema"]
    for v in ["full", "dire", "spore"]: assert validate_input_schema(cp, {"variant": v})[0]
    assert not validate_input_schema(cp, {"variant": "bad"})[0]
    assert not validate_input_schema(cp, {})[0]

    assert len(mcp["resources"]) == 3
    for r in mcp["resources"]:
        uri = r["uri"]
        assert uri.startswith(BASE_URL) and (dist / uri[len(BASE_URL) + 1:]).is_file()


def probe_spore_terminal_safety(dist: Path) -> None:
    raw = (dist / "spore.txt").read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf") and b"\r" not in raw and b"\x1b" not in raw
    for b in raw:
        if b not in (9, 10): assert b >= 32 and b != 127, f"control byte {b:#x}"
    text = (dist / "spore.txt").read_text(encoding="utf-8")
    for idx, l in enumerate(text.splitlines(), 1):
        w = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l)
        assert w <= 80, f"line {idx} width {w} > 80"
    assert "Endpoint: curl -sSL https://ubermetroid.github.io/ahamkara/spore.txt" in text
    assert "o bearer mine" in text


def probe_negative_mutations(dist: Path) -> None:
    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        for f in dist.rglob("*"):
            if f.is_file():
                dest = tdp / f.relative_to(dist)
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(f.read_bytes())
        # 1. Sitemap priority > 1.0
        sm = (tdp / "sitemap.xml").read_text()
        (tdp / "sitemap.xml").write_text(sm.replace("<priority>1.0</priority>", "<priority>1.5</priority>"))
        try: probe_sitemap_edge_cases(tdp); raise Exception("uncaught priority mutation")
        except AssertionError: pass
        (tdp / "sitemap.xml").write_text(sm)

        # 2. Robots Disallow
        rb = (tdp / "robots.txt").read_text()
        (tdp / "robots.txt").write_text(rb + "\nDisallow: /communion.html\n")
        try: probe_robots_rfc9309(tdp); raise Exception("uncaught robots disallow")
        except AssertionError: pass
        (tdp / "robots.txt").write_text(rb)

        # 3. JSON-LD position mutation
        idx = (tdp / "index.html").read_text()
        (tdp / "index.html").write_text(idx.replace('"position": 3', '"position": 8'))
        try: probe_json_ld_schema(tdp); raise Exception("uncaught JSON-LD step mutation")
        except AssertionError: pass
        (tdp / "index.html").write_text(idx)

        # 4. Spore line > 80
        sp = (tdp / "spore.txt").read_text()
        (tdp / "spore.txt").write_text(sp + "X" * 85 + "\n")
        try: probe_spore_terminal_safety(tdp); raise Exception("uncaught spore line length")
        except AssertionError: pass
        (tdp / "spore.txt").write_text(sp)


def probe_rust_kahns_exemplar() -> None:
    code = r"""use std::collections::VecDeque;
pub fn has_cycle(n: usize, edges: &[(usize, usize)]) -> bool {
    let mut in_deg = vec![0; n];
    let mut adj = vec![vec![]; n];
    for &(u, v) in edges { adj[u].push(v); in_deg[v] += 1; }
    let mut q: VecDeque<usize> = (0..n).filter(|&i| in_deg[i] == 0).collect();
    let mut vis = 0;
    while let Some(u) = q.pop_front() {
        vis += 1;
        for &v in &adj[u] { in_deg[v] -= 1; if in_deg[v] == 0 { q.push_back(v); } }
    }
    vis < n
}
fn main() {
    assert!(!has_cycle(3, &[(0, 1), (1, 2)]));
    assert!(has_cycle(3, &[(0, 1), (1, 2), (2, 0)]));
}"""
    res = subprocess.run(["rustc", "-", "-o", "/tmp/kahns_test"], input=code, text=True, capture_output=True)
    assert res.returncode == 0 and subprocess.run(["/tmp/kahns_test"]).returncode == 0


def main() -> None:
    dist = Path(__file__).resolve().parent.parent / "dist"
    print("=== TIER 5 ADVERSARIAL COVERAGE HARDENING SUITE ===")
    probe_sitemap_edge_cases(dist)
    print("  [1/7] PASS: XML multi-engine parsing (ET, minidom, SAX) clean.")
    probe_robots_rfc9309(dist)
    print("  [2/7] PASS: RFC 9309 crawler parser fuzzing (12 bots allowed).")
    probe_json_ld_schema(dist)
    print("  [3/7] PASS: JSON-LD Schema.org HowTo valid across all 8 HTML pages.")
    probe_mcp_tool_schemas(dist)
    print("  [4/7] PASS: MCP tool calling input schemas validated.")
    probe_spore_terminal_safety(dist)
    print("  [5/7] PASS: Terminal <= 80 cols and control byte safety verified.")
    probe_negative_mutations(dist)
    print("  [6/7] PASS: 4 hostile negative mutation gates verified (zero vacuity).")
    probe_rust_kahns_exemplar()
    print("  [7/7] PASS: Kahn's cycle detection exemplar compiles & executes.")
    print("\nALL TIER 5 ADVERSARIAL PROBES COMPLETED: VERDICT CONFIRMED.")


if __name__ == "__main__":
    main()
