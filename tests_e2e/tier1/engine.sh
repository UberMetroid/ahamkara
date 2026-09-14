# ==============================================================================
# Tier 1 parts: F8-F16 - domain models through CLI command router.
# ==============================================================================
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
