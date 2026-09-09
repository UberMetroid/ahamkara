#!/usr/bin/env bash
# ==============================================================================
# Tier 1: Feature Coverage E2E Test Suite
# Validates baseline presence, schema compliance, and happy paths for all 21 features.
# >=5 checks per feature (Total: 105 checks)
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 1: Feature Coverage Tests (21 Features, 105 Checks)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

# ------------------------------------------------------------------------------
# Feature 1: Git Repository & Remote
# ------------------------------------------------------------------------------
test_start "T1-F01-01" "Git repository is initialized"
if git rev-parse --git-dir >/dev/null 2>&1; then
    test_pass "T1-F01-01" "Git repository is initialized"
else
    test_fail "T1-F01-01" "Git repository is initialized" "Not a valid git repository at ${PROJECT_ROOT}"
fi

test_start "T1-F01-02" "Git remote origin exists"
if git remote | grep -q "^origin$"; then
    test_pass "T1-F01-02" "Git remote origin exists"
else
    test_fail "T1-F01-02" "Git remote origin exists" "Remote 'origin' not found"
fi

test_start "T1-F01-03" "Git remote origin points to UberMetroid/ahamkara.git"
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "${ORIGIN_URL}" =~ (https://github.com/|git@github.com:)UberMetroid/ahamkara(\.git)? ]]; then
    test_pass "T1-F01-03" "Git remote origin points to UberMetroid/ahamkara.git (${ORIGIN_URL})"
else
    test_fail "T1-F01-03" "Git remote origin points to UberMetroid/ahamkara.git" "URL is '${ORIGIN_URL}'"
fi

test_start "T1-F01-04" "Working branch exists"
BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -n "${BRANCH}" ]]; then
    test_pass "T1-F01-04" "Working branch exists (${BRANCH})"
else
    test_fail "T1-F01-04" "Working branch exists" "No active git branch detected"
fi

test_start "T1-F01-05" "Git status executes cleanly"
if git status --porcelain >/dev/null 2>&1; then
    test_pass "T1-F01-05" "Git status executes cleanly"
else
    test_fail "T1-F01-05" "Git status executes cleanly" "git status command failed"
fi

# ------------------------------------------------------------------------------
# Feature 2: openOODA Manifest & Scaffolding
# ------------------------------------------------------------------------------
assert_file_exists "T1-F02-01" "${PROJECT_ROOT}/ooda.pkg" "Package manifest ooda.pkg exists"
assert_file_contains "T1-F02-02" "${PROJECT_ROOT}/ooda.pkg" "name[[:space:]]*=[[:space:]]*ahamkara" "ooda.pkg defines package name=ahamkara"
assert_file_contains "T1-F02-03" "${PROJECT_ROOT}/ooda.pkg" "min_pin[[:space:]]*=[[:space:]]*v0.210.0" "ooda.pkg defines min_pin=v0.210.0"
assert_file_contains "T1-F02-04" "${PROJECT_ROOT}/ooda.pkg" "caps[[:space:]]*=.*FsRead" "ooda.pkg specifies FsRead capability"

test_start "T1-F02-05" "openOODA stdlib symlink or directory exists and resolves"
if [[ -e "${PROJECT_ROOT}/std" ]]; then
    test_pass "T1-F02-05" "openOODA stdlib link exists (${PROJECT_ROOT}/std)"
else
    test_fail "T1-F02-05" "openOODA stdlib link exists" "Symlink or directory ${PROJECT_ROOT}/std missing"
fi

# ------------------------------------------------------------------------------
# Feature 3: Documentation & README
# ------------------------------------------------------------------------------
assert_file_exists "T1-F03-01" "${PROJECT_ROOT}/README.md" "Documentation README.md exists"
assert_file_contains "T1-F03-02" "${PROJECT_ROOT}/README.md" "(Ahamkara|Wish-Dragon|Riven)" "README.md contains Ahamkara lore documentation"
assert_file_contains "T1-F03-03" "${PROJECT_ROOT}/README.md" "(openOODA|Architecture|Engine|Layer)" "README.md describes openOODA query engine architecture"
assert_file_contains "T1-F03-04" "${PROJECT_ROOT}/README.md" "(--search|--entity|--category|--stats|query)" "README.md details CLI usage instructions"
assert_file_contains "T1-F03-05" "${PROJECT_ROOT}/README.md" "(verify\.sh|test|verification)" "README.md documents automated verification suite"

