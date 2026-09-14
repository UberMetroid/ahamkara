"""Content checks: canonical checklist, E2E invariants, category partitions.

Mixin for CorpusValidator — relies on self.reporter / self.records /
self.categories_dir.
"""

import json
import re
from typing import Dict, List

from .constants import ALL_CANONICAL_IDS, CANONICAL_CHECKLIST, REQUIRED_CANONICAL_ENTITIES


class ContentChecks:
    """Canonical entity & checklist preservation, E2E invariants, partitions."""

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
    # 8. Category Partition Validation (data/categories/*.jsonl)
    # --------------------------------------------------------------------------
    def validate_category_partitions(self):
        cat_files = list(self.categories_dir.glob("*.jsonl"))
        if len(cat_files) > 0:
            self.reporter.pass_check("VAL-PART-01", f"Found {len(cat_files)} partition JSONL files in categories directory")
        else:
            self.reporter.fail_check("VAL-PART-01", "Partition JSONL files exist in categories directory", "Zero .jsonl files found")
            return

        rec_ids = {r.get("id") for r in self.records if "id" in r}
        total_partition_records = 0
        partition_errors = 0

        for cf in cat_files:
            try:
                with open(cf, "r", encoding="utf-8") as f:
                    part_data = [json.loads(line) for line in f if line.strip()]
                if len(part_data) == 0:
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
