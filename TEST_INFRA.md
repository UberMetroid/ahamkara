# TEST_INFRA.md — Ahamkara Lore Preservation & openOODA Query Engine

## 1. Executive Summary & Testing Philosophy

This document defines the 4-tier opaque-box End-to-End (E2E) testing architecture for the **Ahamkara Lore Preservation and openOODA Query Engine** (`UberMetroid/ahamkara`).

The testing framework is built on four core principles:
1. **Opaque-Box & Requirement-Driven**: Tests are derived strictly from `ORIGINAL_REQUEST.md` and the system specifications in `PROJECT.md`. Tests interact exclusively through documented user-facing contracts: filesystem files, data schemas, CLI flags, process exit codes, and stdout/stderr streams. No internal functions or non-exported symbols are mocked or accessed.
2. **Progressive Testability & Decoupling**: Each tier is self-contained. The runner executes cleanly, reporting explicit pass/fail statuses for each test case. When executed against a clean or partially implemented repository, the suite isolates missing components with actionable diagnostic messages.
3. **Rigorous Coverage Across 4 Tiers**:
   - **Tier 1 (Feature Coverage)**: Validates baseline presence, schema compliance, and happy-path operations for all 21 project features ($\ge 5$ test checks per feature area, totaling $\ge 105$ checks).
   - **Tier 2 (Boundary & Corner Cases)**: Exercises domain boundaries, empty inputs, non-existent queries, bracketed syntactic tokens, Unicode quotes, case insensitivity, path resilience, and limit boundaries ($\ge 5$ tests per feature area, totaling $\ge 105$ checks).
   - **Tier 3 (Cross-Feature Combinations)**: Evaluates combinatorial interactions: entity + theme, keyword + category, CLI formatting flags + limits, multi-attribute conjunctions, and corpus export coherence ($\ge 25$ combinations).
   - **Tier 4 (Real-World Application Scenarios)**: Simulates complete scholar and guardian research workflows (The Great Hunt Researcher, The Exotic Hunter, The Wall Cryptarch, The Dual-Dragon Chronicler, The Metaphysician, and CI/CD Verification Audit).
4. **Deterministic Authoritative Derivation**: Expected outputs are derived directly from canonical Bungie Destiny 1 / Destiny 2 lore definitions (cataloged via the Ishtar Collective API survey) and the openOODA language invariants ($\le 256$ lines per source file, $\le 64$ KiB file size, `oodac check` validation, Landlock jail compatibility).

---

## 2. Test Architecture & Runner Invocation

### 2.1 Test Directory Structure

```
/home/jeryd/Projects/UberMetroid/ahamkara/
├── TEST_INFRA.md                # This specification
├── TEST_READY.md                # Test-ready readiness declaration
└── tests_e2e/                   # 4-tier opaque-box test suite
    ├── run_e2e.sh               # Master test runner (executable)
    ├── tier1_feature_tests.sh   # Tier 1: Baseline feature verification
    ├── tier2_boundary_tests.sh  # Tier 2: Boundary & edge conditions
    ├── tier3_combination_tests.sh # Tier 3: Combinatorial & pairwise tests
    └── tier4_scenario_tests.sh  # Tier 4: Real-world workflow scenarios
```

### 2.2 Master Test Runner CLI Contract (`run_e2e.sh`)

The master runner orchestrates the test tiers and aggregates results:

```bash
# Run all tiers (Tiers 1, 2, 3, 4)
./tests_e2e/run_e2e.sh --all

# Run an individual tier
./tests_e2e/run_e2e.sh --tier 1
./tests_e2e/run_e2e.sh --tier 2
./tests_e2e/run_e2e.sh --tier 3
./tests_e2e/run_e2e.sh --tier 4

# Run with verbose diagnostic output
./tests_e2e/run_e2e.sh --all --verbose

# Display help and usage
./tests_e2e/run_e2e.sh --help
```

### 2.3 Process Return Codes

| Exit Code | Semantics |
|---|---|
| `0` | All executed tests passed successfully. |
| `1` | One or more test assertions failed. |
| `2` | Test runner invocation error (invalid flags, missing test scripts). |

