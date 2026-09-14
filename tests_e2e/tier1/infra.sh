# ==============================================================================
# Tier 1 parts: F1-F3 - git repository, manifest/scaffolding, documentation.
# ==============================================================================
# ------------------------------------------------------------------------------
# Feature 1: Git Repository & Remote
# ------------------------------------------------------------------------------
test_start "T1-F01-01" "Git repository is initialized"
if git rev-parse --git-dir >/dev/null 2>&1; then
    test_pass "T1-F01-01" "Git repository is initialized"
else
    test_fail "T1-F01-01" "Git repository is initialized" "Not a valid git repository at ${PROJECT_ROOT}"
fi

test_start "T1-F01-02" "Git remote origin exists"
if git remote | grep -q "^origin$"; then
    test_pass "T1-F01-02" "Git remote origin exists"
else
    test_fail "T1-F01-02" "Git remote origin exists" "Remote 'origin' not found"
fi

test_start "T1-F01-03" "Git remote origin points to studio2201/ahamkara.git"
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "${ORIGIN_URL}" =~ (https://github.com/|git@github.com:)studio2201/ahamkara(\.git)? ]]; then
    test_pass "T1-F01-03" "Git remote origin points to studio2201/ahamkara.git (${ORIGIN_URL})"
else
    test_fail "T1-F01-03" "Git remote origin points to studio2201/ahamkara.git" "URL is '${ORIGIN_URL}'"
fi

test_start "T1-F01-04" "Working branch exists"
BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -n "${BRANCH}" ]]; then
    test_pass "T1-F01-04" "Working branch exists (${BRANCH})"
else
    test_fail "T1-F01-04" "Working branch exists" "No active git branch detected"
fi

test_start "T1-F01-05" "Git status executes cleanly"
if git status --porcelain >/dev/null 2>&1; then
    test_pass "T1-F01-05" "Git status executes cleanly"
else
    test_fail "T1-F01-05" "Git status executes cleanly" "git status command failed"
fi

# ------------------------------------------------------------------------------
# Feature 2: openOODA Manifest & Scaffolding
# ------------------------------------------------------------------------------
assert_file_exists "T1-F02-01" "${PROJECT_ROOT}/ooda.pkg" "Package manifest ooda.pkg exists"
assert_file_contains "T1-F02-02" "${PROJECT_ROOT}/ooda.pkg" "name[[:space:]]*=[[:space:]]*ahamkara" "ooda.pkg defines package name=ahamkara"
assert_file_contains "T1-F02-03" "${PROJECT_ROOT}/ooda.pkg" "min_pin[[:space:]]*=[[:space:]]*v0.210.0" "ooda.pkg defines min_pin=v0.210.0"
assert_file_contains "T1-F02-04" "${PROJECT_ROOT}/ooda.pkg" "caps[[:space:]]*=.*FsRead" "ooda.pkg specifies FsRead capability"

test_start "T1-F02-05" "openOODA stdlib symlink or directory exists and resolves"
if [[ -e "${PROJECT_ROOT}/std" ]]; then
    test_pass "T1-F02-05" "openOODA stdlib link exists (${PROJECT_ROOT}/std)"
else
    test_fail "T1-F02-05" "openOODA stdlib link exists" "Symlink or directory ${PROJECT_ROOT}/std missing"
fi

# ------------------------------------------------------------------------------
# Feature 3: Documentation & README
# ------------------------------------------------------------------------------
assert_file_exists "T1-F03-01" "${PROJECT_ROOT}/README.md" "Documentation README.md exists"
assert_file_contains "T1-F03-02" "${PROJECT_ROOT}/README.md" "(Ahamkara|Wish-Dragon|Riven)" "README.md contains Ahamkara lore documentation"
assert_file_contains "T1-F03-03" "${PROJECT_ROOT}/README.md" "(openOODA|Architecture|Engine|Layer)" "README.md describes openOODA query engine architecture"
assert_file_contains "T1-F03-04" "${PROJECT_ROOT}/README.md" "(--search|--entity|--category|--stats|query)" "README.md details CLI usage instructions"
assert_file_contains "T1-F03-05" "${PROJECT_ROOT}/README.md" "(verify\.sh|test|verification)" "README.md documents automated verification suite"

# ------------------------------------------------------------------------------
