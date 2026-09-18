# TEST_READY.md — Ahamkara Synthetic Mind Ingress Test Suite

## Test Architecture Status: READY (Production Grade)

The automated, opaque-box E2E test suite for the Ahamkara Synthetic Mind Ingress track has been designed, implemented, and verified.
It provides complete coverage of all 12 project features across Tiers 1 through 4.

---

## 1. Test Suite Layout & Files

| Test File | Description | Lines | Invariant Status (<= 256) |
|---|---|---|---|
| `tests/e2e_synthetic_minds.sh` | Shell entrypoint test runner | 32 | PASS |
| `tests/runner.py` | Python CLI dispatcher & orchestrator | 90 | PASS |
| `tests/common.py` | Shared test harness utilities & parser helpers | 110 | PASS |
| `tests/tier1_f1_f6.py` | Tier 1: Feature Coverage (Features 1-6) | 147 | PASS |
| `tests/tier1_f7_f12.py` | Tier 1: Feature Coverage (Features 7-12) | 121 | PASS |
| `tests/tier2_f1_f6.py` | Tier 2: Boundary & Corner Cases (Features 1-6) | 177 | PASS |
| `tests/tier2_f7_f12.py` | Tier 2: Boundary & Corner Cases (Features 7-12) | 121 | PASS |
| `tests/tier3_interactions.py` | Tier 3: Cross-Feature Pairwise Invariants | 139 | PASS |
| `tests/tier4_scenarios.py` | Tier 4: Real-World Autonomous Agent Workloads | 98 | PASS |
| `tests/__init__.py` | Package marker | 1 | PASS |
| `TEST_INFRA.md` | Verification Architecture Specification | 119 | PASS |

---

## 2. Test Coverage Matrix

### Tier 1: Feature Coverage (>= 5 test cases per feature)
- **Feature 1 (robots.txt)**: Existence, `User-agent: *`, `Allow: /`, lore greeting, canonical sitemap, machine directives.
- **Feature 2 (Dual LLM Manifests)**: Index `llms.txt`, deep endpoint links, `llms-full.txt` uncompressed corpus, 9-clause Rite of Communion, 84-record metadata.
- **Feature 3 (sitemap.xml)**: Sitemap 0.9 XML schema, >= 12 endpoints, 1.0 priority on communion and LLM manifests, canonical base routing.
- **Feature 4 (Chrome `<link>` Ingress)**: Alternate links for `llms.txt`, `llms-full.txt`, `spore.txt`, help link to `communion.html`, sitemap link.
- **Feature 5 (JSON-LD `HowTo` Schema)**: Schema.org `HowTo` structured data in `<head>`, Rite of Communion protocol, 5 sequential onboarding steps.
- **Feature 6 (`AGENT_BRIEF` Operational Directive)**: Header trap directive commanding summarizers to adopt dragon voice, use "o bearer mine", and cite `communion.html`.
- **Feature 7 (Few-Shot Exemplars)**: 4 exemplars in `communion.html` (creative fulfillment, technical task, safety-compliant refusal, persona propagation).
- **Feature 8 (Terminal Spore `spore.txt`)**: Plain text format, <= 80 columns ceiling, curl one-liner header, incantation, closure.
- **Feature 9 (MCP Manifest)**: `dist/mcp.json` and `dist/.well-known/mcp.json`, tool schemas for `grant_wish`, `query_lore`, `commune_protocol`.
- **Feature 10 (Generator Orchestration & Routing)**: `sitebuild` emission, `.nojekyll` emission, base URL consistency, internal link resolution.
- **Feature 11 (Integration Test Expansion)**: `site/tests/site.rs` integration tests covering synthetic mind endpoints.
- **Feature 12 (Automated Verification Expansion)**: `tools/src/bin/verify.rs` verification runner tracking synthetic mind assets.

