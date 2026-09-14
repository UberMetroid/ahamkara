#!/usr/bin/env python3
"""
Ahamkara Lore Corpus Validator
==============================
Automated verification suite and acceptance tester for Milestone 2:
Ahamkara Lore Ingestion & Structured Preservation.

Validates (see scripts/validate/):
1. JSONL stream syntax and formatting (LF endings, trailing LF, per-line parse).
2. Canonical record count (>= 65 entries; 84 expected).
3. 9-field schema compliance (id, title, source, entity, speaker, transcript, tags, chronology, theme).
4. Strict kebab-case IDs and 0 duplicate IDs.
5. All canonical entity taxonomy enums and presence of major entities.
6. All standardized chronology (7) and theme (7) enums.
7. Clean markdown transcripts with HTML stripped and paracausal brackets preserved.
8. Non-empty string or null speaker (never empty string "").
9. Source object integrity (bungie_ref defined, distinct releases >= 4, valid types/games).
10. All 83 canonical checklist items across all 9 source categories.
11. E2E test invariants for Tier 1, Tier 2, and Tier 4 (Bones of Eao, 15th Wish, Skull, etc.).
12. Category partition consistency in data/categories/*.jsonl.

Exit codes:
0 = All validation checks passed.
1 = One or more validation failures detected.
2 = Invocation error (missing arguments, unreadable files).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from validate.cli import main

if __name__ == "__main__":
    main()
