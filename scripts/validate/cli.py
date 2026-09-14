"""CLI entry point for the corpus validator."""

import argparse
import json
import sys
from pathlib import Path

from .reporter import ValidationReporter
from .validator import CorpusValidator


def main():
    parser = argparse.ArgumentParser(
        description="Ahamkara Lore Corpus Validator (Milestone 2 Acceptance Suite)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        default=Path("data/ahamkara_corpus.jsonl"),
        help="Path to canonical JSONL archive file",
    )
    parser.add_argument(
        "--categories-dir",
        type=Path,
        default=Path("data/categories"),
        help="Path to categories partition directory",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Enforce 100%% presence of all 83 checklist items (default: >=65 and E2E requirements)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Display verbose output for every passing check",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress normal progress; only emit failures and exit code",
    )
    parser.add_argument(
        "--json-report",
        type=Path,
        default=None,
        help="Optional path to output machine-readable JSON validation report",
    )

    args = parser.parse_args()

    reporter = ValidationReporter(verbose=args.verbose, quiet=args.quiet)
    validator = CorpusValidator(
        corpus_path=args.corpus,
        categories_dir=args.categories_dir,
        reporter=reporter,
    )

    exit_code = validator.run_all_validations(strict_canonical=args.strict)

    if args.json_report:
        report_data = {
            "exit_code": exit_code,
            "status": "PASSED" if exit_code == 0 else "FAILED",
            "passed_checks": reporter.passed_checks,
            "failed_checks": reporter.failed_checks,
            "total_checks": reporter.passed_checks + reporter.failed_checks,
            "failures": reporter.failures,
        }
        try:
            with open(args.json_report, "w", encoding="utf-8") as f:
                json.dump(report_data, f, indent=2)
        except Exception as e:
            print(f"Failed to write JSON report to {args.json_report}: {e}", file=sys.stderr)

    sys.exit(exit_code)
