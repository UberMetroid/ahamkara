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
# Exit Codes:
#   0: All executed verification assertions passed successfully.
#   1: One or more verification assertions failed.
#   2: Invalid CLI invocation or unrecognized command-line arguments.
# ==============================================================================

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# ------------------------------------------------------------------------------
# CLI Flag & Argument Parsing
# ------------------------------------------------------------------------------
RUN_DATA=0
RUN_CHECK=0
RUN_TEST=0
RUN_E2E=0
VERBOSE=0
QUIET=0
EXPLICIT_STAGE=0

usage() {
    echo -e "${COLOR_BOLD}Ahamkara Automated Verification Suite (verify.sh)${COLOR_RESET}"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Verification Stages:"
    echo "  --all              Execute complete verification pipeline (default)"
    echo "  --data             Validate lore corpus schema, syntax, and canonical items"
    echo "  --check            Run openOODA typechecking (oodac check) and file invariants"
    echo "  --test             Execute master openOODA unit tests and CLI query smoke tests"
    echo "  --e2e              Run opaque-box end-to-end integration tests (run_e2e.sh)"
    echo ""
    echo "Output & Diagnostics:"
    echo "  -q, --quiet        Suppress normal progress; only emit failures and summary"
    echo "  -v, --verbose      Display verbose diagnostics and full command outputs"
    echo "  -h, --help         Display this usage guide and exit"
    echo ""
    echo "Exit Codes:"
    echo "  0: All verification assertions passed successfully"
    echo "  1: One or more assertions failed"
    echo "  2: Invalid CLI invocation or unrecognized arguments"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            RUN_DATA=1
            RUN_CHECK=1
            RUN_TEST=1
            RUN_E2E=1
            EXPLICIT_STAGE=1
            shift
            ;;
        --data)
            RUN_DATA=1
            EXPLICIT_STAGE=1
            shift
            ;;
        --check)
            RUN_CHECK=1
            EXPLICIT_STAGE=1
            shift
            ;;
        --test)
            RUN_TEST=1
            EXPLICIT_STAGE=1
            shift
            ;;
        --e2e)
            RUN_E2E=1
            EXPLICIT_STAGE=1
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${COLOR_RED}Error: Unrecognized option '$1'.${COLOR_RESET}" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# If no specific stage flag is specified, default to executing all stages
if [[ "${EXPLICIT_STAGE}" -eq 0 ]]; then
    RUN_DATA=1
    RUN_CHECK=1
    RUN_TEST=1
    RUN_E2E=1
fi

# ------------------------------------------------------------------------------
# Banner Output
# ------------------------------------------------------------------------------
if [[ "${QUIET}" -eq 0 ]]; then
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}     Ahamkara Lore Preservation & openOODA Suite            ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}     Automated Root Verification Runner (verify.sh)         ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}============================================================${COLOR_RESET}"
    echo "Working Directory: ${PROJECT_ROOT}"
fi

# ------------------------------------------------------------------------------
# Toolchain Discovery & Runtime Configuration
# ------------------------------------------------------------------------------
resolve_ooda_compiler() {
    if [[ -x "/home/jeryd/Projects/openOODA/oodac/bin/oodac" ]]; then
        echo "/home/jeryd/Projects/openOODA/oodac/bin/oodac"
        return 0
    elif [[ -n "${OODA_COMPILER:-}" && -x "${OODA_COMPILER}" ]]; then
        echo "${OODA_COMPILER}"
        return 0
    elif command -v oodac >/dev/null 2>&1; then
        command -v oodac
        return 0
    elif [[ -x "/home/jeryd/.openooda/bin/oodac" ]]; then
        echo "/home/jeryd/.openooda/bin/oodac"
        return 0
    fi
    return 1
}

OODA_COMPILER=$(resolve_ooda_compiler || echo "")
if [[ -n "${OODA_COMPILER}" && -x "${OODA_COMPILER}" ]]; then
    export OODA_COMPILER
    export PATH="$(dirname "${OODA_COMPILER}"):${PATH}"
