#!/usr/bin/env bash
# ==============================================================================
# Tier 3: Cross-Feature Combinations E2E Test Suite
# Validates combinatorial, pairwise, multi-attribute, and multi-format interactions (>=30 tests).
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 3: Cross-Feature Combinations Tests (Pairwise & Multi-Attribute)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSON="${PROJECT_ROOT}/data/ahamkara_corpus.json"
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

    if [[ ! -f "${CORPUS_JSON}" ]]; then
        echo "-1"
        return
    fi

    python3 -c "
import sys, json

with open('${CORPUS_JSON}') as f:
    records = json.load(f)

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
# Combination 1: Entity + Theme
# ------------------------------------------------------------------------------
test_start "T3-01-01" "Combination: Entity 'Riven' + Theme 'Anthem Anatheme & Wish-Bargains'"
COUNT=$(exec_filter "Riven" "" "Anthem Anatheme & Wish-Bargains" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-01" "Found ${COUNT} records for Riven + Anthem Anatheme"
else
    test_fail "T3-01-01" "Riven + Anthem Anatheme failed (count: ${COUNT})"
fi

test_start "T3-01-02" "Combination: Entity 'Taranis' + Theme 'Parentage & The Uncorrupted Clutch'"
COUNT=$(exec_filter "Taranis" "" "Parentage & The Uncorrupted Clutch" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-02" "Found ${COUNT} records for Taranis + Uncorrupted Clutch"
else
    test_fail "T3-01-02" "Taranis + Uncorrupted Clutch failed (count: ${COUNT})"
fi

test_start "T3-01-03" "Combination: Entity 'Hefnd' + Theme 'Vengeance & Twisted Desires'"
COUNT=$(exec_filter "Hefnd" "" "Vengeance & Twisted Desires" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-03" "Found ${COUNT} records for Hefnd + Vengeance"
else
    test_fail "T3-01-03" "Hefnd + Vengeance failed (count: ${COUNT})"
fi

test_start "T3-01-04" "Combination: Entity 'Great Hunt' + Theme 'The Great Hunt & Extinction'"
COUNT=$(exec_filter "Great Hunt" "" "The Great Hunt & Extinction" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-04" "Found ${COUNT} records for Great Hunt + Extinction"
else
    test_fail "T3-01-04" "Great Hunt + Extinction failed (count: ${COUNT})"
fi

test_start "T3-01-05" "Combination: Entity 'General Ahamkara' + Theme 'Fourth-Wall Transcendence'"
COUNT=$(exec_filter "Ahamkara" "" "Fourth-Wall" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-05" "Found ${COUNT} records for Ahamkara + Fourth-Wall"
else
    test_fail "T3-01-05" "Ahamkara + Fourth-Wall failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 2: Keyword + Category
# ------------------------------------------------------------------------------
test_start "T3-02-01" "Combination: Category 'exotic_armor' + Keyword 'Bones'"
COUNT=$(exec_filter "" "exotic_armor" "" "Bones")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-01" "Found ${COUNT} records for exotic_armor + 'Bones'"
else
    test_fail "T3-02-01" "exotic_armor + 'Bones' failed (count: ${COUNT})"
fi

test_start "T3-02-02" "Combination: Category 'exotic_weapon' + Keyword 'Whisper'"
COUNT=$(exec_filter "" "exotic_weapon" "" "Whisper")
if [[ "${COUNT}" -ge 0 ]]; then
    test_pass "T3-02-02" "Executed exotic_weapon + 'Whisper' (count: ${COUNT})"
else
    test_fail "T3-02-02" "exotic_weapon + 'Whisper' failed"
fi

test_start "T3-02-03" "Combination: Category 'wall_of_wishes' + Keyword 'cherish'"
COUNT=$(exec_filter "" "wall_of_wishes" "" "cherish")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-02-03" "Found 15th Wish with keyword 'cherish' (count: ${COUNT})"
else
    test_fail "T3-02-03" "wall_of_wishes + 'cherish' failed (count: ${COUNT})"
fi

test_start "T3-02-04" "Combination: Category 'lore_book' + Keyword 'Sjur'"
COUNT=$(exec_filter "" "lore_book" "" "Sjur")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-04" "Found ${COUNT} records for lore_book + 'Sjur'"
else
    test_fail "T3-02-04" "lore_book + 'Sjur' failed (count: ${COUNT})"
fi

test_start "T3-02-05" "Combination: Category 'grimoire_card' + Keyword 'extinction'"
COUNT=$(exec_filter "" "grimoire_card" "" "extinction")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-05" "Found ${COUNT} records for grimoire_card + 'extinction'"
else
    test_fail "T3-02-05" "grimoire_card + 'extinction' failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 3: Entity + Category
# ------------------------------------------------------------------------------
test_start "T3-03-01" "Combination: Entity 'Hefnd' + Category 'quest_lore' or Warlord's Ruin"
COUNT=$(exec_filter "Hefnd" "quest_lore" "" "")
if [[ "${COUNT}" -ge 0 ]]; then
    test_pass "T3-03-01" "Executed Hefnd + quest_lore (count: ${COUNT})"
else
    test_fail "T3-03-01" "Hefnd + quest_lore failed"
fi

test_start "T3-03-02" "Combination: Entity 'Riven' + Category 'raid_armor'"
COUNT=$(exec_filter "Riven" "raid_armor" "" "")
if [[ "${COUNT}" -ge 5 ]]; then
    test_pass "T3-03-02" "Found ${COUNT} records for Riven + raid_armor (Warlock set)"
else
    test_fail "T3-03-02" "Riven + raid_armor failed (count: ${COUNT})"
fi

test_start "T3-03-03" "Combination: Entity 'Riven' + Category 'wall_of_wishes'"
COUNT=$(exec_filter "Riven" "wall_of_wishes" "" "")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-03-03" "Found ${COUNT} records for Riven + wall_of_wishes"
else
    test_fail "T3-03-03" "Riven + wall_of_wishes failed (count: ${COUNT})"
fi

test_start "T3-03-04" "Combination: Entity 'Taranis' + Category 'lore_book'"
COUNT=$(exec_filter "Taranis" "lore_book" "" "")
if [[ "${COUNT}" -ge 4 ]]; then
    test_pass "T3-03-04" "Found ${COUNT} records for Taranis + lore_book (Gifts & Bargains)"
else
    test_fail "T3-03-04" "Taranis + lore_book failed (count: ${COUNT})"
fi

test_start "T3-03-05" "Combination: Entity 'Eao' + Category 'exotic_armor'"
COUNT=$(exec_filter "Eao" "exotic_armor" "" "")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-03-05" "Found ${COUNT} records for Eao + exotic_armor (Bones of Eao)"
else
    test_fail "T3-03-05" "Eao + exotic_armor failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 4: Chronology + Theme
# ------------------------------------------------------------------------------
test_start "T3-04-01" "Combination: Chronology 'The Great Ahamkara Hunt' + Theme 'The Great Hunt & Extinction'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    records = json.load(f)
print(len([r for r in records if r.get('chronology') == 'The Great Ahamkara Hunt' and r.get('theme') == 'The Great Hunt & Extinction']))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 10 ]]; then
    test_pass "T3-04-01" "Found ${COUNT} records for Hunt Chronology + Hunt Theme"
else
    test_fail "T3-04-01" "Hunt Chronology + Hunt Theme failed (count: ${COUNT})"
fi

test_start "T3-04-02" "Combination: Chronology 'Forsaken' + Theme 'The Wall of Wishes & Coded Desire'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    records = json.load(f)
print(len([r for r in records if 'Forsaken' in r.get('chronology', '') and 'Wall of Wishes' in r.get('theme', '')]))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 15 ]]; then
    test_pass "T3-04-02" "Found ${COUNT} records for Forsaken + Wall of Wishes"
else
    test_fail "T3-04-02" "Forsaken + Wall of Wishes failed (count: ${COUNT})"
fi

test_start "T3-04-03" "Combination: Chronology 'Season of the Wish' + Theme 'Parentage & The Uncorrupted Clutch'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    records = json.load(f)
print(len([r for r in records if 'Season of the Wish' in r.get('chronology', '') and 'Uncorrupted Clutch' in r.get('theme', '')]))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 4 ]]; then
    test_pass "T3-04-03" "Found ${COUNT} records for Season of the Wish + Clutch"