# ------------------------------------------------------------------------------
# Feature 4: Canonical Entity Preservation
# ------------------------------------------------------------------------------
CORPUS_JSON="${PROJECT_ROOT}/data/ahamkara_corpus.json"
CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"

check_entity_presence() {
    local test_id="$1"
    local entity_name="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${CORPUS_JSON}" ]]; then
        test_fail "${test_id}" "${desc}" "Corpus JSON missing: ${CORPUS_JSON}"
        return
    fi
    local found
    found=$(python3 -c "
import json, sys
try:
    with open('${CORPUS_JSON}') as f:
        data = json.load(f)
    hits = [r for r in data if any('${entity_name}'.lower() in str(e).lower() for e in (r.get('entity') if isinstance(r.get('entity'), list) else [r.get('entity', '')]))]
    print(len(hits))
except Exception as e:
    print(0)
" 2>/dev/null || echo 0)
    if [[ "${found}" -gt 0 ]]; then
        test_pass "${test_id}" "${desc} (found ${found} entries)"
    else
        test_fail "${test_id}" "${desc}" "Entity '${entity_name}' not found in corpus"
    fi
}

check_entity_presence "T1-F04-01" "Riven" "Corpus preserves Riven of a Thousand Voices"
check_entity_presence "T1-F04-02" "Taranis" "Corpus preserves Taranis, the Wish-Keeper"
check_entity_presence "T1-F04-03" "Hefnd" "Corpus preserves Hefnd (Warlord's Ruin)"
check_entity_presence "T1-F04-04" "Huginn" "Corpus preserves Huginn & Muninn"
check_entity_presence "T1-F04-05" "Azirim" "Corpus preserves Azirim / Great Hunt dragons"

# ------------------------------------------------------------------------------
# Feature 5: Canonical Source Ingestion (Minimum 65 records)
# ------------------------------------------------------------------------------
test_start "T1-F05-01" "Corpus contains minimum 65 canonical entries"
if [[ -f "${CORPUS_JSON}" ]]; then
    TOTAL_ENTRIES=$(python3 -c "import json; data=json.load(open('${CORPUS_JSON}')); print(len(data))" 2>/dev/null || echo 0)
    if [[ "${TOTAL_ENTRIES}" -ge 65 ]]; then
        test_pass "T1-F05-01" "Corpus contains minimum 65 entries (actual: ${TOTAL_ENTRIES})"
    else
        test_fail "T1-F05-01" "Corpus contains minimum 65 entries" "Found only ${TOTAL_ENTRIES} entries, minimum is 65"
    fi
else
    test_fail "T1-F05-01" "Corpus contains minimum 65 entries" "Corpus file missing: ${CORPUS_JSON}"
fi

check_record_id_presence() {
    local test_id="$1"
    local record_id="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${CORPUS_JSON}" ]]; then
        test_fail "${test_id}" "${desc}" "Corpus JSON missing"
        return
    fi
    local found
    found=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
print(1 if any(r.get('id') == '${record_id}' for r in data) else 0)
" 2>/dev/null || echo 0)
    if [[ "${found}" -eq 1 ]]; then
        test_pass "${test_id}" "${desc}"
    else
        test_fail "${test_id}" "${desc}" "Canonical record ID '${record_id}' not found in corpus"
    fi
}

check_record_id_presence "T1-F05-02" "exotic-skull-of-dire-ahamkara" "Preserves Exotic Armor: Skull of Dire Ahamkara"
check_record_id_presence "T1-F05-03" "weapon-one-thousand-voices" "Preserves Exotic Weapon: One Thousand Voices"
check_record_id_presence "T1-F05-04" "great-hunt-helm" "Preserves Raid Armor: Helm of the Great Hunt"
check_record_id_presence "T1-F05-05" "wish-wall-fifteenth-wish" "Preserves 15th Wish: 'This one you shall cherish'"