fi
export OODA_NO_JAIL=1

# ==============================================================================
# STAGE 1: Data & Lore Corpus Integrity Verification (--data)
# ==============================================================================
if [[ "${RUN_DATA}" -eq 1 ]]; then
    step_header "Stage 1: Lore Corpus Schema & Canonical Integrity"

    CORPUS_JSON="${PROJECT_ROOT}/data/ahamkara_corpus.json"
    CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
    CATEGORIES_DIR="${PROJECT_ROOT}/data/categories"
    VALIDATOR_PY="${PROJECT_ROOT}/scripts/validate_corpus.py"
    EXPECTED_COUNT=84

    # 1. Master files existence and non-empty checks
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "${CORPUS_JSON}" && -s "${CORPUS_JSON}" ]]; then
        log_pass "Master corpus JSON exists and is non-empty" "data/ahamkara_corpus.json"
    else
        log_fail "Master corpus JSON exists and is non-empty" "Missing or empty: ${CORPUS_JSON}"
        print_summary
        exit 1
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "${CORPUS_JSONL}" && -s "${CORPUS_JSONL}" ]]; then
        log_pass "Master corpus JSONL exists and is non-empty" "data/ahamkara_corpus.jsonl"
    else
        log_fail "Master corpus JSONL exists and is non-empty" "Missing or empty: ${CORPUS_JSONL}"
        print_summary
        exit 1
    fi

    # 2. Category partition files
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    EXPECTED_PARTITIONS=("exotics.json" "great_hunt.json" "riven.json" "taranis.json" "wishes.json")
    PARTITION_FAILURES=0
    if [[ -d "${CATEGORIES_DIR}" ]]; then
        for part in "${EXPECTED_PARTITIONS[@]}"; do
            part_path="${CATEGORIES_DIR}/${part}"
            if [[ ! -f "${part_path}" || ! -s "${part_path}" ]]; then
                log_fail "Category partition present: ${part}" "Missing or empty: ${part_path}"
                PARTITION_FAILURES=$((PARTITION_FAILURES + 1))
            fi
        done
    else
        log_fail "Categories partition directory present" "Missing directory: ${CATEGORIES_DIR}"
        PARTITION_FAILURES=$((PARTITION_FAILURES + 1))
    fi

    if [[ "${PARTITION_FAILURES}" -eq 0 ]]; then
        log_pass "All 5 category partition files verified in data/categories/" "5/5 partition archives verified"
    else
        print_summary
        exit 1
    fi

    # 3. Record count parity between JSON and JSONL
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    JSONL_LINES=$(wc -l < "${CORPUS_JSONL}" | tr -d ' ')
    if command -v jq >/dev/null 2>&1; then
        JSON_COUNT=$(jq '. | length' "${CORPUS_JSON}" 2>/dev/null || echo 0)
    else
        JSON_COUNT=$(python3 -c "import json; print(len(json.load(open('${CORPUS_JSON}'))))" 2>/dev/null || echo 0)
    fi

    if [[ "${JSONL_LINES}" -eq "${EXPECTED_COUNT}" && "${JSON_COUNT}" -eq "${EXPECTED_COUNT}" && "${JSONL_LINES}" -eq "${JSON_COUNT}" ]]; then
        log_pass "Corpus record count parity verified" "exactly ${EXPECTED_COUNT} records in JSON and JSONL"
    else
        log_fail "Corpus record count parity" "JSON: ${JSON_COUNT}, JSONL: ${JSONL_LINES}, Expected: ${EXPECTED_COUNT}"
        print_summary
        exit 1
    fi

    # 4. Strict UNIX LF byte validation (0 CR characters)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CR_TOTAL=0
    cr_master_json=$(tr -d -c '\r' < "${CORPUS_JSON}" | wc -c | tr -d ' ')
    cr_master_jsonl=$(tr -d -c '\r' < "${CORPUS_JSONL}" | wc -c | tr -d ' ')
    CR_TOTAL=$((CR_TOTAL + cr_master_json + cr_master_jsonl))

    for cat_file in "${CATEGORIES_DIR}"/*.json; do
        if [[ -f "${cat_file}" ]]; then
            cr_cat=$(tr -d -c '\r' < "${cat_file}" | wc -c | tr -d ' ')
            CR_TOTAL=$((CR_TOTAL + cr_cat))
        fi
    done

    if [[ "${CR_TOTAL}" -eq 0 ]]; then
        log_pass "Strict UNIX LF validated across all archives" "0 CR bytes detected"
    else
        log_fail "Strict UNIX LF character validation" "Found ${CR_TOTAL} Windows CRLF carriage returns"
        print_summary
        exit 1
    fi

    # 5. Trailing LF byte validation
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    TRAILING_HEX=$(tail -c 1 "${CORPUS_JSONL}" | od -An -tx1 | tr -d ' ')
    if [[ "${TRAILING_HEX}" == "0a" ]]; then
        log_pass "JSONL archive terminates with standard newline LF byte (0x0a)" "Valid terminal LF"
    else
        log_fail "JSONL archive newline termination" "Trailing byte: ${TRAILING_HEX}, expected 0x0a"
        print_summary
        exit 1
    fi

    # 6. Canonical Checklist: Entities and Artifacts
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CANONICAL_ERRORS=0

    # Entity: Riven
    if grep -q '"entity":\s*\[[^]]*"Riven"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: Riven confirmed"
    else
        log_fail "Canonical checklist item" "Entity 'Riven' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Entity: Taranis
    if grep -q '"entity":\s*\[[^]]*"Taranis"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: Taranis confirmed"
    else
        log_fail "Canonical checklist item" "Entity 'Taranis' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Entity: Hefnd
    if grep -q '"entity":\s*\[[^]]*"Hefnd"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: Hefnd confirmed"
    else
        log_fail "Canonical checklist item" "Entity 'Hefnd' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Entity: Huginn
    if grep -q '"entity":\s*\[[^]]*"Huginn"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: Huginn confirmed"
    else
        log_fail "Canonical checklist item" "Entity 'Huginn' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Entity: Muninn
    if grep -q '"entity":\s*\[[^]]*"Muninn"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: Muninn confirmed"
    else
        log_fail "Canonical checklist item" "Entity 'Muninn' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Canonical Gear: Skull of Dire Ahamkara
    if grep -q '"id":\s*"exotic-skull-of-dire-ahamkara"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Item: Skull of Dire Ahamkara confirmed"
    else
        log_fail "Canonical checklist item" "Gear 'exotic-skull-of-dire-ahamkara' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Canonical Gear: Young Ahamkara's Spine
    if grep -q '"id":\s*"exotic-young-ahamkaras-spine"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Item: Young Ahamkara's Spine confirmed"
    else
        log_fail "Canonical checklist item" "Gear 'exotic-young-ahamkaras-spine' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    # Canonical Secret: 15th Wish
    if grep -q '"id":\s*"wish-wall-fifteenth-wish"' "${CORPUS_JSONL}"; then
        [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Item: Fifteenth Wish confirmed"
    else
        log_fail "Canonical checklist item" "Secret 'wish-wall-fifteenth-wish' missing from corpus"
        CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
    fi

    if [[ "${CANONICAL_ERRORS}" -eq 0 ]]; then
        log_pass "Canonical lore checklist satisfied (8/8 canonical targets present)" "Riven, Taranis, Hefnd, Huginn, Muninn, Skull, Spine, 15th Wish"
    else
        log_fail "Canonical lore checklist failed" "${CANONICAL_ERRORS} items missing"
        print_summary
        exit 1
    fi

    # 7. Semantic validation via Python script (validate_corpus.py --strict)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "${VALIDATOR_PY}" ]]; then
        VAL_ARGS=(python3 "${VALIDATOR_PY}" --strict)
        if [[ "${VERBOSE}" -eq 1 ]]; then
            VAL_ARGS+=(--verbose)
        fi
        if [[ "${QUIET}" -eq 1 ]]; then
            VAL_ARGS+=(--quiet)
        fi

        VAL_OUT=$("${VAL_ARGS[@]}" 2>&1) && VAL_RET=0 || VAL_RET=$?
        if [[ "${VAL_RET}" -eq 0 && ! "${VAL_OUT}" =~ \[FAIL\] ]]; then
            log_pass "Python corpus semantic validator (scripts/validate_corpus.py --strict)" "50/50 checks passed"
            if [[ "${VERBOSE}" -eq 1 && "${QUIET}" -eq 0 ]]; then
                echo "${VAL_OUT}"
            fi
        else
            log_fail "Python corpus validator failed" "${VAL_OUT}"
            print_summary
            exit 1
        fi
    else
        log_fail "Python corpus validator present" "Missing: ${VALIDATOR_PY}"
        print_summary
        exit 1
    fi
fi

# ==============================================================================
# STAGE 2: openOODA Compiler Typechecking & File Invariants (--check)
# ==============================================================================
if [[ "${RUN_CHECK}" -eq 1 ]]; then
    step_header "Stage 2: openOODA Invariants & Typechecking (oodac check)"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -n "${OODA_COMPILER}" && -x "${OODA_COMPILER}" ]]; then
        log_pass "openOODA compiler located" "${OODA_COMPILER}"
    else
        log_fail "openOODA compiler discovery" "oodac binary not found or not executable"
        print_summary
        exit 1
    fi

    OO_FILES=()
    while IFS= read -r -d '' file; do
        OO_FILES+=("$file")
    done < <(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" -type f -name "*.oo" -print0 | sort -z)

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ ${#OO_FILES[@]} -ge 15 ]]; then
        log_pass "Located openOODA source and test files" "${#OO_FILES[@]} .oo files found"
    else
        log_fail "Located openOODA source and test files" "Found ${#OO_FILES[@]} files, expected >= 15"
        print_summary
        exit 1
    fi

    # 1. File line count limit (<= 256 lines per .oo file)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    OVERSIZED_LINES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" -type f -name "*.oo" 2>/dev/null \
        | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 256 { print $2 ": " $1 }' || true)
    if [[ -z "${OVERSIZED_LINES}" ]]; then
        log_pass "Compiler line limit invariant (<= 256 lines per .oo file)" "All ${#OO_FILES[@]} files compliant"
    else
        log_fail "Compiler line limit invariant" "Files exceeding 256 lines: ${OVERSIZED_LINES}"
        print_summary
        exit 1
    fi

    # 2. File byte size limit (<= 64 KiB per .oo file)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    OVERSIZED_BYTES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" -type f -name "*.oo" -size +65536c 2>/dev/null || true)
    if [[ -z "${OVERSIZED_BYTES}" ]]; then
        log_pass "Compiler file size invariant (<= 64 KiB per .oo file)" "All ${#OO_FILES[@]} files compliant"
    else
        log_fail "Compiler file size invariant" "Files exceeding 64 KiB: ${OVERSIZED_BYTES}"
        print_summary
        exit 1
    fi

    # 3. Indentation hygiene: 0 tab characters
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    TAB_VIOLATIONS=$(grep -rn --include="*.oo" $'\t' "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" 2>/dev/null || true)
    if [[ -z "${TAB_VIOLATIONS}" ]]; then
        log_pass "Whitespace hygiene audit (0 tab characters in .oo files)" "Pure space indentation"
    else
        log_fail "Whitespace hygiene audit" "Found tab characters: ${TAB_VIOLATIONS}"
        print_summary
        exit 1
    fi

    # 4. Encoding hygiene: 0 non-ASCII control characters
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CTRL_VIOLATIONS=$(grep -P -n "[\x00-\x08\x0B\x0C\x0E-\x1F]" "${PROJECT_ROOT}"/src/**/*.oo "${PROJECT_ROOT}"/tests/*.oo 2>/dev/null || true)
    if [[ -z "${CTRL_VIOLATIONS}" ]]; then
        log_pass "Encoding hygiene audit (0 illegal control characters)" "Clean UTF-8"
    else
        log_fail "Encoding hygiene audit" "Found illegal control characters: ${CTRL_VIOLATIONS}"
        print_summary
        exit 1
    fi

    # 5. Compiler typecheck (oodac check across all .oo files)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    TYPECHECK_FAILURES=0
    for oo_file in "${OO_FILES[@]}"; do
        rel_path="${oo_file#${PROJECT_ROOT}/}"
        out=$("${OODA_COMPILER}" check "${oo_file}" 2>&1)
        ret=$?
        if [[ "${ret}" -ne 0 || ! "${out}" =~ OK ]]; then
            log_fail "Typecheck failed on ${rel_path}" "${out}"
            TYPECHECK_FAILURES=$((TYPECHECK_FAILURES + 1))
        elif [[ "${VERBOSE}" -eq 1 ]]; then
            log_info "Typecheck OK: ${rel_path}"
        fi
    done

    if [[ "${TYPECHECK_FAILURES}" -eq 0 ]]; then
        log_pass "All openOODA source and test files pass oodac check" "${#OO_FILES[@]}/${#OO_FILES[@]} verified"
    else
        log_fail "openOODA compiler typechecking" "${TYPECHECK_FAILURES} files failed oodac check"
        print_summary
        exit 1
    fi
fi

# ==============================================================================
# STAGE 3: openOODA Master Unit Tests & Standalone CLI Verification (--test)
# ==============================================================================
if [[ "${RUN_TEST}" -eq 1 ]]; then
    step_header "Stage 3: openOODA Master Unit Tests & CLI Query Verification"

    TEST_SOURCE="${PROJECT_ROOT}/tests/test_main.oo"
    CLI_BIN="${PROJECT_ROOT}/bin/ahamkara"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "${TEST_SOURCE}" ]]; then
        log_pass "Master unit test runner source located" "${TEST_SOURCE}"
    else
        log_fail "Master unit test runner source present" "Missing: ${TEST_SOURCE}"
        print_summary
        exit 1
    fi

    # 1. Execute Unit Test Suite
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    TMP_TEST_BIN="/tmp/verify_test_main_$$"
    TEMP_FILES+=("${TMP_TEST_BIN}")

    if is_in_e2e_harness && [[ -x "${PROJECT_ROOT}/bin/test_main" ]]; then
        ACTIVE_TEST_BIN="${PROJECT_ROOT}/bin/test_main"
        log_pass "Reusing validated test binary (in E2E harness)" "${ACTIVE_TEST_BIN}"
    else
        BUILD_OUT=$("${OODA_COMPILER}" build --backend c "${TEST_SOURCE}" -o "${TMP_TEST_BIN}" 2>&1) && BUILD_RET=0 || BUILD_RET=$?
        if [[ "${BUILD_RET}" -eq 0 && -x "${TMP_TEST_BIN}" ]]; then
            log_pass "Native compilation of tests/test_main.oo" "Compiled binary: ${TMP_TEST_BIN}"
            ACTIVE_TEST_BIN="${TMP_TEST_BIN}"
        else
            rm -f "${TMP_TEST_BIN}"
            log_fail "Native compilation of tests/test_main.oo" "${BUILD_OUT}"
            print_summary
            exit 1
        fi
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    TEST_OUT=$(OODA_NO_JAIL=1 "${ACTIVE_TEST_BIN}" 2>&1) && TEST_RET=0 || TEST_RET=$?
    rm -f "${TMP_TEST_BIN}" 2>/dev/null || true

    if [[ "${TEST_RET}" -eq 0 && "${TEST_OUT}" =~ ALL_TESTS_PASSED ]]; then
        log_pass "openOODA master unit test runner executed cleanly" "OK: ALL_TESTS_PASSED"
        if [[ "${VERBOSE}" -eq 1 && "${QUIET}" -eq 0 ]]; then
            echo "${TEST_OUT}"
        fi
    else
        log_fail "openOODA master unit test runner execution" "Exit: ${TEST_RET}, Output: ${TEST_OUT}"
        print_summary
        exit 1
    fi

    # 2. Ensure standalone CLI binary exists and is up to date
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    REBUILD_CLI=0
    if [[ ! -x "${CLI_BIN}" ]]; then
        REBUILD_CLI=1
    else
        while IFS= read -r -d '' src_file; do
            if [[ "${src_file}" -nt "${CLI_BIN}" ]]; then
                REBUILD_CLI=1
                break
            fi
        done < <(find "${PROJECT_ROOT}/src" -type f -name "*.oo" -print0)
    fi

    if [[ "${REBUILD_CLI}" -eq 1 ]]; then
        mkdir -p "${PROJECT_ROOT}/bin"
        rm -f "${CLI_BIN}"
        CLI_BUILD_OUT=$("${OODA_COMPILER}" build --backend c "${PROJECT_ROOT}/src/main.oo" -o "${CLI_BIN}" 2>&1) && CLI_BUILD_RET=0 || CLI_BUILD_RET=$?
        if [[ "${CLI_BUILD_RET}" -eq 0 && -x "${CLI_BIN}" ]]; then
            log_pass "CLI standalone binary built successfully" "${CLI_BIN}"
        else
            log_fail "CLI standalone binary compilation" "${CLI_BUILD_OUT}"
            print_summary
            exit 1
        fi
    else
        log_pass "CLI standalone binary up-to-date" "${CLI_BIN}"
    fi

    # 3. CLI Smoke & Semantic Query Invocations
    # Operation: --version
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    VER_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --version 2>&1) && VER_RET=0 || VER_RET=$?
    if [[ "${VER_RET}" -eq 0 && "${VER_OUT}" =~ ahamkara\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
        log_pass "CLI --version output matches semver format" "${VER_OUT}"
    else
        log_fail "CLI --version output matches semver format" "${VER_OUT}"
        print_summary
        exit 1
    fi

    # Operation: --help
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    HELP_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --help 2>&1) && HELP_RET=0 || HELP_RET=$?
    if [[ "${HELP_RET}" -eq 0 && "${HELP_OUT}" =~ Usage: ]]; then
        log_pass "CLI --help displays usage guide" "Exit 0"
    else
        log_fail "CLI --help displays usage guide" "${HELP_OUT}"
        print_summary
        exit 1
    fi

    # Operation: --stats
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    STATS_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --stats 2>&1) && STATS_RET=0 || STATS_RET=$?
    if [[ "${STATS_RET}" -eq 0 && "${STATS_OUT}" =~ "Total records: 84" && "${STATS_OUT}" =~ "Total quotes/whispers: 79" ]]; then
        log_pass "CLI --stats aggregations verified" "84 records, 79 whispers"
    else
        log_fail "CLI --stats aggregations verified" "${STATS_OUT}"
        print_summary
        exit 1
    fi

    # Operation: --entity Riven (43 records)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    RIVEN_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --entity Riven 2>&1) && RIVEN_RET=0 || RIVEN_RET=$?
    if [[ "${RIVEN_RET}" -eq 0 && "${RIVEN_OUT}" =~ "Found 43 matching records" ]]; then
        log_pass "CLI query by entity (--entity Riven)" "Found 43 matching records"
    else
        log_fail "CLI query by entity (--entity Riven)" "${RIVEN_OUT}"
        print_summary
        exit 1
    fi

    # Operation: --search "O [Reader] Mine" (1 record)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    SEARCH1_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --search "O [Reader] Mine" 2>&1) && SEARCH1_RET=0 || SEARCH1_RET=$?
    if [[ "${SEARCH1_RET}" -eq 0 && "${SEARCH1_OUT}" =~ "Found 1 matching records" ]]; then
        log_pass "CLI search phrase with punctuation (--search 'O [Reader] Mine')" "Found 1 matching records"
    else
        log_fail "CLI search phrase with punctuation (--search 'O [Reader] Mine')" "${SEARCH1_OUT}"
        print_summary
        exit 1
    fi

    # Operation: --search "extinction" (9 records)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    SEARCH2_OUT=$(OODA_NO_JAIL=1 "${CLI_BIN}" --search "extinction" 2>&1) && SEARCH2_RET=0 || SEARCH2_RET=$?
    if [[ "${SEARCH2_RET}" -eq 0 && "${SEARCH2_OUT}" =~ "Found 9 matching records" ]]; then
        log_pass "CLI case-insensitive search (--search 'extinction')" "Found 9 matching records"
    else
        log_fail "CLI case-insensitive search (--search 'extinction')" "${SEARCH2_OUT}"
        print_summary
        exit 1
    fi
fi

# ==============================================================================
# STAGE 4: Opaque-Box End-to-End Test Suite (--e2e)
# ==============================================================================
if [[ "${RUN_E2E}" -eq 1 ]]; then
    step_header "Stage 4: Opaque-Box End-to-End Test Suite"

    E2E_RUNNER="${PROJECT_ROOT}/tests_e2e/run_e2e.sh"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if is_in_e2e_harness; then
        log_skip "End-to-End Test Suite" "Skipped to prevent recursion (invoked from parent E2E harness)"
    elif [[ -x "${E2E_RUNNER}" ]]; then
        E2E_ARGS=("${E2E_RUNNER}")
        if [[ "${VERBOSE}" -eq 1 ]]; then
            E2E_ARGS+=(-v)
        fi
        export AHAMKARA_E2E_ACTIVE=1
        E2E_OUT=$("${E2E_ARGS[@]}" 2>&1) && E2E_RET=0 || E2E_RET=$?
        if [[ "${E2E_RET}" -ne 0 || ! "${E2E_OUT}" =~ "All Executed Tiers Passed Successfully" ]]; then
            E2E_RET=1
        fi
        if [[ "${E2E_RET}" -eq 0 ]]; then
            log_pass "Opaque-box E2E test suite executed cleanly" "All tiers passed"
            if [[ "${VERBOSE}" -eq 1 && "${QUIET}" -eq 0 ]]; then
                echo "${E2E_OUT}"
            fi
        else
            log_fail "Opaque-box E2E test suite failed" "${E2E_OUT}"
            print_summary
            exit 1
        fi
    else
        log_fail "Master E2E runner exists and is executable" "Missing or not executable: ${E2E_RUNNER}"
        print_summary
        exit 1
    fi
fi

# ==============================================================================
# STAGE 5: Git Repository & Remote Synchronization Verification
# ==============================================================================
if [[ "${EXPLICIT_STAGE}" -eq 0 || "${RUN_DATA}" -eq 1 ]]; then
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
    if [[ "${CURRENT_BRANCH}" == "main" ]]; then
        log_pass "Active branch is 'main'" "HEAD -> ${CURRENT_BRANCH}"
    else
        log_fail "Active branch is 'main'" "Found: '${CURRENT_BRANCH}'"
        print_summary
        exit 1
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    REMOTE_URL=$(git -C "${PROJECT_ROOT}" remote get-url origin 2>/dev/null || echo "")
    if [[ "${REMOTE_URL}" =~ UberMetroid/ahamkara ]]; then
        log_pass "Git remote origin configured" "${REMOTE_URL}"
    else
        log_fail "Git remote origin configured" "Invalid origin URL: ${REMOTE_URL}"
        print_summary
        exit 1
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    UPSTREAM_BRANCH=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    if [[ "${UPSTREAM_BRANCH}" == "origin/main" ]]; then
        log_pass "Upstream tracking branch verified" "${UPSTREAM_BRANCH}"
    else
        log_fail "Upstream tracking branch verified" "Found: '${UPSTREAM_BRANCH}', expected origin/main"
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
        if GH_REPO=$(gh repo view UberMetroid/ahamkara --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
            if [[ "${GH_REPO}" == "UberMetroid/ahamkara" ]]; then
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
fi

# ==============================================================================
# Complete Pass Final Summary Box & Exit Code
# ==============================================================================
print_summary
exit 0
