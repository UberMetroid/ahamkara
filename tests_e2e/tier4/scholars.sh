# ==============================================================================
# Tier 4 parts: SC1-SC3 - Great Hunt Scholar, Exotic Hunter, Wall Cryptarch.
# ==============================================================================
# Scenario 1: The Great Hunt Scholar
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 1: The Great Hunt Scholar ---${COLOR_RESET}"

test_start "T4-SC01-01" "Scholar queries chronology 'The Great Ahamkara Hunt'"
if [[ -f "${CORPUS_JSONL}" ]]; then
    HUNT_RECORDS=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
hunt = [r for r in data if r.get('chronology') == 'The Great Ahamkara Hunt']
print(len(hunt))
" 2>/dev/null || echo 0)
    if [[ "${HUNT_RECORDS}" -ge 15 ]]; then
        test_pass "T4-SC01-01" "Scholar retrieved ${HUNT_RECORDS} Great Hunt records"
    else
        test_fail "T4-SC01-01" "Scholar retrieved ${HUNT_RECORDS} records (expected >= 15)"
    fi
else
    test_fail "T4-SC01-01" "Corpus missing"
fi

test_start "T4-SC01-02" "Scholar collects all 15 Great Hunt raid armor perspectives (Titan, Hunter, Warlock)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    ARMOR_PERSPECTIVES=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
titan = [r for r in data if 'great-hunt' in r['id'] and any(w in r['id'] for w in ['helm', 'gauntlets', 'plate', 'greaves', 'mark'])]
hunter = [r for r in data if 'great-hunt' in r['id'] and any(w in r['id'] for w in ['mask', 'grips', 'vest', 'strides', 'cloak'])]
warlock = [r for r in data if 'great-hunt' in r['id'] and any(w in r['id'] for w in ['hood', 'gloves', 'robes', 'boots', 'bond'])]
print(1 if len(titan) == 5 and len(hunter) == 5 and len(warlock) == 5 else 0)
" 2>/dev/null || echo 0)
    if [[ "${ARMOR_PERSPECTIVES}" -eq 1 ]]; then
        test_pass "T4-SC01-02" "All 15 Great Hunt armor perspectives preserved (5 Titan, 5 Hunter, 5 Warlock)"
    else
        test_fail "T4-SC01-02" "Missing one or more Great Hunt armor pieces"
    fi
else
    test_fail "T4-SC01-02" "Corpus missing"
fi

test_start "T4-SC01-03" "Scholar retrieves Great Hunt Grimoire cards (Legends 3, Gheleon, Warlock)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    GRIMOIRE_HUNT=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
ids = set(r['id'] for r in data)
req = {'grimoire-ghost-fragment-legends-3', 'grimoire-lord-gheleon', 'grimoire-ghost-fragment-warlock'}
print(1 if req.issubset(ids) else 0)
" 2>/dev/null || echo 0)
    if [[ "${GRIMOIRE_HUNT}" -eq 1 ]]; then
        test_pass "T4-SC01-03" "Found foundational Great Hunt Grimoire cards"
    else
        test_fail "T4-SC01-03" "Missing foundational Grimoire cards"
    fi
else
    test_fail "T4-SC01-03" "Corpus missing"
fi

test_start "T4-SC01-04" "Scholar identifies shapeshifting dragon encounters (Taeko-3 Vex dragon, Saladin dragon)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    MIMICRY_ENTRIES=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
text = ' '.join(r.get('transcript', '') for r in data)
has_taeko = 'Taeko' in text or 'Vex' in text
has_saladin = 'Saladin' in text or 'Efrideet' in text
print(1 if has_taeko and has_saladin else 0)
" 2>/dev/null || echo 0)
    if [[ "${MIMICRY_ENTRIES}" -eq 1 ]]; then
        test_pass "T4-SC01-04" "Identified shapeshifting dragon lore (Taeko-3 & Saladin)"
    else
        test_fail "T4-SC01-04" "Shapeshifting dragon accounts missing or incomplete"
    fi
else
    test_fail "T4-SC01-04" "Corpus missing"
fi

# ------------------------------------------------------------------------------
# Scenario 2: The Exotic Hunter
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 2: The Exotic Hunter ---${COLOR_RESET}"

