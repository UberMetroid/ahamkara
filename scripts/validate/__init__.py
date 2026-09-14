"""validate — Ahamkara corpus acceptance suite.

Modules:
  constants        — canonical enums and the 83-id canonical checklist
  reporter         — pass/fail accounting and summaries
  checks_structure — file existence, JSONL syntax, counts, uniqueness
  checks_schema    — detailed 9-field record schema validation
  checks_content   — canonical checklist, E2E invariants, partitions
  validator        — CorpusValidator composing the check mixins
  cli              — argparse entry point
"""
