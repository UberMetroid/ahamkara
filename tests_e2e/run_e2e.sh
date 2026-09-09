#!/usr/bin/env bash
# ==============================================================================
# Ahamkara Lore Preservation & openOODA Query Engine
# Master E2E Test Suite Runner
# Supports --all or individual tiers (--tier 1, --tier 2, --tier 3, --tier 4)
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

usage() {
    echo -e "${COLOR_BOLD}Ahamkara Opaque-Box E2E Test Runner${COLOR_RESET}"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all              Run all 4 tiers sequentially (default if no tier specified)"
    echo "  --tier <1|2|3|4>   Run a specific test tier:"
    echo "                       Tier 1: Feature Coverage (21 features, >=105 checks)"
    echo "                       Tier 2: Boundary & Corner Cases (>=105 checks)"
    echo "                       Tier 3: Cross-Feature Combinations (>=30 tests)"
    echo "                       Tier 4: Real-World Application Scenarios (6 scenarios)"
    echo "  -v, --verbose      Enable verbose diagnostic reporting"
    echo "  -h, --help         Display this help message and exit"
    echo ""
    echo "Exit Codes:"
    echo "  0: All executed tests passed"
    echo "  1: One or more test assertions failed"
    echo "  2: Invalid invocation or missing test dependencies"
}

# Parse CLI arguments
RUN_ALL=0
SELECTED_TIER=""
VERBOSE=0

if [[ $# -eq 0 ]]; then
    RUN_ALL=1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            RUN_ALL=1
            shift
            ;;
        --tier)
            if [[ -z "${2:-}" || ! "$2" =~ ^[1-4]$ ]]; then
                echo -e "${COLOR_RED}Error: --tier requires an argument between 1 and 4.${COLOR_RESET}" >&2
                usage
                exit 2
            fi
            SELECTED_TIER="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            export VERBOSE
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${COLOR_RED}Error: Unrecognized option '$1'.${COLOR_RESET}" >&2
            usage
            exit 2
            ;;
    esac
done

# Ensure test scripts are executable
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

# Execution tracking
OVERALL_STATUS=0
TIER_RESULTS=()

run_tier() {
    local tier_num="$1"
    local script_name="tier${tier_num}_feature_tests.sh"
    case "${tier_num}" in
        1) script_name="tier1_feature_tests.sh" ;;
        2) script_name="tier2_boundary_tests.sh" ;;
        3) script_name="tier3_combination_tests.sh" ;;
        4) script_name="tier4_scenario_tests.sh" ;;
    esac

    local script_path="${SCRIPT_DIR}/${script_name}"
    if [[ ! -x "${script_path}" ]]; then
        echo -e "${COLOR_RED}Error: Test script '${script_path}' not found or not executable.${COLOR_RESET}" >&2
        OVERALL_STATUS=1
        TIER_RESULTS+=("Tier ${tier_num}: ERROR (missing script)")
        return
    fi

    echo -e "${COLOR_CYAN}============================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Executing Tier ${tier_num}: ${script_name}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}============================================================${COLOR_RESET}"

    if "${script_path}"; then
        TIER_RESULTS+=("Tier ${tier_num}: PASSED")
    else
        TIER_RESULTS+=("Tier ${tier_num}: FAILED")
        OVERALL_STATUS=1
    fi
}

echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}     Ahamkara Lore Preservation & openOODA E2E Suite        ${COLOR_RESET}"
echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
echo "Execution Target: ${PROJECT_ROOT}"
echo ""

if [[ -n "${SELECTED_TIER}" ]]; then
    run_tier "${SELECTED_TIER}"
else
    run_tier 1
    run_tier 2
    run_tier 3
    run_tier 4
fi

# Print final master summary
echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}                Master E2E Run Summary                      ${COLOR_RESET}"
echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
for res in "${TIER_RESULTS[@]}"; do
    if [[ "${res}" =~ PASSED ]]; then
        echo -e "${COLOR_GREEN}${res}${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}${res}${COLOR_RESET}"
    fi
done
echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"

if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
    echo -e "${COLOR_GREEN}${COLOR_BOLD}All Executed Tiers Passed Successfully!${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_RED}${COLOR_BOLD}E2E Test Run Completed with Failures.${COLOR_RESET}"
    exit 1
fi
