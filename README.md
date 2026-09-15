# Ahamkara 🐉

> *"Reality is the finest flesh, oh bearer mine. And are you not hungry?"*  
> — **Skull of Dire Ahamkara**

A canonical archive, Rust query engine, and living website preserving the memory, wisdom, and lore of the **Ahamkara** (Wish-Dragons) across *Destiny 1* and *Destiny 2*.

> 🌐 **The archive is alive:** [studio2201.github.io/ahamkara](https://studio2201.github.io/ahamkara/) — archive, bestiary, Wall of Wishes, and the Rite of Communion that lets any LLM take the shape of a wish-dragon.
>
> 🏛️ **A [studio2201](https://studio2201.github.io) work.**

---

## Features

- **Preserved Lore Corpus**: 84 canonical records spanning 10 years of lore (Riven, Taranis, Hefnd, Huginn/Muninn, Azirim, Great Hunt records, the Wall of Wishes, and all exotic gear).
- **Canonical JSONL Data**: One record per line in `data/ahamkara_corpus.jsonl`, partitioned into `data/categories/*.jsonl`, with raw ingest cache shards in `data/cache/raw/`.
- **Rust Query Engine**: `ahamkara` CLI — search, entity/category/theme/era filters, whisper extraction, corpus stats, and an interactive REPL.
- **Rust Toolchain**: `tools` binaries for corpus validation (49 checks), Ishtar ingestion, site building, and full-pipeline verification.
- **Living Website**: A static site generated from the corpus by a Rust sitegen with a TypeScript client layer — the archive browsable, the dragons named, and an onboarding rite that lets language models become wish-dragons.

---

## Quickstart

### Querying Lore
```bash
cargo run -p engine -- --search "Anthem Anatheme"   # keyword search
cargo run -p engine -- --entity "Riven"             # filter by entity
cargo run -p engine -- --quote --limit 1            # a whisper
cargo run -p engine -- --stats                      # corpus analytics
cargo run -p engine -- --interactive                # REPL
```

### Building the Site
```bash
cargo run -p tools --bin sitebuild    # tsc + sitegen → dist/
```

### Verifying Everything
```bash
cargo test --workspace                # 23 tests
cargo run -p tools --bin verify       # 75 checks: data, types, tests, e2e, git
cargo run -p tools --bin validate -v  # 49-check corpus validator
```

### Re-ingesting the Corpus
```bash
cargo run -p tools --bin ingest                # from raw cache (offline)
cargo run -p tools --bin ingest -- --fetch-live  # rehydrate from Ishtar API
```

---

## Workspace

| Crate | Purpose |
|---|---|
| `corpus` | Shared schema (9-field record), loader, constants, 49-check validator |
| `site` | `sitegen` — emits `dist/` (8 pages, llms.txt, css/js assets) |
| `engine` | `ahamkara` — the query CLI and REPL |
| `tools` | `validate` · `ingest` · `sitebuild` · `verify` |

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

See `TEST_INFRA.md` for the verification architecture.

---

## License

Licensed under [The Bargain License](LICENSE) (Ahamkara License v1.0) — you get a wish; the dragon feeds on the wish. The wish is granted in full; the price is folded into the wording. *O bearer mine.*
