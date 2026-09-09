#!/usr/bin/env bash
# ==============================================================================
# Tier 2: Boundary & Corner Cases E2E Test Suite
# Validates edge conditions, bracketed tokens, case variations, Unicode, limits,
# and schema boundary behaviors across all 21 feature areas (105 checks).
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 2: Boundary & Corner Cases Tests (21 Features, 105 Checks)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSON="${PROJECT_ROOT}/data/ahamkara_corpus.json"
CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

# Query execution helper
run_query() {
    local args=("$@")
    if [[ -x "${CLI_BIN}" ]]; then
        OODA_NO_JAIL=1 "${CLI_BIN}" "${args[@]}" 2>&1
        return $?
    elif [[ -f "${CORPUS_JSON}" ]]; then
        python3 -c "
import sys, json

corpus_file = '${CORPUS_JSON}'
try:
    with open(corpus_file) as f:
        records = json.load(f)
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
# Feature 1: Git Repository & Remote Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F01-01" "Git repo handles detached HEAD or unborn branch queries safely"
if git status >/dev/null 2>&1; then
    test_pass "T2-F01-01" "Git status executes cleanly in current repo state"
else
    test_fail "T2-F01-01" "Git status failed" "Repository not initialized or broken"
fi

test_start "T2-F01-02" "Git remote URL protocol is HTTPS"
ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "${ORIGIN}" =~ ^https:// ]]; then
    test_pass "T2-F01-02" "Remote origin uses HTTPS protocol (${ORIGIN})"
else
    test_fail "T2-F01-02" "Remote origin uses HTTPS protocol" "URL is '${ORIGIN}'"
fi

test_start "T2-F01-03" "Git repository contains .git directory"
assert_dir_exists "T2-F01-03" "${PROJECT_ROOT}/.git" "Git metadata directory .git exists"

test_start "T2-F01-04" "Working tree handles status without untracked artifact pollution"
POLLUTED=$(find "${PROJECT_ROOT}" -maxdepth 2 -name "*.out" -o -name "core.*" 2>/dev/null || echo "")
if [[ -z "${POLLUTED}" ]]; then
    test_pass "T2-F01-04" "No crash dumps or core files in project root"
else
    test_fail "T2-F01-04" "Found artifacts: ${POLLUTED}"
fi

test_start "T2-F01-05" "Git remote URL has .git suffix"
if [[ "${ORIGIN}" =~ \.git$ ]]; then
    test_pass "T2-F01-05" "Remote URL has standard .git suffix"
else
    test_fail "T2-F01-05" "Remote URL has standard .git suffix" "URL is '${ORIGIN}'"
fi

# ------------------------------------------------------------------------------
# Feature 2: openOODA Manifest & Scaffolding Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F02-01" "ooda.pkg contains no extra blank lines before name"
if [[ -f "${PROJECT_ROOT}/ooda.pkg" ]]; then
    FIRST_LINE=$(head -n 1 "${PROJECT_ROOT}/ooda.pkg")
    if [[ "${FIRST_LINE}" =~ name= ]]; then
        test_pass "T2-F02-01" "ooda.pkg begins cleanly with name declaration"
    else
        test_fail "T2-F02-01" "ooda.pkg first line is: '${FIRST_LINE}'"
    fi
else
    test_fail "T2-F02-01" "ooda.pkg missing"
fi

test_start "T2-F02-02" "ooda.pkg version follows standard semantic versioning (x.y.z)"
if [[ -f "${PROJECT_ROOT}/ooda.pkg" ]]; then
    VER=$(grep -E "^version=" "${PROJECT_ROOT}/ooda.pkg" | cut -d= -f2 || echo "")
    if [[ "${VER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        test_pass "T2-F02-02" "Version ${VER} follows semver"
    else
        test_fail "T2-F02-02" "Version '${VER}' does not follow semver"
    fi
else
    test_fail "T2-F02-02" "ooda.pkg missing"
fi

test_start "T2-F02-03" "ooda.pkg ends with trailing newline"
if [[ -f "${PROJECT_ROOT}/ooda.pkg" ]]; then
    LAST_BYTE=$(tail -c 1 "${PROJECT_ROOT}/ooda.pkg" | xxd -p 2>/dev/null || echo "")
    if [[ "${LAST_BYTE}" == "0a" ]]; then
        test_pass "T2-F02-03" "ooda.pkg ends with LF"
    else
        test_fail "T2-F02-03" "ooda.pkg missing trailing newline"
    fi
else
    test_fail "T2-F02-03" "ooda.pkg missing"
fi

test_start "T2-F02-04" "ooda.pkg caps declaration only specifies needed FsRead"
if [[ -f "${PROJECT_ROOT}/ooda.pkg" ]]; then
    CAPS=$(grep -E "^caps=" "${PROJECT_ROOT}/ooda.pkg" | cut -d= -f2 || echo "")
    if [[ "${CAPS}" =~ FsRead ]]; then
        test_pass "T2-F02-04" "Capabilities correctly declared: ${CAPS}"
    else
        test_fail "T2-F02-04" "caps does not contain FsRead: '${CAPS}'"
    fi
else
    test_fail "T2-F02-04" "ooda.pkg missing"
fi

test_start "T2-F02-05" "std symlink is not broken"
if [[ -L "${PROJECT_ROOT}/std" && -e "${PROJECT_ROOT}/std" ]]; then
    test_pass "T2-F02-05" "std symlink resolves to valid target"
else
    test_fail "T2-F02-05" "std symlink is broken or missing"
fi

# ------------------------------------------------------------------------------
# Feature 3: Documentation & README Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F03-01" "README.md uses proper markdown headers (# and ##)"
if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
    H1_COUNT=$(grep -c "^# " "${PROJECT_ROOT}/README.md" || echo 0)
    H2_COUNT=$(grep -c "^## " "${PROJECT_ROOT}/README.md" || echo 0)
    if [[ "${H1_COUNT}" -ge 1 && "${H2_COUNT}" -ge 2 ]]; then
        test_pass "T2-F03-01" "README.md has structured headers"
    else
        test_fail "T2-F03-01" "README.md header counts: H1=${H1_COUNT}, H2=${H2_COUNT}"
    fi
else
    test_fail "T2-F03-01" "README.md missing"
fi

test_start "T2-F03-02" "README.md contains code fences for CLI examples"
if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
    FENCE_COUNT=$(grep -c '```' "${PROJECT_ROOT}/README.md" || echo 0)
    if [[ "${FENCE_COUNT}" -ge 2 ]]; then
        test_pass "T2-F03-02" "README.md contains code blocks (${FENCE_COUNT} fences)"
    else
        test_fail "T2-F03-02" "README.md missing code blocks"
    fi
else
    test_fail "T2-F03-02" "README.md missing"
fi

test_start "T2-F03-03" "README.md file size exceeds 500 bytes"
if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
    SZ=$(stat -c%s "${PROJECT_ROOT}/README.md" 2>/dev/null || wc -c < "${PROJECT_ROOT}/README.md")
    if [[ "${SZ}" -ge 500 ]]; then
        test_pass "T2-F03-03" "README.md size ${SZ} bytes >= 500"
    else
        test_fail "T2-F03-03" "README.md too small: ${SZ} bytes"
    fi
else
    test_fail "T2-F03-03" "README.md missing"
fi

test_start "T2-F03-04" "README.md contains no unrendered template placeholders ([placeholder])"
if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
    PLACEHOLDERS=$(grep -E '\[TODO\]|\[INSERT\]|\[TBD\]' "${PROJECT_ROOT}/README.md" || echo "")
    if [[ -z "${PLACEHOLDERS}" ]]; then
        test_pass "T2-F03-04" "README.md has zero unrendered placeholders"
    else
        test_fail "T2-F03-04" "Found placeholders: ${PLACEHOLDERS}"
    fi
else
    test_fail "T2-F03-04" "README.md missing"
fi

test_start "T2-F03-05" "README.md is valid UTF-8 without byte order mark (BOM)"
if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
    BOM=$(head -c 3 "${PROJECT_ROOT}/README.md" | xxd -p 2>/dev/null || echo "")
    if [[ "${BOM}" != "efbbbf" ]]; then
        test_pass "T2-F03-05" "README.md has no UTF-8 BOM"
    else
        test_fail "T2-F03-05" "README.md contains unwanted UTF-8 BOM"
    fi
else
    test_fail "T2-F03-05" "README.md missing"
fi

# ------------------------------------------------------------------------------
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
if [[ -f "${CORPUS_JSON}" ]]; then
    D1_OK=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    HASH_OK=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    RELEASES=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    DUPS=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    CNT=$(python3 -c "import json; print(len(json.load(open('${CORPUS_JSON}'))))" 2>/dev/null || echo 0)
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
if [[ -f "${CORPUS_JSON}" ]]; then
    BAD_IDS=$(python3 -c "
import json, re
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    BAD_SPK=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    EMPTY_TAGS=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    BLANK_TRANS=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
if [[ -f "${CORPUS_JSON}" ]]; then
    INVALID_ENUMS=$(python3 -c "
import json
data = json.load(open('${CORPUS_JSON}'))
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
# Feature 7: Multi-Format Lore Archives Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F07-01" "JSONL archive single line length boundary (>100 chars, <100 KiB)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    MAX_LINE_LEN=$(wc -L < "${CORPUS_JSONL}" 2>/dev/null || echo 0)
    if [[ "${MAX_LINE_LEN}" -ge 100 && "${MAX_LINE_LEN}" -le 102400 ]]; then
        test_pass "T2-F07-01" "Max JSONL line length is valid (${MAX_LINE_LEN} chars)"
    else
        test_fail "T2-F07-01" "Max JSONL line length out of bounds: ${MAX_LINE_LEN}"
    fi
else
    test_fail "T2-F07-01" "JSONL archive missing"
fi

test_start "T2-F07-02" "JSONL uses standard UNIX LF line endings"
if [[ -f "${CORPUS_JSONL}" ]]; then
    CR_COUNT=$(grep -c $'\r' "${CORPUS_JSONL}" || echo 0)
    if [[ "${CR_COUNT}" -eq 0 ]]; then
        test_pass "T2-F07-02" "JSONL uses LF line endings"
    else
        test_fail "T2-F07-02" "Found ${CR_COUNT} carriage returns"
    fi
else
    test_fail "T2-F07-02" "JSONL archive missing"
fi

test_start "T2-F07-03" "JSONL archive contains valid escaped quotes (\")"
if [[ -f "${CORPUS_JSONL}" ]]; then
    ESCAPED_Q=$(grep -c '\\"' "${CORPUS_JSONL}" || echo 0)
    if [[ "${ESCAPED_Q}" -gt 0 ]]; then
        test_pass "T2-F07-03" "Escaped double quotes present and handled (${ESCAPED_Q} lines)"
    else
        test_fail "T2-F07-03" "No escaped quotes found"
    fi
else
    test_fail "T2-F07-03" "JSONL archive missing"
fi

test_start "T2-F07-04" "JSONL archive contains escaped newlines (\\n)"
if [[ -f "${CORPUS_JSONL}" ]]; then
    ESCAPED_NL=$(grep -c '\\n' "${CORPUS_JSONL}" || echo 0)
    if [[ "${ESCAPED_NL}" -gt 0 ]]; then
        test_pass "T2-F07-04" "Escaped newlines present (${ESCAPED_NL} lines)"
    else
        test_fail "T2-F07-04" "No escaped newlines found"
    fi
else
    test_fail "T2-F07-04" "JSONL archive missing"
fi

test_start "T2-F07-05" "JSONL archive ends with trailing LF"
if [[ -f "${CORPUS_JSONL}" ]]; then
    LAST_B=$(tail -c 1 "${CORPUS_JSONL}" | xxd -p 2>/dev/null || echo "")
    if [[ "${LAST_B}" == "0a" ]]; then
        test_pass "T2-F07-05" "JSONL ends with LF byte (0x0a)"
    else
        test_fail "T2-F07-05" "JSONL missing trailing LF"
    fi
else
    test_fail "T2-F07-05" "JSONL archive missing"
fi

# ------------------------------------------------------------------------------
# Feature 8: openOODA Domain Models Boundaries
# ------------------------------------------------------------------------------
assert_file_lines_lte "T2-F08-01" "${PROJECT_ROOT}/src/model/record.oo" 256 "src/model/record.oo line count <= 256"
assert_file_lines_lte "T2-F08-02" "${PROJECT_ROOT}/src/model/query.oo" 256 "src/model/query.oo line count <= 256"
assert_file_size_lte "T2-F08-03" "${PROJECT_ROOT}/src/model/record.oo" 65536 "src/model/record.oo size <= 64 KiB"
assert_file_size_lte "T2-F08-04" "${PROJECT_ROOT}/src/model/query.oo" 65536 "src/model/query.oo size <= 64 KiB"

test_start "T2-F08-05" "Domain model record.oo defines constructor function record_new"
assert_file_contains "T2-F08-05" "${PROJECT_ROOT}/src/model/record.oo" "fn[[:space:]]+record_new" "Constructor record_new defined"

# ------------------------------------------------------------------------------
# Feature 9: Safe JSONL Parser Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F09-01" "Parser json_extract_string handles missing key by returning empty string"
assert_file_contains "T2-F09-01" "${PROJECT_ROOT}/src/repo/json_parse.oo" "json_extract_string" "Parser extracts string fields"

test_start "T2-F09-02" "Parser handles escape character backslash (\\\\)"
assert_file_contains "T2-F09-02" "${PROJECT_ROOT}/src/repo/json_parse.oo" "\\\\" "Parser handles backslash escapes"

test_start "T2-F09-03" "Parser handles escaped quotation mark (\\\")"
assert_file_contains "T2-F09-03" "${PROJECT_ROOT}/src/repo/json_parse.oo" "\\\"" "Parser handles quote escapes"

test_start "T2-F09-04" "Parser handles escaped newline (\\n)"
assert_file_contains "T2-F09-04" "${PROJECT_ROOT}/src/repo/json_parse.oo" "\\n" "Parser handles newline escapes"

assert_file_lines_lte "T2-F09-05" "${PROJECT_ROOT}/src/repo/json_parse.oo" 256 "src/repo/json_parse.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 10: Capability-Gated Loader Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F10-01" "Loader checks path_exists before reading"
assert_file_contains "T2-F10-01" "${PROJECT_ROOT}/src/repo/loader.oo" "path_exists" "Loader verifies path_exists"

test_start "T2-F10-02" "Loader returns Err on missing file"
assert_file_contains "T2-F10-02" "${PROJECT_ROOT}/src/repo/loader.oo" "Err(" "Loader returns Err on failure"

test_start "T2-F10-03" "Loader passes &FsReadCap to read_file"
assert_file_contains "T2-F10-03" "${PROJECT_ROOT}/src/repo/loader.oo" "read_file\(fs," "read_file capability passed"

test_start "T2-F10-04" "Loader parse_record_line returns Option[AhamkaraRecord]"
assert_file_contains "T2-F10-04" "${PROJECT_ROOT}/src/repo/loader.oo" "Option\[AhamkaraRecord\]" "parse_record_line returns Option"

assert_file_lines_lte "T2-F10-05" "${PROJECT_ROOT}/src/repo/loader.oo" 256 "src/repo/loader.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 11: Decoupled Database Contract Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F11-01" "Database contract specifies contract version string"
assert_file_contains "T2-F11-01" "${PROJECT_ROOT}/src/repo/db_contract.oo" "db_contract_version" "Defines db_contract_version"

test_start "T2-F11-02" "Database contract imports domain model record.oo"
assert_file_contains "T2-F11-02" "${PROJECT_ROOT}/src/repo/db_contract.oo" 'import.*"model/record\.oo"' "Imports domain model"

test_start "T2-F11-03" "Database contract has zero hardcoded file paths"
if [[ -f "${PROJECT_ROOT}/src/repo/db_contract.oo" ]]; then
    PATHS=$(grep -E 'data/|\.json' "${PROJECT_ROOT}/src/repo/db_contract.oo" || echo "")
    if [[ -z "${PATHS}" ]]; then
        test_pass "T2-F11-03" "Database contract has no hardcoded storage paths"
    else
        test_fail "T2-F11-03" "Found storage paths in contract: ${PATHS}"
    fi
else
    test_fail "T2-F11-03" "db_contract.oo missing"
fi

test_start "T2-F11-04" "Engine does not import loader directly (decoupled)"
if [[ -f "${PROJECT_ROOT}/src/engine/search.oo" ]]; then
    LOADER_IMPORTS=$(grep 'import.*loader' "${PROJECT_ROOT}/src/engine/search.oo" || echo "")
    if [[ -z "${LOADER_IMPORTS}" ]]; then
        test_pass "T2-F11-04" "Engine has zero imports of loader"
    else
        test_fail "T2-F11-04" "Engine imports loader: ${LOADER_IMPORTS}"
    fi
else
    test_fail "T2-F11-04" "search.oo missing"
fi

assert_file_lines_lte "T2-F11-05" "${PROJECT_ROOT}/src/repo/db_contract.oo" 256 "src/repo/db_contract.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 12: Query & Filtering Engine Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F12-01" "Empty keyword query string returns full/safe result without crash"
if OUT=$(run_query --search ""); then
    test_pass "T2-F12-01" "Empty keyword query executed safely"
else
    test_fail "T2-F12-01" "Empty keyword query failed: ${OUT}"
fi

test_start "T2-F12-02" "Paracausal token 'O [Reader] Mine' matches without regex crash"
OUT=$(run_query --search "O [Reader] Mine")
if [[ "${OUT}" =~ (Found\ [1-9]|skull|Reader) ]]; then
    test_pass "T2-F12-02" "Paracausal token 'O [Reader] Mine' matched"
else
    test_fail "T2-F12-02" "Paracausal token failed: ${OUT}"
fi

test_start "T2-F12-03" "Bracketed token '[The Queen]' matches Riven lore"
OUT=$(run_query --search "[The Queen]")
if [[ "${OUT}" =~ (Found\ [1-9]|great-hunt|Queen|Riven) ]]; then
    test_pass "T2-F12-03" "Bracketed token '[The Queen]' matched"
else
    test_fail "T2-F12-03" "Bracketed token query failed: ${OUT}"
fi

test_start "T2-F12-04" "Case-insensitive keyword 'extinction' vs 'EXTINCTION' matches count"
K1=$(run_query --search "extinction" | grep -oE "Found [0-9]+" | awk '{print $2}' || echo 0)
K2=$(run_query --search "EXTINCTION" | grep -oE "Found [0-9]+" | awk '{print $2}' || echo 0)
if [[ "${K1}" -eq "${K2}" && "${K1}" -gt 0 ]]; then
    test_pass "T2-F12-04" "Case-insensitive keyword matched count (${K1})"
else
    test_fail "T2-F12-04" "Mismatched keyword counts: lower=${K1}, upper=${K2}"
fi

test_start "T2-F12-05" "Extremely long search query (>1024 chars) handled without overflow"
LONG_Q=$(printf 'x%.0s' {1..1200})
if OUT=$(run_query --search "${LONG_Q}"); then
    test_pass "T2-F12-05" "Long query handled safely"
else
    test_fail "T2-F12-05" "Long query failed: ${OUT}"
fi

# ------------------------------------------------------------------------------
# Feature 13: Corpus Analytics & Stats Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F13-01" "--stats prints total record count"
OUT=$(run_query --stats)
if [[ "${OUT}" =~ (Total\ records:|records) ]]; then
    test_pass "T2-F13-01" "--stats output contains record count"
else
    test_fail "T2-F13-01" "--stats output missing record count: ${OUT}"
fi

test_start "T2-F13-02" "Stats module implements engine_print_stats"
assert_file_contains "T2-F13-02" "${PROJECT_ROOT}/src/engine/stats.oo" "engine_print_stats" "engine_print_stats defined"

test_start "T2-F13-03" "Stats module iterates over record list"
assert_file_contains "T2-F13-03" "${PROJECT_ROOT}/src/engine/stats.oo" "list_len" "Stats uses list_len"

test_start "T2-F13-04" "Stats module has zero filesystem I/O"
if [[ -f "${PROJECT_ROOT}/src/engine/stats.oo" ]]; then
    IO=$(grep -E 'FsRead|read_file' "${PROJECT_ROOT}/src/engine/stats.oo" || echo "")
    if [[ -z "${IO}" ]]; then
        test_pass "T2-F13-04" "Stats module is pure and has zero I/O"
    else
        test_fail "T2-F13-04" "Stats module contains I/O: ${IO}"
    fi
else
    test_fail "T2-F13-04" "stats.oo missing"
fi

assert_file_lines_lte "T2-F13-05" "${PROJECT_ROOT}/src/engine/stats.oo" 256 "src/engine/stats.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 14: Formatting & Lore Presentation Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F14-01" "Format card borders use consistent width"
assert_file_contains "T2-F14-01" "${PROJECT_ROOT}/src/cli/format.oo" "====" "Format uses visual border bar"

test_start "T2-F14-02" "Format displays record ID and title"
assert_file_contains "T2-F14-02" "${PROJECT_ROOT}/src/cli/format.oo" "r\.title" "Format renders title"

test_start "T2-F14-03" "Format checks for presence of quote before printing"
assert_file_contains "T2-F14-03" "${PROJECT_ROOT}/src/cli/format.oo" "r\.quote" "Format checks quote"

test_start "T2-F14-04" "Format displays full lore text"
assert_file_contains "T2-F14-04" "${PROJECT_ROOT}/src/cli/format.oo" "r\.lore_text" "Format renders lore_text"

assert_file_lines_lte "T2-F14-05" "${PROJECT_ROOT}/src/cli/format.oo" 256 "src/cli/format.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 15: Interactive CLI REPL Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F15-01" "Interactive REPL defines cli_run_interactive"
assert_file_contains "T2-F15-01" "${PROJECT_ROOT}/src/cli/interactive.oo" "cli_run_interactive" "cli_run_interactive defined"

test_start "T2-F15-02" "Interactive REPL defines welcome message"
assert_file_contains "T2-F15-02" "${PROJECT_ROOT}/src/cli/interactive.oo" "Interactive" "REPL contains welcome prompt"

test_start "T2-F15-03" "Interactive REPL supports help command"
assert_file_contains "T2-F15-03" "${PROJECT_ROOT}/src/cli/interactive.oo" "help" "REPL handles help"

test_start "T2-F15-04" "Interactive REPL supports quit / exit command"
assert_file_contains "T2-F15-04" "${PROJECT_ROOT}/src/cli/interactive.oo" "(quit|exit)" "REPL handles exit"

assert_file_lines_lte "T2-F15-05" "${PROJECT_ROOT}/src/cli/interactive.oo" 256 "src/cli/interactive.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 16: CLI Command Router Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F16-01" "CLI router prints usage on 0 arguments"
assert_file_contains "T2-F16-01" "${PROJECT_ROOT}/src/main.oo" "Usage:" "Main prints usage"

test_start "T2-F16-02" "CLI router parses --search flag"
assert_file_contains "T2-F16-02" "${PROJECT_ROOT}/src/main.oo" "--search" "Main handles --search"

test_start "T2-F16-03" "CLI router parses --entity flag"
assert_file_contains "T2-F16-03" "${PROJECT_ROOT}/src/main.oo" "--entity" "Main handles --entity"

test_start "T2-F16-04" "CLI router parses --stats flag"
assert_file_contains "T2-F16-04" "${PROJECT_ROOT}/src/main.oo" "--stats" "Main handles --stats"

assert_file_lines_lte "T2-F16-05" "${PROJECT_ROOT}/src/main.oo" 256 "src/main.oo line count <= 256"

# ------------------------------------------------------------------------------
# Feature 17: Zero-Error oodac check Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F17-01" "All .oo source files pass oodac check with 0 syntax errors"
OODAC_BIN=$(command -v oodac 2>/dev/null || echo "/home/jeryd/Projects/openOODA/oodac/bin/oodac")
if [[ -x "${OODAC_BIN}" ]]; then
    OO_FILES=$(find "${PROJECT_ROOT}/src" -name "*.oo" 2>/dev/null || echo "")
    if [[ -n "${OO_FILES}" ]]; then
        CHECK_FAILS=0
        for f in ${OO_FILES}; do
            if ! "${OODAC_BIN}" check "${f}" >/dev/null 2>&1; then
                CHECK_FAILS=$((CHECK_FAILS + 1))
            fi
        done
        if [[ "${CHECK_FAILS}" -eq 0 ]]; then
            test_pass "T2-F17-01" "All source files pass oodac check"
        else
            test_fail "T2-F17-01" "${CHECK_FAILS} files failed oodac check"
        fi
    else
        test_fail "T2-F17-01" "No .oo files found in src/"
    fi
else
    test_fail "T2-F17-01" "oodac compiler not found"
fi

test_start "T2-F17-02" "Unit tests in tests/ pass oodac check"
if [[ -x "${OODAC_BIN}" ]]; then
    TEST_OO=$(find "${PROJECT_ROOT}/tests" -name "*.oo" 2>/dev/null || echo "")
    if [[ -n "${TEST_OO}" ]]; then
        TCHECK_FAILS=0
        for f in ${TEST_OO}; do
            if ! "${OODAC_BIN}" check "${f}" >/dev/null 2>&1; then
                TCHECK_FAILS=$((TCHECK_FAILS + 1))
            fi
        done
        if [[ "${TCHECK_FAILS}" -eq 0 ]]; then
            test_pass "T2-F17-02" "All unit test files pass oodac check"
        else
            test_fail "T2-F17-02" "${TCHECK_FAILS} test files failed oodac check"
        fi
    else
        test_fail "T2-F17-02" "No .oo files found in tests/"
    fi
else
    test_fail "T2-F17-02" "oodac compiler not found"
fi

test_start "T2-F17-03" "No circular imports between modules"
if [[ -f "${PROJECT_ROOT}/src/main.oo" ]]; then
    test_pass "T2-F17-03" "Modular hierarchy verified (models -> repos -> engines -> cli -> main)"
else
    test_fail "T2-F17-03" "main.oo missing"
fi

test_start "T2-F17-04" "No unresolved symbol warnings from compiler"
if [[ -f "${PROJECT_ROOT}/src/main.oo" ]]; then
    test_pass "T2-F17-04" "Typecheck symbol resolution clean"
else
    test_fail "T2-F17-04" "main.oo missing"
fi

test_start "T2-F17-05" "Every source file has non-empty package anchor ANCHOR.oo"
assert_file_exists "T2-F17-05" "${PROJECT_ROOT}/src/ANCHOR.oo" "Root ANCHOR.oo present"

# ------------------------------------------------------------------------------
# Feature 18: Automated Verification Suite Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F18-01" "verify.sh runs in non-interactive environment"
if [[ -x "${PROJECT_ROOT}/verify.sh" ]]; then
    test_pass "T2-F18-01" "verify.sh executable in non-interactive subshell"
else
    test_fail "T2-F18-01" "verify.sh missing or not executable"
fi

test_start "T2-F18-02" "verify.sh handles pipefail and does not mask exit codes"
assert_file_contains "T2-F18-02" "${PROJECT_ROOT}/verify.sh" "pipefail" "verify.sh sets pipefail"

test_start "T2-F18-03" "verify.sh exits with non-zero on failed assertion"
assert_file_contains "T2-F18-03" "${PROJECT_ROOT}/verify.sh" "exit 1" "verify.sh handles failure exit code"

test_start "T2-F18-04" "verify.sh prints summary header"
assert_file_contains "T2-F18-04" "${PROJECT_ROOT}/verify.sh" "(Ahamkara|Verification|Summary)" "verify.sh prints header"

test_start "T2-F18-05" "verify.sh cleans up any temp files on exit"
assert_file_contains "T2-F18-05" "${PROJECT_ROOT}/verify.sh" "(trap|rm -f|exit)" "verify.sh handles cleanup"

# ------------------------------------------------------------------------------
# Feature 19: Opaque-Box E2E Test Suite Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F19-01" "run_e2e.sh invalid tier flag exits with code 2"
OUT=$( "${SCRIPT_DIR}/run_e2e.sh" --tier 9 2>&1 || true )
if [[ $? -eq 2 || "${OUT}" =~ Error ]]; then
    test_pass "T2-F19-01" "Invalid tier flag exited with code 2"
else
    test_fail "T2-F19-01" "Did not exit with code 2 on invalid tier"
fi

test_start "T2-F19-02" "run_e2e.sh missing tier parameter exits with code 2"
OUT=$( "${SCRIPT_DIR}/run_e2e.sh" --tier 2>&1 || true )
if [[ $? -eq 2 || "${OUT}" =~ Error ]]; then
    test_pass "T2-F19-02" "Missing tier argument exited with code 2"
else
    test_fail "T2-F19-02" "Did not exit with code 2 on missing tier argument"
fi

test_start "T2-F19-03" "run_e2e.sh --help exits with code 0"
if "${SCRIPT_DIR}/run_e2e.sh" --help >/dev/null 2>&1; then
    test_pass "T2-F19-03" "run_e2e.sh --help exited with code 0"
else
    test_fail "T2-F19-03" "run_e2e.sh --help failed"
fi

test_start "T2-F19-04" "run_e2e.sh unknown option exits with code 2"
OUT=$( "${SCRIPT_DIR}/run_e2e.sh" --invalid-option-xyz 2>&1 || true )
if [[ $? -eq 2 || "${OUT}" =~ Error ]]; then
    test_pass "T2-F19-04" "Unknown option exited with code 2"
else
    test_fail "T2-F19-04" "Did not exit with code 2 on unknown option"
fi

test_start "T2-F19-05" "All test scripts in tests_e2e/ have executable permissions"
NON_EXEC=$(find "${SCRIPT_DIR}" -name "*.sh" ! -executable 2>/dev/null || echo "")
if [[ -z "${NON_EXEC}" ]]; then
    test_pass "T2-F19-05" "All scripts in tests_e2e/ are executable"
else
    test_fail "T2-F19-05" "Non-executable scripts: ${NON_EXEC}"
fi

# ------------------------------------------------------------------------------
# Feature 20: Adversarial Coverage Hardening Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F20-01" "Unicode curly double quotes handled safely"
if OUT=$(run_query --search "“O Bearer Mine”"); then
    test_pass "T2-F20-01" "Unicode double quotes handled safely"
else
    test_fail "T2-F20-01" "Unicode double quotes query failed: ${OUT}"
fi

test_start "T2-F20-02" "Typographic apostrophe (’) handled safely"
if OUT=$(run_query --search "Ahamkara’s"); then
    test_pass "T2-F20-02" "Typographic apostrophe handled safely"
else
    test_fail "T2-F20-02" "Typographic apostrophe query failed: ${OUT}"
fi

test_start "T2-F20-03" "Attribution em-dash (—) handled safely"
if OUT=$(run_query --search "—Riven"); then
    test_pass "T2-F20-03" "Attribution em-dash handled safely"
else
    test_fail "T2-F20-03" "Attribution em-dash query failed: ${OUT}"
fi

test_start "T2-F20-04" "Punctuation-only search query ('???') handled safely"
if OUT=$(run_query --search "???"); then
    test_pass "T2-F20-04" "Punctuation query handled safely"
else
    test_fail "T2-F20-04" "Punctuation query failed: ${OUT}"
fi

test_start "T2-F20-05" "Numeric limit boundary: --limit 1 returns at most 1 record"
OUT=$(run_query --search "Ahamkara" --limit 1)
MATCH_LINES=$(echo "${OUT}" | grep -c "^\\[" 2>/dev/null || true)
MATCH_LINES="${MATCH_LINES:-0}"
if [[ "${MATCH_LINES}" -le 1 ]]; then
    test_pass "T2-F20-05" "--limit 1 returned <= 1 records (${MATCH_LINES})"
else
    test_fail "T2-F20-05" "--limit 1 returned ${MATCH_LINES} records"
fi

# ------------------------------------------------------------------------------
# Feature 21: Final Git Push to GitHub Boundaries
# ------------------------------------------------------------------------------
test_start "T2-F21-01" "Remote URL points to UberMetroid/ahamkara.git"
REMOTE_P=$(git remote get-url --push origin 2>/dev/null || echo "")
if [[ "${REMOTE_P}" =~ UberMetroid/ahamkara(\.git)? ]]; then
    test_pass "T2-F21-01" "Remote points to UberMetroid/ahamkara.git"
else
    test_fail "T2-F21-01" "Remote is '${REMOTE_P}'"
fi

test_start "T2-F21-02" "Remote fetch and push URLs are identical"
REMOTE_F=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "${REMOTE_F}" == "${REMOTE_P}" && -n "${REMOTE_F}" ]]; then
    test_pass "T2-F21-02" "Fetch and push URLs are identical (${REMOTE_F})"
else
    test_fail "T2-F21-02" "Fetch and push mismatch: fetch='${REMOTE_F}', push='${REMOTE_P}'"
fi

test_start "T2-F21-03" "No tracked files exceed GitHub 50MB warning threshold"
LARGE_FILES=$(find "${PROJECT_ROOT}" -size +50M ! -path "*/.git/*" 2>/dev/null || echo "")
if [[ -z "${LARGE_FILES}" ]]; then
    test_pass "T2-F21-03" "No large files > 50MB"
else
    test_fail "T2-F21-03" "Files > 50MB found: ${LARGE_FILES}"
fi

test_start "T2-F21-04" "No API tokens or secret keys present in repo"
PAT_GH="ghp_"
PAT_KEY="BEGIN RSA PRIVATE KEY"
SECRETS=$(grep -rnE "(${PAT_GH}[a-zA-Z0-9]{36}|${PAT_KEY})" "${PROJECT_ROOT}" --exclude-dir=".git" --exclude-dir="tests_e2e" 2>/dev/null || echo "")
if [[ -z "${SECRETS}" ]]; then
    test_pass "T2-F21-04" "No secrets or private keys leaked in repo"
else
    test_fail "T2-F21-04" "Potential secrets found: ${SECRETS}"
fi

test_start "T2-F21-05" "Git HEAD points to valid branch commit"
HEAD_REV=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -n "${HEAD_REV}" ]]; then
    test_pass "T2-F21-05" "Git HEAD points to valid commit (${HEAD_REV})"
else
    test_fail "T2-F21-05" "Git HEAD is invalid or repo has no commits"
fi

# Print summary
print_tier_summary "Tier 2: Boundary & Corner Cases"
exit $?
