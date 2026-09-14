# stage_corpus.sh — Stage 1: lore corpus schema & canonical integrity.
# Defines stage_corpus(); invoked by verify.sh when --data/--all.

stage_corpus() {
    step_header "Stage 1: Lore Corpus Schema & Canonical Integrity"

    CORPUS_JSONL="${PROJECT_ROOT}/data/ahamkara_corpus.jsonl"
    CATEGORIES_DIR="${PROJECT_ROOT}/data/categories"
    VALIDATOR_PY="${PROJECT_ROOT}/scripts/validate_corpus.py"
    EXPECTED_COUNT=84

    # 1. Canonical archive existence and non-empty check
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "${CORPUS_JSONL}" && -s "${CORPUS_JSONL}" ]]; then
        log_pass "Canonical corpus JSONL exists and is non-empty" "data/ahamkara_corpus.jsonl"
    else
        log_fail "Canonical corpus JSONL exists and is non-empty" "Missing or empty: ${CORPUS_JSONL}"
        print_summary
        exit 1
    fi

    # 2. Category partition files (JSONL)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    EXPECTED_PARTITIONS=("exotics.jsonl" "great_hunt.jsonl" "riven.jsonl" "taranis.jsonl" "wishes.jsonl")
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

    # 3. Canonical record count
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    JSONL_LINES=$(wc -l < "${CORPUS_JSONL}" | tr -d ' ')
    if [[ "${JSONL_LINES}" -eq "${EXPECTED_COUNT}" ]]; then
        log_pass "Canonical record count verified" "exactly ${EXPECTED_COUNT} records in JSONL"
    else
        log_fail "Canonical record count" "JSONL: ${JSONL_LINES}, expected: ${EXPECTED_COUNT}"
        print_summary
        exit 1
    fi

    # 4. Strict UNIX LF byte validation (0 CR characters)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CR_TOTAL=0
    cr_master_jsonl=$(tr -d -c '\r' < "${CORPUS_JSONL}" | wc -c | tr -d ' ')
    CR_TOTAL=$((CR_TOTAL + cr_master_jsonl))

    for cat_file in "${CATEGORIES_DIR}"/*.jsonl; do
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

    for entity in Riven Taranis Hefnd Huginn Muninn; do
        if grep -q "\"entity\":\s*\[[^]]*\"${entity}\"" "${CORPUS_JSONL}"; then
            [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Entity: ${entity} confirmed"
        else
            log_fail "Canonical checklist item" "Entity '${entity}' missing from corpus"
            CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
        fi
    done

    for rid in exotic-skull-of-dire-ahamkara exotic-young-ahamkaras-spine wish-wall-fifteenth-wish; do
        if grep -q "\"id\":\s*\"${rid}\"" "${CORPUS_JSONL}"; then
            [[ "${VERBOSE}" -eq 1 ]] && log_info "Canonical Item: ${rid} confirmed"
        else
            log_fail "Canonical checklist item" "'${rid}' missing from corpus"
            CANONICAL_ERRORS=$((CANONICAL_ERRORS + 1))
        fi
    done

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
            log_pass "Python corpus semantic validator (scripts/validate_corpus.py --strict)" "all checks passed"
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
}
