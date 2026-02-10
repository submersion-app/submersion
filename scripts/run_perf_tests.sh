#!/bin/bash
set -euo pipefail

echo "========================================"
echo " Submersion Performance Test Suite"
echo "========================================"
echo ""

# Track overall pass/fail
FAILURES=0

run_benchmark() {
  local name="$1"
  local file="$2"

  echo "--- $name ---"
  if output=$(flutter test "$file" --reporter expanded 2>&1); then
    # Extract timing lines (lines with "ms" printed by our tests)
    echo "$output" | grep -E '^\s+(getDive|batch|getAll|getSites|search|Single|Batch|WARNING)' || true
    # Extract pass/fail summary
    local passed
    passed=$(echo "$output" | grep -oE '\+[0-9]+' | tail -1 | tr -d '+')
    echo "  Result: $passed tests passed"
  else
    FAILURES=$((FAILURES + 1))
    echo "$output" | grep -E '(FAIL|Expected|Actual|getDive|batch|getAll|getSites|search|Single|Batch|WARNING)' || true
    echo "  Result: FAILED"
  fi
  echo ""
}

run_benchmark "Dive Repository Benchmarks (5000 dives)" \
  "test/performance/dive_repository_perf_test.dart"

run_benchmark "Site Repository Benchmarks (2000 sites)" \
  "test/performance/site_repository_perf_test.dart"

run_benchmark "Profile Loading Benchmarks" \
  "test/performance/profile_loading_perf_test.dart"

echo "========================================"
if [ "$FAILURES" -eq 0 ]; then
  echo " All benchmarks passed."
else
  echo " $FAILURES benchmark suite(s) had failures."
  exit 1
fi
echo "========================================"
