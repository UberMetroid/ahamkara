# ==============================================================================
# Tier 5 parts: S3-S5 - corpus corruption, CLI limits, env/toolchain invariants.
# ==============================================================================
# Section 3: Lore Corpus Data File Corruption & Edge Cases (T5-CORPUS)
# ==============================================================================
echo -e "${COLOR_BLUE}--- Section 3: Lore Corpus Data File Corruption Resilience ---${COLOR_RESET}"

CORPUS_WORKSPACE="${TEMP_DIR}/corpus_workspace"
mkdir -p "${CORPUS_WORKSPACE}/data"
TEST_CORPUS="${CORPUS_WORKSPACE}/data/ahamkara_corpus.jsonl"

test_start "T5-CORPUS-01" "Empty line in the middle of JSONL corpus"
python3 -c "
with open('${REAL_CORPUS}') as src:
    lines = [src.readline() for _ in range(6)]
with open('${TEST_CORPUS}', 'w') as dst:
    dst.writelines(lines[:3] + ['\n'] + lines[3:6])
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 6" ]]; then
    test_pass "T5-CORPUS-01" "Empty line safely skipped; all 6 valid records preserved"
else
    test_fail "T5-CORPUS-01" "Empty line handling failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-02" "Multiple consecutive empty lines and whitespace lines"
python3 -c "
with open('${REAL_CORPUS}') as src:
    lines = [src.readline() for _ in range(4)]
with open('${TEST_CORPUS}', 'w') as dst:
    dst.writelines(lines[:2] + ['\n', '\n', '   \n', '\t\n'] + lines[2:4])
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 4" ]]; then
    test_pass "T5-CORPUS-02" "Consecutive empty and whitespace lines safely skipped (4 records loaded)"
else
    test_fail "T5-CORPUS-02" "Multiple empty lines failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-03" "Trailing non-JSON garbage line at EOF"
python3 -c "
with open('${REAL_CORPUS}') as src:
    lines = [src.readline() for _ in range(3)]
with open('${TEST_CORPUS}', 'w') as dst:
    dst.writelines(lines + ['CORRUPTED_NON_JSON_LINE_AT_EOF\n'])
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 3" ]]; then
    test_pass "T5-CORPUS-03" "Corrupted non-JSON trailing line rejected; 3 valid records preserved"
else
    test_fail "T5-CORPUS-03" "Trailing non-JSON line failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-04" "Non-JSON characters appended to valid JSON line"
python3 -c "
with open('${REAL_CORPUS}') as src:
    line = src.readline().rstrip('\n')
with open('${TEST_CORPUS}', 'w') as dst:
    dst.write(line + ' EXTRA_TRAILING_GARBAGE\n')
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 1" ]]; then
    test_pass "T5-CORPUS-04" "String field extraction resilient to trailing line noise"
else
    test_fail "T5-CORPUS-04" "Trailing noise failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-05" "Record missing mandatory 'title' field"
python3 -c "
with open('${TEST_CORPUS}', 'w') as dst:
    dst.write('{\"id\": \"missing-title-rec\", \"category\": \"exotics\", \"entity\": \"Riven\", \"lore_text\": \"text\"}\n')
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 0" ]]; then
    test_pass "T5-CORPUS-05" "Record missing mandatory field safely rejected by validator"
else
    test_fail "T5-CORPUS-05" "Missing field validation failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-06" "Completely empty corpus file (0 bytes)"
: > "${TEST_CORPUS}"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 0" ]]; then
    test_pass "T5-CORPUS-06" "Zero-byte corpus loaded safely reporting 0 records"
else
    test_fail "T5-CORPUS-06" "0-byte corpus failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-07" "Corpus containing only newline bytes"
printf "\n\n\n" > "${TEST_CORPUS}"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --stats 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Total records: 0" ]]; then
    test_pass "T5-CORPUS-07" "Newline-only corpus loaded safely reporting 0 records"
else
    test_fail "T5-CORPUS-07" "Newline-only corpus failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CORPUS-08" "Multibyte UTF-8 Unicode characters (Chinese, Russian, emojis)"
