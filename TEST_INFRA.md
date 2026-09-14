# TEST_INFRA.md — Ahamkara Verification Architecture

## 1. Philosophy

All verification is Rust. The repository is a single Cargo workspace;
`cargo test --workspace` and the `verify` binary cover every contract the
old shell/Python/openOODA tiers covered — against real binaries, real
files, and the canonical corpus.

Opaque-box rule still holds: tests exercise user-facing contracts (CLI
flags, exit codes, stdout, generated files, JSONL schema), never
internal functions.

## 2. Layout

```
corpus/            shared library: Record/Source schema, loader, constants,
                   checks/ (49-check corpus validator)
site/              sitegen binary → dist/ (8 pages + assets)
                   tests/site.rs — generated-HTML e2e
engine/            ahamkara query CLI
                   tests/cli.rs — 17 opaque-box CLI tests
tools/             repo binaries: validate · ingest · sitebuild · verify
data/              ahamkara_corpus.jsonl · catalog.jsonl · categories/ · cache/
```

## 3. Commands

```bash
cargo test --workspace          # unit + integration + e2e (23 tests)
cargo run -p tools --bin verify # full pipeline: data→check→test→e2e→git (75 checks)

# individual stages
verify --data      # 49-check corpus validator on data/
verify --check     # cargo check + tsc --noEmit + 256-line file cap
verify --test      # cargo test --workspace
verify --e2e       # build site, assert dist/, CLI smoke tests
verify --git       # branch ahamkara + origin studio2201/ahamkara

# the other binaries
verify → validate  # corpus checks only, -v for per-check output
ingest             # catalog + cache → corpus.jsonl + partitions (offline by default)
ingest --fetch-live               # rehydrate raw cache from Ishtar API
sitebuild          # tsc + sitegen → dist/
```

## 4. What the layers guarantee

- **`corpus::checks` (49 checks)** — JSONL well-formedness, LF-only line
  endings, unique kebab-case ids, 9-field schema, enum membership
  (chronology/theme/source-type), entity preservation floors
  (Riven ≥ 40, Taranis ≥ 4, …), category coverage, E2E canaries
  (Bones of Eao "Defy extinction", Skull's fourth-wall address, 15th
  Wish "cherish"), partition coherence with the master corpus.
- **`site` e2e** — dist/ emits all 8 pages + llms.txt + css/js; every
  internal href resolves to a real file; every fragment id exists;
  the whisper pool parses as JSON with no embedded quotes/speaker tails;
  the trap is the header on every page; no stale artifacts survive
  a rebuild.
- **`engine` e2e** — CLI contract: semver `--version`, `--help` usage,
  exact match counts (Riven=43, extinction=9, wall_of_wishes=15),
  id lookup hit/miss, limit boundaries (0, 5), unknown-flag and
  missing-argument errors.
- **`verify --e2e`** — the same surface the old `tests_e2e` tiers
  covered, run against release binaries.

## 5. Invariants

- Every tracked source file ≤ 256 lines (checked in `verify --check`).
- `data/ahamkara_corpus.jsonl` is the single source of truth; all
  counts are derived, never hardcoded (except canary floors).
- Re-ingestion from the raw cache is a no-op: the serializer reproduces
  Python's `json.dumps` separators byte-for-byte.
