# Ahamkara: Lore Preservation & openOODA Query Engine

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Toolchain](https://img.shields.io/badge/Toolchain-openOODA_v0.210+-orange.svg)](https://github.com/openOODA)
[![Corpus](https://img.shields.io/badge/Canonical_Records-65+-green.svg)](data/)
[![Source](https://img.shields.io/badge/Lore_Source-Ishtar_Collective_API-purple.svg)](https://www.ishtar-collective.net/)

> *"Reality is the finest flesh, oh bearer mine. And are you not hungry?"*  
> — **Skull of Dire Ahamkara**

---

## 1. Project Overview

**Ahamkara** is an archival knowledge repository and query engine dedicated to preserving the memory, wisdom, and canonical lore of the **Ahamkara** (Wish-Dragons) across *Destiny 1* and *Destiny 2*.

The Ahamkara are paracausal shapeshifters who feed upon the disparity between *what is* and *what could be* through the **Anthem Anatheme**—the paracausal law binding reality to subjective desire. Even in death, their calcified bones whisper to their bearers, warping spacetime, breaching fourth walls, and fulfilling wishes with lethal irony.

This project achieves two core objectives:
1. **Canonical Preservation**: Normalizes, categorizes, and archives 65+ primary Ahamkara lore entries spanning 10 years of Bungie releases (2014–2024), sourced and verified via the Ishtar Collective API into structured, streamable JSON and JSONL datasets.
2. **openOODA Query Engine**: Provides a strongly typed, capability-gated query engine and interactive CLI built natively in [openOODA](https://github.com/openOODA) (`.oo`). The engine features a decoupled multi-tier architecture designed to migrate seamlessly to the forthcoming `ooda db` backend without touching application logic.

---

## 2. Lore Catalog & Canonical Scope

The preserved corpus comprehensively documents the Ahamkara across all major historical epochs and entity appearances in *Destiny* canon.

### 2.1 Canonical Entity Directory

| Entity | Titles / Designations | Historical Era | Key Relationships | Canonical Significance |
|---|---|---|---|---|
| **Riven** | *Riven of a Thousand Voices*, *The Last Ahamkara* | Reef Golden Age → *Forsaken* → *Season of the Wish* | Mara Sov, Oryx, Savathûn, Taranis | Last known living Ahamkara in Sol; helped construct the Dreaming City; Taken by Oryx; orchestrated the Last Wish curse upon death; her spirit concluded the 15th Wish bargain. |
| **Taranis** | *The Wish-Keeper*, *The Solitary Dragon* | Pre-Collapse → *Season of the Wish* | Riven (Mate), The Hatchlings (Clutch) | Subverted the predatory Anthem Anatheme; sheltered in the Black Garden; sacrificed his physical existence by granting his own wish to preserve the uncorrupted clutch. |
| **Hefnd** | *Hefnd of the Mountain*, *The Bonded Beast* | Dark Age → Modern Era | Warlord Rath, Naeem, Fikrul / Scorn | Bound to the European Dark Zone fortress (Warlord's Ruin); formed a genuine protective bond with Naeem; his death-cursed bones were later co-opted by Scorn dark ether. |
| **Huginn & Muninn** | *The Corvid Skulls*, *Companions of Sjur* | Reef Golden Age → *Forsaken* | Sjur Eido, Mara Sov | Pair of dragons who arrived peacefully in the Reef; willingly slain prior to the Great Hunt; their bleached skulls in Harbinger's Seclude grant Queensfoil and Light. |
| **Azirim** | *The Cliff-Singer*, *The Deceiver* | Reef Golden Age | Mara Sov, Awoken of the Reef | Treacherous trickster who enchanted Awoken dancers along the Weeping Wall, luring them off the precipice to their doom; exemplar of lethal wish-bargains. |
| **Eao** | *Eao the Extinct* | Golden Age / Early City Age | Hunter Bearers | Ancient dragon whose relics grant triple and quadruple jumps (*Bones of Eao*); enshrined in the geode caverns of Eao's Nest in the Dreaming City. |
| **Unnamed Great Hunt Dragons** | *The Hunt Dragons* | The Great Ahamkara Hunt | Wei Ning, Lord Shaxx, Saladin Forge, Efrideet, Praedyth, Kabr, Liu Feng, Tallulah Fairwind | Polymorphic chimeras encountered during the Consensus extermination campaign across Earth, Venus, and Mars (mimicking Vex Hydras, European mythic dragons, lion-tusked beasts, and playing card games). |
| **Harmony Wish-Dragons** | *The Dragons of the Silver Mast* | Ancient Fundament / Hive War | Oryx, Savathûn, Xivu Arath, Harmony | Cosmological wish-dragons nesting around the Traveler's Gift Mast; slaughtered by the Hive fleets during the early campaigns of the Books of Sorrow. |

---

### 2.2 Canonical Source Inventory (65+ Entries)

The archive enforces a strict minimum threshold of 65 primary canonical records across 9 distinct source categories:

```
+-------------------------------------------------------------------------------+
| Source Category        | Count | Key Canonical Artifacts Included             |
+------------------------+-------+----------------------------------------------+
| 1. Exotic Armor        |   5   | Skull of Dire Ahamkara, Young Ahamkara's     |
|                        |       | Spine, Claws of Ahamkara, Sealed Ahamkara    |
|                        |       | Grasps, Bones of Eao (D1)                    |
| 2. Exotic Weapons      |   4   | One Thousand Voices, Wish-Keeper,            |
|                        |       | Wish-Ender, Buried Bloodline                 |
| 3. Last Wish Weapons   |   8   | Apex Predator, Age-Old Bond, Transfiguration,|
|                        |       | Nation of Beasts, Techeun Force,             |
|                        |       | Chattering Bone, Tyranny of Heaven,          |
|                        |       | The Supremacy                                |
| 4. Great Hunt Armor    |  15   | Complete Titan, Hunter, and Warlock sets     |
|                        |       | (Helm, Gauntlets, Plate, Greaves, Mark, etc.)|
| 5. Warlord's Ruin Gear |   5   | Vengeful Whisper, Dragoncult Sickle,         |
|                        |       | Naeem's Lance, Zira's Shell, Hefnd's Cairn   |
| 6. Canonical Lore Books|  12   | Marasenna (Katabasis, Azirim, Fideicide I-III|
|                        |       | Imponent I, IV), Awoken of the Reef (Telic), |
|                        |       | Book: Gifts and Bargains (Chapters 1-4),     |
|                        |       | Lethophobia, Oathkeeper                      |
| 7. Wall of Wishes      |  15   | Full cipher plates: First Wish through       |
|                        |       | Fifteenth Wish ("This one you shall cherish")|
| 8. D1 Grimoire Cards   |   9   | Legends 3, Warlock, Hunter, Titan, City Age, |
|                        |       | Lord Gheleon, Osiris, Books of Sorrow VIII/XLVI|
| 9. Dialogue Transcripts|   7   | Last Wish Raid Intro & Cinematic, Eao's Nest,|
|                        |       | Tree of Azirim, Ahamkara Tales (Osiris/Crow,  |
|                        |       | Shaxx/Mara), Final Wish Conjuration          |
+------------------------+-------+----------------------------------------------+
| TOTAL CANONICAL ENTRIES:  80 records preserved (>= 65 mandatory minimum)      |
+-------------------------------------------------------------------------------+
```

---

### 2.3 Chronological & Thematic Taxonomy

All records are categorized under standardized chronological eras and paracausal themes:

#### Chronological Eras
1. **Pre-Collapse & Ancient Origins**: Primordial emergence, the Harmony Gift Mast, and the Books of Sorrow.
2. **Dark Age & Early City Age**: The emergence of the Iron Lords, Warlord Rath's keep, and early Ahamkara sightings on Earth.
3. **The Great Ahamkara Hunt**: The Consensus edict of extinction, Guardian fireteams across Venus and Mars, and polymorphic dragon encounters.
4. **Reef Golden Age & The Dreaming City**: The arrival of Huginn and Muninn, the building of the Dreaming City, and the Wall of Wishes.
5. **The Taken War**: Oryx's assault on the Reef, the infiltration of the Dreaming City, and the Taking of Riven.
6. **Forsaken & The Dreaming City Curse**: The raid on Last Wish, the death of Riven, and the 3-week paracausal time-loop curse.
7. **Season of the Wish & The Final Shape**: The recovery of Riven's spirit, the legend of Taranis, the uncorrupted clutch, and the 15th Wish.

#### Paracausal Themes
1. **Anthem Anatheme & Wish-Bargains**: The desire-reality gap and the lethal irony of unconstrained wishes.
2. **The Great Hunt & Extinction**: The military campaigns of the Vanguard and the philosophical necessity of genocide.
3. **Fourth-Wall Transcendence ("O [Reader] Mine")**: Paracausal awareness of the player and the reality beyond the screen.
4. **The Wall of Wishes & Coded Desire**: Linguistic and mathematical firewalls built to circumvent subjective exploitation.
5. **Parentage & The Uncorrupted Clutch**: Selfless sacrifice, maternal defiance, and the survival of the species.
6. **Deathless Bones & Parasitic Whispers**: Post-mortem paracausal persistence through calcified armor and weapons.
7. **Vengeance & Twisted Desires**: The retaliatory curses of dying Ahamkara against their slayers.

---

### 2.4 Data Record Schema

Every preserved lore entry strictly conforms to a 9-field structured schema:

```json
{
  "id": "exotic-skull-of-dire-ahamkara",
  "title": "Skull of Dire Ahamkara",
  "source": {
    "type": "exotic_armor",
    "game": "Destiny 2",
    "book": null,
    "release": "Warmind",
    "bungie_ref": 2844889941,
    "ishtar_url": "https://www.ishtar-collective.net/entries/skull-of-dire-ahamkara"
  },
  "entity": ["General Ahamkara"],
  "speaker": "Ahamkara Skull",
  "transcript": "Reality is the finest flesh, oh bearer mine. And are you not hungry?...",
  "tags": ["exotic", "armor", "warlock", "helmet", "fourth-wall", "whisper", "o-bearer-mine"],
  "chronology": "The Great Ahamkara Hunt",
  "theme": "Fourth-Wall Transcendence (\"O [Reader] Mine\")"
}
```

---

## 3. openOODA Query Engine Architecture

The query engine is engineered in **openOODA** (`.oo`), a statically typed, capability-secure systems programming language. The engine uses a strictly decoupled four-tier architecture designed to allow instant migration to the forthcoming `ooda db` backend without altering search or presentation layers.

```
+--------------------------------------------------------------------------------+
|                          openOODA Query Engine Tiers                           |
|                                                                                |
|  +--------------------------------------------------------------------------+  |
|  | Tier 4: Presentation & CLI (`src/cli/`, `src/main.oo`)                   |  |
|  | - Interactive REPL explorer loop (`src/cli/interactive.oo`)              |  |
|  | - CLI flag and command router (`src/main.oo`)                            |  |
|  | - Terminal lore card and whisper quote formatter (`src/cli/format.oo`)  |  |
|  +--------------------------------------------------------------------------+  |
|                                      |                                         |
|                                      v                                         |
|  +--------------------------------------------------------------------------+  |
|  | Tier 3: Search & Analytics Engine (`src/engine/`)                        |  |
|  | - Case-insensitive keyword and substring matcher (`src/engine/search.oo`)|  |
|  | - Multi-parameter query filter (entity, category, theme, quote)          |  |
|  | - Corpus statistics and analytics aggregator (`src/engine/stats.oo`)     |  |
|  +--------------------------------------------------------------------------+  |
|                                      |                                         |
|                                      v                                         |
|  +--------------------------------------------------------------------------+  |
|  | Tier 2: Storage & Repository Layer (`src/repo/`)                         |  |
|  | - Stream-line parser extracting string & tag arrays (`json_parse.oo`)    |  |
|  | - Capability-gated loader (`&FsReadCap`) reading JSONL (`loader.oo`)      |  |
|  | - Decoupled DB contract adapter (`db_contract.oo`) ready for `ooda db`   |  |
|  +--------------------------------------------------------------------------+  |
|                                      |                                         |
|                                      v                                         |
|  +--------------------------------------------------------------------------+  |
|  | Tier 1: Domain Models (`src/model/`)                                     |  |
|  | - Strongly typed `AhamkaraRecord` and constructor (`record.oo`)          |  |
|  | - Search parameter model `QueryFilter` and defaults (`query.oo`)         |  |
|  +--------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------+
```

### 3.1 Compiler Invariants & Security Architecture

The codebase strictly adheres to openOODA compiler constraints and security guarantees:

- **Strict 256-Line Limit**: Every `.oo` source file is modularized to stay strictly under 256 lines as enforced by `oodac check` (`check_mod.oo:105`). Monolithic files trigger compile-time failure.
- **64 KiB Maximum File Size**: All source files remain well below the 65,536-byte limit.
- **Capability-Gated Security**: File system access requires the unforgeable `&FsReadCap` capability token. Downstream engine and CLI layers operate as pure, unprivileged functions with zero ambient authority.
- **Landlock Sandbox Execution**: The compiled native binary enforces Linux Landlock jail sandboxing during production runs, ensuring data confidentiality and filesystem isolation.

---

## 4. Quick Start & CLI Usage

### 4.1 Prerequisites

The query engine requires the openOODA compiler toolchain (`oodac` and `ooda`) installed in your environment:

```bash
# Verify compiler installation
oodac --version || /home/jeryd/.openooda/bin/oodac --version
```

### 4.2 Building the Binary

Compile the openOODA source into a standalone native binary:

```bash
# Build native binary via the C backend
OODA_COMPILER=/home/jeryd/Projects/openOODA/oodac/bin/oodac \
  /home/jeryd/Projects/openOODA/oodac/bin/oodac build --backend c src/main.oo -o bin/ahamkara
```

### 4.3 Interactive REPL Mode

Launch the interactive terminal explorer to browse lore records dynamically:

```bash
OODA_NO_JAIL=1 ./bin/ahamkara --interactive
```

```
============================================================
              AHAMKARA LORE QUERY ENGINE (REPL)             
============================================================
Commands:
  search <term>      Search full text across all lore records
  entity <name>      Filter records by Ahamkara entity name
  category <cat>     Filter by category (e.g. exotics, raid)
  quote              Display random Ahamkara whisper quote
  stats              Show corpus statistics and counts
  help               Display this help message
  quit / exit        Exit interactive shell
------------------------------------------------------------
ahamkara> entity Riven
Found 18 matching lore entries for 'Riven'.
[great-hunt-hood] Hood of the Great Hunt
Entity: Riven | Category: raid_armor | Source: Great Hunt Set
--- Lore ---
"I am Riven. Riven of a Thousand Voices..."
------------------------------------------------------------
ahamkara> 
```

### 4.4 Direct CLI Query Commands

Run one-shot queries directly from the command line:

```bash
# Search by keyword across titles, quotes, and transcripts
OODA_NO_JAIL=1 ./bin/ahamkara --search "Anthem Anatheme"

# Filter by canonical entity name
OODA_NO_JAIL=1 ./bin/ahamkara --entity "Taranis"

# Filter by lore category
OODA_NO_JAIL=1 ./bin/ahamkara --category "Exotic Armor"

# Retrieve entries containing iconic Ahamkara quotes ("O Bearer Mine", etc.)
OODA_NO_JAIL=1 ./bin/ahamkara --quote

# Display full corpus analytics and distribution counts
OODA_NO_JAIL=1 ./bin/ahamkara --stats
```

### 4.5 CLI Command Reference

| Flag / Option | Argument | Description | Example |
|---|---|---|---|
| `--search` | `<term>` | Case-insensitive substring search across all fields | `--search "O [Reader] Mine"` |
| `--entity` | `<name>` | Filter by canonical dragon name | `--entity "Hefnd"` |
| `--category`| `<cat>` | Filter by source category slug | `--category "wall_of_wishes"` |
| `--quote` | *(none)* | Restrict results to records containing canonical quotes | `--quote` |
| `--stats` | *(none)* | Print aggregated corpus metrics and entity distributions | `--stats` |
| `--interactive` | *(none)* | Start interactive terminal REPL explorer | `--interactive` |

---

## 5. Automated Verification & Quality Assurance

The repository includes a comprehensive verification suite (`verify.sh`) and an opaque-box end-to-end test suite (`tests_e2e/`).

### 5.1 Running the Verification Suite

The `verify.sh` script provides 100% automated validation with zero human intervention required:

```bash
./verify.sh
```

The script verifies:
1. **JSON & JSONL Syntax Integrity**: Validates both `data/ahamkara_corpus.json` and `data/ahamkara_corpus.jsonl` using Python's strict JSON validator.
2. **Canonical Checklist Enforcement**: Asserts the presence of all 65+ mandatory canonical records (including *Skull of Dire Ahamkara*, *Young Ahamkara's Spine*, *Bones of Eao*, *Riven*, *Taranis*, *Hefnd*, and all 15 Wishes).
3. **Record Field Completeness**: Ensures no null or empty strings in mandatory fields (`id`, `title`, `transcript`, `source`, `entity`).
4. **openOODA Typecheck (`oodac check`)**: Compiles and typechecks all `.oo` source files, verifying 0 type errors.
5. **Strict File Invariants**: Asserts that every `.oo` source file is $\le 256$ lines and $\le 64$ KiB.
6. **Functional Execution**: Executes real queries against the compiled binary and verifies exit code 0.

### 5.2 Running End-to-End Tests

```bash
./tests_e2e/run_e2e.sh
```

The E2E test suite exercises four distinct tiers:
- **Tier 1 (Feature Coverage)**: Direct CLI argument routing and individual filter flags.
- **Tier 2 (Boundary & Stress)**: Whitespace handling, Unicode quotes, case insensitivity, empty matches.
- **Tier 3 (Combinations)**: Multi-attribute queries (e.g. `--entity Riven --category raid_armor`).
- **Tier 4 (Application Scenarios)**: REPL command sequences, simulated user sessions, and stream ingestion.

---

## 6. Repository Layout

```
.
├── LICENSE                          # Apache License 2.0
├── README.md                        # Documentation and architecture guide
├── ooda.pkg                         # openOODA package manifest
├── verify.sh                        # Automated verification suite (exit 0)
├── std -> /home/jeryd/Projects/openOODA/std # openOODA standard library symlink
├── bin/                             # Compiled native binaries
│   └── ahamkara
├── data/                            # Canonical Ahamkara lore archives
│   ├── ahamkara_corpus.json         # Pretty-printed JSON array
│   ├── ahamkara_corpus.jsonl        # Line-delimited streamable JSONL
│   └── categories/                  # Entity and thematic partitions
│       ├── exotics.json             # Exotic weapons & armors
│       ├── great_hunt.json          # The Great Hunt lore tabs & Grimoire
│       ├── riven.json               # Riven of a Thousand Voices records
│       ├── taranis.json             # Taranis & Wish-Keeper records
│       └── wishes.json              # Wall of Wishes entries
├── src/                             # openOODA source code (<= 256 lines per file)
│   ├── ANCHOR.oo                    # Root module anchor
│   ├── main.oo                      # Entry point & CLI argument router
│   ├── model/                       # Tier 1: Domain models
│   │   ├── ANCHOR.oo
│   │   ├── record.oo                # AhamkaraRecord struct & validation
│   │   └── query.oo                 # QueryFilter struct & constructor
│   ├── repo/                        # Tier 2: Storage & DB contract layer
│   │   ├── ANCHOR.oo
│   │   ├── json_parse.oo            # Pure string & JSON extraction functions
│   │   ├── loader.oo                # Capability-gated JSONL stream loader
│   │   └── db_contract.oo           # Decoupled interface contract for ooda db
│   ├── engine/                      # Tier 3: Search & analytics engine
│   │   ├── ANCHOR.oo
│   │   ├── search.oo                # Substring & multi-filter search logic
│   │   └── stats.oo                 # Corpus analytics & distribution calculations
│   └── cli/                         # Tier 4: Presentation & REPL
│       ├── ANCHOR.oo
│       ├── format.oo                # Card formatting & terminal display
│       └── interactive.oo           # Interactive REPL session
├── tests/                           # openOODA unit tests
│   ├── ANCHOR.oo
│   ├── test_model.oo
│   ├── test_parser.oo
│   ├── test_engine.oo
│   └── test_repo.oo
└── tests_e2e/                       # Opaque-box E2E test suite
    ├── run_e2e.sh                   # Master E2E test runner
    ├── tier1_feature_tests.sh       # Tier 1 feature tests
    ├── tier2_boundary_tests.sh      # Tier 2 boundary tests
    ├── tier3_combination_tests.sh   # Tier 3 combination tests
    └── tier4_scenario_tests.sh      # Tier 4 application scenario tests
```

---

## 7. Attribution & Licensing

### Software License
The openOODA query engine source code, parser utilities, tests, and verification scripts are released under the [Apache License, Version 2.0](LICENSE).

### Intellectual Property & Lore Attribution
- *Destiny*, *Destiny 2*, the Taken War, the Dreaming City, Riven, Ahamkara, Grimoire texts, lore books, item descriptions, and all related characters and trademarks are the intellectual property of **Bungie, Inc.**
- This project is an independent lore preservation and educational open-source software project created under fair use for archival and research purposes.
- Canonical lore data was ingested and verified via the **[Ishtar Collective API](https://api.ishtar-collective.net/)**. Sincere gratitude to the Ishtar Collective archivist community for their tireless work cataloging the history of the *Destiny* universe.

---
*“This one you shall cherish.”*
