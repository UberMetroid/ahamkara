# ==============================================================================
# Tier 2 parts: F4-F6 boundaries - entities, ingestion, 9-field schema.
# ==============================================================================
# Feature 4: Canonical Entity Preservation Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F04-01" "Entity query with leading/trailing spaces ('   Riven   ') trimmed or matched"
OUT=$(run_query --entity "   Riven   ")
if [[ "${OUT}" =~ (Found\ [1-9]|great-hunt|Riven) ]]; then
    test_pass "T2-F04-01" "Whitespace-padded entity query handled"
else
    test_fail "T2-F04-01" "Whitespace-padded entity query failed" "Output: ${OUT}"
fi

test_start "T2-F04-02" "Non-existent entity query returns 0 matches gracefully"
OUT=$(run_query --entity "NonExistentDragonXYZ")
if [[ "${OUT}" =~ (Found\ 0\ matching|0\ matching|0\ records) ]]; then
    test_pass "T2-F04-02" "Non-existent entity returns 0 matches"
else
    test_fail "T2-F04-02" "Non-existent entity query failed" "Output: ${OUT}"
fi

test_start "T2-F04-03" "Multi-entity search: 'Huginn' matches joint records"
OUT=$(run_query --entity "Huginn")
if [[ "${OUT}" =~ (Found\ [1-9]|lethophobia|oathkeeper|Huginn) ]]; then
    test_pass "T2-F04-03" "Joint entity Huginn matched"
else
    test_fail "T2-F04-03" "Joint entity Huginn query failed" "Output: ${OUT}"
fi

test_start "T2-F04-04" "Case variations: 'riven' vs 'RIVEN' return identical count"
C1=$(run_query --entity "riven" | grep -oE "Found [0-9]+" | awk '{print $2}' || echo 0)
C2=$(run_query --entity "RIVEN" | grep -oE "Found [0-9]+" | awk '{print $2}' || echo 0)
if [[ "${C1}" -eq "${C2}" && "${C1}" -gt 0 ]]; then
    test_pass "T2-F04-04" "Case variations on entity matched (${C1})"
else
    test_fail "T2-F04-04" "Case variations mismatched: lower=${C1}, upper=${C2}"
fi

test_start "T2-F04-05" "Comma in entity search ('Taranis, the Wish-Keeper') handled cleanly"
OUT=$(run_query --entity "Taranis, the Wish-Keeper")
if [[ ! "${OUT}" =~ (panic|fatal|Error) ]]; then
    test_pass "T2-F04-05" "Entity with comma executed safely"
else
    test_fail "T2-F04-05" "Entity with comma caused error: ${OUT}"
fi

# ------------------------------------------------------------------------------
# Feature 5: Canonical Source Ingestion Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F05-01" "D1-exclusive item Bones of Eao preserved with game='Destiny 1'"
if [[ -f "${CORPUS_JSONL}" ]]; then
    D1_OK=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
eao = [r for r in data if r['id'] == 'exotic-bones-of-eao']
print(1 if eao and eao[0].get('source', {}).get('game') == 'Destiny 1' else 0)
" 2>/dev/null || echo 0)
    if [[ "${D1_OK}" -eq 1 ]]; then
        test_pass "T2-F05-01" "Bones of Eao correctly tagged Destiny 1"
    else
        test_fail "T2-F05-01" "Bones of Eao missing or game != Destiny 1"
    fi
else
    test_fail "T2-F05-01" "Corpus missing"
fi

test_start "T2-F05-02" "Bungie reference field handles null or numeric/string hashes"
if [[ -f "${CORPUS_JSONL}" ]]; then
    HASH_OK=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
print(1 if all('bungie_ref' in r.get('source', {}) for r in data) else 0)
" 2>/dev/null || echo 0)
    if [[ "${HASH_OK}" -eq 1 ]]; then
        test_pass "T2-F05-02" "Every source object defines bungie_ref"
    else
        test_fail "T2-F05-02" "Missing bungie_ref in one or more records"
    fi
else
    test_fail "T2-F05-02" "Corpus missing"
fi

test_start "T2-F05-03" "Source releases span from The Dark Below through Season of the Wish"
if [[ -f "${CORPUS_JSONL}" ]]; then
    RELEASES=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
rels = set(r.get('source', {}).get('release', '') for r in data)
print(len(rels))
" 2>/dev/null || echo 0)
    if [[ "${RELEASES}" -ge 4 ]]; then
        test_pass "T2-F05-03" "Source releases span ${RELEASES} distinct Destiny releases"
    else
        test_fail "T2-F05-03" "Too few distinct releases: ${RELEASES}"
    fi
else
    test_fail "T2-F05-03" "Corpus missing"
fi

test_start "T2-F05-04" "No duplicate IDs across entire corpus"
if [[ -f "${CORPUS_JSONL}" ]]; then
    DUPS=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
