# stage_e2e.sh — Stage 4: opaque-box end-to-end suite.
# Defines stage_e2e(); invoked by verify.sh when --e2e/--all.
stage_e2e() {
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
}
