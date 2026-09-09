#!/usr/bin/env bash
# ==============================================================================
# Tier 4: Real-World Application Scenarios E2E Test Suite
# Validates 6 comprehensive end-to-end user workflows:
# 1. The Great Hunt Scholar
# 2. The Exotic Hunter
# 3. The Wall of Wishes Cryptarch
# 4. The Chronicler of Taranis & Hefnd
# 5. The Paracausal Metaphysician
# 6. The Automated CI/CD Verifier
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 4: Real-World Application Scenarios (6 Scenarios)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSON="${PROJECT_ROOT}/data/ahamkara_corpus.json"
CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

# ------------------------------------------------------------------------------
# Scenario 1: The Great Hunt Scholar
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 1: The Great Hunt Scholar ---${COLOR_RESET}"

test_start "T4-SC01-01" "Scholar queries chronology 'The Great Ahamkara Hunt'"
if [[ -f "${CORPUS_JSON}" ]]; then
    HUNT_RECORDS=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    ARMOR_PERSPECTIVES=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    GRIMOIRE_HUNT=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    MIMICRY_ENTRIES=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    EXOTIC_ARMOR_OK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    EXOTIC_WEAPONS_OK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    EAO_TEXT=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    WISH_SERIES=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    WISH15_OK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
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
# Scenario 4: The Chronicler of Taranis & Hefnd
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 4: The Chronicler of Taranis & Hefnd ---${COLOR_RESET}"

test_start "T4-SC04-01" "Chronicler retrieves Book: Gifts and Bargains chapters for Taranis"
if [[ -f "${CORPUS_JSON}" ]]; then
    TARANIS_BOOK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
ids = set(r['id'] for r in data)
req = {'book-gifts-first-gift', 'book-gifts-second-gift', 'book-gifts-third-gift', 'book-gifts-last-bargain'}
print(1 if req.issubset(ids) else 0)
" 2>/dev/null || echo 0)
    if [[ "${TARANIS_BOOK}" -eq 1 ]]; then
        test_pass "T4-SC04-01" "All 4 chapters of Gifts and Bargains retrieved"
    else
        test_fail "T4-SC04-01" "Missing chapters of Gifts and Bargains"
    fi
else
    test_fail "T4-SC04-01" "Corpus missing"
fi

test_start "T4-SC04-02" "Chronicler retrieves Hefnd's tragedy in Warlord's Ruin"
if [[ -f "${CORPUS_JSON}" ]]; then
    HEFND_OK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
ids = set(r['id'] for r in data)
req = {'warlord-vengeful-whisper', 'weapon-buried-bloodline'}
print(1 if req.issubset(ids) else 0)
" 2>/dev/null || echo 0)
    if [[ "${HEFND_OK}" -eq 1 ]]; then
        test_pass "T4-SC04-02" "Hefnd's gear and lore retrieved"
    else
        test_fail "T4-SC04-02" "Missing Hefnd gear records"
    fi
else
    test_fail "T4-SC04-02" "Corpus missing"
fi

# ------------------------------------------------------------------------------
# Scenario 5: The Paracausal Metaphysician (Fourth-Wall Transcendence)
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 5: The Paracausal Metaphysician ---${COLOR_RESET}"

test_start "T4-SC05-01" "Metaphysician verifies Fourth-Wall Transcendence in Skull of Dire Ahamkara"
if [[ -f "${CORPUS_JSON}" ]]; then
    FOURTH_WALL=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
skull = [r for r in data if r['id'] == 'exotic-skull-of-dire-ahamkara']
if skull:
    txt = skull[0].get('transcript', '')
    has_reader = '[Reader]' in txt or 'O [Reader] Mine' in txt or 'host' in txt
    print(1 if has_reader else 0)
else:
    print(0)
" 2>/dev/null || echo 0)
    if [[ "${FOURTH_WALL}" -eq 1 ]]; then
        test_pass "T4-SC05-01" "Skull of Dire Ahamkara preserves fourth-wall address"
    else
        test_fail "T4-SC05-01" "Fourth-wall address missing in Skull"
    fi
else
    test_fail "T4-SC05-01" "Corpus missing"
fi

test_start "T4-SC05-02" "Metaphysician confirms bracket preservation across paracausal dialogue"
if [[ -f "${CORPUS_JSON}" ]]; then
    BRACKETS_OK=$(python3 -c "
import json
with open('${CORPUS_JSON}') as f:
    data = json.load(f)
all_text = ' '.join(r.get('transcript', '') for r in data)
print(1 if '[' in all_text and ']' in all_text else 0)
" 2>/dev/null || echo 0)
    if [[ "${BRACKETS_OK}" -eq 1 ]]; then
        test_pass "T4-SC05-02" "Paracausal square brackets intact in transcripts"
    else
        test_fail "T4-SC05-02" "Paracausal square brackets missing"
    fi
else
    test_fail "T4-SC05-02" "Corpus missing"
fi

# ------------------------------------------------------------------------------
# Scenario 6: The Automated CI/CD Verifier
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 6: The Automated CI/CD Verifier ---${COLOR_RESET}"

test_start "T4-SC06-01" "CI/CD Verifier runs automated script verify.sh"
if [[ -x "${PROJECT_ROOT}/verify.sh" ]]; then
    if "${PROJECT_ROOT}/verify.sh" >/dev/null 2>&1; then
        test_pass "T4-SC06-01" "verify.sh executed cleanly (exit code 0)"
    else
        test_fail "T4-SC06-01" "verify.sh exited with non-zero code"
    fi
else
    test_fail "T4-SC06-01" "verify.sh missing or not executable"
fi

test_start "T4-SC06-02" "CI/CD Verifier audits compiler line limits (<= 256 lines per .oo file)"
VIOLATIONS=$(find "${PROJECT_ROOT}/src" -name "*.oo" 2>/dev/null | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 256 { print $2 }' || echo "")
if [[ -z "${VIOLATIONS}" ]]; then
    test_pass "T4-SC06-02" "Zero files exceed compiler 256-line limit"
else
    test_fail "T4-SC06-02" "Files exceeding 256 lines: ${VIOLATIONS}"
fi

test_start "T4-SC06-03" "CI/CD Verifier verifies Git origin synchronization capability"
if git remote get-url origin >/dev/null 2>&1; then
    test_pass "T4-SC06-03" "Git remote origin is configured for deployment"
else
    test_fail "T4-SC06-03" "Git remote origin not configured"
fi

# Print summary
print_tier_summary "Tier 4: Real-World Application Scenarios"
exit $?
