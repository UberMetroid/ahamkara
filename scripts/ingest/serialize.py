"""Serialization: canonical JSONL corpus, category partitions, raw cache shards.

All archives are JSONL — one record per line — so no single file exceeds the
repo's 256-line limit and every line is independently diffable.
"""

import json
import os


def _write_jsonl(path: str, records: list):
    with open(path, "wb") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False).encode("utf-8") + b"\n")


def serialize_corpus(records: list, output_dir: str):
    """Write the canonical JSONL corpus and category partition archives."""
    os.makedirs(output_dir, exist_ok=True)
    cats_dir = os.path.join(output_dir, "categories")
    os.makedirs(cats_dir, exist_ok=True)

    # 1. Canonical JSONL corpus (one line per record, strict LF byte 0x0a)
    corpus_jsonl_path = os.path.join(output_dir, "ahamkara_corpus.jsonl")
    _write_jsonl(corpus_jsonl_path, records)

    # 2. Category partitions (JSONL)
    exotics = [r for r in records if r["source"]["type"] in ("exotic_armor", "exotic_weapon")]
    wishes = [r for r in records if r["source"]["type"] == "wall_of_wishes"]
    great_hunt = [
        r for r in records
        if r["source"]["type"] in ("raid_armor", "raid_weapon")
        or "great-hunt" in r["id"]
        or "Great Ahamkara Hunt" in r.get("chronology", "")
        or "Unnamed Great Hunt Dragons" in r.get("entity", [])
    ]
    riven = [r for r in records if "Riven" in r.get("entity", [])]
    taranis = [r for r in records if "Taranis" in r.get("entity", [])]

    partitions = {
        "exotics.jsonl": exotics,
        "great_hunt.jsonl": great_hunt,
        "riven.jsonl": riven,
        "taranis.jsonl": taranis,
        "wishes.jsonl": wishes
    }

    for filename, part_records in partitions.items():
        _write_jsonl(os.path.join(cats_dir, filename), part_records)

    return corpus_jsonl_path, cats_dir


# Raw fetch cache: one JSON file per record id under data/cache/raw/ so no
# cache file can outgrow the repo's per-file line limit.

def load_cache(cache_dir: str) -> dict:
    """Load every cached raw payload; returns {rid: payload}."""
    raw_cache = {}
    if not cache_dir or not os.path.isdir(cache_dir):
        return raw_cache
    for name in sorted(os.listdir(cache_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(cache_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw_cache[name[:-5]] = json.load(f)
        except Exception as e:
            print(f"[WARN] Failed to read cache shard {path}: {e}")
    if raw_cache:
        print(f"[CACHE] Loaded {len(raw_cache)} entries from cache dir: {cache_dir}")
    return raw_cache


def save_cache(cache_dir: str, raw_cache: dict):
    """Persist the raw cache as one file per record id."""
    os.makedirs(cache_dir, exist_ok=True)
    for rid, payload in raw_cache.items():
        path = os.path.join(cache_dir, f"{rid}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
            f.write("\n")
    print(f"[CACHE] Saved {len(raw_cache)} entries to {cache_dir}")
