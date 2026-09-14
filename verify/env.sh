# env.sh — shell environment: traps, colors, metrics, logging, recursion guard.
# Sourced by verify.sh; not executed directly.
set -eo pipefail

# ------------------------------------------------------------------------------
# Signal Handling & Temporary Resource Cleanup
# ------------------------------------------------------------------------------
TEMP_FILES=()
TEMP_DIRS=()

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM HUP
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        rm -f "${TEMP_FILES[@]}" 2>/dev/null || true
    fi
    if [[ ${#TEMP_DIRS[@]} -gt 0 ]]; then
        rm -rf "${TEMP_DIRS[@]}" 2>/dev/null || true
    fi
    exit "${exit_code}"
}
trap cleanup EXIT INT TERM HUP

# ------------------------------------------------------------------------------
# Project Directory Resolution
# ------------------------------------------------------------------------------
VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${VERIFY_DIR}/.." && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
cd "${PROJECT_ROOT}" || exit 1

# ------------------------------------------------------------------------------
# ANSI Color Formatting & TTY Detection
# ------------------------------------------------------------------------------
if { [[ -t 1 ]] || [[ -n "${FORCE_COLOR:-}" ]]; } && [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_MAGENTA="\033[0;35m"
    COLOR_CYAN="\033[0;36m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_BOLD=""
fi

# ------------------------------------------------------------------------------
# Global Metrics & Accounting
# ------------------------------------------------------------------------------
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0
START_TIME=$(date +%s)

# ------------------------------------------------------------------------------
# Diagnostic & Output Logging Primitives
# ------------------------------------------------------------------------------
log_pass() {
    local name="$1"
    local detail="${2:-}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    if [[ "${QUIET}" -eq 0 ]]; then
        if [[ -n "${detail}" ]]; then
            echo -e "  ${COLOR_GREEN}[PASS]${COLOR_RESET} ${name} ${COLOR_CYAN}(${detail})${COLOR_RESET}"
        else
            echo -e "  ${COLOR_GREEN}[PASS]${COLOR_RESET} ${name}"
        fi
    fi
}

log_fail() {
    local name="$1"
    local detail="${2:-}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} ${name}" >&2
    if [[ -n "${detail}" ]]; then
        echo -e "         ${COLOR_RED}Reason: ${detail}${COLOR_RESET}" >&2
    fi
}

log_skip() {
    local name="$1"
    local reason="${2:-precondition not met}"
    SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
    if [[ "${QUIET}" -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}[SKIP]${COLOR_RESET} ${name} (${reason})"
    fi
}

log_info() {
    local msg="$1"
    if [[ "${QUIET}" -eq 0 ]]; then
        echo -e "  ${COLOR_CYAN}[INFO]${COLOR_RESET} ${msg}"
    fi
}

step_header() {
    local title="$1"
    if [[ "${QUIET}" -eq 0 ]]; then
        echo ""
        echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
        echo -e "${COLOR_BOLD}  ${title}${COLOR_RESET}"
        echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    fi
}

step_subheader() {
    local subtitle="$1"
    if [[ "${QUIET}" -eq 0 ]]; then
        echo -e "${COLOR_BLUE}--- ${subtitle} ---${COLOR_RESET}"
    fi
}

print_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    if [[ "${QUIET}" -eq 1 && "${FAILED_CHECKS}" -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}              Ahamkara Verification Summary                 ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo -e "Total Checks:   ${TOTAL_CHECKS}"
    echo -e "Passed:         ${COLOR_GREEN}${PASSED_CHECKS}${COLOR_RESET}"
    if [[ "${FAILED_CHECKS}" -gt 0 ]]; then
        echo -e "Failed:         ${COLOR_RED}${FAILED_CHECKS}${COLOR_RESET}"
    else
        echo -e "Failed:         0"
    fi
    if [[ "${SKIPPED_CHECKS}" -gt 0 ]]; then
        echo -e "Skipped:        ${COLOR_YELLOW}${SKIPPED_CHECKS}${COLOR_RESET}"
    fi
    echo -e "Elapsed Time:   ${duration}s"
    if [[ "${FAILED_CHECKS}" -eq 0 ]]; then
        echo -e "Status:         ${COLOR_GREEN}${COLOR_BOLD}PASSED (All Verification Invariants Satisfied)${COLOR_RESET}"
    else
        echo -e "Status:         ${COLOR_RED}${COLOR_BOLD}FAILED (Verification Assertions Destabilized)${COLOR_RESET}"
    fi
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# Re-entrancy & Infinite Recursion Guard
# ------------------------------------------------------------------------------
is_in_e2e_harness() {
    # 1. Environment variable guard
    if [[ -n "${AHAMKARA_E2E_ACTIVE:-}" ]]; then
        return 0
    fi

    # 2. Process hierarchy inspection
    local cur_ppid="${PPID:-}"
    while [[ -n "${cur_ppid}" && "${cur_ppid}" -gt 1 ]]; do
        local pcmd=""
        if [[ -f "/proc/${cur_ppid}/cmdline" ]]; then
            pcmd=$(tr '\0' ' ' < "/proc/${cur_ppid}/cmdline" 2>/dev/null || true)
        fi
        if [[ "${pcmd}" =~ (run_e2e|tier1|tier2|tier3|tier4) ]]; then
            return 0
        fi
        cur_ppid=$(awk '{print $4}' "/proc/${cur_ppid}/stat" 2>/dev/null || true)
    done

    return 1
}
