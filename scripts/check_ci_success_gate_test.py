#!/usr/bin/env python3
"""Unit tests for check_ci_success_gate.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_ci_success_gate",
    os.path.join(_HERE, "check_ci_success_gate.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

# Every job reaches the gate, so a failure anywhere turns the required check red.
GREEN = """\
name: CI/CD
on:
  push:
    branches: [main]
concurrency:
  group: ${{ github.workflow }}
jobs:
  changes:
    name: Detect code changes
    runs-on: ubuntu-latest
  analyze:
    name: Analyze & Format
    runs-on: ubuntu-latest
  script-tests:
    name: Script Tests
    runs-on: ubuntu-latest
  pr-number:
    name: Record PR number
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
  ci-success:
    name: CI Success
    if: always()
    needs:
      - changes
      - analyze
      - script-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: python3 scripts/check_ci_success_gate.py
"""

# script-tests exists but never reaches the gate: it can fail while the required
# check stays green. This is the defect the guard exists to catch.
RED_UNGATED_JOB = GREEN.replace("      - script-tests\n", "")

# The inline flow-sequence spelling of needs must be understood too, otherwise
# rewriting the list in that style would silently disable the guard.
GREEN_INLINE_NEEDS = GREEN.replace(
    """    needs:
      - changes
      - analyze
      - script-tests
""",
    "    needs: [changes, analyze, script-tests]\n",
)

RED_NO_GATE_JOB = GREEN.replace("  ci-success:\n", "  something-else:\n")

# Trailing comments are valid YAML and carry no meaning. A parser that stops
# recognising a key because someone annotated it turns a comment edit into a
# CI failure, so every key this guard matches has to tolerate them.
GREEN_COMMENTED_KEYS = (
    GREEN.replace("jobs:\n", "jobs:  # the pipeline\n")
    .replace("    needs:\n", "    needs:  # every job below\n")
    .replace("      - analyze\n", "      - analyze  # lint and format\n")
)

GREEN_COMMENTED_INLINE_NEEDS = GREEN_INLINE_NEEDS.replace(
    "    needs: [changes, analyze, script-tests]\n",
    "    needs: [changes, analyze, script-tests]  # every job below\n",
)

RED_GATE_WITHOUT_NEEDS = """\
jobs:
  analyze:
    runs-on: ubuntu-latest
  ci-success:
    name: CI Success
    runs-on: ubuntu-latest
    steps:
      - run: python3 scripts/check_ci_success_gate.py
"""

# The guard runs only in a gated job, never in the gate itself. Dropping that
# job from `needs` would then make the guard advisory, so it could no longer
# report its own de-gating: exactly the self-concealing failure it exists to
# prevent. The gate has to run it too.
RED_GATE_DOES_NOT_RUN_GUARD = GREEN.replace(
    "      - run: python3 scripts/check_ci_success_gate.py\n", ""
)

# Deleting the step but leaving documentation behind must not read as running
# it. A guard that accepts a mention of its own filename as proof of execution
# is the false green it exists to prevent.
RED_GATE_ONLY_MENTIONS_GUARD_IN_COMMENT = GREEN.replace(
    "      - run: python3 scripts/check_ci_success_gate.py\n",
    "      # we used to run scripts/check_ci_success_gate.py here\n",
)

# A shell comment inside a run block is equally non-executing.
RED_GATE_MENTIONS_GUARD_IN_SHELL_COMMENT = GREEN.replace(
    "      - run: python3 scripts/check_ci_success_gate.py\n",
    """      - run: |
          # scripts/check_ci_success_gate.py used to run here
          echo done
""",
)

# The inline spelling with a trailing YAML comment still genuinely runs it.
GREEN_RUN_WITH_TRAILING_COMMENT = GREEN.replace(
    "      - run: python3 scripts/check_ci_success_gate.py\n",
    "      - run: python3 scripts/check_ci_success_gate.py  # self-hosting\n",
)

# So does the block-scalar spelling.
GREEN_RUN_AS_BLOCK_SCALAR = GREEN.replace(
    "      - run: python3 scripts/check_ci_success_gate.py\n",
    """      - run: |
          python3 scripts/check_ci_success_gate.py