### 2.4 Test Reporting Format

Every test outputs standard, machine-parseable progress lines:
```
[PASS] T1-F01-01: Git repository initialized with valid HEAD
[FAIL] T1-F05-01: Canonical corpus contains minimum 65 entries (found 0)
[SKIP] T4-SC01-01: Binary ./bin/ahamkara not found; compile step required
```

A summary block is emitted upon completion:
```
============================================================
           Ahamkara E2E Test Suite Summary
============================================================
Total Executed: 250
Passed:         250
Failed:         0
Skipped:        0
Status:         PASSED
============================================================
```

---

## 3. Feature Inventory Matrix (All 21 Features)

The following matrix maps every feature defined in `PROJECT.md` to its respective test tiers, inputs, expected outputs, and authoritative sources.

| # | Feature | Target Tiers | Test IDs | Input / Operation | Authoritative Source & Expected Output |
|---|---------|--------------|----------|-------------------|---------------------------------------|
| 1 | Git Repository & Remote | T1, T2, T3 | T1-F01, T2-F01, T3-F01 | `git rev-parse`, `git remote -v`, branch verification | Remote origin is `https://github.com/UberMetroid/ahamkara.git`; main branch exists; clean status. |
| 2 | openOODA Manifest & Scaffolding | T1, T2, T3 | T1-F02, T2-F02, T3-F02 | Read `ooda.pkg`, check `std` symlink, directory layout | `ooda.pkg` contains `name=ahamkara`, `min_pin=v0.210.0`, `caps=FsRead`; `std` symlink resolves to openOODA stdlib. |
| 3 | Documentation & README | T1, T2 | T1-F03, T2-F03 | Inspect `README.md` contents, structure, and code blocks | Contains project overview, lore catalog summary, openOODA engine usage, CLI examples, verification guide. |
| 4 | Canonical Entity Preservation | T1, T2, T3, T4 | T1-F04, T2-F04, T3-F04, T4-SC01..05 | Query records for 8 canonical entities: Riven, Taranis, Hefnd, Huginn, Muninn, Azirim, Eao, Great Hunt Dragons | All 8 entities present in corpus; correct entity taxonomy and canonical attributes preserved. |
| 5 | Canonical Source Ingestion | T1, T2, T3, T4 | T1-F05, T2-F05, T3-F05, T4-SC01..05 | Check 65 canonical items across 9 categories | Minimum 65 entries present: Exotic armor (5), weapons (4), Last Wish (8), Great Hunt (15), Warlord's Ruin (5), Books (12), Wall of Wishes (15), Grimoire (9), Transcripts (7). |
| 6 | 9-Field Structured Schema | T1, T2 | T1-F06, T2-F06 | Validate every record against the 9-field schema | Every record contains `id`, `title`, `source`, `entity`, `speaker`, `transcript`, `tags`, `chronology`, `theme`. `id` matches kebab-case regex. Non-empty text. |
| 7 | Canonical JSONL Lore Archives | T1, T2, T3 | T1-F07, T2-F07, T3-F07 | Check `data/ahamkara_corpus.jsonl`, `data/categories/*.jsonl`, `data/cache/raw/` | Canonical JSONL exists, partition files exist, partition records exactly cover the corpus. |
| 8 | openOODA Domain Models | T1, T2 | T1-F08, T2-F08 | Inspect `src/model/*.oo`, check types and functions | Strongly typed `AhamkaraRecord`, `QueryFilter`, `SearchResult`, `RecordStats`; line counts $\le 256$; file sizes $\le 64$ KiB. |
| 9 | Safe JSONL Parser | T1, T2, T3 | T1-F09, T2-F09, T3-F09 | Line-by-line string extraction in `src/repo/json_parse.oo` | Extracts string fields, tags list, handles escaped characters (`\"`, `\n`, `\t`, `\\`), no external C dependencies. |
| 10 | Capability-Gated Loader | T1, T2 | T1-F10, T2-F10 | Verify `repo_load_all` receives `&FsReadCap` | File access is gated by capability; returns `Result[List[AhamkaraRecord], String]`; non-existent file returns `Err`. |
| 11 | Decoupled Database Contract | T1, T2, T3 | T1-F11, T2-F11, T3-F11 | Inspect `src/repo/db_contract.oo` | Clean contract interface separating storage layer for future `ooda db` migration; models and engine have zero storage dependency. |
| 12 | Query & Filtering Engine | T1, T2, T3, T4 | T1-F12, T2-F12, T3-F12, T4-SC01..05 | Filter by keyword, entity, category, theme, tag | Case-insensitive substring matching; accurate subset returned; empty results on unmatched criteria. |
| 13 | Corpus Analytics & Stats | T1, T2, T3 | T1-F13, T2-F13, T3-F13 | Execute `--stats` CLI mode or `engine_print_stats` | Emits total record count, entity breakdown, category counts, chronology breakdown, theme distribution. |
| 14 | Formatting & Lore Presentation | T1, T2, T4 | T1-F14, T2-F14, T4-SC02, T4-SC03 | CLI output formatting (`print_record_card`, `--quote`) | Outputs formatted card with ID, Title, Entity, Source, Whisper quotation, and Markdown body enclosed in visual borders. |
| 15 | Interactive CLI REPL | T1, T2, T4 | T1-F15, T2-F15, T4-SC04 | REPL loop invocation (`--interactive` or `interactive`) | Starts REPL loop; responds to `help`, `search <term>`, `entity <name>`, `stats`, `quit`/`exit`. |
| 16 | CLI Command Router | T1, T2, T3 | T1-F16, T2-F16, T3-F16 | CLI flag parsing: `--search`, `--entity`, `--category`, `--quote`, `--stats`, `--interactive` | Correct dispatching to underlying engine functions; graceful handling of unknown flags. |
| 17 | Zero-Error `oodac check` | T1, T2 | T1-F17, T2-F17 | Run `oodac check` over all `.oo` files in `src/` and `tests/` | Zero compilation or type errors; all files pass cleanly with `OK`. |
| 18 | Automated Verification Suite | T1, T2, T4 | T1-F18, T2-F18, T4-SC06 | Execute `verify.sh` | Script is executable (`chmod +x`), executes data checks, `oodac check`, unit tests, exits with code 0. |
| 19 | Opaque-Box E2E Test Suite | T1 | T1-F19 | Master test runner `run_e2e.sh` and 4 tier scripts | All test scripts exist, executable, accept tier flags, produce standard output, pass when project is built. |
| 20 | Adversarial Coverage Hardening | T1, T2, T3 | T1-F20, T2-F20, T3-F20 | Malformed JSONL lines, extreme strings, missing fields, injected special characters | System rejects corrupted inputs gracefully without segmentation faults or silent data truncation. |
| 21 | Final Git Push to GitHub | T1, T3 | T1-F21, T3-F21 | Check remote URL and sync state | Remote points to `https://github.com/UberMetroid/ahamkara.git`; working tree ready for push. |

