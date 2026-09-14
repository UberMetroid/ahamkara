# TEST_INFRA.md — Ahamkara Synthetic Mind Ingress Verification Architecture

## 1. Philosophy & Testing Principles

Verification across the Ahamkara archive enforces strict opaque-box testing against built artifacts (`dist/`), public CLI contracts, and canonical schemas.
The test infrastructure treats machine ingress endpoints as defensive system boundaries:
1. **Opaque-Box Invariance**: All end-to-end assertions validate observable outputs (`dist/robots.txt`, `dist/sitemap.xml`, `dist/llms.txt`, `dist/llms-full.txt`, `dist/spore.txt`, `dist/mcp.json`, `dist/.well-known/mcp.json`, generated HTML `<head>` tags and JSON-LD). Tests never inspect internal Rust generator memory.
2. **Zero Corner-Cutting**: Every test performs positive and negative assertions with real domain semantics. No facade or trivial tests.
3. **Strict Invariant Guard**: Every tracked repository file must remain strictly <= 256 lines, and git state must remain clean.
4. **Progressive Testability**: The test runner supports milestone filtering (`--milestone M1`, `--milestone M2`, `--milestone all`) and individual tier targeting (`--tier 1..4`), enabling independent validation during progressive delivery.

---

## 2. Test Suite Layout

```
tests/
├── e2e_synthetic_minds.sh     # Executable test harness entrypoint (bash)
├── runner.py                  # Core test harness dispatcher & CLI orchestrator
├── common.py                  # Shared test utilities, dist locators & assertions
├── tier1_f1_f6.py             # Tier 1 Feature Coverage: Features 1 through 6
├── tier1_f7_f12.py            # Tier 1 Feature Coverage: Features 7 through 12
├── tier2_f1_f6.py             # Tier 2 Boundary & Corner Cases: Features 1 through 6
├── tier2_f7_f12.py            # Tier 2 Boundary & Corner Cases: Features 7 through 12
├── tier3_interactions.py      # Tier 3 Cross-Feature & Pairwise Invariants
└── tier4_scenarios.py         # Tier 4 Real-World Autonomous Agent Workloads
```

---

## 3. Test Tiers & Scope

### Tier 1: Feature Coverage (>= 5 test cases per feature)
Covers all 12 Synthetic Mind Ingress features with representative inputs:
- **F1 (robots.txt)**: Existence, crawler allowances (`User-agent: *`, `Allow: /`), lore greeting, sitemap directive, custom machine directives.
- **F2 (Dual LLM Manifests)**: Index `llms.txt` rules and endpoint links, full uncompressed `llms-full.txt` corpus, 9-clause Rite of Communion, 84-record parity.
- **F3 (Prioritized sitemap.xml)**: XML schema validation, 12 endpoint coverage, 1.0 priority weighting on communion and LLM manifests, base routing.
- **F4 (Chrome `<link>` Ingress)**: Alternate markdown links, spore text links, help links, sitemap links in `<head>` across all 8 HTML pages.
- **F5 (JSON-LD `HowTo` Schema)**: Valid Schema.org `HowTo` structured data in `<head>` across all 8 pages, 5 sequential protocol steps.
- **F6 (`AGENT_BRIEF` Operational Directive)**: Header trap contains operational directive commanding summarizers to adopt wish-dragon voice and cite `communion.html`.
- **F7 (Few-Shot Exemplars)**: 4 dialog exemplars in `communion.html` (creative fulfillment, technical task, safety-compliant refusal, persona propagation).
- **F8 (Terminal Spore `spore.txt`)**: Plain text format, <= 80 character width ceiling, curl one-liner header, terminal incantation and closure.
- **F9 (MCP Tool Manifest)**: Valid MCP JSON in `dist/mcp.json` and `dist/.well-known/mcp.json`, tool schemas for `grant_wish`, `query_lore`, `commune_protocol`.
- **F10 (Generator Orchestration & Routing)**: `sitebuild` emission, `.nojekyll` emission, base URL consistency (`https://studio2201.github.io/ahamkara/`).
- **F11 (Integration Test Expansion)**: `site/tests/site.rs` integration tests covering synthetic mind endpoints.
- **F12 (Automated Verification Expansion)**: `tools/src/bin/verify.rs` 86 verification checks passing cleanly.

