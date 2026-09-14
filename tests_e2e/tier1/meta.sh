# ==============================================================================
# Tier 1 parts: F17-F21 - typecheck, verify suite, e2e suite, hardening, git push.
# ==============================================================================
assert_file_contains "T1-F18-05" "${PROJECT_ROOT}/verify.sh" "exit 0" "verify.sh exits with 0 on pass"

# ------------------------------------------------------------------------------
# Feature 19: Opaque-Box E2E Test Suite
# ------------------------------------------------------------------------------
assert_file_exists "T1-F19-01" "${PROJECT_ROOT}/tests_e2e/run_e2e.sh" "Master runner tests_e2e/run_e2e.sh exists"
assert_file_exists "T1-F19-02" "${PROJECT_ROOT}/tests_e2e/tier1_feature_tests.sh" "Tier 1 script exists"
assert_file_exists "T1-F19-03" "${PROJECT_ROOT}/tests_e2e/tier2_boundary_tests.sh" "Tier 2 script exists"
assert_file_exists "T1-F19-04" "${PROJECT_ROOT}/tests_e2e/tier3_combination_tests.sh" "Tier 3 script exists"
assert_file_exists "T1-F19-05" "${PROJECT_ROOT}/tests_e2e/tier4_scenario_tests.sh" "Tier 4 script exists"

# ------------------------------------------------------------------------------
# Feature 20: Adversarial Coverage Hardening
# ------------------------------------------------------------------------------
test_start "T1-F20-01" "Every .oo file obeys strict 256-line limit"
OVERSIZED_LINES=$(find "${PROJECT_ROOT}/src" -name "*.oo" 2>/dev/null | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 256 { print $2 ": " $1 }' || echo "")
if [[ -z "${OVERSIZED_LINES}" ]]; then
    test_pass "T1-F20-01" "Every .oo file obeys strict 256-line limit"
else
    test_fail "T1-F20-01" "Every .oo file obeys strict 256-line limit" "Files exceeding 256 lines: ${OVERSIZED_LINES}"
fi

test_start "T1-F20-02" "Every .oo file obeys 64 KiB per-file limit"
OVERSIZED_BYTES=$(find "${PROJECT_ROOT}/src" -name "*.oo" -size +65536c 2>/dev/null || echo "")
if [[ -z "${OVERSIZED_BYTES}" ]]; then
    test_pass "T1-F20-02" "Every .oo file obeys 64 KiB limit"
else
    test_fail "T1-F20-02" "Every .oo file obeys 64 KiB limit" "Files exceeding 64KiB: ${OVERSIZED_BYTES}"
fi

test_start "T1-F20-03" "No non-ASCII control characters in openOODA source files"
CONTROL_CHARS=$(grep -P -n "[\x00-\x08\x0B\x0C\x0E-\x1F]" "${PROJECT_ROOT}"/src/**/*.oo 2>/dev/null || echo "")
if [[ -z "${CONTROL_CHARS}" ]]; then
    test_pass "T1-F20-03" "No illegal control characters in .oo files"
else
    test_fail "T1-F20-03" "No illegal control characters in .oo files" "Found control characters: ${CONTROL_CHARS}"
fi

test_start "T1-F20-04" "Source files contain valid ANCHOR.oo module anchors"
if [[ -f "${PROJECT_ROOT}/src/ANCHOR.oo" && -f "${PROJECT_ROOT}/src/model/ANCHOR.oo" && -f "${PROJECT_ROOT}/src/repo/ANCHOR.oo" ]]; then
    test_pass "T1-F20-04" "Module anchors ANCHOR.oo present"
else
    test_fail "T1-F20-04" "Module anchors ANCHOR.oo present" "ANCHOR.oo missing in one or more source modules"
fi

test_start "T1-F20-05" "No forbidden directory traversal (..) in import statements"
TRAVERSALS=$(grep -rn 'import.*"\.\.' "${PROJECT_ROOT}/src" 2>/dev/null || echo "")
if [[ -z "${TRAVERSALS}" ]]; then
    test_pass "T1-F20-05" "No directory traversal (..) in imports"
else
    test_fail "T1-F20-05" "No directory traversal (..) in imports" "Forbidden imports found: ${TRAVERSALS}"
fi

# ------------------------------------------------------------------------------
# Feature 21: Final Git Push to GitHub
# ------------------------------------------------------------------------------
test_start "T1-F21-01" "Git remote URL is configured for HTTPS push"
PUSH_URL=$(git remote get-url --push origin 2>/dev/null || echo "")
if [[ "${PUSH_URL}" =~ (https://github.com/|git@github.com:)studio2201/ahamkara(\.git)? ]]; then
    test_pass "T1-F21-01" "Git remote push URL is configured (${PUSH_URL})"
else
    test_fail "T1-F21-01" "Git remote push URL is configured" "Push URL is '${PUSH_URL}'"
fi

test_start "T1-F21-02" "Default branch is ahamkara"
DEF_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "${DEF_BRANCH}" == "ahamkara" ]]; then
    test_pass "T1-F21-02" "Default branch is valid (${DEF_BRANCH})"
else
    test_fail "T1-F21-02" "Default branch is valid" "Current branch is '${DEF_BRANCH}'"
fi

test_start "T1-F21-03" "No committed binary artifacts in source tree"
BIN_FILES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/data" -name "*.bin" -o -name "*.o" -o -name "*.so" -o -name "*.exe" 2>/dev/null || echo "")
if [[ -z "${BIN_FILES}" ]]; then
    test_pass "T1-F21-03" "No unwanted binary artifacts in src/ or data/"
else
    test_fail "T1-F21-03" "No unwanted binary artifacts in src/ or data/" "Binaries found: ${BIN_FILES}"
fi

test_start "T1-F21-04" "Repository ignore file or clean hygiene exists"
if [[ -f "${PROJECT_ROOT}/.gitignore" || -d "${PROJECT_ROOT}/.git" ]]; then
    test_pass "T1-F21-04" "Git repository hygiene is established"
else
    test_fail "T1-F21-04" "Git repository hygiene is established" "No .gitignore or .git directory"
fi

test_start "T1-F21-05" "Git remote origin is reachable over network"
if git ls-remote --heads origin >/dev/null 2>&1; then
    test_pass "T1-F21-05" "Git remote origin is reachable"
else
    test_fail "T1-F21-05" "Git remote origin is reachable" "git ls-remote failed (network or authentication)"
fi

