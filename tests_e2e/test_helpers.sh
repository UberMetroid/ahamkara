#!/usr/bin/env bash
# ==============================================================================
# Ahamkara E2E Testing Framework — Common Test Helpers
# ==============================================================================

# Strict bash modes
set -o pipefail

# ANSI color codes
if [[ -t 1 ]] || [[ -n "${FORCE_COLOR:-}" ]]; then
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_CYAN="\033[0;36m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
    COLOR_BOLD=""
fi

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Verbosity flag
VERBOSE="${VERBOSE:-0}"

# Reporting primitives
test_start() {
    local test_id="$1"
    local desc="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ "${VERBOSE}" -ge 2 ]]; then
        echo -e "${COLOR_CYAN}[START]${COLOR_RESET} ${test_id}: ${desc}"
    fi
}

test_pass() {
    local test_id="$1"
    local desc="$2"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} ${test_id}: ${desc}"
}

test_fail() {
    local test_id="$1"
    local desc="$2"
    local detail="${3:-}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} ${test_id}: ${desc}"
    if [[ -n "${detail}" ]]; then
        echo -e "       ${COLOR_RED}Reason: ${detail}${COLOR_RESET}"
    fi
}

test_skip() {
    local test_id="$1"
    local desc="$2"
    local reason="${3:-precondition not met}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    echo -e "${COLOR_YELLOW}[SKIP]${COLOR_RESET} ${test_id}: ${desc} (${reason})"
}

# Assertion primitives
assert_file_exists() {
    local test_id="$1"
    local file_path="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ -f "${file_path}" ]]; then
        test_pass "${test_id}" "${desc}"
        return 0
    else
        test_fail "${test_id}" "${desc}" "File does not exist: ${file_path}"
        return 1
    fi
}

assert_dir_exists() {
    local test_id="$1"
    local dir_path="$2"
    local desc="$3"
    test_start "${test_id}" "${desc}"
    if [[ -d "${dir_path}" ]]; then
        test_pass "${test_id}" "${desc}"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Directory does not exist: ${dir_path}"
        return 1
    fi
}

assert_file_contains() {
    local test_id="$1"
    local file_path="$2"
    local pattern="$3"
    local desc="$4"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${file_path}" ]]; then
        test_fail "${test_id}" "${desc}" "Target file missing: ${file_path}"
        return 1
    fi
    if grep -qE -- "${pattern}" "${file_path}" 2>/dev/null; then
        test_pass "${test_id}" "${desc}"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Pattern '${pattern}' not found in ${file_path}"
        return 1
    fi
}

assert_file_lines_lte() {
    local test_id="$1"
    local file_path="$2"
    local max_lines="$3"
    local desc="$4"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${file_path}" ]]; then
        test_fail "${test_id}" "${desc}" "File missing: ${file_path}"
        return 1
    fi
    local count
    count=$(wc -l < "${file_path}")
    if [[ "${count}" -le "${max_lines}" ]]; then
        test_pass "${test_id}" "${desc} (${count} <= ${max_lines})"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Line count ${count} exceeds limit of ${max_lines}"
        return 1
    fi
}

assert_file_size_lte() {
    local test_id="$1"
    local file_path="$2"
    local max_bytes="$3"
    local desc="$4"
    test_start "${test_id}" "${desc}"
    if [[ ! -f "${file_path}" ]]; then
        test_fail "${test_id}" "${desc}" "File missing: ${file_path}"
        return 1
    fi
    local size
    size=$(stat -c%s "${file_path}" 2>/dev/null || wc -c < "${file_path}")
    if [[ "${size}" -le "${max_bytes}" ]]; then
        test_pass "${test_id}" "${desc} (${size} <= ${max_bytes} bytes)"
        return 0
    else
        test_fail "${test_id}" "${desc}" "File size ${size} exceeds limit of ${max_bytes} bytes"
        return 1
    fi
}

assert_eq() {
    local test_id="$1"
    local actual="$2"
    local expected="$3"
    local desc="$4"
    test_start "${test_id}" "${desc}"
    if [[ "${actual}" == "${expected}" ]]; then
        test_pass "${test_id}" "${desc}"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Expected '${expected}', got '${actual}'"
        return 1
    fi
}

assert_gte() {
    local test_id="$1"
    local actual="$2"
    local expected="$3"
    local desc="$4"
    test_start "${test_id}" "${desc}"
    if [[ "${actual}" -ge "${expected}" ]]; then
        test_pass "${test_id}" "${desc} (${actual} >= ${expected})"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Expected >= ${expected}, got ${actual}"
        return 1
    fi
}

assert_cmd_success() {
    local test_id="$1"
    local desc="$2"
    shift 2
    test_start "${test_id}" "${desc}"
    local output
    if output=$("$@" 2>&1); then
        test_pass "${test_id}" "${desc}"
        return 0
    else
        test_fail "${test_id}" "${desc}" "Command failed: $* (output: ${output})"
        return 1
    fi
}

# Print tier summary
print_tier_summary() {
    local tier_name="$1"
    echo ""
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}     ${tier_name} Summary${COLOR_RESET}"
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo -e "Total:   ${TOTAL_TESTS}"
    echo -e "Passed:  ${COLOR_GREEN}${PASSED_TESTS}${COLOR_RESET}"
    echo -e "Failed:  ${COLOR_RED}${FAILED_TESTS}${COLOR_RESET}"
    echo -e "Skipped: ${COLOR_YELLOW}${SKIPPED_TESTS}${COLOR_RESET}"
    if [[ "${FAILED_TESTS}" -eq 0 ]]; then
        echo -e "Status:  ${COLOR_GREEN}${COLOR_BOLD}PASSED${COLOR_RESET}"
    else
        echo -e "Status:  ${COLOR_RED}${COLOR_BOLD}FAILED${COLOR_RESET}"
    fi
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo ""
    if [[ "${FAILED_TESTS}" -gt 0 ]]; then
        return 1
    fi
    return 0
}
