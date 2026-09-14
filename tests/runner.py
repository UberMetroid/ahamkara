"""runner.py — Main E2E test runner for Ahamkara Synthetic Mind Ingress."""

import argparse
import sys
from pathlib import Path

# Add parent directory to sys.path to allow imports from tests package
test_dir = Path(__file__).resolve().parent
if str(test_dir.parent) not in sys.path:
    sys.path.insert(0, str(test_dir.parent))

from tests.common import TestContext, get_dist_dir, get_repo_root
from tests import (
    tier1_f1_f6,
    tier1_f7_f12,
    tier2_f1_f6,
    tier2_f7_f12,
    tier3_interactions,
    tier4_scenarios,
)

def parse_args():
    p = argparse.ArgumentParser(description="Ahamkara Synthetic Mind Ingress E2E Test Suite")
    p.add_argument("--tier", choices=["1", "2", "3", "4", "all"], default="all",
                   help="Run tests for a specific tier (default: all)")
    p.add_argument("--milestone", choices=["M1", "M2", "all"], default="all",
                   help="Filter features by target milestone (default: all)")
    p.add_argument("--dist", type=str, default=None,
                   help="Path to dist directory (default: <repo_root>/dist)")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="Verbose output showing every passed check")
    p.add_argument("-q", "--quiet", action="store_true",
                   help="Quiet output (only summary and failures)")
    return p.parse_args()

def main() -> int:
    args = parse_args()
    verbose = args.verbose and not args.quiet
    repo_root = get_repo_root()
    try:
        dist = get_dist_dir(args.dist)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    ctx = TestContext(milestone=args.milestone, verbose=verbose)
    run_tier = args.tier

    print("=" * 70)
    print(f"Ahamkara E2E Test Suite — Milestone Scope: {args.milestone} | Tier: {args.tier}")
    print(f"Target dist: {dist}")
    print("=" * 70)

    # Tier 1: Feature Coverage
    if run_tier in ("1", "all"):
        print("\n--- Tier 1: Feature Coverage (Features 1-12) ---")
        tier1_f1_f6.run(ctx, dist)
        tier1_f7_f12.run(ctx, dist, repo_root)

    # Tier 2: Boundary & Corner Cases
    if run_tier in ("2", "all"):
        print("\n--- Tier 2: Boundary & Corner Cases (Features 1-12) ---")
        tier2_f1_f6.run(ctx, dist)
        tier2_f7_f12.run(ctx, dist, repo_root)

    # Tier 3: Cross-Feature Interactions
    if run_tier in ("3", "all"):
        print("\n--- Tier 3: Cross-Feature Interactions ---")
        tier3_interactions.run(ctx, dist, repo_root)

    # Tier 4: Real-World Scenarios
    if run_tier in ("4", "all"):
        print("\n--- Tier 4: Real-World Scenarios ---")
        tier4_scenarios.run(ctx, dist, repo_root)

    print("\n" + "=" * 70)
    print(f"Results: {ctx.passed} passed, {ctx.failed} failed, {ctx.skipped} skipped")
    print("=" * 70)

    if ctx.failed > 0:
        print("\nFailures summary:")
        for r in ctx.results:
            if not r["ok"]:
                print(f"  FAILED [T{r['tier']}.F{r['feature']}] {r['name']}: {r['detail']}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