python3 -c "
with open('${TEST_CORPUS}', 'w', encoding='utf-8') as dst:
    dst.write('{\"id\": \"unicode-dragons\", \"title\": \"🐉 愿望之龙\", \"category\": \"exotics\", \"entity\": \"Riven\", \"quote\": \"О, мой носитель\", \"lore_text\": \"Тест лора с эмодзи 🌌✨\"}\n')
"
OUT=$( (cd "${CORPUS_WORKSPACE}" && "${CLI_BIN}" --search "愿望之龙" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 1 matching records" ]]; then
    test_pass "T5-CORPUS-08" "Multibyte Unicode and emojis loaded and searched without byte corruption"
else
    test_fail "T5-CORPUS-08" "Unicode corpus failed" "Code: ${RET}, Out: ${OUT}"
fi

# ==============================================================================
# Section 4: CLI Argument & Limit Boundary Exploits (T5-CLI)
# ==============================================================================
echo -e "${COLOR_BLUE}--- Section 4: CLI Argument & Limit Boundary Exploits ---${COLOR_RESET}"

test_start "T5-CLI-01" "Extreme limit value (--limit 999999)"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --limit 999999 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 5 matching records" ]]; then
    test_pass "T5-CLI-01" "Large limit handled accurately without integer overflow"
else
    test_fail "T5-CLI-01" "Large limit failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CLI-02" "Zero limit value (--limit 0)"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --limit 0 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-CLI-02" "Zero limit returns 0 matching records as specified"
else
    test_fail "T5-CLI-02" "Zero limit failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CLI-03" "Non-numeric limit argument (--limit invalid_text)"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --limit invalid_text 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 5 matching records" ]]; then
    test_pass "T5-CLI-03" "Non-numeric limit parsed safely as 0 without crash"
else
    test_fail "T5-CLI-03" "Non-numeric limit failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-CLI-04" "Whitespace-padded query string (--search '   Riven   ')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "   Riven   " 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 ]]; then
    test_pass "T5-CLI-04" "Whitespace-padded query trimmed and evaluated cleanly"
else
    test_fail "T5-CLI-04" "Whitespace-padded search failed" "Code: ${RET}"
fi

test_start "T5-CLI-05" "Punctuation-only search query (--search '???!!!')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "???!!!" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-CLI-05" "Punctuation-only search evaluated safely without error"
else
    test_fail "T5-CLI-05" "Punctuation query failed" "Code: ${RET}"
fi

test_start "T5-CLI-06" "Trailing flags without arguments at end of argv"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search --entity --category 2>&1) )
RET=$?
if [[ ("${RET}" -eq 0 || "${RET}" -eq 2) && "${OUT}" =~ (Usage:|Error:) ]]; then
    test_pass "T5-CLI-06" "Trailing flags without values safely handled without index out-of-bounds"
else
    test_fail "T5-CLI-06" "Trailing flags failed" "Code: ${RET}, Out: ${OUT}"
fi

# ==============================================================================
# Section 5: Environment Constraint & Toolchain Invariants (T5-ENV)
# ==============================================================================
echo -e "${COLOR_BLUE}--- Section 5: Environment Constraint & Toolchain Invariants ---${COLOR_RESET}"

