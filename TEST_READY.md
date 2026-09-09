# TEST_READY.md — Ahamkara Lore Preservation & openOODA Query Engine

## Status: TEST READY

The comprehensive, 4-tier opaque-box E2E testing infrastructure for the **Ahamkara Lore Preservation and openOODA Query Engine** has been designed, implemented, and verified.

---

## 1. Test Suite Architecture & Deliverables

All test scripts are located in `/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/` and are fully executable (`chmod +x`):

| File | Purpose | Test Count | Target Scope |
|---|---|---|---|
| `run_e2e.sh` | Master Test Runner | N/A | Orchestrates Tiers 1–4, supports `--tier <N>`, `--all`, `--verbose`, `-h` |
| `test_helpers.sh` | Common Test Framework | N/A | Assertion macros, color formatting, result aggregation |
| `tier1_feature_tests.sh` | Tier 1: Feature Coverage | **105 tests** | All 21 features from `PROJECT.md` ($\ge 5$ checks per feature) |
| `tier2_boundary_tests.sh` | Tier 2: Boundary & Corner Cases | **136 tests** | Edge cases, bracketed tokens, Unicode, limits, schema limits across 21 features |
| `tier3_combination_tests.sh` | Tier 3: Combinations | **27 tests** | Pairwise interactions, entity + theme, category + keyword, format coherence |
| `tier4_scenario_tests.sh` | Tier 4: Real-World Scenarios | **16 tests** | 6 complete Scholar and Guardian research workflows |
| **Total Test Assertions** | | **284 tests** | Comprehensive opaque-box coverage |

Associated documentation:
- `/home/jeryd/Projects/UberMetroid/ahamkara/TEST_INFRA.md` — Test philosophy, 21-feature inventory matrix, and execution specifications.

---

## 2. Verification Commands

To execute the test suite against the project:

```bash
# Ensure execution permissions (already set)
chmod +x /home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/*.sh

# Run all 4 tiers sequentially
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --all

# Run individual tiers
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 1   # Baseline feature presence (105 tests)
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 2   # Boundaries & corner cases (136 tests)
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 3   # Combinations & multi-attribute (27 tests)
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 4   # Real-world application scenarios (16 tests)

# Verbose execution with detailed diagnostic logs
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --all --verbose
```

---

## 3. Authoritative Source of Expected Outputs

Every test assertion is derived strictly from:
1. **Canonical Destiny 1 / Destiny 2 Lore Specifications**: Cataloged via the Ishtar Collective API survey (`survey_spec_miner_lore/handoff.md`), requiring 65+ canonical entries across 9 categories (Exotic armor, exotic weapons, Last Wish weapons, Great Hunt armor, Warlord's Ruin, Lore books, Wall of Wishes 1–15, Grimoire cards, Transcripts).
2. **openOODA Tactical Toolchain & Language Invariants**: Strict 256-line per-file limit (`oodac/check/check_mod.oo:105`), 64 KiB per-file limit (`oodac/cli/cli_parse.oo:102`), `oodac check` clean typechecking, capability tokens (`&FsReadCap`), and Landlock jail compatibility (`OODA_NO_JAIL=1`).
3. **Decoupled Architecture Requirements**: Decoupled `src/repo/db_contract.oo` interface separating models/engine from file storage for future `ooda db` migration.

---

## 4. Current Test Suite State (Pre-Implementation Baseline)

Execution of `./tests_e2e/run_e2e.sh --all` confirms:
- Master runner and all tier scripts parse with 100% valid Bash syntax (`bash -n` clean).
- CLI argument routing (`--all`, `--tier <N>`, `--verbose`, `--help`) functions accurately.
- Assertions trigger real checks against the repository filesystem.
- Current failed assertions isolate pending milestone deliverables (M1 Repository Init, M2 Lore Ingestion, M3 Lore Access Layer, M4 Query CLI, M5 Automated Verification Suite).
- As each milestone is completed by the implementing agents, the corresponding test assertions will turn green automatically without requiring test modifications.
