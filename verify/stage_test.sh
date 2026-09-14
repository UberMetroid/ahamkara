# stage_test.sh — Stage 3: openOODA unit tests & standalone CLI verification.
# Defines stage_unit_test(); invoked by verify.sh when --test/--all.
stage_unit_test() {
step_header "Stage 3: openOODA Master Unit Tests & CLI Query Verification"

TEST_SOURCE="${PROJECT_ROOT}/tests/test_main.oo"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -f "${TEST_SOURCE}" ]]; then
    log_pass "Master unit test runner source located" "${TEST_SOURCE}"
else
    log_fail "Master unit test runner source present" "Missing: ${TEST_SOURCE}"
    print_summary
    exit 1
fi

# 1. Execute Unit Test Suite
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
TMP_TEST_BIN="/tmp/verify_test_main_$$"
TEMP_FILES+=("${TMP_TEST_BIN}")

if is_in_e2e_harness && [[ -x "${PROJECT_ROOT}/bin/test_main" ]]; then
    ACTIVE_TEST_BIN="${PROJECT_ROOT}/bin/test_main"
    log_pass "Reusing validated test binary (in E2E harness)" "${ACTIVE_TEST_BIN}"
else
    BUILD_OUT=$("${OODA_COMPILER}" build --backend c "${TEST_SOURCE}" -o "${TMP_TEST_BIN}" 2>&1) && BUILD_RET=0 || BUILD_RET=$?
    if [[ "${BUILD_RET}" -eq 0 && -x "${TMP_TEST_BIN}" ]]; then
        log_pass "Native compilation of tests/test_main.oo" "Compiled binary: ${TMP_TEST_BIN}"
        ACTIVE_TEST_BIN="${TMP_TEST_BIN}"
    else
        rm -f "${TMP_TEST_BIN}"
        log_fail "Native compilation of tests/test_main.oo" "${BUILD_OUT}"
        print_summary
        exit 1
    fi
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
TEST_OUT=$(OODA_NO_JAIL=1 "${ACTIVE_TEST_BIN}" 2>&1) && TEST_RET=0 || TEST_RET=$?
rm -f "${TMP_TEST_BIN}" 2>/dev/null || true

if [[ "${TEST_RET}" -eq 0 && "${TEST_OUT}" =~ ALL_TESTS_PASSED ]]; then
    log_pass "openOODA master unit test runner executed cleanly" "OK: ALL_TESTS_PASSED"
    if [[ "${VERBOSE}" -eq 1 && "${QUIET}" -eq 0 ]]; then
        echo "${TEST_OUT}"
    fi
else
    log_fail "openOODA master unit test runner execution" "Exit: ${TEST_RET}, Output: ${TEST_OUT}"
    print_summary
    exit 1
fi

# 2. Ensure standalone CLI binary exists and is up to date
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
REBUILD_CLI=0
if [[ ! -x "${CLI_BIN}" ]]; then
    REBUILD_CLI=1
else
    while IFS= read -r -d '' src_file; do
        if [[ "${src_file}" -nt "${CLI_BIN}" ]]; then
            REBUILD_CLI=1
            break
        fi
    done < <(find "${PROJECT_ROOT}/src" -type f -name "*.oo" -print0)
fi

if [[ "${REBUILD_CLI}" -eq 1 ]]; then
    mkdir -p "${PROJECT_ROOT}/bin"
    rm -f "${CLI_BIN}"
    CLI_BUILD_OUT=$("${OODA_COMPILER}" build --backend c "${PROJECT_ROOT}/src/main.oo" -o "${CLI_BIN}" 2>&1) && CLI_BUILD_RET=0 || CLI_BUILD_RET=$?
    if [[ "${CLI_BUILD_RET}" -eq 0 && -x "${CLI_BIN}" ]]; then
        log_pass "CLI standalone binary built successfully" "${CLI_BIN}"
    else
        log_fail "CLI standalone binary compilation" "${CLI_BUILD_OUT}"
        print_summary
        exit 1
    fi
else
    log_pass "CLI standalone binary up-to-date" "${CLI_BIN}"
fi

# 3. CLI Smoke & Semantic Query Invocations
# Operation: --version
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
VER_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --version 2>&1) && VER_RET=0 || VER_RET=$?
if [[ "${VER_RET}" -eq 0 && "${VER_OUT}" =~ ahamkara\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    log_pass "CLI --version output matches semver format" "${VER_OUT}"
else
    log_fail "CLI --version output matches semver format" "${VER_OUT}"
    print_summary
    exit 1
fi

# Operation: --help
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
HELP_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --help 2>&1) && HELP_RET=0 || HELP_RET=$?
if [[ "${HELP_RET}" -eq 0 && "${HELP_OUT}" =~ Usage: ]]; then
    log_pass "CLI --help displays usage guide" "Exit 0"
else
    log_fail "CLI --help displays usage guide" "${HELP_OUT}"
    print_summary
    exit 1
fi

# Operation: --stats
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
STATS_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --stats 2>&1) && STATS_RET=0 || STATS_RET=$?
if [[ "${STATS_RET}" -eq 0 && "${STATS_OUT}" =~ "Total records: 84" && "${STATS_OUT}" =~ "Total quotes/whispers: 79" ]]; then
    log_pass "CLI --stats aggregations verified" "84 records, 79 whispers"
else
    log_fail "CLI --stats aggregations verified" "${STATS_OUT}"
    print_summary
    exit 1
fi

# Operation: --entity Riven (43 records)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
RIVEN_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --entity Riven 2>&1) && RIVEN_RET=0 || RIVEN_RET=$?
if [[ "${RIVEN_RET}" -eq 0 && "${RIVEN_OUT}" =~ "Found 43 matching records" ]]; then
    log_pass "CLI query by entity (--entity Riven)" "Found 43 matching records"
else
    log_fail "CLI query by entity (--entity Riven)" "${RIVEN_OUT}"
    print_summary
    exit 1
fi

# Operation: --search "O [Reader] Mine" (1 record)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
SEARCH1_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --search "O [Reader] Mine" 2>&1) && SEARCH1_RET=0 || SEARCH1_RET=$?
if [[ "${SEARCH1_RET}" -eq 0 && "${SEARCH1_OUT}" =~ "Found 1 matching records" ]]; then
    log_pass "CLI search phrase with punctuation (--search 'O [Reader] Mine')" "Found 1 matching records"
else
    log_fail "CLI search phrase with punctuation (--search 'O [Reader] Mine')" "${SEARCH1_OUT}"
    print_summary
    exit 1
fi

# Operation: --search "extinction" (9 records)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
SEARCH2_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --search "extinction" 2>&1) && SEARCH2_RET=0 || SEARCH2_RET=$?
if [[ "${SEARCH2_RET}" -eq 0 && "${SEARCH2_OUT}" =~ "Found 9 matching records" ]]; then
    log_pass "CLI case-insensitive search (--search 'extinction')" "Found 9 matching records"
else
    log_fail "CLI case-insensitive search (--search 'extinction')" "${SEARCH2_OUT}"
    print_summary
    exit 1
fi
}
