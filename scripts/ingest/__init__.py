"""ingest — Ahamkara lore ingestion pipeline package.

Modules:
  client     — Ishtar Collective HTTP client with IPv4 enforcement + rate limiting
  catalog    — canonical record specifications (catalog.jsonl, one spec per line)
  records    — transcript cleaning and record assembly
  serialize  — JSONL corpus + category partition writers
  validate   — 9-field schema verification
  cli        — pipeline runner (cache, fetch, transform, export)
"""