---

## 4. Detailed Tier Specifications

### 4.1 Tier 1: Feature Coverage Suite (`tier1_feature_tests.sh`)
Verifies that all 21 features exist and function according to specification:
- **T1-F01**: Git repo initialized, origin remote set to `https://github.com/UberMetroid/ahamkara.git`, valid default branch.
- **T1-F02**: `ooda.pkg` manifest contains `name=ahamkara`, `min_pin`, `caps=FsRead`; `std` symlink valid.
- **T1-F03**: `README.md` exists and contains overview, architecture diagram, usage guide, and lore catalog.
- **T1-F04**: Corpus contains all 8 canonical entities (Riven, Taranis, Hefnd, Huginn, Muninn, Azirim, Eao, Great Hunt Dragons).
- **T1-F05**: Corpus contains $\ge 65$ canonical entries across all 9 source categories.
- **T1-F06**: Records strictly validate against the 9-field schema (`id`, `title`, `source`, `entity`, `speaker`, `transcript`, `tags`, `chronology`, `theme`).
- **T1-F07**: Canonical archive is JSONL (`ahamkara_corpus.jsonl`) with JSONL category partitions (`data/categories/*.jsonl`) — all files ≤ 256 lines.
- **T1-F08**: openOODA domain models in `src/model/` conform to $\le 256$ lines rule and $\le 64$ KiB size.
- **T1-F09**: Safe JSONL parser implementation in `src/repo/json_parse.oo` handles string and array extraction.
- **T1-F10**: Repository loader in `src/repo/loader.oo` takes `&FsReadCap` and returns `Result[List[AhamkaraRecord], String]`.
- **T1-F11**: Decoupled database contract in `src/repo/db_contract.oo` provides abstraction for `ooda db`.
- **T1-F12**: Search engine in `src/engine/search.oo` filters by keyword, entity, category, theme.
- **T1-F13**: Analytics module in `src/engine/stats.oo` computes aggregate statistics.
- **T1-F14**: Formatter in `src/cli/format.oo` renders lore cards and quotes.
- **T1-F15**: Interactive REPL in `src/cli/interactive.oo` provides REPL loop.
- **T1-F16**: CLI entry point in `src/main.oo` parses arguments and dispatches commands.
- **T1-F17**: `oodac check` passes with zero type errors on all `.oo` files.
- **T1-F18**: `verify.sh` exists, is executable, and verifies integrity.
- **T1-F19**: E2E test suite scripts exist and are executable.
- **T1-F20**: Adversarial hardening verifies resilience against input corruption.
- **T1-F21**: Git push capability to GitHub remote.

