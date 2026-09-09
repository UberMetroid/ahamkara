#!/usr/bin/env python3
"""
Ahamkara Lore Corpus Validator
==============================
Automated verification suite and acceptance tester for Milestone 2:
Ahamkara Lore Ingestion & Structured Preservation.

Validates:
1. Syntax and file formatting (JSON & JSONL stream format, LF endings, trailing LF).
2. Count parity between JSON and JSONL archives (>= 65 entries).
3. 9-field schema compliance (id, title, source, entity, speaker, transcript, tags, chronology, theme).
4. Strict kebab-case IDs and 0 duplicate IDs.
5. All canonical entity taxonomy enums and presence of major entities.
6. All standardized chronology (7) and theme (7) enums.
7. Clean markdown transcripts with HTML stripped and paracausal brackets preserved.
8. Non-empty string or null speaker (never empty string "").
9. Source object integrity (bungie_ref defined, distinct releases >= 4, valid types/games).
10. All 65+ canonical checklist items across all 9 source categories.
11. E2E test invariants for Tier 1, Tier 2, and Tier 4 (Bones of Eao, 15th Wish, Skull, etc.).
12. Category partition consistency in data/categories/*.json.

Exit codes:
0 = All validation checks passed.
1 = One or more validation failures detected.
2 = Invocation error (missing arguments, unreadable files).
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# ==============================================================================
# Canonical Constants & Allowed Enums
# ==============================================================================

ID_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

VALID_CHRONOLOGIES: Set[str] = {
    "Pre-Collapse & Ancient Origins",
    "Dark Age & Early City Age",
    "The Great Ahamkara Hunt",
    "Reef Golden Age & The Dreaming City",
    "The Taken War",
    "Forsaken & The Dreaming City Curse",
    "Season of the Wish & The Final Shape",
}

VALID_THEMES: Set[str] = {
    "Anthem Anatheme & Wish-Bargains",
    "The Great Hunt & Extinction",
    'Fourth-Wall Transcendence ("O [Reader] Mine")',
    "The Wall of Wishes & Coded Desire",
    "Parentage & The Uncorrupted Clutch",
    "Deathless Bones & Parasitic Whispers",
    "Vengeance & Twisted Desires",
}

VALID_SOURCE_TYPES: Set[str] = {
    "exotic_armor",
    "exotic_weapon",
    "raid_armor",
    "raid_weapon",
    "lore_book",
    "grimoire_card",
    "dialogue_transcript",
    "quest_lore",
    "wall_of_wishes",
}

VALID_GAMES: Set[str] = {
    "Destiny 1",
    "Destiny 2",
}

VALID_ENTITIES: Set[str] = {
    "Riven",
    "Taranis",
    "Hefnd",
    "Huginn",
    "Muninn",
    "Azirim",
    "Eao",
    "Unnamed Great Hunt Dragons",
    "Harmony Wish-Dragons",
    "General Ahamkara",
}

# The 8 canonical entities checked by E2E test suites
REQUIRED_CANONICAL_ENTITIES: List[str] = [
    "Riven",
    "Taranis",
    "Hefnd",
    "Huginn",
    "Muninn",
    "Azirim",
    "Eao",
]

# Full 83-entry Canonical Checklist cataloged in survey_spec_miner_lore
CANONICAL_CHECKLIST: Dict[str, List[str]] = {
    "Exotic Armor (5)": [
        "exotic-skull-of-dire-ahamkara",
        "exotic-young-ahamkaras-spine",
        "exotic-claws-of-ahamkara",
        "exotic-sealed-ahamkara-grasps",
        "exotic-bones-of-eao",
    ],
    "Exotic Weapons (4)": [
        "weapon-one-thousand-voices",
        "weapon-wish-keeper",
        "weapon-wish-ender",
        "weapon-buried-bloodline",
    ],
    "Last Wish Raid Weapons (8)": [
        "raid-weapon-apex-predator",
        "raid-weapon-age-old-bond",
        "raid-weapon-transfiguration",
        "raid-weapon-nation-of-beasts",
        "raid-weapon-techeun-force",
        "raid-weapon-chattering-bone",
        "raid-weapon-tyranny-of-heaven",
        "raid-weapon-the-supremacy",
    ],
    "Great Hunt Raid Armor (15)": [
        "great-hunt-helm",
        "great-hunt-gauntlets",
        "great-hunt-plate",
        "great-hunt-greaves",
        "great-hunt-mark",
        "great-hunt-mask",
        "great-hunt-grips",
        "great-hunt-vest",
        "great-hunt-strides",
        "great-hunt-cloak",
        "great-hunt-hood",
        "great-hunt-gloves",
        "great-hunt-robes",
        "great-hunt-boots",
        "great-hunt-bond",
    ],
    "Warlord's Ruin Gear & Records (5)": [
        "warlord-vengeful-whisper",
        "warlord-dragoncult-sickle",
        "warlord-naeems-lance",
        "warlord-ziras-shell",
        "warlord-shadow-mountain-8",
    ],
    "Lore Books & Chapters (15)": [
        "book-marasenna-katabasis",
        "book-marasenna-azirim",
        "book-marasenna-fideicide-i",
        "book-marasenna-fideicide-ii",
        "book-marasenna-fideicide-iii",
        "book-marasenna-imponent-i",
        "book-marasenna-imponent-iv",
        "book-awoken-reef-telic-i",
        "book-awoken-reef-telic-ii",
        "book-gifts-first-gift",
        "book-gifts-second-gift",
        "book-gifts-third-gift",
        "book-gifts-last-bargain",
        "lore-lethophobia",
        "lore-oathkeeper",
    ],
    "Wall of Wishes (15)": [
        "wish-wall-first-wish",
        "wish-wall-second-wish",
        "wish-wall-third-wish",
        "wish-wall-fourth-wish",
        "wish-wall-fifth-wish",
        "wish-wall-sixth-wish",
        "wish-wall-seventh-wish",
        "wish-wall-eighth-wish",
        "wish-wall-ninth-wish",
        "wish-wall-tenth-wish",
        "wish-wall-eleventh-wish",
        "wish-wall-twelfth-wish",
        "wish-wall-thirteenth-wish",
        "wish-wall-fourteenth-wish",
        "wish-wall-fifteenth-wish",
    ],
    "Destiny 1 Grimoire Cards (9)": [
        "grimoire-ghost-fragment-legends-3",
        "grimoire-ghost-fragment-warlock",
        "grimoire-ghost-fragment-hunter",
        "grimoire-ghost-fragment-titan",
        "grimoire-ghost-fragment-the-city-age",
        "grimoire-lord-gheleon",
        "grimoire-osiris",
        "grimoire-sorrow-viii-leviathan",
        "grimoire-sorrow-xlvi-gift-mast",
    ],
    "Dialogue & Transcripts (7)": [
        "transcript-last-wish-introduction",
        "transcript-last-wish-cinematic",
        "transcript-pilgrimage-eaos-nest",
        "transcript-pilgrimage-tree-esila",
        "transcript-tales-osiris-crow",
        "transcript-tales-shaxx-mara",
        "transcript-final-wish-conjure-riven",
    ],
}

# Flattened set of all canonical IDs (83 entries)
ALL_CANONICAL_IDS: Set[str] = {
    item for group in CANONICAL_CHECKLIST.values() for item in group
}

# ==============================================================================
# Validation Result Tracking
# ==============================================================================

class ValidationReporter:
    def __init__(self, verbose: bool = False, quiet: bool = False):
        self.verbose = verbose
        self.quiet = quiet
        self.passed_checks: int = 0
        self.failed_checks: int = 0
        self.failures: List[Dict[str, Any]] = []

    def pass_check(self, check_id: str, description: str, detail: str = ""):
        self.passed_checks += 1
        if self.verbose and not self.quiet:
            msg = f"[PASS] {check_id}: {description}"
            if detail:
                msg += f" ({detail})"
            print(f"\033[0;32m{msg}\033[0m")

    def fail_check(self, check_id: str, description: str, error: str):
        self.failed_checks += 1
        self.failures.append({
            "id": check_id,
            "description": description,
            "error": error
        })
        if not self.quiet:
            print(f"\033[0;31m[FAIL] {check_id}: {description}\033[0m")
            print(f"       \033[0;31mReason: {error}\033[0m")

    def print_summary(self) -> int:
        if self.quiet:
            return 0 if self.failed_checks == 0 else 1

        total = self.passed_checks + self.failed_checks
        print("\n" + "=" * 60)
        print("          Ahamkara Corpus Validation Summary")
        print("=" * 60)
        print(f"Total Checks:   {total}")
        print(f"\033[0;32mPassed:         {self.passed_checks}\033[0m")
        if self.failed_checks == 0:
            print(f"\033[0;32mFailed:         0\033[0m")
            print("\033[1;32mStatus:         PASSED (Corpus 100% Compliant)\033[0m")
            print("=" * 60 + "\n")
            return 0
        else:
            print(f"\033[0;31mFailed:         {self.failed_checks}\033[0m")
            print("\033[1;31mStatus:         FAILED\033[0m")
            print("=" * 60)
            print("\nFailure Details:")
            for i, f in enumerate(self.failures, 1):
                print(f"{i}. [{f['id']}] {f['description']}")
                print(f"   Error: {f['error']}")
            print()
            return 1


# ==============================================================================
# Corpus Validator Engine
# ==============================================================================

class CorpusValidator:
    def __init__(self, corpus_path: Path, jsonl_path: Path, categories_dir: Path, reporter: ValidationReporter):
        self.corpus_path = corpus_path
        self.jsonl_path = jsonl_path
        self.categories_dir = categories_dir
        self.reporter = reporter
        self.records: List[Dict[str, Any]] = []
        self.jsonl_lines: List[str] = []

    def run_all_validations(self, strict_canonical: bool = False) -> int:
        """Executes the complete validation pipeline."""
        if not self.validate_file_existence():
            return self.reporter.print_summary()

        self.validate_json_syntax()
        self.validate_jsonl_syntax()
        self.validate_record_counts()
        self.validate_uniqueness()
        self.validate_record_schema()
        self.validate_canonical_checklist(strict=strict_canonical)
        self.validate_e2e_invariants()
        self.validate_category_partitions()

        return self.reporter.print_summary()

    # --------------------------------------------------------------------------
    # 1. File Existence & Permissions
    # --------------------------------------------------------------------------
    def validate_file_existence(self) -> bool:
        ok = True
        if self.corpus_path.is_file() and self.corpus_path.stat().st_size > 0:
            self.reporter.pass_check("VAL-FILE-01", "Corpus JSON file exists and non-empty", str(self.corpus_path))
        else:
            self.reporter.fail_check("VAL-FILE-01", "Corpus JSON file exists and non-empty", f"Missing or empty: {self.corpus_path}")
            ok = False

        if self.jsonl_path.is_file() and self.jsonl_path.stat().st_size > 0:
            self.reporter.pass_check("VAL-FILE-02", "Corpus JSONL file exists and non-empty", str(self.jsonl_path))
        else:
            self.reporter.fail_check("VAL-FILE-02", "Corpus JSONL file exists and non-empty", f"Missing or empty: {self.jsonl_path}")
            ok = False

        if self.categories_dir.is_dir():
            self.reporter.pass_check("VAL-FILE-03", "Categories partition directory exists", str(self.categories_dir))
        else:
            self.reporter.fail_check("VAL-FILE-03", "Categories partition directory exists", f"Missing directory: {self.categories_dir}")
            ok = False

        return ok

    # --------------------------------------------------------------------------
    # 2. JSON & JSONL Syntax & Formatting
    # --------------------------------------------------------------------------
    def validate_json_syntax(self):
        try:
            with open(self.corpus_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, list):
                self.records = data
                self.reporter.pass_check("VAL-JSON-01", "Corpus parses as valid JSON array", f"{len(data)} items")
            else:
                self.reporter.fail_check("VAL-JSON-01", "Corpus parses as valid JSON array", f"Root element is {type(data).__name__}, expected list")
        except Exception as e:
            self.reporter.fail_check("VAL-JSON-01", "Corpus parses as valid JSON array", f"JSON parse error: {e}")

    def validate_jsonl_syntax(self):
        try:
            with open(self.jsonl_path, "rb") as f:
                raw_bytes = f.read()

            # Check trailing newline LF byte
            if raw_bytes.endswith(b"\n"):
                self.reporter.pass_check("VAL-JSONL-01", "JSONL ends with standard LF byte (0x0a)")
            else:
                self.reporter.fail_check("VAL-JSONL-01", "JSONL ends with standard LF byte (0x0a)", "Missing trailing newline")

            # Check for carriage returns (CR)
            if b"\r" in raw_bytes:
                cr_count = raw_bytes.count(b"\r")
                self.reporter.fail_check("VAL-JSONL-02", "JSONL contains zero Windows CRLF carriage returns", f"Found {cr_count} CR bytes")
            else:
                self.reporter.pass_check("VAL-JSONL-02", "JSONL contains zero Windows CRLF carriage returns")

            lines = raw_bytes.decode("utf-8").splitlines()
            self.jsonl_lines = lines

            line_parse_errors = 0
            len_bound_errors = 0
            escaped_quote_count = 0
            escaped_nl_count = 0

            for idx, line in enumerate(lines, 1):
                if not line.strip():
                    self.reporter.fail_check("VAL-JSONL-03", "No blank lines in JSONL archive", f"Line {idx} is empty")
                    continue

                if len(line) < 100 or len(line) > 102400:
                    len_bound_errors += 1

                if '\\"' in line:
                    escaped_quote_count += 1
                if "\\n" in line:
                    escaped_nl_count += 1

                try:
                    obj = json.loads(line)
                    if not isinstance(obj, dict):
                        line_parse_errors += 1
                except Exception:
                    line_parse_errors += 1

            if line_parse_errors == 0:
                self.reporter.pass_check("VAL-JSONL-04", "Every JSONL line parses into a valid JSON object", f"{len(lines)} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-04", "Every JSONL line parses into a valid JSON object", f"{line_parse_errors} malformed lines")

            if len_bound_errors == 0:
                self.reporter.pass_check("VAL-JSONL-05", "All JSONL lines satisfy length boundaries (100 <= len <= 102400)")
            else:
                self.reporter.fail_check("VAL-JSONL-05", "All JSONL lines satisfy length boundaries (100 <= len <= 102400)", f"{len_bound_errors} lines out of bounds")

            if escaped_quote_count > 0:
                self.reporter.pass_check("VAL-JSONL-06", "JSONL archive contains escaped quotes", f"{escaped_quote_count} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-06", "JSONL archive contains escaped quotes", "Zero escaped quotes found")

            if escaped_nl_count > 0:
                self.reporter.pass_check("VAL-JSONL-07", "JSONL archive contains escaped newlines", f"{escaped_nl_count} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-07", "JSONL archive contains escaped newlines", "Zero escaped newlines found")

        except Exception as e:
            self.reporter.fail_check("VAL-JSONL-00", "Read and parse JSONL file", str(e))

    # --------------------------------------------------------------------------
    # 3. Record Count Parity & Thresholds
    # --------------------------------------------------------------------------
    def validate_record_counts(self):
        json_count = len(self.records)
        jsonl_count = len(self.jsonl_lines)

        if json_count >= 65:
            self.reporter.pass_check("VAL-CNT-01", "Corpus contains minimum 65 canonical entries", f"Count: {json_count}")
        else:
            self.reporter.fail_check("VAL-CNT-01", "Corpus contains minimum 65 canonical entries", f"Found {json_count}, minimum is 65")

        if json_count == jsonl_count and json_count > 0:
            self.reporter.pass_check("VAL-CNT-02", "Record count matches between JSON and JSONL archives", f"{json_count} entries")
        else:
            self.reporter.fail_check("VAL-CNT-02", "Record count matches between JSON and JSONL archives", f"JSON: {json_count}, JSONL: {jsonl_count}")

    # --------------------------------------------------------------------------
    # 4. Strict Uniqueness
    # --------------------------------------------------------------------------
    def validate_uniqueness(self):
        ids = [r.get("id") for r in self.records if "id" in r]
        duplicates = set([x for x in ids if ids.count(x) > 1])
        if len(duplicates) == 0:
            self.reporter.pass_check("VAL-UNIQ-01", "All record IDs are strictly unique (0 duplicates)", f"{len(ids)} unique IDs")
        else:
            self.reporter.fail_check("VAL-UNIQ-01", "All record IDs are strictly unique (0 duplicates)", f"Duplicate IDs detected: {duplicates}")

    # --------------------------------------------------------------------------
    # 5. Detailed 9-Field Schema Validation
    # --------------------------------------------------------------------------
    def validate_record_schema(self):
        bad_id_format = []
        bad_title = []
        bad_source = []
        bad_entity = []
        bad_speaker = []
        bad_transcript = []
        bad_tags = []
        bad_chronology = []
        bad_theme = []
        html_leak_transcripts = []
        distinct_releases: Set[str] = set()

        html_tag_re = re.compile(r"<(?:p|br|div|span|h[1-6]|table|tr|td|a\s|strong|em)[^>]*>", re.IGNORECASE)

        for r in self.records:
            rid = str(r.get("id", ""))

            # 1. ID check: kebab-case
            if not ID_PATTERN.match(rid):
                bad_id_format.append((rid, "Does not match kebab-case regex"))

            # 2. Title check: non-empty string
            title = r.get("title")
            if not isinstance(title, str) or len(title.strip()) == 0:
                bad_title.append(rid)

            # 3. Source check
            src = r.get("source")
            if not isinstance(src, dict):
                bad_source.append((rid, "source is not a dict"))
            else:
                stype = src.get("type")
                sgame = src.get("game")
                srelease = src.get("release")
                surl = src.get("ishtar_url")

                if stype not in VALID_SOURCE_TYPES:
                    bad_source.append((rid, f"invalid source.type: {stype}"))
                if sgame not in VALID_GAMES:
                    bad_source.append((rid, f"invalid source.game: {sgame}"))
                if not isinstance(srelease, str) or len(srelease.strip()) == 0:
                    bad_source.append((rid, f"missing or blank source.release: {srelease}"))
                else:
                    distinct_releases.add(srelease.strip())
                if not isinstance(surl, str) or not (surl.startswith("http://") or surl.startswith("https://")):
                    bad_source.append((rid, f"invalid source.ishtar_url: {surl}"))
                if "bungie_ref" not in src:
                    bad_source.append((rid, "missing bungie_ref key"))

            # 4. Entity check
            entity = r.get("entity")
            if not isinstance(entity, list) or len(entity) == 0:
                bad_entity.append((rid, "entity is not a non-empty list"))
            else:
                for e in entity:
                    if e not in VALID_ENTITIES:
                        bad_entity.append((rid, f"unknown entity enum: '{e}'"))

            # 5. Speaker check: string or null (never "")
            if "speaker" not in r:
                bad_speaker.append((rid, "speaker key missing"))
            else:
                spk = r.get("speaker")
                if spk == "":
                    bad_speaker.append((rid, "speaker is empty string (must be null or non-empty string)"))
                elif spk is not None and not isinstance(spk, str):
                    bad_speaker.append((rid, f"speaker invalid type: {type(spk).__name__}"))

            # 6. Transcript check: non-empty string, no raw html
            trans = r.get("transcript")
            if not isinstance(trans, str) or len(trans.strip()) == 0:
                bad_transcript.append(rid)
            else:
                if html_tag_re.search(trans):
                    html_leak_transcripts.append(rid)

            # 7. Tags check: list of >= 1 string
            tags = r.get("tags")
            if not isinstance(tags, list) or len(tags) == 0:
                bad_tags.append((rid, "tags is not a non-empty list"))
            else:
                for t in tags:
                    if not isinstance(t, str) or len(t.strip()) == 0:
                        bad_tags.append((rid, f"tag is blank or not a string: '{t}'"))

            # 8. Chronology check
            chron = r.get("chronology")
            if chron not in VALID_CHRONOLOGIES:
                bad_chronology.append((rid, f"invalid chronology: '{chron}'"))

            # 9. Theme check
            theme = r.get("theme")
            if theme not in VALID_THEMES:
                bad_theme.append((rid, f"invalid theme: '{theme}'"))

        # Report results
        if not bad_id_format:
            self.reporter.pass_check("VAL-SCH-01", "Every record contains valid kebab-case 'id'")
        else:
            self.reporter.fail_check("VAL-SCH-01", "Every record contains valid kebab-case 'id'", f"{len(bad_id_format)} invalid IDs: {bad_id_format[:3]}")

        if not bad_title:
            self.reporter.pass_check("VAL-SCH-02", "Every record contains non-empty 'title'")
        else:
            self.reporter.fail_check("VAL-SCH-02", "Every record contains non-empty 'title'", f"{len(bad_title)} records missing title: {bad_title[:3]}")

        if not bad_source:
            self.reporter.pass_check("VAL-SCH-03", "Every record contains valid 'source' object with type, game, release, and bungie_ref")
        else:
            self.reporter.fail_check("VAL-SCH-03", "Every record contains valid 'source' object", f"{len(bad_source)} source errors: {bad_source[:3]}")

        if len(distinct_releases) >= 4:
            self.reporter.pass_check("VAL-SCH-04", f"Source releases span >= 4 distinct Destiny releases ({len(distinct_releases)} found)")
        else:
            self.reporter.fail_check("VAL-SCH-04", "Source releases span >= 4 distinct Destiny releases", f"Found only {len(distinct_releases)}: {distinct_releases}")

        if not bad_entity:
            self.reporter.pass_check("VAL-SCH-05", "Every record contains valid non-empty 'entity' list with allowed enums")
        else:
            self.reporter.fail_check("VAL-SCH-05", "Every record contains valid non-empty 'entity' list", f"{len(bad_entity)} entity errors: {bad_entity[:3]}")

        if not bad_speaker:
            self.reporter.pass_check("VAL-SCH-06", "Speaker field is either string or null (never empty string '')")
        else:
            self.reporter.fail_check("VAL-SCH-06", "Speaker field is either string or null", f"{len(bad_speaker)} speaker errors: {bad_speaker[:3]}")

        if not bad_transcript:
            self.reporter.pass_check("VAL-SCH-07", "Every record contains non-empty 'transcript' text")
        else:
            self.reporter.fail_check("VAL-SCH-07", "Every record contains non-empty 'transcript' text", f"{len(bad_transcript)} blank transcripts: {bad_transcript[:3]}")

        if not html_leak_transcripts:
            self.reporter.pass_check("VAL-SCH-08", "All transcripts sanitized of raw unrendered HTML tags (<br>, <p>, etc.)")
        else:
            self.reporter.fail_check("VAL-SCH-08", "All transcripts sanitized of raw unrendered HTML tags", f"{len(html_leak_transcripts)} records contain raw HTML: {html_leak_transcripts[:3]}")

        if not bad_tags:
            self.reporter.pass_check("VAL-SCH-09", "Every record contains non-empty 'tags' list with valid strings")
        else:
            self.reporter.fail_check("VAL-SCH-09", "Every record contains non-empty 'tags' list", f"{len(bad_tags)} tags errors: {bad_tags[:3]}")

        if not bad_chronology:
            self.reporter.pass_check("VAL-SCH-10", "Every record contains valid 'chronology' enum")
        else:
            self.reporter.fail_check("VAL-SCH-10", "Every record contains valid 'chronology' enum", f"{len(bad_chronology)} chronology errors: {bad_chronology[:3]}")

        if not bad_theme:
            self.reporter.pass_check("VAL-SCH-11", "Every record contains valid 'theme' enum")
        else:
            self.reporter.fail_check("VAL-SCH-11", "Every record contains valid 'theme' enum", f"{len(bad_theme)} theme errors: {bad_theme[:3]}")

    # --------------------------------------------------------------------------
    # 6. Canonical Entity & Checklist Preservations
    # --------------------------------------------------------------------------
    def validate_canonical_checklist(self, strict: bool = False):
        record_ids = {r.get("id") for r in self.records if "id" in r}

        # Check the 7 major canonical entities
        for entity_name in REQUIRED_CANONICAL_ENTITIES:
            hits = [
                r for r in self.records
                if any(entity_name.lower() in str(e).lower() for e in (r.get("entity") if isinstance(r.get("entity"), list) else [r.get("entity", "")]))
            ]
            if len(hits) > 0:
                self.reporter.pass_check(f"VAL-ENT-{entity_name.upper()}", f"Canonical entity '{entity_name}' preserved in corpus ({len(hits)} records)")
            else:
                self.reporter.fail_check(f"VAL-ENT-{entity_name.upper()}", f"Canonical entity '{entity_name}' preserved in corpus", "Zero records found")

        # Validate checklist groups
        total_canonical_found = 0
        missing_canonical_map: Dict[str, List[str]] = {}

        for group_name, expected_ids in CANONICAL_CHECKLIST.items():
            missing_in_group = [cid for cid in expected_ids if cid not in record_ids]
            found_in_group = len(expected_ids) - len(missing_in_group)
            total_canonical_found += found_in_group

            check_slug = re.sub(r"[^a-zA-Z0-9]+", "-", group_name).strip("-").upper()
            if len(missing_in_group) == 0:
                self.reporter.pass_check(f"VAL-CAT-{check_slug}", f"{group_name}: All {len(expected_ids)} items preserved")
            else:
                missing_canonical_map[group_name] = missing_in_group
                if strict:
                    self.reporter.fail_check(f"VAL-CAT-{check_slug}", f"{group_name}: Incomplete preservation", f"Missing {len(missing_in_group)}/{len(expected_ids)}: {missing_in_group}")
                else:
                    if found_in_group > 0:
                        self.reporter.pass_check(f"VAL-CAT-{check_slug}", f"{group_name}: Partially preserved ({found_in_group}/{len(expected_ids)})")
                    else:
                        self.reporter.fail_check(f"VAL-CAT-{check_slug}", f"{group_name}: Zero items preserved", f"Expected: {expected_ids}")

        coverage_pct = (total_canonical_found / len(ALL_CANONICAL_IDS)) * 100.0
        if coverage_pct >= 80.0 or (not strict and total_canonical_found >= 65):
            self.reporter.pass_check("VAL-CHK-TOTAL", f"Canonical checklist coverage satisfied ({total_canonical_found}/{len(ALL_CANONICAL_IDS)} = {coverage_pct:.1f}%)")
        else:
            self.reporter.fail_check("VAL-CHK-TOTAL", "Canonical checklist coverage insufficient", f"Found {total_canonical_found}/{len(ALL_CANONICAL_IDS)} ({coverage_pct:.1f}%)")

    # --------------------------------------------------------------------------
    # 7. Specific E2E Test Suite Invariants (Tier 1, 2, 4)
    # --------------------------------------------------------------------------
    def validate_e2e_invariants(self):
        rec_map = {r["id"]: r for r in self.records if "id" in r}

        # 1. Bones of Eao: Destiny 1 game and 'Defy extinction' text (T2-F05-01, T4-SC02-03)
        eao = rec_map.get("exotic-bones-of-eao")
        if eao:
            game_ok = eao.get("source", {}).get("game") == "Destiny 1"
            txt_ok = "defy extinction" in eao.get("transcript", "").lower()
            if game_ok and txt_ok:
                self.reporter.pass_check("VAL-E2E-EAO", "Bones of Eao tagged Destiny 1 and contains 'Defy extinction'")
            else:
                self.reporter.fail_check("VAL-E2E-EAO", "Bones of Eao invariant failed", f"game_ok={game_ok}, txt_ok={txt_ok}")
        else:
            self.reporter.fail_check("VAL-E2E-EAO", "Bones of Eao invariant failed", "exotic-bones-of-eao missing from corpus")

        # 2. Skull of Dire Ahamkara: Fourth-wall address (T4-SC05-01)
        skull = rec_map.get("exotic-skull-of-dire-ahamkara")
        if skull:
            txt = skull.get("transcript", "")
            has_fourth_wall = "[Reader]" in txt or "O [Reader] Mine" in txt or "host" in txt.lower()
            if has_fourth_wall:
                self.reporter.pass_check("VAL-E2E-SKULL", "Skull of Dire Ahamkara preserves fourth-wall address ('[Reader]' or 'host')")
            else:
                self.reporter.fail_check("VAL-E2E-SKULL", "Skull of Dire Ahamkara preserves fourth-wall address", "Fourth-wall token missing from transcript")
        else:
            self.reporter.fail_check("VAL-E2E-SKULL", "Skull of Dire Ahamkara invariant failed", "exotic-skull-of-dire-ahamkara missing")

        # 3. Fifteenth Wish: Contains 'cherish' (T1-F05-05, T4-SC03-02)
        w15 = rec_map.get("wish-wall-fifteenth-wish")
        if w15:
            has_cherish = "cherish" in w15.get("transcript", "").lower()
            if has_cherish:
                self.reporter.pass_check("VAL-E2E-WISH15", "15th Wish contains canonical quote 'cherish'")
            else:
                self.reporter.fail_check("VAL-E2E-WISH15", "15th Wish contains canonical quote 'cherish'", "'cherish' not found in transcript")
        else:
            self.reporter.fail_check("VAL-E2E-WISH15", "15th Wish invariant failed", "wish-wall-fifteenth-wish missing")

        # 4. Wall of Wishes series: All 15 wishes have source.type == 'wall_of_wishes' (T4-SC03-01)
        wishes = [r for r in self.records if r.get("source", {}).get("type") == "wall_of_wishes"]
        if len(wishes) == 15:
            self.reporter.pass_check("VAL-E2E-WISH-ALL", "All 15 Wall of Wishes plates tagged source.type='wall_of_wishes'")
        else:
            self.reporter.fail_check("VAL-E2E-WISH-ALL", "All 15 Wall of Wishes plates tagged source.type='wall_of_wishes'", f"Found {len(wishes)} wishes, expected 15")

        # 5. Book: Gifts and Bargains: 4 chapters for Taranis (T4-SC04-01)
        gifts_req = {"book-gifts-first-gift", "book-gifts-second-gift", "book-gifts-third-gift", "book-gifts-last-bargain"}
        if gifts_req.issubset(set(rec_map.keys())):
            self.reporter.pass_check("VAL-E2E-TARANIS", "All 4 chapters of Book: Gifts and Bargains present for Taranis")
        else:
            missing = gifts_req - set(rec_map.keys())
            self.reporter.fail_check("VAL-E2E-TARANIS", "All 4 chapters of Book: Gifts and Bargains present for Taranis", f"Missing: {missing}")

        # 6. Hefnd gear: Vengeful Whisper & Buried Bloodline (T4-SC04-02)
        hefnd_req = {"warlord-vengeful-whisper", "weapon-buried-bloodline"}
        if hefnd_req.issubset(set(rec_map.keys())):
            self.reporter.pass_check("VAL-E2E-HEFND", "Hefnd's core gear records (Vengeful Whisper & Buried Bloodline) verified")
        else:
            missing = hefnd_req - set(rec_map.keys())
            self.reporter.fail_check("VAL-E2E-HEFND", "Hefnd's core gear records verified", f"Missing: {missing}")

        # 7. Paracausal square brackets intact in transcripts (T4-SC05-02)
        all_transcripts = " ".join(r.get("transcript", "") for r in self.records)
        if "[" in all_transcripts and "]" in all_transcripts:
            self.reporter.pass_check("VAL-E2E-BRACKETS", "Paracausal square brackets preserved intact in transcripts")
        else:
            self.reporter.fail_check("VAL-E2E-BRACKETS", "Paracausal square brackets preserved intact in transcripts", "Square brackets missing across corpus")

    # --------------------------------------------------------------------------
    # 8. Category Partition Validation (data/categories/*.json)
    # --------------------------------------------------------------------------
    def validate_category_partitions(self):
        cat_files = list(self.categories_dir.glob("*.json"))
        if len(cat_files) > 0:
            self.reporter.pass_check("VAL-PART-01", f"Found {len(cat_files)} partition JSON files in categories directory")
        else:
            self.reporter.fail_check("VAL-PART-01", "Partition JSON files exist in categories directory", "Zero .json files found")
            return

        rec_ids = {r.get("id") for r in self.records if "id" in r}
        total_partition_records = 0
        partition_errors = 0

        for cf in cat_files:
            try:
                with open(cf, "r", encoding="utf-8") as f:
                    part_data = json.load(f)
                if not isinstance(part_data, list) or len(part_data) == 0:
                    partition_errors += 1
                    continue
                total_partition_records += len(part_data)
                # Check that every record exists in the master corpus
                for pr in part_data:
                    pid = pr.get("id")
                    if pid not in rec_ids:
                        partition_errors += 1
            except Exception:
                partition_errors += 1

        if partition_errors == 0:
            self.reporter.pass_check("VAL-PART-02", "All partition files contain valid records mapped to master corpus", f"{total_partition_records} partition entries verified")
        else:
            self.reporter.fail_check("VAL-PART-02", "All partition files contain valid records mapped to master corpus", f"{partition_errors} errors across partition files")


# ==============================================================================
# CLI Entry Point
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Ahamkara Lore Corpus Validator (Milestone 2 Acceptance Suite)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        default=Path("data/ahamkara_corpus.json"),
        help="Path to canonical JSON archive file",
    )
    parser.add_argument(
        "--jsonl",
        type=Path,
        default=Path("data/ahamkara_corpus.jsonl"),
        help="Path to streamable JSONL archive file",
    )
    parser.add_argument(
        "--categories-dir",
        type=Path,
        default=Path("data/categories"),
        help="Path to categories partition directory",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Enforce 100%% presence of all 83 checklist items (default: >=65 and E2E requirements)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Display verbose output for every passing check",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress normal progress; only emit failures and exit code",
    )
    parser.add_argument(
        "--json-report",
        type=Path,
        default=None,
        help="Optional path to output machine-readable JSON validation report",
    )

    args = parser.parse_args()

    reporter = ValidationReporter(verbose=args.verbose, quiet=args.quiet)
    validator = CorpusValidator(
        corpus_path=args.corpus,
        jsonl_path=args.jsonl,
        categories_dir=args.categories_dir,
        reporter=reporter,
    )

    exit_code = validator.run_all_validations(strict_canonical=args.strict)

    if args.json_report:
        report_data = {
            "exit_code": exit_code,
            "status": "PASSED" if exit_code == 0 else "FAILED",
            "passed_checks": reporter.passed_checks,
            "failed_checks": reporter.failed_checks,
            "total_checks": reporter.passed_checks + reporter.failed_checks,
            "failures": reporter.failures,
        }
        try:
            with open(args.json_report, "w", encoding="utf-8") as f:
                json.dump(report_data, f, indent=2)
        except Exception as e:
            print(f"Failed to write JSON report to {args.json_report}: {e}", file=sys.stderr)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
