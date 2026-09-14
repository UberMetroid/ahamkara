#!/usr/bin/env bash
# ==============================================================================
# Ahamkara Lore Preservation & openOODA Query Engine
# Master Automated Verification Suite (verify.sh)
# ==============================================================================
# Pipeline Overview:
#   Stage 1: Lore Corpus Schema & Canonical Integrity (data/ + validate_corpus.py)
#   Stage 2: openOODA Invariants & Typechecking (oodac check across all .oo files)
#   Stage 3: openOODA Master Unit Test & Standalone CLI Verification
#   Stage 4: Opaque-Box End-to-End Suite (tests_e2e/run_e2e.sh with recursion guard)
#   Stage 5: Git Repository & Remote Synchronization Verification
#
# Layout (see verify/):
#   env.sh               — traps, colors, metrics, logging primitives, recursion guard
#   cli.sh               — flag parsing, banner, oodac toolchain discovery
#   stage_corpus.sh      — stage_corpus()   (Stage 1)
#   stage_typecheck.sh   — stage_typecheck() (Stage 2)
#   stage_test.sh        — stage_unit_test() (Stage 3)
#   stage_e2e.sh         — stage_e2e()      (Stage 4)
#   stage_git.sh         — stage_git()      (Stage 5)
#
# Exit Codes:
#   0: All executed verification assertions passed successfully.
#   1: One or more verification assertions failed.
#   2: Invalid CLI invocation or unrecognized command-line arguments.
# ==============================================================================

VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify"
source "${VERIFY_DIR}/env.sh"
source "${VERIFY_DIR}/cli.sh"
source "${VERIFY_DIR}/stage_corpus.sh"
source "${VERIFY_DIR}/stage_typecheck.sh"
source "${VERIFY_DIR}/stage_test.sh"
source "${VERIFY_DIR}/stage_e2e.sh"
source "${VERIFY_DIR}/stage_git.sh"

if [[ "${RUN_DATA}" -eq 1 ]]; then stage_corpus; fi
if [[ "${RUN_CHECK}" -eq 1 ]]; then stage_typecheck; fi
if [[ "${RUN_TEST}" -eq 1 ]]; then stage_unit_test; fi
if [[ "${RUN_E2E}" -eq 1 ]]; then stage_e2e; fi
if [[ "${EXPLICIT_STAGE}" -eq 0 || "${RUN_DATA}" -eq 1 ]]; then stage_git; fi

# ==============================================================================
# Complete Pass Final Summary Box & Exit Code
# ==============================================================================
print_summary
exit 0
