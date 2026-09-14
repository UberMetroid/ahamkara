#!/usr/bin/env bash
# ==============================================================================
# Tier 1: Feature Coverage E2E Test Suite (runner)
# Validates baseline presence, schema compliance, and happy paths for all 21 features.
# Functional parts live under tests_e2e/tier1/.
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 1: Feature Coverage Tests (21 Features, 105 Checks)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

source "${SCRIPT_DIR}/tier1/infra.sh"
source "${SCRIPT_DIR}/tier1/corpus.sh"
source "${SCRIPT_DIR}/tier1/engine.sh"
source "${SCRIPT_DIR}/tier1/meta.sh"

# Print summary
print_tier_summary "Tier 1: Feature Coverage"

exit $?