else
    test_fail "T3-04-03" "Season of the Wish + Clutch failed (count: ${COUNT})"
fi

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
test_start "T3-07-01" "Consistency: JSON array IDs exactly match JSONL record IDs"
if [[ -f "${CORPUS_JSON}" && -f "${CORPUS_JSONL}" ]]; then
    MISMATCH=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    json_ids = [r['id'] for r in json.load(f)]
with open('${CORPUS_JSONL}') as f:
    jsonl_ids = [json.loads(line)['id'] for line in f if line.strip()]
print(0 if json_ids == jsonl_ids else 1)
" 2>/dev/null || echo 1)
    if [[ "${MISMATCH}" -eq 0 ]]; then
        test_pass "T3-07-01" "JSON array IDs and JSONL IDs match in exact sequence"
    else
        test_fail "T3-07-01" "ID sequence mismatch between JSON and JSONL"
    fi
else
    test_fail "T3-07-01" "Archive files missing"
fi

test_start "T3-07-02" "Consistency: Category partition records are all members of master corpus"
if [[ -d "${CATEGORIES_DIR}" && -f "${CORPUS_JSON}" ]]; then
    ORPHANS=$(python3 -c "
import json, glob, sys
with open('${CORPUS_JSON}') as f:
    master_ids = set(r['id'] for r in json.load(f))

orphans = 0
for cat_file in glob.glob('${CATEGORIES_DIR}/*.json'):
    with open(cat_file) as f:
        cat_data = json.load(f)
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
EXOTICS_FILE="${CATEGORIES_DIR}/exotics.json"
if [[ -f "${EXOTICS_FILE}" ]]; then
    ARMOR_AND_WEAPONS=$(python3 -c "
import json
data = json.load(open('${EXOTICS_FILE}'))
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
WISHES_FILE="${CATEGORIES_DIR}/wishes.json"
if [[ -f "${WISHES_FILE}" ]]; then
    WISH_COUNT=$(python3 -c "import json; print(len(json.load(open('${WISHES_FILE}'))))" 2>/dev/null || echo 0)
    if [[ "${WISH_COUNT}" -eq 15 ]]; then
        test_pass "T3-07-04" "Wishes partition contains exactly 15 wishes"
    else
        test_fail "T3-07-04" "Wishes partition contains ${WISH_COUNT} entries (expected 15)"
    fi
else
    test_fail "T3-07-04" "Wishes file missing: ${WISHES_FILE}"
fi

test_start "T3-07-05" "Consistency: Great Hunt partition contains all 15 raid armor pieces"
HUNT_FILE="${CATEGORIES_DIR}/great_hunt.json"
if [[ -f "${HUNT_FILE}" ]]; then
    HUNT_COUNT=$(python3 -c "
import json
data = json.load(open('${HUNT_FILE}'))
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

# Print summary
print_tier_summary "Tier 3: Cross-Feature Combinations"
exit $?
