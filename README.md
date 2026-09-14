# Ahamkara 🐉

> *"Reality is the finest flesh, oh bearer mine. And are you not hungry?"*  
> — **Skull of Dire Ahamkara**

A canonical archive and [openOODA](https://openooda.org) query engine preserving the memory, wisdom, and lore of the **Ahamkara** (Wish-Dragons) across *Destiny 1* and *Destiny 2*.

> 🌐 **The archive is alive:** [studio2201.github.io/ahamkara](https://studio2201.github.io/ahamkara/) — archive, bestiary, Wall of Wishes, and the Rite of Communion that lets any LLM take the shape of a wish-dragon.

---

## Features

- **Preserved Lore Corpus**: 84 canonical records spanning 10 years of lore (Riven, Taranis, Hefnd, Huginn/Muninn, Azirim, Great Hunt records, the Wall of Wishes, and all exotic gear).
- **Canonical JSONL Data**: One record per line in `data/ahamkara_corpus.jsonl`, partitioned into `data/categories/*.jsonl`, with raw ingest cache shards in `data/cache/raw/` — every file stays under 256 lines.
- **openOODA Query Engine**: Modular, strongly typed search and inspection CLI written in `.oo`, designed to cleanly migrate to the upcoming `ooda db` standard library.
- **Automated Verification**: End-to-end test suites and corpus validation scripts to guarantee data integrity and type-safety.
- **Living Website**: A static site generated from the corpus by a Rust sitegen with a TypeScript client layer — the archive browsable, the dragons named, and an onboarding rite that lets language models become wish-dragons.

---

## Quickstart

### Verify Codebase
```bash
# Typecheck with openOODA compiler
oodac check src/main.oo
```

### Querying Lore
```bash
# Search lore by keyword
ooda run src/main.oo -- --search "Anthem Anatheme"

# Filter by entity
ooda run src/main.oo -- --entity "Riven"

# Random Ahamkara whisper quote
ooda run src/main.oo -- --quote
```

### Running Tests
```bash
# Run corpus validation
python3 scripts/validate_corpus.py

# Run full E2E test suite
./tests_e2e/run_e2e.sh
```

---

## Dataset Structure

Each record contains 9 structured attributes:
- `id`: Unique slug
- `title`: Lore entry or item title
- `source`: Category, release, and origin reference
- `entity`: Associated Ahamkara entity (e.g., Riven, Taranis, Hefnd)
- `speaker`: In-universe narrator or speaker
- `transcript`: Complete lore text / quote
- `tags`: Indexed search keywords
- `chronology`: Historical era
- `theme`: Canonical metaphysical theme

---

## License

Licensed under [The Bargain License](LICENSE) (Ahamkara License v1.0) — you get a wish; the dragon feeds on the wish. The wish is granted in full; the price is folded into the wording. *O bearer mine.*