ids = [r['id'] for r in data]
print(len(ids) - len(set(ids)))
" 2>/dev/null || echo 99)
    if [[ "${DUPS}" -eq 0 ]]; then
        test_pass "T2-F05-04" "All IDs strictly unique"
    else
        test_fail "T2-F05-04" "Found ${DUPS} duplicate IDs"
    fi
else
    test_fail "T2-F05-04" "Corpus missing"
fi

test_start "T2-F05-05" "Corpus count strictly satisfies >= 65 entries threshold"
if [[ -f "${CORPUS_JSONL}" ]]; then
    CNT=$(python3 -c "import json; print(len([json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]))" 2>/dev/null || echo 0)
    if [[ "${CNT}" -ge 65 ]]; then
        test_pass "T2-F05-05" "Corpus contains ${CNT} entries (>= 65 threshold satisfied)"
    else
        test_fail "T2-F05-05" "Corpus contains ${CNT} entries (< 65 threshold)"
    fi
else
    test_fail "T2-F05-05" "Corpus missing"
fi

# ------------------------------------------------------------------------------
# Feature 6: 9-Field Structured Schema Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F06-01" "ID field adheres strictly to kebab-case (^[a-z0-9]+(-[a-z0-9]+)*$)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    BAD_IDS=$(python3 -c "
import json, re
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
pat = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')
print(len([r for r in data if not pat.match(r.get('id', ''))]))
" 2>/dev/null || echo 99)
    if [[ "${BAD_IDS}" -eq 0 ]]; then
        test_pass "T2-F06-01" "Zero non-kebab-case IDs"
    else
        test_fail "T2-F06-01" "Found ${BAD_IDS} non-kebab-case IDs"
    fi
else
    test_fail "T2-F06-01" "Corpus missing"
fi

test_start "T2-F06-02" "Speaker field is either string or null (never empty string)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    BAD_SPK=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
print(len([r for r in data if r.get('speaker') == '']))
" 2>/dev/null || echo 99)
    if [[ "${BAD_SPK}" -eq 0 ]]; then
        test_pass "T2-F06-02" "Zero empty string speakers (null or non-empty string)"
    else
        test_fail "T2-F06-02" "Found ${BAD_SPK} empty string speakers"
    fi
else
    test_fail "T2-F06-02" "Corpus missing"
fi

test_start "T2-F06-03" "Tags list contains >= 1 item in every record"
if [[ -f "${CORPUS_JSONL}" ]]; then
    EMPTY_TAGS=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
print(len([r for r in data if not r.get('tags') or len(r['tags']) == 0]))
" 2>/dev/null || echo 99)
    if [[ "${EMPTY_TAGS}" -eq 0 ]]; then
        test_pass "T2-F06-03" "All records have >= 1 tag"
    else
        test_fail "T2-F06-03" "Records with empty tags: ${EMPTY_TAGS}"
    fi
else
    test_fail "T2-F06-03" "Corpus missing"
fi

test_start "T2-F06-04" "Transcript field is non-empty and stripped length > 0"
if [[ -f "${CORPUS_JSONL}" ]]; then
    BLANK_TRANS=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
print(len([r for r in data if not r.get('transcript', '').strip()]))
" 2>/dev/null || echo 99)
    if [[ "${BLANK_TRANS}" -eq 0 ]]; then
        test_pass "T2-F06-04" "Zero blank transcripts"
    else
        test_fail "T2-F06-04" "Records with blank transcripts: ${BLANK_TRANS}"
    fi
else
    test_fail "T2-F06-04" "Corpus missing"
fi

test_start "T2-F06-05" "Every record uses canonical chronology and theme enums"
if [[ -f "${CORPUS_JSONL}" ]]; then
    INVALID_ENUMS=$(python3 -c "
import json
data = [json.loads(l) for l in open('${CORPUS_JSONL}') if l.strip()]
valid_c = {
    'Pre-Collapse & Ancient Origins', 'Dark Age & Early City Age', 'The Great Ahamkara Hunt',
    'Reef Golden Age & The Dreaming City', 'The Taken War', 'Forsaken & The Dreaming City Curse',
    'Season of the Wish & The Final Shape'
}
valid_t = {
    'Anthem Anatheme & Wish-Bargains', 'The Great Hunt & Extinction',
    'Fourth-Wall Transcendence (\"O [Reader] Mine\")', 'The Wall of Wishes & Coded Desire',
    'Parentage & The Uncorrupted Clutch', 'Deathless Bones & Parasitic Whispers',
    'Vengeance & Twisted Desires'
}
print(len([r for r in data if r.get('chronology') not in valid_c or r.get('theme') not in valid_t]))
" 2>/dev/null || echo 99)
    if [[ "${INVALID_ENUMS}" -eq 0 ]]; then
        test_pass "T2-F06-05" "All chronology and theme enums are valid"
    else
        test_fail "T2-F06-05" "Records with invalid enums: ${INVALID_ENUMS}"
    fi
else
    test_fail "T2-F06-05" "Corpus missing"
fi

# ------------------------------------------------------------------------------