# ------------------------------------------------------------------------------
# Feature 6: 9-Field Structured Schema Validation
# ------------------------------------------------------------------------------
validate_schema() {
    test_start "T1-F06-01" "Every record contains valid kebab-case 'id'"
    test_start "T1-F06-02" "Every record contains non-empty 'title' and 'source' object"
    test_start "T1-F06-03" "Every record contains 'entity' and 'tags' array fields"
    test_start "T1-F06-04" "Every record contains non-empty 'transcript' text"
    test_start "T1-F06-05" "Every record contains valid 'chronology' and 'theme' enums"

    if [[ ! -f "${CORPUS_JSON}" ]]; then
        test_fail "T1-F06-01" "Every record contains valid kebab-case 'id'" "Corpus file missing"
        test_fail "T1-F06-02" "Every record contains non-empty 'title' and 'source' object" "Corpus file missing"
        test_fail "T1-F06-03" "Every record contains 'entity' and 'tags' array fields" "Corpus file missing"
        test_fail "T1-F06-04" "Every record contains non-empty 'transcript' text" "Corpus file missing"
        test_fail "T1-F06-05" "Every record contains valid 'chronology' and 'theme' enums" "Corpus file missing"
        return
    fi

    python3 -c "
import json, re, sys

with open('${CORPUS_JSON}') as f:
    records = json.load(f)

id_pattern = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')
errors = {'id': 0, 'title_src': 0, 'arrays': 0, 'transcript': 0, 'enums': 0}

valid_chronology = {
    'Pre-Collapse & Ancient Origins',
    'Dark Age & Early City Age',
    'The Great Ahamkara Hunt',
    'Reef Golden Age & The Dreaming City',
    'The Taken War',
    'Forsaken & The Dreaming City Curse',
    'Season of the Wish & The Final Shape'
}

valid_themes = {
    'Anthem Anatheme & Wish-Bargains',
    'The Great Hunt & Extinction',
    'Fourth-Wall Transcendence (\"O [Reader] Mine\")',
    'The Wall of Wishes & Coded Desire',
    'Parentage & The Uncorrupted Clutch',
    'Deathless Bones & Parasitic Whispers',
    'Vengeance & Twisted Desires'
}

for r in records:
    rid = r.get('id', '')
    if not id_pattern.match(rid):
        errors['id'] += 1
    
    title = r.get('title', '')
    src = r.get('source')
    if not title or not isinstance(src, dict) or 'type' not in src or 'game' not in src:
        errors['title_src'] += 1
        
    entity = r.get('entity')
    tags = r.get('tags')
    if not isinstance(entity, list) or len(entity) == 0 or not isinstance(tags, list):
        errors['arrays'] += 1
        
    transcript = r.get('transcript', '')
    if not transcript or len(transcript.strip()) == 0:
        errors['transcript'] += 1
        
    chron = r.get('chronology', '')
    theme = r.get('theme', '')
    if chron not in valid_chronology or theme not in valid_themes:
        errors['enums'] += 1

sys.exit(0 if sum(errors.values()) == 0 else 1)
" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        test_pass "T1-F06-01" "Every record contains valid kebab-case 'id'"
        test_pass "T1-F06-02" "Every record contains non-empty 'title' and 'source' object"
        test_pass "T1-F06-03" "Every record contains 'entity' and 'tags' array fields"
        test_pass "T1-F06-04" "Every record contains non-empty 'transcript' text"
        test_pass "T1-F06-05" "Every record contains valid 'chronology' and 'theme' enums"
    else
        test_fail "T1-F06-01" "Every record contains valid kebab-case 'id'" "Schema validation encountered errors"
        test_fail "T1-F06-02" "Every record contains non-empty 'title' and 'source' object" "Schema validation encountered errors"
        test_fail "T1-F06-03" "Every record contains 'entity' and 'tags' array fields" "Schema validation encountered errors"
        test_fail "T1-F06-04" "Every record contains non-empty 'transcript' text" "Schema validation encountered errors"
        test_fail "T1-F06-05" "Every record contains valid 'chronology' and 'theme' enums" "Schema validation encountered errors"
    fi
}
validate_schema

