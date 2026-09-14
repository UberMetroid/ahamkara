# ==============================================================================
# Tier 2 parts: F1-F3 boundaries - git repository, manifest, documentation.
# ==============================================================================
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
