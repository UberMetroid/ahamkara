# ==============================================================================
# Tier 1 parts: F4-F7 - entity preservation, ingestion, schema, archives.
# ==============================================================================
# Feature 4: Canonical Entity Preservation
# ------------------------------------------------------------------------------
CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"

check_entity_presence() {
    local test_id="$1"
    local entity_name="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${CORPUS_JSONL}" ]]; then
        test_fail "${test_id}" "${desc}" "Corpus JSON missing: ${CORPUS_JSONL}"
        return
    fi
    local found
    found=$(python3 -c "
import json, sys
try:
    with open('${CORPUS_JSONL}') as f:
        data = [json.loads(l) for l in f if l.strip()]
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
if [[ -f "${CORPUS_JSONL}" ]]; then
    TOTAL_ENTRIES=$(python3 -c "import json; data=[json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]; print(len(data))" 2>/dev/null || echo 0)
    if [[ "${TOTAL_ENTRIES}" -ge 65 ]]; then
        test_pass "T1-F05-01" "Corpus contains minimum 65 entries (actual: ${TOTAL_ENTRIES})"
    else
        test_fail "T1-F05-01" "Corpus contains minimum 65 entries" "Found only ${TOTAL_ENTRIES} entries, minimum is 65"
    fi
else
    test_fail "T1-F05-01" "Corpus contains minimum 65 entries" "Corpus file missing: ${CORPUS_JSONL}"
fi

check_record_id_presence() {
    local test_id="$1"
    local record_id="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${CORPUS_JSONL}" ]]; then
        test_fail "${test_id}" "${desc}" "Corpus JSON missing"
        return
    fi
    local found
    found=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
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

    if [[ ! -f "${CORPUS_JSONL}" ]]; then
        test_fail "T1-F06-01" "Every record contains valid kebab-case 'id'" "Corpus file missing"
        test_fail "T1-F06-02" "Every record contains non-empty 'title' and 'source' object" "Corpus file missing"
        test_fail "T1-F06-03" "Every record contains 'entity' and 'tags' array fields" "Corpus file missing"
        test_fail "T1-F06-04" "Every record contains non-empty 'transcript' text" "Corpus file missing"
        test_fail "T1-F06-05" "Every record contains valid 'chronology' and 'theme' enums" "Corpus file missing"
        return
    fi

    python3 -c "
import json, re, sys

with open('${CORPUS_JSONL}') as f:
    records = [json.loads(l) for l in f if l.strip()]

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
# Feature 7: Canonical JSONL Archive & Partitions
# ------------------------------------------------------------------------------
assert_file_exists "T1-F07-01" "${PROJECT_ROOT}/data/ahamkara_corpus.jsonl" "Canonical JSONL archive exists"
assert_dir_exists "T1-F07-02" "${PROJECT_ROOT}/data/categories" "Categories partition directory exists"
assert_dir_exists "T1-F07-03" "${PROJECT_ROOT}/data/cache/raw" "Raw cache shard directory exists"

test_start "T1-F07-04" "JSONL partition files exist in data/categories/"
if ls "${PROJECT_ROOT}/data/categories"/*.jsonl >/dev/null 2>&1; then
    CAT_COUNT=$(ls "${PROJECT_ROOT}/data/categories"/*.jsonl | wc -l)
    test_pass "T1-F07-04" "Partition files exist in data/categories/ (${CAT_COUNT} categories found)"
else
    test_fail "T1-F07-04" "Partition files exist in data/categories/" "No .jsonl files in data/categories/"
fi

test_start "T1-F07-05" "Every partition record exists in the canonical corpus"
if [[ -f "${CORPUS_JSONL}" ]]; then
    ORPHANS=$(python3 -c "
import json, glob
corpus_ids = set(json.loads(l)['id'] for l in open('${CORPUS_JSONL}') if l.strip())
orphans = 0
for p in glob.glob('${PROJECT_ROOT}/data/categories/*.jsonl'):
    for l in open(p):
        if l.strip() and json.loads(l)['id'] not in corpus_ids:
            orphans += 1
print(orphans)
" 2>/dev/null || echo 99)
    if [[ "${ORPHANS}" -eq 0 ]]; then
        test_pass "T1-F07-05" "All partition records are members of the canonical corpus"
    else
        test_fail "T1-F07-05" "Partition records must exist in canonical corpus" "${ORPHANS} orphan records found"
    fi
else
    test_fail "T1-F07-05" "Every partition record exists in the canonical corpus" "Corpus JSONL missing"
fi

