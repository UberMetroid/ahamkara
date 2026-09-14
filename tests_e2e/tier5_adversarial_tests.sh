#!/usr/bin/env bash
# ==============================================================================
# Tier 5: Adversarial Coverage Hardening & Attack Surface E2E Test Suite (runner)
# Validates query engine boundaries, shell injection resilience, REPL fuzzing,
# data file corruption resilience, and script environment constraints.
# Functional parts live under tests_e2e/tier5/.
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 5: Adversarial Coverage Hardening (35 Checks)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"
REAL_CORPUS="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
export OODA_NO_JAIL=1

if [[ ! -x "${CLI_BIN}" ]]; then
    echo -e "${COLOR_RED}Error: Live binary ${CLI_BIN} not found or not executable.${COLOR_RESET}" >&2
    exit 1
fi

# Set up isolated temporary workspace for fast and non-destructive testing
TEMP_DIR=$(mktemp -d "/tmp/ahamkara_tier5_XXXXXX")
TEMP_DATA="${TEMP_DIR}/data"
mkdir -p "${TEMP_DATA}"

cleanup_tier5() {
    rm -rf "${TEMP_DIR}" /tmp/adversarial_pwn_*.txt 2>/dev/null || true
}
trap cleanup_tier5 EXIT INT TERM

# Create a minimal valid corpus (5 records) for rapid boundary testing
MINI_CORPUS="${TEMP_DATA}/ahamkara_corpus.jsonl"
head -n 5 "${REAL_CORPUS}" > "${MINI_CORPUS}"

# ==============================================================================

source "${SCRIPT_DIR}/tier5/attack_surface.sh"
source "${SCRIPT_DIR}/tier5/resilience.sh"

# Print final tier summary
print_tier_summary "Tier 5: Adversarial Coverage Hardening"

exit $?
