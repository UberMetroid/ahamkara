"""Structural checks: file existence, JSONL syntax, counts, uniqueness.

Mixin for CorpusValidator — methods rely on self.reporter / self.records /
self.jsonl_lines / self.corpus_path / self.categories_dir.
"""

import json


class StructureChecks:
    """File existence, JSONL syntax/formatting, counts, uniqueness, 9-field schema."""

    # --------------------------------------------------------------------------
    # 1. File Existence
    # --------------------------------------------------------------------------
    def validate_file_existence(self) -> bool:
        ok = True
        if self.corpus_path.is_file() and self.corpus_path.stat().st_size > 0:
            self.reporter.pass_check("VAL-FILE-01", "Canonical JSONL corpus exists and non-empty", str(self.corpus_path))
        else:
            self.reporter.fail_check("VAL-FILE-01", "Canonical JSONL corpus exists and non-empty", f"Missing or empty: {self.corpus_path}")
            ok = False

        if self.categories_dir.is_dir():
            self.reporter.pass_check("VAL-FILE-02", "Categories partition directory exists", str(self.categories_dir))
        else:
            self.reporter.fail_check("VAL-FILE-02", "Categories partition directory exists", f"Missing directory: {self.categories_dir}")
            ok = False

        return ok

    # --------------------------------------------------------------------------
    # 2. JSONL Syntax & Formatting (canonical archive)
    # --------------------------------------------------------------------------
    def validate_jsonl_syntax(self):
        try:
            with open(self.corpus_path, "rb") as f:
                raw_bytes = f.read()

            # Check trailing newline LF byte
            if raw_bytes.endswith(b"\n"):
                self.reporter.pass_check("VAL-JSONL-01", "JSONL ends with standard LF byte (0x0a)")
            else:
                self.reporter.fail_check("VAL-JSONL-01", "JSONL ends with standard LF byte (0x0a)", "Missing trailing newline")

            # Check for carriage returns (CR)
            if b"\r" in raw_bytes:
                cr_count = raw_bytes.count(b"\r")
                self.reporter.fail_check("VAL-JSONL-02", "JSONL contains zero Windows CRLF carriage returns", f"Found {cr_count} CR bytes")
            else:
                self.reporter.pass_check("VAL-JSONL-02", "JSONL contains zero Windows CRLF carriage returns")

            lines = raw_bytes.decode("utf-8").splitlines()
            self.jsonl_lines = lines

            line_parse_errors = 0
            len_bound_errors = 0
            escaped_quote_count = 0
            escaped_nl_count = 0
            records = []

            for idx, line in enumerate(lines, 1):
                if not line.strip():
                    self.reporter.fail_check("VAL-JSONL-03", "No blank lines in JSONL archive", f"Line {idx} is empty")
                    continue

                if len(line) < 100 or len(line) > 102400:
                    len_bound_errors += 1

                if '\\"' in line:
                    escaped_quote_count += 1
                if "\\n" in line:
                    escaped_nl_count += 1

                try:
                    obj = json.loads(line)
                    if not isinstance(obj, dict):
                        line_parse_errors += 1
                    else:
                        records.append(obj)
                except Exception:
                    line_parse_errors += 1

            self.records = records

            if line_parse_errors == 0:
                self.reporter.pass_check("VAL-JSONL-04", "Every JSONL line parses into a valid JSON object", f"{len(lines)} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-04", "Every JSONL line parses into a valid JSON object", f"{line_parse_errors} malformed lines")

            if len_bound_errors == 0:
                self.reporter.pass_check("VAL-JSONL-05", "All JSONL lines satisfy length boundaries (100 <= len <= 102400)")
            else:
                self.reporter.fail_check("VAL-JSONL-05", "All JSONL lines satisfy length boundaries (100 <= len <= 102400)", f"{len_bound_errors} lines out of bounds")

            if escaped_quote_count > 0:
                self.reporter.pass_check("VAL-JSONL-06", "JSONL archive contains escaped quotes", f"{escaped_quote_count} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-06", "JSONL archive contains escaped quotes", "Zero escaped quotes found")

            if escaped_nl_count > 0:
                self.reporter.pass_check("VAL-JSONL-07", "JSONL archive contains escaped newlines", f"{escaped_nl_count} lines")
            else:
                self.reporter.fail_check("VAL-JSONL-07", "JSONL archive contains escaped newlines", "Zero escaped newlines found")

        except Exception as e:
            self.reporter.fail_check("VAL-JSONL-00", "Read and parse JSONL file", str(e))

    # --------------------------------------------------------------------------
    # 3. Record Count Thresholds
    # --------------------------------------------------------------------------
    def validate_record_counts(self):
        count = len(self.records)

        if count >= 65:
            self.reporter.pass_check("VAL-CNT-01", "Corpus contains minimum 65 canonical entries", f"Count: {count}")
        else:
            self.reporter.fail_check("VAL-CNT-01", "Corpus contains minimum 65 canonical entries", f"Found {count}, minimum is 65")

        if count == len(self.jsonl_lines) and count > 0:
            self.reporter.pass_check("VAL-CNT-02", "Every JSONL line produced exactly one record", f"{count} records")
        else:
            self.reporter.fail_check("VAL-CNT-02", "Every JSONL line produced exactly one record", f"Records: {count}, lines: {len(self.jsonl_lines)}")

    # --------------------------------------------------------------------------
    # 4. Strict Uniqueness
    # --------------------------------------------------------------------------
    def validate_uniqueness(self):
        ids = [r.get("id") for r in self.records if "id" in r]
        duplicates = set([x for x in ids if ids.count(x) > 1])
        if len(duplicates) == 0:
            self.reporter.pass_check("VAL-UNIQ-01", "All record IDs are strictly unique (0 duplicates)", f"{len(ids)} unique IDs")
        else:
            self.reporter.fail_check("VAL-UNIQ-01", "All record IDs are strictly unique (0 duplicates)", f"Duplicate IDs detected: {duplicates}")