### 4.2 Tier 2: Boundary & Corner Cases Suite (`tier2_boundary_tests.sh`)
Verifies robustness against boundary conditions, strange formatting, and edge cases:
- **T2-01**: Empty query strings (`--search ""`, `--keyword ""`) return full or empty set without crashing.
- **T2-02**: Non-existent entities (`--entity "XivuArathDragonOfNothing"`) return 0 results gracefully.
- **T2-03**: Bracketed terms representing paracausal syntax (`"O [Reader] Mine"`, `"[The Queen]"`, `"[bargain]"`) search accurately without regex syntax failure.
- **T2-04**: Case-insensitive entity searches (`"riven"`, `"RIVEN"`, `"RiVeN"`) return identical hit counts.
- **T2-05**: Case-insensitive keyword searches (`"EXTINCTION"`, `"extinction"`) return identical results.
- **T2-06**: Unicode quotes and apostrophes (`“O Bearer Mine”`, `’`) handled cleanly without byte corruption.
- **T2-07**: Missing data corpus file handled with clear `ERROR:` message and graceful exit, not crash.
- **T2-08**: Punctuation-only queries (`"???"`, `"--"`, `"..."`) executed safely.
- **T2-09**: Whitespace-padded queries (`"   Riven   "`, `"\tTaranis\n"`) trimmed or matched correctly.
- **T2-10**: Extreme query lengths ($>1024$ characters) rejected or evaluated without buffer overflows.
- **T2-11**: Numeric and symbol limits (`--limit 0`, `--limit 1`, `--limit 100`, `--limit -1`).
- **T2-12**: Malformed JSONL line with missing quotation marks rejected by parser without crashing.
- **T2-13**: Duplicate IDs detected or prevented.
- **T2-14**: Empty transcripts or blank titles caught by validator.
- **T2-15**: Special characters in titles (`:`, `-`, `/`, `'`) preserved accurately.

