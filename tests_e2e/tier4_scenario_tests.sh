#!/usr/bin/env bash
# ==============================================================================
# Tier 4: Real-World Application Scenarios E2E Test Suite (runner)
# Validates 6 comprehensive end-to-end user workflows:
# 1. The Great Hunt Scholar
# 2. The Exotic Hunter
# 3. The Wall of Wishes Cryptarch
# 4. The Chronicler of Taranis & Hefnd
# 5. The Paracausal Metaphysician
# 6. The Automated CI/CD Verifier
# Functional parts live under tests_e2e/tier4/.
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

cd "${PROJECT_ROOT}" || exit 1

echo -e "${COLOR_BOLD}Starting Tier 4: Real-World Application Scenarios (6 Scenarios)${COLOR_RESET}"
echo "Project Root: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"

CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

# ------------------------------------------------------------------------------

source "${SCRIPT_DIR}/tier4/scholars.sh"
source "${SCRIPT_DIR}/tier4/meta.sh"

# Print summary
print_tier_summary "Tier 4: Real-World Application Scenarios"

exit $?
