# stage_git.sh — Stage 5: git repository & remote synchronization.
# Defines stage_git(); invoked by verify.sh on full runs.
stage_git() {
step_header "Stage 5: Git Repository & Remote Synchronization"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if git -C "${PROJECT_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_pass "Git repository structure confirmed" "${PROJECT_ROOT}"
else
    log_fail "Git repository structure confirmed" "Not inside a git work tree"
    print_summary
    exit 1
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
CURRENT_BRANCH=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "${CURRENT_BRANCH}" == "ahamkara" ]]; then
    log_pass "Active branch is 'ahamkara'" "HEAD -> ${CURRENT_BRANCH}"
else
    log_fail "Active branch is 'ahamkara'" "Found: '${CURRENT_BRANCH}'"
    print_summary
    exit 1
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
REMOTE_URL=$(git -C "${PROJECT_ROOT}" remote get-url origin 2>/dev/null || echo "")
if [[ "${REMOTE_URL}" =~ studio2201/ahamkara ]]; then
    log_pass "Git remote origin configured" "${REMOTE_URL}"
else
    log_fail "Git remote origin configured" "Invalid origin URL: ${REMOTE_URL}"
    print_summary
    exit 1
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
UPSTREAM_BRANCH=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
if [[ "${UPSTREAM_BRANCH}" == "origin/ahamkara" ]]; then
    log_pass "Upstream tracking branch verified" "${UPSTREAM_BRANCH}"
else
    log_fail "Upstream tracking branch verified" "Found: '${UPSTREAM_BRANCH}', expected origin/ahamkara"
    print_summary
    exit 1
fi

# Working tree dirty check (advisory warning so uncommitted in-progress changes do not abort)
DIRTY_FILES=$(git -C "${PROJECT_ROOT}" status --porcelain 2>/dev/null || echo "")
if [[ -z "${DIRTY_FILES}" ]]; then
    log_info "Working tree is completely clean"
else
    log_info "Working tree contains uncommitted modifications"
fi

# GitHub CLI connection check with graceful degradation
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v gh >/dev/null 2>&1; then
    if GH_REPO=$(gh repo view studio2201/ahamkara --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        if [[ "${GH_REPO}" == "studio2201/ahamkara" ]]; then
            log_pass "GitHub CLI remote repository verified" "${GH_REPO}"
        else
            log_fail "GitHub CLI remote repository verified" "Unexpected repository: ${GH_REPO}"
            print_summary
            exit 1
        fi
    else
        log_skip "GitHub CLI remote repository query" "API unreachable or unauthenticated; local git checks verified"
    fi
else
    log_skip "GitHub CLI remote query" "gh CLI not installed in current environment"
fi
}
