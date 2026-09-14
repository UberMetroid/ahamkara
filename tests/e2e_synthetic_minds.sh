#!/usr/bin/env bash
# ==============================================================================
# e2e_synthetic_minds.sh — E2E Test Suite Runner for Synthetic Mind Ingress
#
# Usage:
#   bash tests/e2e_synthetic_minds.sh [options]
#
# Options:
#   --tier <1|2|3|4|all>   Target a specific test tier (default: all)
#   --milestone <M1|M2|all> Target milestone scope (default: all)
#   --dist <path>          Path to dist directory (default: dist)
#   -v, --verbose          Print every test assertion
#   -q, --quiet            Print only summary and failures
#   -h, --help             Show this help message
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Resolve Python 3 executable
PYTHON_BIN="$(which python3 2>/dev/null || true)"
if [ -z "${PYTHON_BIN}" ]; then
    echo "ERROR: python3 not found in PATH" >&2
    exit 1
fi

cd "${REPO_ROOT}"

# Delegate directly to runner.py with passed arguments
exec "${PYTHON_BIN}" -m tests.runner "$@"
