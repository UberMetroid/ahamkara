#!/usr/bin/env bash
# ==============================================================================
# Tier 2: Boundary & Corner Cases E2E Test Suite (runner)
# Validates edge conditions, bracketed tokens, case variations, Unicode, limits,
# and schema boundary behaviors across all 21 feature areas (105 checks).
# Functional parts live under tests_e2e/tier2/.
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 2: Boundary & Corner Cases Tests (21 Features, 105 Checks)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

# Query execution helper
run_query() {
    local args=("$@")
    if [[ -x "${CLI_BIN}" ]]; then
        OODA_NO_JAIL=1 "${CLI_BIN}" "${args[@]}" 2>&1
        return $?
    elif [[ -f "${CORPUS_JSONL}" ]]; then
        python3 -c "
import sys, json

corpus_file = '${CORPUS_JSONL}'
try:
    with open(corpus_file) as f:
        records = [json.loads(l) for l in f if l.strip()]
except Exception:
    sys.exit(1)

args = sys.argv[1:]
keyword = ''
entity = ''
category = ''
limit = 0
quote_only = False

i = 0
while i < len(args):
    arg = args[i]
    if arg in ('--search', '--keyword') and i + 1 < len(args):
        keyword = args[i+1]
        i += 2
    elif arg == '--entity' and i + 1 < len(args):
        entity = args[i+1]
        i += 2
    elif arg == '--category' and i + 1 < len(args):
        category = args[i+1]
        i += 2
    elif arg == '--limit' and i + 1 < len(args):
        try: limit = int(args[i+1])
        except: limit = 0
        i += 2
    elif arg == '--quote':
        quote_only = True
        i += 1
    elif arg == '--stats':
        print(f'Total records: {len(records)}')
        sys.exit(0)
    else:
        i += 1

results = []
for r in records:
    # Entity filter
    if entity:
        ent_list = r.get('entity', [])
        if isinstance(ent_list, str): ent_list = [ent_list]
        if not any(entity.strip().lower() in str(e).lower() for e in ent_list):
            continue

    # Category filter
    if category:
        cat = r.get('source', {}).get('type', '')
        if category.strip().lower() not in cat.lower() and category.strip().lower() not in r.get('theme', '').lower():
            continue

    # Quote filter
    if quote_only and not r.get('speaker'):
        continue

    # Keyword filter
    if keyword:
        kw = keyword.strip().lower()
        title = r.get('title', '').lower()
        transcript = r.get('transcript', '').lower()
        tags = ' '.join(r.get('tags', [])).lower()
        if kw not in title and kw not in transcript and kw not in tags:
            continue

    results.append(r)
    if limit > 0 and len(results) >= limit:
        break

print(f'Found {len(results)} matching records.')
for r in results:
    print(f\"[{r.get('id')}] {r.get('title')}\")
" "${args[@]}" 2>&1
        return $?
    else
        return 127
    fi
}

# ------------------------------------------------------------------------------

source "${SCRIPT_DIR}/tier2/infra.sh"
source "${SCRIPT_DIR}/tier2/schema.sh"
source "${SCRIPT_DIR}/tier2/engine.sh"
source "${SCRIPT_DIR}/tier2/meta.sh"
source "${SCRIPT_DIR}/tier2/suites.sh"

# Print summary
print_tier_summary "Tier 2: Boundary & Corner Cases"

exit $?
