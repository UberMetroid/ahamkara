#!/usr/bin/env python3
"""
scripts/ingest_lore.py — Automated Ahamkara Lore Ingestion Pipeline

Ingests canonical Ahamkara lore records from the Ishtar Collective API
(https://api.ishtar-collective.net/) and normalizes them into structured
JSONL archives and categorized partitions.

Layout (see scripts/ingest/):
  catalog.jsonl — canonical record specifications (one spec per line)
  client.py     — Ishtar HTTP client (IPv4 enforcement, rate limiting, retries)
  records.py    — transcript cleaning + record assembly
  serialize.py  — JSONL corpus/partition writers + raw-cache shard I/O
  validate.py   — 9-field schema verification
  cli.py        — pipeline runner
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ingest.cli import main

if __name__ == "__main__":
    main()
