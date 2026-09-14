# ==============================================================================
# Tier 5 parts: S1-S2 - shell injection resilience, REPL stdin fuzzing.
# ==============================================================================
# Section 1: Shell Injection & Metacharacter Boundary Resilience (T5-INJ)
# ==============================================================================
echo -e "${COLOR_BLUE}--- Section 1: Shell Injection & Metacharacter Resilience ---${COLOR_RESET}"

test_start "T5-INJ-01" "Semicolon command chaining attempt (--search '; ls -la; echo INJECTED')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "; ls -la; echo INJECTED" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-01" "Semicolon metacharacters handled as literal search query"
else
    test_fail "T5-INJ-01" "Semicolon query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-02" "Pipe redirection operator attempt (--search '| cat /etc/passwd')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "| cat /etc/passwd" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-02" "Pipe metacharacter handled as literal search query"
else
    test_fail "T5-INJ-02" "Pipe query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-03" "Subshell expansion syntax attempt (--search '\$(whoami)')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search '$(whoami)' 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-03" "Subshell token handled as literal search query"
else
    test_fail "T5-INJ-03" "Subshell query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-04" "Backtick execution syntax attempt (--search '\`id\`')"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search '`id`' 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-04" "Backtick token handled as literal search query"
else
    test_fail "T5-INJ-04" "Backtick query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-05" "Redirection write attempt (--search '> /tmp/adversarial_pwn_test.txt')"
PWN_FILE="/tmp/adversarial_pwn_test.txt"
rm -f "${PWN_FILE}"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "> ${PWN_FILE}" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && ! -f "${PWN_FILE}" ]]; then
    test_pass "T5-INJ-05" "Redirection token handled as literal search query without writing file"
else
    test_fail "T5-INJ-05" "Redirection token failed" "File created or error code: ${RET}"
fi

test_start "T5-INJ-06" "Extreme query length stress (1,000 characters)"
LONG_Q1=$(python3 -c 'print("A" * 1000)')
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "${LONG_Q1}" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-06" "1,000 character search query handled safely without buffer overflow"
else
    test_fail "T5-INJ-06" "1,000 char query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-07" "Extreme query length stress (5,000 characters)"
LONG_Q2=$(python3 -c 'print("A" * 5000)')
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "${LONG_Q2}" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-07" "5,000 character search query handled safely without stack overflow"
else
    test_fail "T5-INJ-07" "5,000 char query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-08" "ANSI terminal escape sequence injection (\x1b[31;1mRED\x1b[0m)"
ANSI_Q=$'\x1b[31;1mRED\x1b[0m'
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search "${ANSI_Q}" 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-08" "ANSI escape sequences handled safely as raw string input"
else
    test_fail "T5-INJ-08" "ANSI query failed" "Code: ${RET}, Out: ${OUT}"
fi

test_start "T5-INJ-09" "Unbalanced quotes in query string (\"\"\"\"\"\")"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search '""""""' 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 ]]; then
    test_pass "T5-INJ-09" "Unbalanced quotes handled safely without parser crash"
else
    test_fail "T5-INJ-09" "Unbalanced quotes failed" "Code: ${RET}"
fi

test_start "T5-INJ-10" "Deeply nested paracausal brackets in query string"
OUT=$( (cd "${TEMP_DIR}" && "${CLI_BIN}" --search '[[[[[[[O [Reader] Mine]]]]]]]' 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Found 0 matching records" ]]; then
    test_pass "T5-INJ-10" "Deeply nested brackets handled safely without regex or parser fault"
else
    test_fail "T5-INJ-10" "Nested brackets failed" "Code: ${RET}"
fi

# ==============================================================================
# Section 2: REPL Pipeline & Rapid Stdin Fuzzing (T5-REPL)
# ==============================================================================
echo -e "${COLOR_BLUE}--- Section 2: REPL Pipeline & Rapid Stdin Fuzzing ---${COLOR_RESET}"

test_start "T5-REPL-01" "Rapid newline stream piped to --interactive"
OUT=$(printf "\n\n\n\n\n" | (cd "${TEMP_DIR}" && "${CLI_BIN}" --interactive 2>&1))
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Interactive REPL session ready" ]]; then
    test_pass "T5-REPL-01" "Rapid empty newlines handled safely without hanging"
else
    test_fail "T5-REPL-01" "Rapid newlines failed" "Code: ${RET}"
fi

test_start "T5-REPL-02" "Rapid command flood with unknown tokens"
FLOOD_INPUT="search\nfind\ncategory\nentity\nunknown_xyz\nstats\nquit\n"
OUT=$(printf "%b" "${FLOOD_INPUT}" | (cd "${TEMP_DIR}" && "${CLI_BIN}" --interactive 2>&1))
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Interactive REPL session ready" ]]; then
    test_pass "T5-REPL-02" "Command flood handled safely without pipeline corruption"
else
    test_fail "T5-REPL-02" "Command flood failed" "Code: ${RET}"
fi

test_start "T5-REPL-03" "SQL injection syntax in stdin pipeline"
SQL_INPUT=$'\' OR 1=1 --\n" OR ""="\nquit\n'
OUT=$(printf "%s" "${SQL_INPUT}" | (cd "${TEMP_DIR}" && "${CLI_BIN}" --interactive 2>&1))
RET=$?
if [[ "${RET}" -eq 0 ]]; then
    test_pass "T5-REPL-03" "SQL syntax tokens in REPL stdin processed safely"
else
    test_fail "T5-REPL-03" "SQL stdin failed" "Code: ${RET}"
fi

test_start "T5-REPL-04" "Large buffer fuzzing (10,000 chars piped to stdin)"
LARGE_BUF=$(python3 -c 'print("A" * 10000 + "\nquit")')
OUT=$(printf "%s" "${LARGE_BUF}" | (cd "${TEMP_DIR}" && "${CLI_BIN}" --interactive 2>&1))
RET=$?
if [[ "${RET}" -eq 0 ]]; then
    test_pass "T5-REPL-04" "10,000 character stdin buffer handled without segfault"
else
    test_fail "T5-REPL-04" "Large buffer fuzzing failed" "Code: ${RET}"
fi

test_start "T5-REPL-05" "Rapid EOF termination (: | ./bin/ahamkara --interactive)"
OUT=$( : | (cd "${TEMP_DIR}" && "${CLI_BIN}" --interactive 2>&1) )
RET=$?
if [[ "${RET}" -eq 0 && "${OUT}" =~ "Interactive REPL session ready" ]]; then
    test_pass "T5-REPL-05" "Immediate EOF on stdin terminates cleanly"
else
    test_fail "T5-REPL-05" "Rapid EOF failed" "Code: ${RET}"
fi

# ==============================================================================
