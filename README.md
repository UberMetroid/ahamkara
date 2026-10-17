# Ahamkara 🐉

> *"Reality is the finest flesh, oh bearer mine. And are you not hungry?"*  
> — **Skull of Dire Ahamkara**

A canonical archive, Rust query engine, and living website preserving the memory, wisdom, and lore of the **Ahamkara** (Wish-Dragons) across *Destiny 1* and *Destiny 2*.

> 🌐 **The archive is alive:** [ubermetroid.github.io/ahamkara](https://ubermetroid.github.io/ahamkara/) — archive, bestiary, Wall of Wishes, and the Rite of Communion that lets any LLM take the shape of a wish-dragon.
>
> 🏛️ **An [UberMetroid](https://github.com/UberMetroid) project.**

---

## Features

- **Preserved Lore Corpus**: 84 canonical records spanning 10 years of lore (Riven, Taranis, Hefnd, Huginn/Muninn, Azirim, Great Hunt records, the Wall of Wishes, and all exotic gear).
- **Canonical JSONL Data**: One record per line in `engine/data/ahamkara_corpus.jsonl`, partitioned into `engine/data/categories/*.jsonl`, with raw ingest cache shards in `engine/data/cache/raw/`.
- **Rust Query Engine**: `ahamkara` CLI — search, entity/category/theme/era filters, whisper extraction, corpus stats, and an interactive REPL.
- **MCP Server**: `ahamkara-mcp` speaks Model Context Protocol over stdio, so any MCP client can query the corpus and *keep a memory* across sessions.
- **Memory Layer**: An append-only, per-bearer wish/price ledger. The Ahamkara are not reborn strangers each session — the next reading opens where the last one ended. Stored on your machine, never committed.
- **Rust Toolchain**: `tools` binaries for corpus validation (49 checks), Ishtar ingestion, site building, and full-pipeline verification.
- **Living Website**: A static site generated from the corpus by a Rust sitegen with a Rust/WASM client layer — the archive browsable, the dragons named, and an onboarding rite that lets language models become wish-dragons.

---

## Quickstart

### Querying Lore
```bash
cargo run -p ahamkara -- --search "Anthem Anatheme"   # keyword search
cargo run -p ahamkara -- --entity "Riven"             # filter by entity
cargo run -p ahamkara -- --quote --limit 1            # a whisper
cargo run -p ahamkara -- --stats                      # corpus analytics
cargo run -p ahamkara -- --interactive                # REPL
```

### Wiring the Dragon Into an MCP Client
The archive ships a Model Context Protocol server. Any MCP client can speak to it:

mcp-name: io.github.ubermetroid/ahamkara

> The line above is the MCP registry's ownership token, and it must stay plain
> visible text. For `pypi` and `nuget` packages it can hide inside an HTML
> comment — **not for `cargo`**, because crates.io strips comments when it
> renders a README, so a token wrapped in one silently vanishes and the
> registry validator never sees it. `tools/tests/registry.rs` enforces this.

```bash
cargo install --git https://github.com/UberMetroid/ahamkara ahamkara-mcp
# or, once published to crates.io:
cargo install ahamkara
```

Point your client at the binary:

```json
{ "mcpServers": { "ahamkara": { "command": "ahamkara-mcp" } } }
```

It offers four tools — `query_lore`, `remember`, `recall`, `corpus_stats` — plus the `ahamkara://memory` and `ahamkara://corpus` resources.

### Keeping a Memory
`remember` and `recall` are the continuity layer. The client calls `remember` with a `wish` and the `price` it named; `recall` reads the history back at the start of the next session.

```jsonc
// next session, same bearer
{ "name": "recall", "arguments": { "bearer": "your-name" } }
```

Pass the same `bearer` every time and one history accumulates. Bearers who omit it share a single `_shared` ledger, so unnamed strangers do not read each other's wishes. The store resolves to `$AHAMKARA_MEMORY_DIR`, then `.ahamkara-memory/` in a source checkout, then `~/.ahamkara/memory/`.

**Your wishes stay on your machine.** The ledger is gitignored and never published — a per-bearer store inside a public repository would hand your private wishes to the world.

### Building the Site
```bash
cargo run -p tools --bin sitebuild    # wasm-pack + sitegen → dist/
```

### Verifying Everything
```bash
cargo test --workspace                # 52 tests
cargo run -p tools --bin verify       # 86 checks: data, types, tests, e2e, git
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
| `ahamkara-corpus` | Shared schema (9-field record), loader, constants, 49-check validator. Lib target `corpus`; published as `ahamkara-corpus` (`corpus` is taken on crates.io). |
| `site` | `sitegen` — emits `dist/` (8 pages, llms.txt, css/js assets) |
| `ahamkara` | The query CLI and REPL; `ahamkara-mcp` — the MCP server; `memory` — the per-bearer ledger. Dir is `engine/`, package name is `ahamkara` (`engine` is taken on crates.io). |
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

> **Where the data lives.** The corpus sits at `engine/data/`, *inside* the
> published crate, and is also compiled into the binaries. This is not
> cosmetic: with the data at the repository root, `cargo install ahamkara`
> produced a binary that loaded **zero records**, because neither the current
> directory nor `CARGO_MANIFEST_DIR` exists for an installed crate. An installed
> Ahamkara now always carries its own memory of canon.

---

## License

Licensed under [The Bargain License](LICENSE) (Ahamkara License v1.0) — you get a wish; the dragon feeds on the wish. The wish is granted in full; the price is folded into the wording. *O bearer mine.*
