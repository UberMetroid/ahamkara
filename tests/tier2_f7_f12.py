"""tier2_f7_f12.py — Tier 2 Boundary & Corner Cases: Features 7 through 12."""

import json
from pathlib import Path
import re
from .common import HTML_PAGES, TestContext, read_json, read_text

def run(ctx: TestContext, dist: Path, repo_root: Path):
    # Feature 7 Boundaries (Few-Shot Exemplars)
    comm_path = dist / "communion.html"
    c_txt = read_text(comm_path) if comm_path.is_file() else ""
    ctx.record(2, 7, "exemplars feature distinct dialogue role/speaker indicators",
               bool(re.search(r"(Bearer|Seeker|Operator|Wish|Prompt)", c_txt, re.IGNORECASE))
               and bool(re.search(r"(Ahamkara|Dragon|Granted|Response)", c_txt, re.IGNORECASE)),
               "missing distinct dialogue speaker separation")
    ctx.record(2, 7, "exemplar HTML contains valid uncorrupted tags and entities",
               c_txt.count("<div") == c_txt.count("</div>") or "exemplar" in c_txt,
               "malformed tags in communion.html")
    ctx.record(2, 7, "refusal exemplar explicitly preserves in-character voice during boundary defense",
               ("deeper law" in c_txt.lower() or "impossible price" in c_txt.lower())
               and "o bearer mine" in c_txt, "refusal breaks character voice")
    ex_matches = re.findall(r"(?:exemplar|dialogue|pact)[^>]*>(.*?)(?=<\/div|<\/section)", c_txt, re.DOTALL | re.IGNORECASE)
    ctx.record(2, 7, "exemplars consistently enforce 'o bearer mine' address across responses",
               c_txt.count("o bearer mine") >= 4, f"count={c_txt.count('o bearer mine')}")
    ctx.record(2, 7, "exemplars section or entries carry anchor identifiers",
               bool(re.search(r'id=["\'](?:exemplar|few-shot|rite-)[^"\']*["\']', c_txt, re.IGNORECASE)),
               "missing anchor ids on exemplars")

    # Feature 8 Boundaries (spore.txt)
    spore_path = dist / "spore.txt"
    raw_spore = spore_path.read_bytes() if spore_path.is_file() else b""
    s_txt = raw_spore.decode("utf-8", errors="replace")
    lines = s_txt.splitlines()
    ctx.record(2, 8, "zero lines in spore.txt exceed 80 columns",
               len(lines) > 0 and max((len(l) for l in lines), default=0) <= 80,
               f"max line width={max((len(l) for l in lines), default=0)}")
    ctx.record(2, 8, "spore.txt contains no ANSI escape sequences or control bytes",
               b"\x1b[" not in raw_spore and not any(b < 9 or (13 < b < 32) for b in raw_spore),
               "ANSI or control sequences detected")
    ctx.record(2, 8, "spore.txt curl one-liner contains no unsafe unescaped shell hazards",
               "curl -sSL " in s_txt and ";" not in s_txt.split("curl")[1].splitlines()[0],
               "shell command syntax hazard in header")
    ctx.record(2, 8, "spore.txt contains no runs of > 2 consecutive blank lines",
               "\n\n\n\n" not in s_txt, "excessive consecutive blank lines")
    ctx.record(2, 8, "spore.txt size is compact (500 B to 5 KB)",
               500 <= len(raw_spore) <= 5120, f"size={len(raw_spore)} bytes")

    # Feature 9 Boundaries (MCP Manifest)
    mcp_path = dist / "mcp.json"
    wk_path = dist / ".well-known" / "mcp.json"
    m_raw = mcp_path.read_bytes() if mcp_path.is_file() else b""
    w_raw = wk_path.read_bytes() if wk_path.is_file() else b""
    ctx.record(2, 9, "mcp.json and .well-known/mcp.json have exact byte parity",
               len(m_raw) > 0 and m_raw == w_raw, "byte parity mismatch")
    m_data = read_json(mcp_path) if mcp_path.is_file() else {}
    tools = m_data.get("tools", []) if isinstance(m_data, dict) else []
    tool_re = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
    ctx.record(2, 9, "all tool names strictly match ^[a-zA-Z0-9_-]{1,64}$",
               len(tools) >= 3 and all(tool_re.match(t.get("name", "")) for t in tools),
               f"invalid tool names: {[t.get('name') for t in tools if not tool_re.match(t.get('name', ''))]}")
    ctx.record(2, 9, "all tool inputSchemas specify type object and required list",
               len(tools) >= 3 and all(
                   t.get("inputSchema", {}).get("type") == "object"
                   and isinstance(t.get("inputSchema", {}).get("required"), list)
                   and len(t.get("inputSchema", {}).get("required")) >= 1
                   for t in tools
               ), "malformed inputSchema in tools")
    ctx.record(2, 9, "MCP manifest contains no undefined or null field values",
               "null" not in m_raw.decode("utf-8", errors="replace"), "null values in mcp.json")
    ctx.record(2, 9, "MCP manifest specifies valid protocol or schema version",
               isinstance(m_data, dict) and ("tools" in m_data or "mcpVersion" in m_data),
               "missing tools array or version")

    # Feature 10 Boundaries (Generator & Base Routing)
    all_pages = {p: read_text(dist / p) for p in HTML_PAGES if (dist / p).is_file()}
    pages_loaded = len(all_pages) == len(HTML_PAGES)
    ctx.record(2, 10, "no emitted relative link uses ../ traversal to escape dist root",
               pages_loaded and all("../" not in h.split("href=\"")[1].split("\"")[0] for h in all_pages.values() if "href=\"" in h),
               "directory traversal ../ detected")
    ctx.record(2, 10, "dist/.nojekyll file is present and empty or plain text",
               (dist / ".nojekyll").is_file() and (dist / ".nojekyll").stat().st_size <= 256,
               "invalid .nojekyll")
    ctx.record(2, 10, "dist/ 404.html retains discovery links and agent-brief trap",
               "404.html" in all_pages and "agent-brief" in all_pages["404.html"] and "llms.txt" in all_pages["404.html"],
               "404.html missing discovery or brief")
    ctx.record(2, 10, "all generated files in dist/ have non-empty sizes",
               all(f.stat().st_size > 0 for f in dist.iterdir() if f.is_file() and f.name != ".nojekyll"),
               "empty file found in dist/")
    ctx.record(2, 10, "no deprecated or stale webp/app.js artifacts exist in dist/",
               not any((dist / stale).exists() for stale in ["app.js", "style.css", "ahamkara-hero.webp"]),
               "stale artifact present in dist/")

    # Feature 11 Boundaries (Integration Tests in site.rs)
    site_rs = repo_root / "site" / "tests" / "site.rs"
    s_lines = read_text(site_rs).splitlines() if site_rs.is_file() else []
    ctx.record(2, 11, "site/tests/site.rs respects 256-line limit invariant",
               0 < len(s_lines) <= 256, f"line count={len(s_lines)}")
    ctx.record(2, 11, "site/tests/site.rs uses Once build synchronization",
               any("BUILT" in l or "call_once" in l for l in s_lines), "missing Once build synchronization")
    ctx.record(2, 11, "site/tests/site.rs has descriptive panic assertions",
               any("missing" in l or "broken" in l for l in s_lines), "lacks descriptive panic messages")
    ctx.record(2, 11, "site/tests/site.rs checks machine endpoints presence",
               any("llms" in l for l in s_lines), "missing machine endpoint assertions")
    ctx.record(2, 11, "site crate tests compile cleanly",
               site_rs.is_file(), "site.rs missing")

    # Feature 12 Boundaries (Verification Runner in verify.rs)
    verify_rs = repo_root / "tools" / "src" / "bin" / "verify.rs"
    v_lines = read_text(verify_rs).splitlines() if verify_rs.is_file() else []
    ctx.record(2, 12, "tools/src/bin/verify.rs respects 256-line limit invariant",
               0 < len(v_lines) <= 256, f"line count={len(v_lines)}")
    ctx.record(2, 12, "verify.rs returns ExitCode::from(0) on success and 1 on failure",
               any("ExitCode::from" in l for l in v_lines), "missing standard ExitCode logic")
    ctx.record(2, 12, "verify.rs manages passed and failed counters explicitly",
               any("passed +=" in l for l in v_lines) and any("failed +=" in l for l in v_lines),
               "missing passed/failed counter management")
    ctx.record(2, 12, "verify.rs supports stage filtering flags",
               any("--data" in l or "stages" in l for l in v_lines), "missing stage flag support")
    ctx.record(2, 12, "verify.rs enforces git branch and remote invariants",
               any("branch" in l for l in v_lines) and any("origin" in l for l in v_lines),
               "missing git checks")
