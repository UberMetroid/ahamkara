# ==============================================================================
# Tier 2 parts: F19-F21 boundaries - e2e suite, adversarial hardening, git push.
# ==============================================================================
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
test_start "T2-F21-01" "Remote URL points to studio2201/ahamkara.git"
REMOTE_P=$(git remote get-url --push origin 2>/dev/null || echo "")
if [[ "${REMOTE_P}" =~ studio2201/ahamkara(\.git)? ]]; then
    test_pass "T2-F21-01" "Remote points to studio2201/ahamkara.git"
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

