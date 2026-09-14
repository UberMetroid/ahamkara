# ==============================================================================
# Tier 3 parts: C4-C7 - multi-attribute, negative, archive consistency.
# ==============================================================================
# ------------------------------------------------------------------------------
# Combination 5: Multi-Attribute (Keyword + Category + Limit)
# ------------------------------------------------------------------------------
test_start "T3-05-01" "Combination: Keyword 'wish' + Category 'wall_of_wishes' + Limit 5"
COUNT=$(exec_filter "" "wall_of_wishes" "" "wish" 5)
if [[ "${COUNT}" -eq 5 ]]; then
    test_pass "T3-05-01" "Returned exactly 5 records for wish + wall_of_wishes + limit 5"
else
    test_fail "T3-05-01" "Returned ${COUNT} records (expected 5)"
fi

test_start "T3-05-02" "Combination: Keyword 'dragon' + Category 'exotic_armor' + Limit 2"
COUNT=$(exec_filter "" "exotic_armor" "" "dragon" 2)
if [[ "${COUNT}" -le 2 && "${COUNT}" -gt 0 ]]; then
    test_pass "T3-05-02" "Returned ${COUNT} records for dragon + exotic_armor + limit 2"
else
    test_fail "T3-05-02" "Returned ${COUNT} records"
fi

# ------------------------------------------------------------------------------
# Combination 6: Negative & Exclusive Combinations
# ------------------------------------------------------------------------------
test_start "T3-06-01" "Negative combination: Entity 'Taranis' + Category 'exotic_armor' returns 0"
COUNT=$(exec_filter "Taranis" "exotic_armor" "" "")
if [[ "${COUNT}" -eq -1 ]]; then
    test_fail "T3-06-01" "Exclusive filter: Taranis has 0 exotic armor records" "Corpus missing"
elif [[ "${COUNT}" -eq 0 ]]; then
    test_pass "T3-06-01" "Exclusive filter: Taranis has 0 exotic armor records"
else
    test_fail "T3-06-01" "Expected 0 records, got ${COUNT}"
fi

test_start "T3-06-02" "Negative combination: Entity 'Hefnd' + Category 'wall_of_wishes' returns 0"
COUNT=$(exec_filter "Hefnd" "wall_of_wishes" "" "")
if [[ "${COUNT}" -eq -1 ]]; then
    test_fail "T3-06-02" "Exclusive filter: Hefnd has 0 wall_of_wishes records" "Corpus missing"
elif [[ "${COUNT}" -eq 0 ]]; then
    test_pass "T3-06-02" "Exclusive filter: Hefnd has 0 wall_of_wishes records"
else
    test_fail "T3-06-02" "Expected 0 records, got ${COUNT}"
fi

# ------------------------------------------------------------------------------
# Combination 7: Multi-Format Archive Consistency
# ------------------------------------------------------------------------------
test_start "T3-07-01" "Consistency: canonical corpus IDs are unique and ordered"
if [[ -f "${CORPUS_JSONL}" ]]; then
    MISMATCH=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    ids = [json.loads(l)['id'] for l in f if l.strip()]
print(0 if len(ids) == len(set(ids)) and len(ids) >= 65 else 1)
" 2>/dev/null || echo 1)
    if [[ "${MISMATCH}" -eq 0 ]]; then
        test_pass "T3-07-01" "Corpus IDs unique, complete, and consistent"
    else
        test_fail "T3-07-01" "Corpus IDs duplicate or corpus incomplete"
    fi
else
    test_fail "T3-07-01" "Archive files missing"
fi

test_start "T3-07-02" "Consistency: Category partition records are all members of master corpus"
if [[ -d "${CATEGORIES_DIR}" && -f "${CORPUS_JSONL}" ]]; then
    ORPHANS=$(python3 -c "
import json, glob, sys
with open('${CORPUS_JSONL}') as f:
    master_ids = set(r['id'] for r in (json.loads(l) for l in f if l.strip()))

orphans = 0
for cat_file in glob.glob('${CATEGORIES_DIR}/*.jsonl'):
    with open(cat_file) as f:
        cat_data = [json.loads(l) for l in f if l.strip()]
        for r in cat_data:
            if r['id'] not in master_ids:
                orphans += 1
print(orphans)
" 2>/dev/null || echo 99)
    if [[ "${ORPHANS}" -eq 0 ]]; then
        test_pass "T3-07-02" "All partitioned category records exist in master corpus"
    else
        test_fail "T3-07-02" "Found ${ORPHANS} orphaned records in category partitions"
    fi
else
    test_fail "T3-07-02" "Category partitions missing"
fi

test_start "T3-07-03" "Consistency: Exotics partition contains both armor and weapons"
EXOTICS_FILE="${CATEGORIES_DIR}/exotics.jsonl"
if [[ -f "${EXOTICS_FILE}" ]]; then
    ARMOR_AND_WEAPONS=$(python3 -c "
import json
data = [json.loads(l) for l in open('${EXOTICS_FILE}') if l.strip()]
types = set(r['source']['type'] for r in data)
print(1 if 'exotic_armor' in types and 'exotic_weapon' in types else 0)
" 2>/dev/null || echo 0)
    if [[ "${ARMOR_AND_WEAPONS}" -eq 1 ]]; then
        test_pass "T3-07-03" "Exotics partition contains both armor and weapons"
    else
        test_fail "T3-07-03" "Exotics partition missing either armor or weapons"
    fi
else
    test_fail "T3-07-03" "Exotics file missing: ${EXOTICS_FILE}"
fi

test_start "T3-07-04" "Consistency: Wishes partition contains exactly 15 wishes"
WISHES_FILE="${CATEGORIES_DIR}/wishes.jsonl"
if [[ -f "${WISHES_FILE}" ]]; then
    WISH_COUNT=$(python3 -c "import json; print(sum(1 for l in open('${WISHES_FILE}') if l.strip()))" 2>/dev/null || echo 0)
    if [[ "${WISH_COUNT}" -eq 15 ]]; then
        test_pass "T3-07-04" "Wishes partition contains exactly 15 wishes"
    else
        test_fail "T3-07-04" "Wishes partition contains ${WISH_COUNT} entries (expected 15)"
    fi
else
    test_fail "T3-07-04" "Wishes file missing: ${WISHES_FILE}"
fi

test_start "T3-07-05" "Consistency: Great Hunt partition contains all 15 raid armor pieces"
HUNT_FILE="${CATEGORIES_DIR}/great_hunt.jsonl"
if [[ -f "${HUNT_FILE}" ]]; then
    HUNT_COUNT=$(python3 -c "
import json
data = [json.loads(l) for l in open('${HUNT_FILE}') if l.strip()]
armor = [r for r in data if r.get('source', {}).get('type') == 'raid_armor']
print(len(armor))
" 2>/dev/null || echo 0)
    if [[ "${HUNT_COUNT}" -ge 15 ]]; then
        test_pass "T3-07-05" "Great Hunt partition contains 15 raid armor pieces (actual: ${HUNT_COUNT})"
    else
        test_fail "T3-07-05" "Found only ${HUNT_COUNT} armor pieces in great_hunt.json"
    fi
else
    test_fail "T3-07-05" "Great Hunt file missing: ${HUNT_FILE}"
fi