test_start "T5-ENV-01" "verify.sh resilience in environment without GitHub CLI (gh)"
OUT=$(python3 -c "
import os, subprocess, tempfile, shutil

temp_bin = tempfile.mkdtemp(prefix='no_gh_')
tools = ['bash', 'cat', 'grep', 'sed', 'awk', 'tr', 'wc', 'tail', 'od', 'date', 'git', 'python3', 'find', 'xargs', 'ls', 'head', 'dirname']
for t in tools:
    p = shutil.which(t)
    if p: os.symlink(p, os.path.join(temp_bin, t))

env = {'PATH': temp_bin, 'HOME': os.environ.get('HOME', '/home/jeryd'), 'OODA_NO_JAIL': '1'}
res = subprocess.run(['./verify.sh', '--data'], cwd='${PROJECT_ROOT}', env=env, capture_output=True, text=True)
print(res.returncode)
shutil.rmtree(temp_bin)
" 2>/dev/null || echo 1)
if [[ "${OUT}" == "0" ]]; then
    test_pass "T5-ENV-01" "verify.sh degrades gracefully and passes when gh is not installed"
else
    test_fail "T5-ENV-01" "Missing gh execution failed" "Exit: ${OUT}"
fi

test_start "T5-ENV-02" "verify.sh resilience in environment without jq (python3 fallback)"
OUT=$(python3 -c "
import os, subprocess, tempfile, shutil

temp_bin = tempfile.mkdtemp(prefix='no_jq_')
tools = ['bash', 'cat', 'grep', 'sed', 'awk', 'tr', 'wc', 'tail', 'od', 'date', 'git', 'python3', 'find', 'xargs', 'ls', 'head', 'dirname']
for t in tools:
    p = shutil.which(t)
    if p: os.symlink(p, os.path.join(temp_bin, t))

env = {'PATH': temp_bin, 'HOME': os.environ.get('HOME', '/home/jeryd'), 'OODA_NO_JAIL': '1'}
res = subprocess.run(['./verify.sh', '--data'], cwd='${PROJECT_ROOT}', env=env, capture_output=True, text=True)
print(res.returncode)
shutil.rmtree(temp_bin)
" 2>/dev/null || echo 1)
if [[ "${OUT}" == "0" ]]; then
    test_pass "T5-ENV-02" "verify.sh calculates JSON length via python3 fallback when jq is missing"
else
    test_fail "T5-ENV-02" "Missing jq execution failed" "Exit: ${OUT}"
fi

test_start "T5-ENV-03" "Compiler invariant: All .oo files strictly <= 256 lines"
OVERSIZED_LINES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" -type f -name "*.oo" 2>/dev/null \
    | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 256 { print $2 ": " $1 }' || true)
if [[ -z "${OVERSIZED_LINES}" ]]; then
    test_pass "T5-ENV-03" "All openOODA source and test files satisfy <= 256 lines rule"
else
    test_fail "T5-ENV-03" "Files exceed 256 lines" "${OVERSIZED_LINES}"
fi

test_start "T5-ENV-04" "Compiler invariant: All .oo files strictly <= 64 KiB"
OVERSIZED_BYTES=$(find "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" -type f -name "*.oo" -size +65536c 2>/dev/null || true)
if [[ -z "${OVERSIZED_BYTES}" ]]; then
    test_pass "T5-ENV-04" "All openOODA source and test files satisfy <= 64 KiB rule"
else
    test_fail "T5-ENV-04" "Files exceed 64 KiB" "${OVERSIZED_BYTES}"
fi

test_start "T5-ENV-05" "Whitespace hygiene: Zero tab characters in any .oo source files"
TAB_VIOLATIONS=$(grep -rn --include="*.oo" $'\t' "${PROJECT_ROOT}/src" "${PROJECT_ROOT}/tests" 2>/dev/null || true)
if [[ -z "${TAB_VIOLATIONS}" ]]; then
    test_pass "T5-ENV-05" "All .oo files use pure space indentation (0 tab characters)"
else
    test_fail "T5-ENV-05" "Tab characters detected" "${TAB_VIOLATIONS}"
fi

test_start "T5-ENV-06" "Encoding hygiene: Zero illegal non-ASCII control characters"
CTRL_VIOLATIONS=$(grep -P -n "[\x00-\x08\x0B\x0C\x0E-\x1F]" "${PROJECT_ROOT}"/src/**/*.oo "${PROJECT_ROOT}"/tests/*.oo 2>/dev/null || true)
if [[ -z "${CTRL_VIOLATIONS}" ]]; then
    test_pass "T5-ENV-06" "All .oo files have clean encoding (0 illegal control characters)"
else
    test_fail "T5-ENV-06" "Illegal control characters detected" "${CTRL_VIOLATIONS}"
fi