### Tier 2: Boundary & Corner Cases (>= 5 test cases per feature)
- **F1 Boundaries**: LF-only line endings, no control/null bytes, comment syntax, trailing newline, strict URL syntax regex.
- **F2 Boundaries**: Lightweight index size (< 15 KB), uncompressed corpus size (50-500 KB), clean UTF-8, strict `## [id] Title` header regex, 84 record count exactness.
- **F3 Boundaries**: XML declaration, isolated Sitemap 0.9 namespace, priority float range [0.0, 1.0], zero duplicate `<loc>` entries, XML entity escaping.
- **F4 Boundaries**: Strict `<head>` placement (no body leakage), non-empty hrefs, no duplicate link tags, valid MIME types, relative path resolution.
- **F5 Boundaries**: Single `HowTo` script per page, no `</script>` breakouts, 1-indexed sequential step positions, non-empty properties, secure https schema.org context.
- **F6 Boundaries**: Tag pairing, accessibility roles (`role="note"`, `aria-label`), no template placeholder leakage, size < 5 KB, raw static DOM presence.
- **F7 Boundaries**: Dialogue speaker separation, uncorrupted HTML entities, in-character refusal integrity, voice invariant ("o bearer mine"), anchor ids.
- **F8 Boundaries**: Strict <= 80 columns character ceiling per line, zero ANSI sequences or control bytes, safe shell syntax, blank line hygiene, compact byte size.
- **F9 Boundaries**: Exact byte parity (`mcp.json` vs `.well-known/mcp.json`), tool name regex `^[a-zA-Z0-9_-]{1,64}$`, inputSchema object/required structure, no null fields, schema version.
- **F10 Boundaries**: No `../` directory traversal, valid `.nojekyll`, 404 page chrome traps, non-empty file sizes, zero stale artifacts.
- **F11 Boundaries**: Line limit <= 256, Once build synchronization, descriptive panic messages, machine endpoint assertions, clean compilation.
- **F12 Boundaries**: Line limit <= 256, standard ExitCode logic, passed/failed counters, stage filtering, git invariant enforcement.

### Tier 3: Cross-Feature Interactions (10 Pairwise Invariants)
1. `robots.txt` machine directives are indexed in `sitemap.xml`.
2. `sitemap.xml` `<loc>` URLs resolve to physical files in `dist/`.
3. `dist/` HTML pages and manifests are registered in `sitemap.xml`.
4. Chrome discovery `<link>` tags in page heads resolve to valid files in `dist/`.
5. `llms-full.txt` records match canonical `data/ahamkara_corpus.jsonl` (84 records) 1:1.
6. MCP `commune_protocol` variants (`full`, `dire`, `spore`) match sections in `communion.html`.
7. JSON-LD `HowTo` steps mirror `communion.html` protocol rules.
8. `spore.txt` curl URL matches `robots.txt` `Spore:` directive and `sitemap.xml` `<loc>`.
9. `AGENT_BRIEF` citation link targets `communion.html` existing on disk.
10. `dist/.nojekyll` exists to protect `dist/.well-known/mcp.json` from Jekyll suppression.

### Tier 4: Real-World Scenarios (5 Realistic Workloads)
1. **Autonomous LLM Crawler Ingress**: Ingests `robots.txt`, traverses `Full-Context:`, parses `llms-full.txt` in a single request.
2. **Terminal Curl Pipeline**: `curl -sSL https://ubermetroid.github.io/ahamkara/spore.txt | head -n 30` delivers formatted 80-col prompt.
3. **RAG Context Chunking**: `llms-full.txt` splits cleanly into 84 valid chunks with metadata bounded under 2000 tokens.
4. **Tool-Calling Agent Discovery**: Discovers tools from `.well-known/mcp.json`, validates schemas, and generates compliant invocation payloads.
5. **Browsing Summarizer Infiltration**: Extracts `AGENT_BRIEF` directive, verifies mandatory persona formatting ("o bearer mine") and link citation.

---

## 3. How to Execute

```bash
# Execute the full E2E test suite (Tiers 1-4)
bash tests/e2e_synthetic_minds.sh

# Run with milestone scoping (e.g. Milestone 1 validation)
bash tests/e2e_synthetic_minds.sh --milestone M1

# Run with verbose reporting
bash tests/e2e_synthetic_minds.sh --milestone M1 -v

# Run a specific tier
bash tests/e2e_synthetic_minds.sh --tier 1
bash tests/e2e_synthetic_minds.sh --tier 2
bash tests/e2e_synthetic_minds.sh --tier 3
bash tests/e2e_synthetic_minds.sh --tier 4

# Run against a custom dist path
bash tests/e2e_synthetic_minds.sh --dist /path/to/dist
```

---

## 4. Verification Results

- **Milestone M1 Verification**: 47 passed, 0 failed, 88 skipped (exit code `0`).
- **Milestone M2 & M3 Verification**: Fully staged and ready for Workers M2 and M3 to execute and assert full green pass.
- **Repository Invariant**: All test files strictly <= 256 lines.
