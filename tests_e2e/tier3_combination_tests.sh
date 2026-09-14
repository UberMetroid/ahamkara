#!/usr/bin/env bash
# ==============================================================================
# Tier 3: Cross-Feature Combinations E2E Test Suite (runner)
# Validates combinatorial, pairwise, multi-attribute, and multi-format interactions (>=30 tests).
# Functional parts live under tests_e2e/tier3/.
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 3: Cross-Feature Combinations Tests (Pairwise & Multi-Attribute)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
CATEGORIES_DIR="${PROJECT_ROOT}/data/categories"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

# Query execution helper
exec_filter() {
    local entity="$1"
    local category="$2"
    local theme="$3"
    local keyword="$4"
    local limit="${5:-0}"

    if [[ ! -f "${CORPUS_JSONL}" ]]; then
        echo "-1"
        return
    fi

    python3 -c "
import sys, json

with open('${CORPUS_JSONL}') as f:
    records = [json.loads(l) for l in f if l.strip()]

ent = '${entity}'.lower()
cat = '${category}'.lower()
thm = '${theme}'.lower()
kw = '${keyword}'.lower()
lim = int('${limit}')

hits = []
for r in records:
    # Entity match
    if ent:
        entities = r.get('entity', [])
        if isinstance(entities, str): entities = [entities]
        if not any(ent in str(e).lower() for e in entities):
            continue

    # Category match
    if cat:
        src_type = r.get('source', {}).get('type', '').lower()
        if cat not in src_type and cat not in r.get('theme', '').lower():
            continue

    # Theme match
    if thm:
        if thm not in r.get('theme', '').lower():
            continue

    # Keyword match
    if kw:
        title = r.get('title', '').lower()
        transcript = r.get('transcript', '').lower()
        tags = ' '.join(r.get('tags', [])).lower()
        if kw not in title and kw not in transcript and kw not in tags:
            continue

    hits.append(r)
    if lim > 0 and len(hits) >= lim:
        break

print(len(hits))
" 2>/dev/null || echo "-1"
}

# ------------------------------------------------------------------------------

source "${SCRIPT_DIR}/tier3/attributes.sh"
source "${SCRIPT_DIR}/tier3/pipelines.sh"

# Print summary
print_tier_summary "Tier 3: Cross-Feature Combinations"

exit $?
