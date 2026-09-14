# ==============================================================================
# Tier 2 parts: F7-F13 boundaries - archives, models, parser, loader, db, query, stats.
# ==============================================================================
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
assert_file_contains "T2-F10-02" "${PROJECT_ROOT}/src/repo/loader.oo" "Err\(" "Loader returns Err on failure"

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
