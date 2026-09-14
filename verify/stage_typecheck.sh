# stage_typecheck.sh — Stage 2: openOODA invariants & oodac typechecking.
# Defines stage_typecheck(); invoked by verify.sh when --check/--all.
stage_typecheck() {
# ==============================================================================
# STAGE 2: openOODA Compiler Typechecking & File Invariants (--check)
# ==============================================================================

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
    ret=0
    out=$("${OODA_COMPILER}" check "${oo_file}" 2>&1) || ret=$?
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

}