""",
)


class ParserTests(unittest.TestCase):
    def test_job_ids_skip_non_job_top_level_keys(self):
        # `push` and `group` sit at the same indent as job ids but precede
        # `jobs:`, so keying off indentation alone would wrongly collect them.
        self.assertEqual(
            guard.job_ids(GREEN),
            ["changes", "analyze", "script-tests", "pr-number", "ci-success"],
        )

    def test_needs_parses_block_sequence(self):
        self.assertEqual(
            guard.gate_needs(GREEN), ["changes", "analyze", "script-tests"]
        )

    def test_needs_parses_inline_sequence(self):
        self.assertEqual(
            guard.gate_needs(GREEN_INLINE_NEEDS),
            ["changes", "analyze", "script-tests"],
        )

    def test_needs_is_none_when_gate_has_no_needs(self):
        self.assertIsNone(guard.gate_needs(RED_GATE_WITHOUT_NEEDS))

    def test_trailing_comments_do_not_hide_jobs_key(self):
        self.assertEqual(
            guard.job_ids(GREEN_COMMENTED_KEYS),
            ["changes", "analyze", "script-tests", "pr-number", "ci-success"],
        )

    def test_trailing_comments_do_not_hide_block_needs(self):
        self.assertEqual(
            guard.gate_needs(GREEN_COMMENTED_KEYS),
            ["changes", "analyze", "script-tests"],
        )

    def test_trailing_comments_do_not_hide_inline_needs(self):
        self.assertEqual(
            guard.gate_needs(GREEN_COMMENTED_INLINE_NEEDS),
            ["changes", "analyze", "script-tests"],
        )


class GuardTests(unittest.TestCase):
    def test_green_has_no_violations(self):
        self.assertEqual(guard.find_violations(GREEN), [])

    def test_inline_needs_green_has_no_violations(self):
        self.assertEqual(guard.find_violations(GREEN_INLINE_NEEDS), [])

    def test_gate_that_does_not_run_the_guard_is_flagged(self):
        violations = guard.find_violations(RED_GATE_DOES_NOT_RUN_GUARD)
        self.assertTrue(
            any(guard.GUARD_SCRIPT in v for v in violations),
            f"expected a violation naming {guard.GUARD_SCRIPT}: {violations}",
        )

    def test_gate_runs_guard_detects_the_step(self):
        self.assertTrue(guard.gate_runs_guard(GREEN))
        self.assertFalse(guard.gate_runs_guard(RED_GATE_DOES_NOT_RUN_GUARD))

    def test_yaml_comment_mentioning_the_guard_does_not_count(self):
        self.assertFalse(
            guard.gate_runs_guard(RED_GATE_ONLY_MENTIONS_GUARD_IN_COMMENT)
        )
        violations = guard.find_violations(RED_GATE_ONLY_MENTIONS_GUARD_IN_COMMENT)
        self.assertTrue(any(guard.GUARD_SCRIPT in v for v in violations))

    def test_shell_comment_mentioning_the_guard_does_not_count(self):
        self.assertFalse(
            guard.gate_runs_guard(RED_GATE_MENTIONS_GUARD_IN_SHELL_COMMENT)
        )

    def test_inline_run_with_trailing_comment_counts(self):
        self.assertTrue(guard.gate_runs_guard(GREEN_RUN_WITH_TRAILING_COMMENT))

    def test_block_scalar_run_counts(self):
        self.assertTrue(guard.gate_runs_guard(GREEN_RUN_AS_BLOCK_SCALAR))

    def test_guard_step_in_another_job_does_not_satisfy_the_gate(self):
        # Running it only in a gated job is the arrangement that cannot survive
        # a needs-list edit, so it must not count as the gate running it.
        text = RED_GATE_DOES_NOT_RUN_GUARD.replace(
            """  script-tests:
    name: Script Tests
    runs-on: ubuntu-latest
