#!/bin/bash
#
# The number of parallel test isolates for a local flutter test run, shared by
# hooks/pre-push and scripts/run_all_tests.sh. Source it, then call
# resolve_test_concurrency.

# The core count, at most 16 and at least 2. A fixed 6 left most of a modern
# laptop idle. Measured on an 18-core M5 Pro over a 388-file run, warm cache,
# alternating 6/16/6/16: 162.8/162.8s at 6 against 124.7/124.8s at 16, so 23%
# faster. 24 measured no better than 16, so 16 is the knee: the machine has
# only 6 performance cores, and the rest are efficiency cores.
default_test_concurrency() {
    local n
    n=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 6)
    case "$n" in
        ''|*[!0-9]*) n=6 ;;
    esac
    if [ "$n" -gt 16 ]; then n=16; fi
    if [ "$n" -lt 2 ]; then n=2; fi
    printf '%s' "$n"
}

# Prints TEST_CONCURRENCY when it is a positive whole number, read as decimal
# (08 is 8), and the default otherwise. An invalid value is reported on stderr
# rather than stopping the run: a mistyped tuning knob must never block a push.
resolve_test_concurrency() {
    local fallback value
    fallback="$(default_test_concurrency)"
    value="${TEST_CONCURRENCY:-}"
    if [ -z "$value" ]; then
        printf '%s' "$fallback"
        return
    fi
    case "$value" in
        *[!0-9]*) ;;
        *)
            if [ "$((10#$value))" -gt 0 ]; then
                printf '%s' "$((10#$value))"
                return
            fi
            ;;
    esac
    echo "Ignoring invalid TEST_CONCURRENCY='${value}'; using ${fallback}." >&2
    printf '%s' "$fallback"
}
