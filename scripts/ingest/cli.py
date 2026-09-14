"""Pipeline runner: load catalog, hydrate from cache/API, normalize, export."""

import argparse
import json
import os
import sys

from .client import IshtarClient
from .records import build_record
from .serialize import load_cache, save_cache, serialize_corpus
from .validate import validate_records

PACKAGE_DIR = os.path.dirname(os.path.abspath(__file__))
CATALOG_PATH = os.path.join(PACKAGE_DIR, "catalog.jsonl")


def load_catalog() -> list:
    """Load the canonical record specification (one JSON object per line)."""
    specs = []
    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                specs.append(json.loads(line))
    return specs


def resolve_cache_dir(args) -> str:
    """Pick the raw-cache shard directory (one JSON file per record id)."""
    if args.cache_dir:
        return args.cache_dir
    candidates = [
        os.path.join(args.output_dir, "cache", "raw"),
        os.path.join(PACKAGE_DIR, "..", "..", "data", "cache", "raw"),
        os.path.join("data", "cache", "raw"),
    ]
    for p in candidates:
        if os.path.isdir(p):
            return os.path.normpath(p)
    return os.path.normpath(candidates[0])


def main():
    parser = argparse.ArgumentParser(description="Ingest canonical Ahamkara lore records.")
    parser.add_argument("--fetch-live", action="store_true", help="Force fetching from live Ishtar API over IPv4")
    parser.add_argument("--offline", action="store_true", help="Strict offline mode: load exclusively from local cache")
    parser.add_argument("--cache-dir", default="", help="Path to raw cache shard directory")
    parser.add_argument("--output-dir", default="data", help="Output directory for generated archives")
    parser.add_argument("--rate-limit", type=float, default=0.1, help="Rate limit delay in seconds (default: 0.1)")
    parser.add_argument("--verify", action="store_true", help="Run schema verification on generated corpus")
    args = parser.parse_args()

    catalog = load_catalog()
    cache_dir = resolve_cache_dir(args)
    raw_cache = load_cache(cache_dir)

    client = IshtarClient(rate_limit=args.rate_limit)
    updated_cache = False

    if args.fetch_live or (not args.offline and len(raw_cache) < len(catalog)):
        print(f"[INGEST] Fetching records from Ishtar API ({len(catalog)} items)...")
        for spec in catalog:
            rid = spec["id"]
            if not args.fetch_live and rid in raw_cache:
                continue

            path = spec["api_path"]
            doc_type = spec["doc_type"]
            res = client.fetch(path)
            if res and isinstance(res, dict) and doc_type in res:
                raw_cache[rid] = {
                    "id": rid,
                    "api_path": path,
                    "doc_type": doc_type,
                    "data": res[doc_type]
                }
                updated_cache = True
                print(f"  + Fetched: {rid}")
            else:
                print(f"  ! Fallback for: {rid}")

        if updated_cache:
            save_cache(cache_dir, raw_cache)

    normalized_records = []
    missing = []
    for spec in catalog:
        rid = spec["id"]
        if rid in raw_cache:
            normalized_records.append(build_record(spec, raw_cache[rid]))
        else:
            missing.append(rid)

    if missing:
        print(f"[WARN] {len(missing)} records missing from cache/fetch: {missing}")

    print(f"[TRANSFORM] Processed {len(normalized_records)} normalized records.")

    jsonl_path, cats_dir = serialize_corpus(normalized_records, args.output_dir)
    print(f"[EXPORT] Created:\n  - {jsonl_path}\n  - {cats_dir}")

    if args.verify or True:
        if not validate_records(normalized_records):
            sys.exit(1)

    print("[DONE] Lore ingestion pipeline successfully finished.")