# ------------------------------------------------------------------------------
# Feature 7: Multi-Format Lore Archives
# ------------------------------------------------------------------------------
assert_file_exists "T1-F07-01" "${PROJECT_ROOT}/data/ahamkara_corpus.json" "Canonical JSON archive exists"
assert_file_exists "T1-F07-02" "${PROJECT_ROOT}/data/ahamkara_corpus.jsonl" "Streamable JSONL archive exists"
assert_dir_exists "T1-F07-03" "${PROJECT_ROOT}/data/categories" "Categories partition directory exists"

test_start "T1-F07-04" "Partition files exist in data/categories/"
if ls "${PROJECT_ROOT}/data/categories"/*.json >/dev/null 2>&1; then
    CAT_COUNT=$(ls "${PROJECT_ROOT}/data/categories"/*.json | wc -l)
    test_pass "T1-F07-04" "Partition files exist in data/categories/ (${CAT_COUNT} categories found)"
else
    test_fail "T1-F07-04" "Partition files exist in data/categories/" "No .json files in data/categories/"
fi

test_start "T1-F07-05" "Record count matches between JSON and JSONL archives"
if [[ -f "${CORPUS_JSON}" && -f "${CORPUS_JSONL}" ]]; then
    JSON_COUNT=$(python3 -c "import json; print(len(json.load(open('${CORPUS_JSON}'))))" 2>/dev/null || echo -1)
    JSONL_COUNT=$(wc -l < "${CORPUS_JSONL}" 2>/dev/null || echo -2)
    if [[ "${JSON_COUNT}" -eq "${JSONL_COUNT}" && "${JSON_COUNT}" -gt 0 ]]; then
        test_pass "T1-F07-05" "Record count matches between JSON and JSONL (${JSON_COUNT} records)"
    else
        test_fail "T1-F07-05" "Record count matches between JSON and JSONL" "JSON: ${JSON_COUNT}, JSONL: ${JSONL_COUNT}"
    fi
else
    test_fail "T1-F07-05" "Record count matches between JSON and JSONL" "Archive files missing"
fi

# ------------------------------------------------------------------------------
# Feature 8: openOODA Domain Models
# ------------------------------------------------------------------------------
assert_file_exists "T1-F08-01" "${PROJECT_ROOT}/src/model/record.oo" "Domain model src/model/record.oo exists"
assert_file_exists "T1-F08-02" "${PROJECT_ROOT}/src/model/query.oo" "Domain model src/model/query.oo exists"
assert_file_contains "T1-F08-03" "${PROJECT_ROOT}/src/model/record.oo" "type[[:space:]]+AhamkaraRecord" "Defines AhamkaraRecord struct"
assert_file_lines_lte "T1-F08-04" "${PROJECT_ROOT}/src/model/record.oo" 256 "src/model/record.oo line count <= 256"
assert_file_size_lte "T1-F08-05" "${PROJECT_ROOT}/src/model/record.oo" 65536 "src/model/record.oo file size <= 64 KiB"

# ------------------------------------------------------------------------------
# Feature 9: Safe JSONL Parser
# ------------------------------------------------------------------------------
assert_file_exists "T1-F09-01" "${PROJECT_ROOT}/src/repo/json_parse.oo" "Parser module src/repo/json_parse.oo exists"
assert_file_contains "T1-F09-02" "${PROJECT_ROOT}/src/repo/json_parse.oo" "json_extract_string" "Parser implements json_extract_string"
assert_file_contains "T1-F09-03" "${PROJECT_ROOT}/src/repo/json_parse.oo" "json_extract_tags" "Parser implements json_extract_tags"
assert_file_lines_lte "T1-F09-04" "${PROJECT_ROOT}/src/repo/json_parse.oo" 256 "src/repo/json_parse.oo line count <= 256"
assert_file_size_lte "T1-F09-05" "${PROJECT_ROOT}/src/repo/json_parse.oo" 65536 "src/repo/json_parse.oo file size <= 64 KiB"

# ------------------------------------------------------------------------------
# Feature 10: Capability-Gated Loader
# ------------------------------------------------------------------------------
assert_file_exists "T1-F10-01" "${PROJECT_ROOT}/src/repo/loader.oo" "Loader module src/repo/loader.oo exists"
assert_file_contains "T1-F10-02" "${PROJECT_ROOT}/src/repo/loader.oo" "&FsReadCap" "Loader gates filesystem access via &FsReadCap"
assert_file_contains "T1-F10-03" "${PROJECT_ROOT}/src/repo/loader.oo" "repo_load_all" "Loader implements repo_load_all"
assert_file_contains "T1-F10-04" "${PROJECT_ROOT}/src/repo/loader.oo" "parse_record_line" "Loader implements parse_record_line"
assert_file_lines_lte "T1-F10-05" "${PROJECT_ROOT}/src/repo/loader.oo" 256 "src/repo/loader.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 11: Decoupled Database Contract
# ------------------------------------------------------------------------------
assert_file_exists "T1-F11-01" "${PROJECT_ROOT}/src/repo/db_contract.oo" "Database contract src/repo/db_contract.oo exists"
assert_file_contains "T1-F11-02" "${PROJECT_ROOT}/src/repo/db_contract.oo" "(db_contract|contract)" "Defines ooda db abstraction contract"
assert_file_lines_lte "T1-F11-03" "${PROJECT_ROOT}/src/repo/db_contract.oo" 256 "src/repo/db_contract.oo line count <= 256"

test_start "T1-F11-04" "Domain models have zero I/O imports"
if [[ -f "${PROJECT_ROOT}/src/model/record.oo" ]]; then
    if grep -qE "FsRead|read_file|import.*repo" "${PROJECT_ROOT}/src/model/record.oo"; then
        test_fail "T1-F11-04" "Domain models have zero I/O imports" "Found I/O references in model/record.oo"
    else
        test_pass "T1-F11-04" "Domain models have zero I/O imports"
    fi
else
    test_fail "T1-F11-04" "Domain models have zero I/O imports" "Model file missing"
fi

test_start "T1-F11-05" "Decoupled architecture: engine operates without filesystem I/O"
if [[ -f "${PROJECT_ROOT}/src/engine/search.oo" ]]; then
    if grep -qE "read_file|FsReadCap" "${PROJECT_ROOT}/src/engine/search.oo"; then
        test_fail "T1-F11-05" "Engine operates without filesystem I/O" "Found I/O operations in engine/search.oo"
    else
        test_pass "T1-F11-05" "Engine operates without filesystem I/O"
    fi
else
    test_fail "T1-F11-05" "Engine operates without filesystem I/O" "Engine file missing"
fi

# ------------------------------------------------------------------------------
# Feature 12: Query & Filtering Engine
# ------------------------------------------------------------------------------
assert_file_exists "T1-F12-01" "${PROJECT_ROOT}/src/engine/search.oo" "Search engine src/engine/search.oo exists"
assert_file_contains "T1-F12-02" "${PROJECT_ROOT}/src/engine/search.oo" "(contains_ic|to_lowercase|str_contains)" "Search engine supports case-insensitive search"
assert_file_contains "T1-F12-03" "${PROJECT_ROOT}/src/engine/search.oo" "entity" "Search engine filters by entity"
assert_file_contains "T1-F12-04" "${PROJECT_ROOT}/src/engine/search.oo" "category" "Search engine filters by category"
assert_file_lines_lte "T1-F12-05" "${PROJECT_ROOT}/src/engine/search.oo" 256 "src/engine/search.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 13: Corpus Analytics & Stats
# ------------------------------------------------------------------------------
assert_file_exists "T1-F13-01" "${PROJECT_ROOT}/src/engine/stats.oo" "Analytics module src/engine/stats.oo exists"
assert_file_contains "T1-F13-02" "${PROJECT_ROOT}/src/engine/stats.oo" "(stats|print_stats|RecordStats)" "Defines analytics aggregation"
assert_file_contains "T1-F13-03" "${PROJECT_ROOT}/src/engine/stats.oo" "entity" "Analytics computes entity statistics"
assert_file_contains "T1-F13-04" "${PROJECT_ROOT}/src/engine/stats.oo" "category" "Analytics computes category statistics"
assert_file_lines_lte "T1-F13-05" "${PROJECT_ROOT}/src/engine/stats.oo" 256 "src/engine/stats.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 14: Formatting & Lore Presentation
# ------------------------------------------------------------------------------
assert_file_exists "T1-F14-01" "${PROJECT_ROOT}/src/cli/format.oo" "CLI format module src/cli/format.oo exists"
assert_file_contains "T1-F14-02" "${PROJECT_ROOT}/src/cli/format.oo" "print_record_card" "Format module implements print_record_card"
assert_file_contains "T1-F14-03" "${PROJECT_ROOT}/src/cli/format.oo" "quote" "Format module formats whisper quotations"
assert_file_contains "T1-F14-04" "${PROJECT_ROOT}/src/cli/format.oo" "lore_text" "Format module displays lore text"
assert_file_lines_lte "T1-F14-05" "${PROJECT_ROOT}/src/cli/format.oo" 256 "src/cli/format.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 15: Interactive CLI REPL
# ------------------------------------------------------------------------------
assert_file_exists "T1-F15-01" "${PROJECT_ROOT}/src/cli/interactive.oo" "Interactive module src/cli/interactive.oo exists"
assert_file_contains "T1-F15-02" "${PROJECT_ROOT}/src/cli/interactive.oo" "(interactive|cli_run_interactive)" "Implements REPL runner"
assert_file_contains "T1-F15-03" "${PROJECT_ROOT}/src/cli/interactive.oo" "(search|find)" "REPL supports search commands"
assert_file_contains "T1-F15-04" "${PROJECT_ROOT}/src/cli/interactive.oo" "(quit|exit)" "REPL supports quit command"
assert_file_lines_lte "T1-F15-05" "${PROJECT_ROOT}/src/cli/interactive.oo" 256 "src/cli/interactive.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 16: CLI Command Router
# ------------------------------------------------------------------------------
assert_file_exists "T1-F16-01" "${PROJECT_ROOT}/src/main.oo" "Main CLI router src/main.oo exists"
assert_file_contains "T1-F16-02" "${PROJECT_ROOT}/src/main.oo" "pub fn main" "Defines main entry point"
assert_file_contains "T1-F16-03" "${PROJECT_ROOT}/src/main.oo" "(&FsReadCap|args)" "Main receives capability and args"
assert_file_contains "T1-F16-04" "${PROJECT_ROOT}/src/main.oo" "(--search|--keyword)" "Main handles search flag"
assert_file_lines_lte "T1-F16-05" "${PROJECT_ROOT}/src/main.oo" 256 "src/main.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 17: Zero-Error oodac check
# ------------------------------------------------------------------------------
run_oodac_check() {
    local test_id="$1"
    local file_path="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${file_path}" ]]; then
        test_fail "${test_id}" "${desc}" "Source file missing: ${file_path}"
        return
    fi
    local oodac_bin
    oodac_bin=$(command -v oodac 2>/dev/null || echo "/home/jeryd/Projects/openOODA/oodac/bin/oodac")
    if [[ ! -x "${oodac_bin}" ]]; then
        test_fail "${test_id}" "${desc}" "oodac compiler not found or not executable"
        return
    fi
    local out
    if out=$("${oodac_bin}" check "${file_path}" 2>&1); then
        test_pass "${test_id}" "${desc}"
    else
        test_fail "${test_id}" "${desc}" "oodac check failed: ${out}"
    fi
}

run_oodac_check "T1-F17-01" "${PROJECT_ROOT}/src/model/record.oo" "oodac check passes on src/model/record.oo"
run_oodac_check "T1-F17-02" "${PROJECT_ROOT}/src/repo/json_parse.oo" "oodac check passes on src/repo/json_parse.oo"
run_oodac_check "T1-F17-03" "${PROJECT_ROOT}/src/engine/search.oo" "oodac check passes on src/engine/search.oo"
run_oodac_check "T1-F17-04" "${PROJECT_ROOT}/src/cli/format.oo" "oodac check passes on src/cli/format.oo"
run_oodac_check "T1-F17-05" "${PROJECT_ROOT}/src/main.oo" "oodac check passes on src/main.oo"

# ------------------------------------------------------------------------------
# Feature 18: Automated Verification Suite
# ------------------------------------------------------------------------------
assert_file_exists "T1-F18-01" "${PROJECT_ROOT}/verify.sh" "Automated verification script verify.sh exists"

test_start "T1-F18-02" "verify.sh has executable permissions"
if [[ -x "${PROJECT_ROOT}/verify.sh" ]]; then
    test_pass "T1-F18-02" "verify.sh is executable"
else
    test_fail "T1-F18-02" "verify.sh is executable" "verify.sh is not marked executable (+x)"
fi

assert_file_contains "T1-F18-03" "${PROJECT_ROOT}/verify.sh" "(oodac check|check)" "verify.sh runs typecheck verification"
assert_file_contains "T1-F18-04" "${PROJECT_ROOT}/verify.sh" "(corpus|json|canonical)" "verify.sh checks corpus integrity"
assert_file_contains "T1-F18-05" "${PROJECT_ROOT}/verify.sh" "exit 0" "verify.sh exits with 0 on pass"

# ------------------------------------------------------------------------------
# Feature 19: Opaque-Box E2E Test Suite
# ------------------------------------------------------------------------------
assert_file_exists "T1-F19-01" "${PROJECT_ROOT}/tests_e2e/run_e2e.sh" "Master runner tests_e2e/run_e2e.sh exists"
assert_file_exists "T1-F19-02" "${PROJECT_ROOT}/tests_e2e/tier1_feature_tests.sh" "Tier 1 script exists"
assert_file_exists "T1-F19-03" "${PROJECT_ROOT}/tests_e2e/tier2_boundary_tests.sh" "Tier 2 script exists"
assert_file_exists "T1-F19-04" "${PROJECT_ROOT}/tests_e2e/tier3_combination_tests.sh" "Tier 3 script exists"
assert_file_exists "T1-F19-05" "${PROJECT_ROOT}/tests_e2e/tier4_scenario_tests.sh" "Tier 4 script exists"

# ------------------------------------------------------------------------------
# Feature 20: Adversarial Coverage Hardening
# ------------------------------------------------------------------------------
test_start "T1-F20-01" "Every .oo file obeys strict 256-line limit"
OVERSIZED_LINES=$(find "${PROJECT_ROOT}/src" -name "*.oo" 2>/dev/null | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 256 { print $2 ": " $1 }' || echo "")
if [[ -z "${OVERSIZED_LINES}" ]]; then
    test_pass "T1-F20-01" "Every .oo file obeys strict 256-line limit"
else
    test_fail "T1-F20-01" "Every .oo file obeys strict 256-line limit" "Files exceeding 256 lines: ${OVERSIZED_LINES}"
fi

test_start "T1-F20-02" "Every .oo file obeys 64 KiB per-file limit"
OVERSIZED_BYTES=$(find "${PROJECT_ROOT}/src" -name "*.oo" -size +65536c 2>/dev/null || echo "")
if [[ -z "${OVERSIZED_BYTES}" ]]; then
    test_pass "T1-F20-02" "Every .oo file obeys 64 KiB limit"
else
    test_fail "T1-F20-02" "Every .oo file obeys 64 KiB limit" "Files exceeding 64KiB: ${OVERSIZED_BYTES}"
fi

test_start "T1-F20-03" "No non-ASCII control characters in openOODA source files"
CONTROL_CHARS=$(grep -P -n "[\x00-\x08\x0B\x0C\x0E-\x1F]" "${PROJECT_ROOT}"/src/**/*.oo 2>/dev/null || echo "")
if [[ -z "${CONTROL_CHARS}" ]]; then
    test_pass "T1-F20-03" "No illegal control characters in .oo files"
