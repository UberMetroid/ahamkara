# cli.sh — argument parsing, banner, and oodac toolchain discovery.
# Sourced by verify.sh; not executed directly.
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