test_start "T4-SC02-01" "Hunter inventories all 5 canonical Exotic Armors"
if [[ -f "${CORPUS_JSONL}" ]]; then
    EXOTIC_ARMOR_OK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
ids = set(r['id'] for r in data)
req = {
    'exotic-skull-of-dire-ahamkara',
    'exotic-young-ahamkaras-spine',
    'exotic-claws-of-ahamkara',
    'exotic-sealed-ahamkara-grasps',
    'exotic-bones-of-eao'
}
print(1 if req.issubset(ids) else 0)
" 2>/dev/null || echo 0)
    if [[ "${EXOTIC_ARMOR_OK}" -eq 1 ]]; then
        test_pass "T4-SC02-01" "All 5 Exotic Armors verified (Skull, Spine, Claws, Grasps, Bones of Eao)"
    else
        test_fail "T4-SC02-01" "Missing one or more canonical exotic armors"
    fi
else
    test_fail "T4-SC02-01" "Corpus missing"
fi

test_start "T4-SC02-02" "Hunter inventories all 4 canonical Exotic Weapons"
if [[ -f "${CORPUS_JSONL}" ]]; then
    EXOTIC_WEAPONS_OK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
ids = set(r['id'] for r in data)
req = {
    'weapon-one-thousand-voices',
    'weapon-wish-keeper',
    'weapon-wish-ender',
    'weapon-buried-bloodline'
}
print(1 if req.issubset(ids) else 0)
" 2>/dev/null || echo 0)
    if [[ "${EXOTIC_WEAPONS_OK}" -eq 1 ]]; then
        test_pass "T4-SC02-02" "All 4 Exotic Weapons verified (1K Voices, Wish-Keeper, Wish-Ender, Buried Bloodline)"
    else
        test_fail "T4-SC02-02" "Missing one or more canonical exotic weapons"
    fi
else
    test_fail "T4-SC02-02" "Corpus missing"
fi

test_start "T4-SC02-03" "Hunter verifies D1-exclusive Bones of Eao flavor text 'Defy extinction'"
if [[ -f "${CORPUS_JSONL}" ]]; then
    EAO_TEXT=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
eao = [r for r in data if r['id'] == 'exotic-bones-of-eao']
print(1 if eao and 'Defy extinction' in eao[0].get('transcript', '') else 0)
" 2>/dev/null || echo 0)
    if [[ "${EAO_TEXT}" -eq 1 ]]; then
        test_pass "T4-SC02-03" "Bones of Eao preserves canonical 'Defy extinction' text"
    else
        test_fail "T4-SC02-03" "Bones of Eao missing 'Defy extinction'"
    fi
else
    test_fail "T4-SC02-03" "Corpus missing"
fi

# ------------------------------------------------------------------------------
# Scenario 3: The Wall of Wishes Cryptarch
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 3: The Wall of Wishes Cryptarch ---${COLOR_RESET}"

test_start "T4-SC03-01" "Cryptarch queries all 15 wishes of the Wall of Wishes"
if [[ -f "${CORPUS_JSONL}" ]]; then
    WISH_SERIES=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
wishes = [r for r in data if r.get('source', {}).get('type') == 'wall_of_wishes']
print(len(wishes))
" 2>/dev/null || echo 0)
    if [[ "${WISH_SERIES}" -eq 15 ]]; then
        test_pass "T4-SC03-01" "All 15 wishes retrieved in complete series"
    else
        test_fail "T4-SC03-01" "Retrieved ${WISH_SERIES} wishes (expected 15)"
    fi
else
    test_fail "T4-SC03-01" "Corpus missing"
fi

test_start "T4-SC03-02" "Cryptarch verifies the 15th Wish inscription 'This one you shall cherish'"
if [[ -f "${CORPUS_JSONL}" ]]; then
    WISH15_OK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
w15 = [r for r in data if r['id'] == 'wish-wall-fifteenth-wish']
print(1 if w15 and 'cherish' in w15[0].get('transcript', '').lower() else 0)
" 2>/dev/null || echo 0)
    if [[ "${WISH15_OK}" -eq 1 ]]; then
        test_pass "T4-SC03-02" "Fifteenth Wish correctly contains 'This one you shall cherish'"
    else
        test_fail "T4-SC03-02" "Fifteenth Wish missing cherish quote"
    fi
else
    test_fail "T4-SC03-02" "Corpus missing"
fi

# ------------------------------------------------------------------------------