else
    test_fail "T1-F20-03" "No illegal control characters in .oo files" "Found control characters: ${CONTROL_CHARS}"
fi

test_start "T1-F20-04" "Source files contain valid ANCHOR.oo module anchors"
if [[ -f "${PROJECT_ROOT}/src/ANCHOR.oo" && -f "${PROJECT_ROOT}/src/model/ANCHOR.oo" && -f "${PROJECT_ROOT}/src/repo/ANCHOR.oo" ]]; then
    test_pass "T1-F20-04" "Module anchors ANCHOR.oo present"
else
    test_fail "T1-F20-04" "Module anchors ANCHOR.oo present" "ANCHOR.oo missing in one or more source modules"
fi

test_start "T1-F20-05" "No forbidden directory traversal (..) in import statements"
TRAVERSALS=$(grep -rn 'import.*"\.\.' "${PROJECT_ROOT}/src" 2>/dev/null || echo "")
if [[ -z "${TRAVERSALS}" ]]; then
    test_pass "T1-F20-05" "No directory traversal (..) in imports"
else
    test_fail "T1-F20-05" "No directory traversal (..) in imports" "Forbidden imports found: ${TRAVERSALS}"
fi

# ------------------------------------------------------------------------------
# Feature 21: Final Git Push to GitHub
# ------------------------------------------------------------------------------
test_start "T1-F21-01" "Git remote URL is configured for HTTPS push"
PUSH_URL=$(git remote get-url --push origin 2>/dev/null || echo "")
if [[ "${PUSH_URL}" =~ (https://github.com/|git@github.com:)UberMetroid/ahamkara(\.git)? ]]; then
    test_pass "T1-F21-01" "Git remote push URL is configured (${PUSH_URL})"
else
    test_fail "T1-F21-01" "Git remote push URL is configured" "Push URL is '${PUSH_URL}'"
fi

test_start "T1-F21-02" "Default branch is set to main or master"
DEF_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "${DEF_BRANCH}" == "main" || "${DEF_BRANCH}" == "master" ]]; then
    test_pass "T1-F21-02" "Default branch is valid (${DEF_BRANCH})"
else
    test_fail "T1-F21-02" "Default branch is valid" "Current branch is '${DEF_BRANCH}'"
fi

test_start "T1-F21-03" "No committed binary artifacts in source tree"
BIN_FILES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/data" -name "*.bin" -o -name "*.o" -o -name "*.so" -o -name "*.exe" 2>/dev/null || echo "")
if [[ -z "${BIN_FILES}" ]]; then
    test_pass "T1-F21-03" "No unwanted binary artifacts in src/ or data/"
else
    test_fail "T1-F21-03" "No unwanted binary artifacts in src/ or data/" "Binaries found: ${BIN_FILES}"
fi

test_start "T1-F21-04" "Repository ignore file or clean hygiene exists"
if [[ -f "${PROJECT_ROOT}/.gitignore" || -d "${PROJECT_ROOT}/.git" ]]; then
    test_pass "T1-F21-04" "Git repository hygiene is established"
else
    test_fail "T1-F21-04" "Git repository hygiene is established" "No .gitignore or .git directory"
fi

test_start "T1-F21-05" "Git remote origin is reachable over network"
if git ls-remote --heads origin >/dev/null 2>&1; then
    test_pass "T1-F21-05" "Git remote origin is reachable"
else
    test_fail "T1-F21-05" "Git remote origin is reachable" "git ls-remote failed (network or authentication)"
fi

# Print summary
print_tier_summary "Tier 1: Feature Coverage"
exit $?
