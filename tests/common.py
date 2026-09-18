"""common.py — Shared test harness utilities for Ahamkara E2E testing."""

import json
import os
import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

BASE_URL = "https://ubermetroid.github.io/ahamkara"
HTML_PAGES = [
    "index.html", "lore.html", "dragons.html", "history.html",
    "wishes.html", "facts.html", "communion.html", "404.html",
]

FEATURE_MILESTONE = {
    1: "M1", 2: "M1", 3: "M1", 4: "M1",
    5: "M2", 6: "M2", 7: "M2", 8: "M2", 9: "M2", 10: "M2",
    11: "M3", 12: "M3",
}

def get_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent

def get_dist_dir(override: str | None = None) -> Path:
    if override:
        p = Path(override).resolve()
        if not p.is_dir():
            raise FileNotFoundError(f"Dist directory not found: {p}")
        return p
    return get_repo_root() / "dist"

class TestContext:
    def __init__(self, milestone: str = "all", verbose: bool = False):
        self.milestone = milestone
        self.verbose = verbose
        self.passed = 0
        self.failed = 0
        self.skipped = 0
        self.results: list[dict] = []

    def should_run_feature(self, feat_num: int) -> bool:
        if self.milestone == "all":
            return True
        feat_ms = FEATURE_MILESTONE.get(feat_num, "M3")
        if self.milestone == "M1":
            return feat_ms == "M1"
        if self.milestone == "M2":
            return feat_ms in ("M1", "M2")
        return True

    def record(self, tier: int, feature: int, name: str, ok: bool, detail: str = ""):
        if not self.should_run_feature(feature):
            self.skipped += 1
            if self.verbose:
                print(f"  SKIP [T{tier}.F{feature}] {name} (Milestone {FEATURE_MILESTONE.get(feature)})")
            return
        status = "PASS" if ok else "FAIL"
        if ok:
            self.passed += 1
        else:
            self.failed += 1
        res = {
            "tier": tier, "feature": feature, "name": name,
            "ok": ok, "detail": detail,
        }
        self.results.append(res)
        if self.verbose or not ok:
            suffix = f" — {detail}" if detail and not ok else ""
            print(f"  {status} [T{tier}.F{feature}] {name}{suffix}")

def read_text(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(f"File not found: {path}")
    return path.read_text(encoding="utf-8")

def read_json(path: Path) -> dict | list:
    content = read_text(path)
    return json.loads(content)

def parse_xml(path: Path) -> ET.Element:
    content = read_text(path)
    return ET.fromstring(content)

def extract_head(html: str) -> str:
    m = re.search(r"<head[^>]*>(.*?)</head>", html, re.DOTALL | re.IGNORECASE)
    return m.group(1) if m else ""

def extract_json_ld(html: str) -> list[dict]:
    head = extract_head(html)
    scripts = re.findall(
        r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        head, re.DOTALL | re.IGNORECASE,
    )
    res = []
    for s in scripts:
        clean = s.strip()
        if clean:
            res.append(json.loads(clean))
    return res

def extract_links(html: str) -> list[dict[str, str]]:
    head = extract_head(html)
    pattern = re.compile(r'<link\s+([^>]+)>', re.IGNORECASE)
    res = []
    for match in pattern.finditer(head):
        attrs_str = match.group(1)
        attrs = dict(re.findall(r'([a-zA-Z0-9_-]+)=["\']([^"\']*)["\']', attrs_str))
        res.append(attrs)
    return res
