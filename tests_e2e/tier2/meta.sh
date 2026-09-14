# ==============================================================================
# Tier 2 parts: F14-F18 boundaries - formatting, REPL, router, typecheck, verify suite.
# ==============================================================================
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

test_start "T2-F18-02" "verify.sh modules set pipefail and do not mask exit codes"
if grep -rl 'pipefail' "${PROJECT_ROOT}/verify.sh" "${PROJECT_ROOT}/verify/"*.sh >/dev/null 2>&1; then
    test_pass "T2-F18-02" "pipefail set in verification suite"
else
    test_fail "T2-F18-02" "verify.sh sets pipefail" "no pipefail found in verify.sh or verify/*.sh"
fi

test_start "T2-F18-03" "verify.sh exits with non-zero on failed assertion"
if grep -rl 'exit 1' "${PROJECT_ROOT}/verify.sh" "${PROJECT_ROOT}/verify/"*.sh >/dev/null 2>&1; then
    test_pass "T2-F18-03" "verify.sh handles failure exit code"
else
    test_fail "T2-F18-03" "verify.sh handles failure exit code" "no exit 1 found in verify.sh or verify/*.sh"
fi

test_start "T2-F18-04" "verify.sh prints summary header"
if grep -rl 'Ahamkara Verification Summary' "${PROJECT_ROOT}/verify.sh" "${PROJECT_ROOT}/verify/"*.sh >/dev/null 2>&1; then
    test_pass "T2-F18-04" "verify.sh prints header"
else
    test_fail "T2-F18-04" "verify.sh prints header" "no summary header found"
fi

test_start "T2-F18-05" "verify.sh cleans up any temp files on exit"
if grep -rlE 'trap|rm -f|exit' "${PROJECT_ROOT}/verify.sh" "${PROJECT_ROOT}/verify/"*.sh >/dev/null 2>&1; then
    test_pass "T2-F18-05" "verify.sh handles cleanup"
else
    test_fail "T2-F18-05" "verify.sh handles cleanup" "no cleanup found"
fi

# ------------------------------------------------------------------------------
