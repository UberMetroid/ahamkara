"""Validation result tracking and reporting."""

from typing import Any, Dict, List

class ValidationReporter:
    def __init__(self, verbose: bool = False, quiet: bool = False):
        self.verbose = verbose
        self.quiet = quiet
        self.passed_checks: int = 0
        self.failed_checks: int = 0
        self.failures: List[Dict[str, Any]] = []

    def pass_check(self, check_id: str, description: str, detail: str = ""):
        self.passed_checks += 1
        if self.verbose and not self.quiet:
            msg = f"[PASS] {check_id}: {description}"
            if detail:
                msg += f" ({detail})"
            print(f"\033[0;32m{msg}\033[0m")

    def fail_check(self, check_id: str, description: str, error: str):
        self.failed_checks += 1
        self.failures.append({
            "id": check_id,
            "description": description,
            "error": error
        })
        if not self.quiet:
            print(f"\033[0;31m[FAIL] {check_id}: {description}\033[0m")
            print(f"       \033[0;31mReason: {error}\033[0m")

    def print_summary(self) -> int:
        if self.quiet:
            return 0 if self.failed_checks == 0 else 1

        total = self.passed_checks + self.failed_checks
        print("\n" + "=" * 60)
        print("          Ahamkara Corpus Validation Summary")
        print("=" * 60)
        print(f"Total Checks:   {total}")
        print(f"\033[0;32mPassed:         {self.passed_checks}\033[0m")
        if self.failed_checks == 0:
            print(f"\033[0;32mFailed:         0\033[0m")
            print("\033[1;32mStatus:         PASSED (Corpus 100% Compliant)\033[0m")
            print("=" * 60 + "\n")
            return 0
        else:
            print(f"\033[0;31mFailed:         {self.failed_checks}\033[0m")
            print("\033[1;31mStatus:         FAILED\033[0m")
            print("=" * 60)
            print("\nFailure Details:")
            for i, f in enumerate(self.failures, 1):
                print(f"{i}. [{f['id']}] {f['description']}")
                print(f"   Error: {f['error']}")
            print()
            return 1