### 4.3 Tier 3: Cross-Feature Combinations Suite (`tier3_combination_tests.sh`)
Verifies pairwise and multi-attribute interactions:
- **T3-01**: Entity `Riven` + Theme `Anthem Anatheme & Wish-Bargains`.
- **T3-02**: Entity `Taranis` + Theme `Parentage & The Uncorrupted Clutch`.
- **T3-03**: Entity `Hefnd` + Category `Warlord's Ruin`.
- **T3-04**: Category `Exotic Armor` + Keyword `Bones`.
- **T3-05**: Category `Exotic Weapon` + Keyword `Whisper`.
- **T3-06**: Category `Wall of Wishes` + Keyword `cherish` (15th Wish verification).
- **T3-07**: Entity `Huginn` + Category `Lore Book` (or related lore tabs).
- **T3-08**: Entity `Azirim` + Chronology `Reef Golden Age & The Dreaming City`.
- **T3-09**: Entity `Eao` + Keyword `extinction`.
- **T3-10**: Chronology `The Great Ahamkara Hunt` + Theme `The Great Hunt & Extinction`.
- **T3-11**: Category `Raid Armor` + Entity `Riven` (Warlock Great Hunt set).
- **T3-12**: Category `Raid Armor` + Keyword `Hunter` (Hunter Great Hunt set).
- **T3-13**: Category `Raid Armor` + Keyword `Titan` (Titan Great Hunt set).
- **T3-14**: Keyword `bargain` + Flag `--quote` (Whisper extraction).
- **T3-15**: Keyword `wish` + `--category "Wall of Wishes"` + `--limit 5`.
- **T3-16**: Multi-format cross-check: record count in `ahamkara_corpus.json` equals line count in `ahamkara_corpus.jsonl`.
- **T3-17**: Category partition cross-check: sum of category file records matches master corpus count.
- **T3-18**: CLI `--stats` combined with query filters.
- **T3-19**: Search keyword appearing in title vs quote vs body text.
- **T3-20**: Negative combination: Entity `Taranis` + Category `Exotic Armor` (should yield 0 results since Taranis is associated with `Wish-Keeper` bow and lore book, not armor).

### 4.4 Tier 4: Real-World Application Scenarios Suite (`tier4_scenario_tests.sh`)
Simulates authentic Scholar and Guardian workflows end-to-end:
- **Scenario 1 (The Great Hunt Scholar)**:
  A lore scholar researches the Consensus Great Hunt. The workflow executes queries for the edict of extinction, collects the 15 Great Hunt armor perspectives, verifies the D1 Grimoire Hunt cards, and compiles an account of the shapeshifting dragons.
- **Scenario 2 (The Exotic Hunter)**:
  A Guardian inspects all Ahamkara bone exotics (Skull of Dire Ahamkara, Young Ahamkara's Spine, Claws of Ahamkara, Sealed Ahamkara Grasps, Bones of Eao), verifies their whisper quotes, and analyzes the fourth-wall breaking addresses ("O [Reader] Mine").
- **Scenario 3 (The Wall of Wishes Cryptarch)**:
  A cryptarch inspects the Wall of Wishes records, verifies that all 15 wishes are present in sequence, checks the plate inscriptions, and validates the resolution of the 15th Wish in Season of the Wish.
- **Scenario 4 (The Dual Dragons Chronicler — Taranis & Hefnd)**:
  A chronicler compares the benevolent sacrifice of Taranis (*Gifts and Bargains*, *Wish-Keeper*) with the tragedy and bone vengeance of Hefnd (*Warlord's Ruin*, *Buried Bloodline*).
- **Scenario 5 (The Paracausal Metaphysician)**:
  An investigator tracks the viral phrase "O Bearer Mine" / "O [Reader] Mine" across exotics, raid weapons, and dialogue transcripts, verifying paracausal bracketed syntax preservation.
- **Scenario 6 (The Automated CI/CD Verifier)**:
  Simulates a CI build pipeline executing `verify.sh`, validating file invariants ($\le 256$ lines, $\le 64$ KiB), checking `oodac check` across all modules, and asserting git remote synchronization.

---

## 5. Verification Commands

To execute the tests and inspect results:

```bash
# Set environment
export PATH="/home/jeryd/.openooda/bin:/home/jeryd/Projects/openOODA/oodac/bin:$PATH"
export OODA_NO_JAIL=1

# Execute all E2E tiers
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --all

# Execute specific tier
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 1
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 2
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 3
/home/jeryd/Projects/UberMetroid/ahamkara/tests_e2e/run_e2e.sh --tier 4
```
