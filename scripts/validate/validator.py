"""CorpusValidator — composes structure, schema, and content check mixins."""

from pathlib import Path
from typing import Any, Dict, List

from .checks_content import ContentChecks
from .checks_schema import SchemaChecks
from .checks_structure import StructureChecks
from .reporter import ValidationReporter


class CorpusValidator(StructureChecks, SchemaChecks, ContentChecks):
    def __init__(self, corpus_path: Path, categories_dir: Path, reporter: ValidationReporter):
        self.corpus_path = corpus_path
        self.categories_dir = categories_dir
        self.reporter = reporter
        self.records: List[Dict[str, Any]] = []
        self.jsonl_lines: List[str] = []

    def run_all_validations(self, strict_canonical: bool = False) -> int:
        """Executes the complete validation pipeline."""
        if not self.validate_file_existence():
            return self.reporter.print_summary()

        self.validate_jsonl_syntax()
        self.validate_record_counts()
        self.validate_uniqueness()
        self.validate_record_schema()
        self.validate_canonical_checklist(strict=strict_canonical)
        self.validate_e2e_invariants()
        self.validate_category_partitions()

        return self.reporter.print_summary()