""",
            """  script-tests:
    name: Script Tests
    runs-on: ubuntu-latest
    steps:
      - run: python3 scripts/check_ci_success_gate.py
""",
        )
        self.assertIn("check_ci_success_gate.py", text)
        self.assertFalse(guard.gate_runs_guard(text))

    def test_commented_keys_have_no_violations(self):
        # Annotating a key must not be reported as "the gate has no needs".
        self.assertEqual(guard.find_violations(GREEN_COMMENTED_KEYS), [])
        self.assertEqual(guard.find_violations(GREEN_COMMENTED_INLINE_NEEDS), [])

    def test_ungated_job_is_flagged(self):
        violations = guard.find_violations(RED_UNGATED_JOB)
        self.assertTrue(any("script-tests" in v for v in violations))

    def test_exempt_job_is_not_required_to_be_gated(self):
        # pr-number only uploads the PR number for the coverage upload; it is
        # deliberately outside the gate and must not be reported.
        self.assertEqual(
            [v for v in guard.find_violations(GREEN) if "pr-number" in v], []
        )

    def test_gate_never_requires_itself(self):
        self.assertEqual(
            [v for v in guard.find_violations(GREEN) if "ci-success" in v], []
        )

    def test_missing_gate_job_is_flagged(self):
        violations = guard.find_violations(RED_NO_GATE_JOB)
        self.assertTrue(any(guard.GATE_JOB in v for v in violations))

    def test_gate_without_needs_is_flagged(self):
        violations = guard.find_violations(RED_GATE_WITHOUT_NEEDS)
        self.assertTrue(any("needs" in v for v in violations))

    def test_needs_entry_for_unknown_job_is_flagged(self):
        # A renamed or deleted job left behind in `needs` makes the whole
        # workflow invalid, so catch it here rather than at run time.
        text = GREEN.replace("      - analyze\n", "      - analyse\n")
        violations = guard.find_violations(text)
        self.assertTrue(any("analyse" in v for v in violations))


class FileTests(unittest.TestCase):
    def _write(self, text):
        fd, path = tempfile.mkstemp(suffix=".yaml")
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        self.addCleanup(os.unlink, path)
        return path

    def test_check_file_ok(self):
        ok, _ = guard.check_file(self._write(GREEN))
        self.assertTrue(ok)

    def test_pass_message_acknowledges_exemptions(self):
        # EXEMPT_JOBS are allowed outside the gate, so a bare "every job
        # reaches the gate" would overstate what was verified.
        _, lines = guard.check_file(self._write(GREEN))
        self.assertTrue(
            any("non-exempt" in line for line in lines), lines
        )

    def test_check_file_red(self):
        ok, _ = guard.check_file(self._write(RED_UNGATED_JOB))
        self.assertFalse(ok)

    def test_main_passes_on_green(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["check", self._write(GREEN)])
        self.assertEqual(rc, 0)

    def test_main_fails_on_red(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["check", self._write(RED_UNGATED_JOB)])
        self.assertEqual(rc, 1)
        self.assertIn("script-tests", buf.getvalue())

    def test_main_reports_unreadable_file(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["check", os.path.join(_HERE, "no-such-file.yaml")])
        self.assertEqual(rc, 1)
        self.assertIn("ERROR", buf.getvalue())

    def test_repository_workflow_is_gated(self):
        # The real thing: guards against this file drifting out of date.
        path = os.path.join(
            os.path.dirname(_HERE), ".github", "workflows", "ci.yaml"
        )
        ok, lines = guard.check_file(path)
        self.assertTrue(ok, "\n".join(lines))


if __name__ == "__main__":
    unittest.main()
