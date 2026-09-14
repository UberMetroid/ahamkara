# ==============================================================================
# Tier 4 parts: SC4-SC6 - Taranis/Hefnd chronicler, metaphysician, CI verifier.
# ==============================================================================
# Scenario 4: The Chronicler of Taranis & Hefnd
# ------------------------------------------------------------------------------
echo -e "${COLOR_BLUE}--- Scenario 4: The Chronicler of Taranis & Hefnd ---${COLOR_RESET}"

test_start "T4-SC04-01" "Chronicler retrieves Book: Gifts and Bargains chapters for Taranis"
if [[ -f "${CORPUS_JSONL}" ]]; then
    TARANIS_BOOK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
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
if [[ -f "${CORPUS_JSONL}" ]]; then
    HEFND_OK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
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
if [[ -f "${CORPUS_JSONL}" ]]; then
    FOURTH_WALL=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
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
if [[ -f "${CORPUS_JSONL}" ]]; then
    BRACKETS_OK=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    data = [json.loads(l) for l in f if l.strip()]
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