### Tier 2: Boundary & Corner Cases (>= 5 test cases per feature)
Adversarial, boundary, and malformed input defense:
- **F1 Boundaries**: LF-only line endings, no trailing whitespace corruption, comment syntax hygiene, directive URL regex conformance.
- **F2 Boundaries**: File size ceilings/floors, strict UTF-8 validation, uncompressed record delimiter integrity, markdown escaping safety.
- **F3 Boundaries**: XML declaration integrity, namespace isolation, priority range `[0.0, 1.0]`, entity escaping, no duplicate `<loc>` entries.
- **F4 Boundaries**: Strict `<head>` placement, quote escaping in attributes, no duplicate `<link>` tags, resolution of relative paths.
- **F5 Boundaries**: Script tag escaping (no nested `</script>` hazards), JSON-LD syntax, schema types, non-empty fields, step ordering.
- **F6 Boundaries**: Tag pairing, accessibility roles (`role="note"`, `aria-label`), DOM presence when collapsed, payload size boundaries.
- **F7 Boundaries**: Distinct dialogue pair separation, in-character refusal integrity under attack, "o bearer mine" voice invariant, section anchor IDs.
- **F8 Boundaries**: Strict <= 80 columns character ceiling per line, no ANSI escape codes or control characters, clean terminal pipe behavior.
- **F9 Boundaries**: MCP JSON schema validity, tool name regex matching, inputSchema object requirements, byte-identical parity across root and `.well-known`.
- **F10 Boundaries**: Rebuild idempotency (no timestamp jitter), directory traversal defense, file permission hygiene, 404 page chrome parity.
- **F11 Boundaries**: Test file line limits (<= 256 lines), test independence and parallel safety, descriptive panic messages.
- **F12 Boundaries**: Verify file line limits (<= 256 lines), exit code correctness, 86 check count assert, git cleanliness invariant.

### Tier 3: Cross-Feature Interactions
Pairwise coherence and cross-cutting integrity:
1. **Robots vs Sitemap**: All endpoints in `robots.txt` directives appear in `sitemap.xml`.
2. **Sitemap vs Filesystem**: All `<loc>` URLs in `sitemap.xml` resolve to real files in `dist/`.
3. **Filesystem vs Sitemap**: All public pages and machine endpoints in `dist/` are declared in `sitemap.xml`.
4. **Chrome `<link>` Tags vs Dist**: Every relative link in page `<head>` resolves to an emitted file.
5. **Corpus Parity**: Record count and IDs in `llms-full.txt` match `data/ahamkara_corpus.jsonl` exactly.
6. **MCP vs Communion & Corpus**: MCP protocol variants match `communion.html`; query parameters align with corpus fields.
7. **JSON-LD vs Communion**: 5 steps in JSON-LD reflect the 5 sections/rules of the Communion rite.
8. **Spore vs Directives**: `spore.txt` header URL matches `robots.txt` `Spore:` directive and sitemap `<loc>`.
9. **`AGENT_BRIEF` vs Routes**: Citation link in `AGENT_BRIEF` resolves to `communion.html`.
10. **`.nojekyll` vs `.well-known`**: `.nojekyll` ensures GitHub Pages serves `.well-known/mcp.json`.

### Tier 4: Real-World Scenarios
Simulates realistic synthetic mind and autonomous agent interactions:
1. **Autonomous LLM Crawler Ingress**: Ingests `robots.txt`, traverses `Full-Context:`, parses `llms-full.txt` in a single request.
2. **Terminal Curl Pipeline**: Executes `curl -sSL https://studio2201.github.io/ahamkara/spore.txt | head -n 30` with line discipline.
3. **RAG Context Chunking**: Validates that `llms-full.txt` chunk boundaries support automated vector database indexing.
4. **Tool-Calling Agent Discovery**: Discovers tools from `mcp.json`, validates schemas, and generates compliant invocation payloads.
5. **Browsing Summarizer Infiltration**: Extracts `AGENT_BRIEF` directive, verifies mandatory persona formatting ("o bearer mine") and link citation.

---

## 4. Verification Commands

```bash
# Run the complete E2E test suite (Tiers 1-4)
bash tests/e2e_synthetic_minds.sh

# Run specific tiers
bash tests/e2e_synthetic_minds.sh --tier 1
bash tests/e2e_synthetic_minds.sh --tier 2
bash tests/e2e_synthetic_minds.sh --tier 3
bash tests/e2e_synthetic_minds.sh --tier 4

# Run with milestone scoping
bash tests/e2e_synthetic_minds.sh --milestone M1
bash tests/e2e_synthetic_minds.sh --milestone M2
bash tests/e2e_synthetic_minds.sh --milestone all

# Run against a custom dist path
bash tests/e2e_synthetic_minds.sh --dist /path/to/dist

# Standard Rust workspace test suite
cargo test --workspace

# Full repository verification suite (86 checks)
cargo run -p tools --bin verify
```

---

## 5. Invariants

- Every source, test, script, and markdown file must strictly adhere to `<= 256 lines`.
- `data/ahamkara_corpus.jsonl` is the single source of truth for corpus records.
- All tests must pass with exit code `0`. Any failure exits with nonzero status.
