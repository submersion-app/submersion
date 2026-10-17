#!/usr/bin/env python3
"""Unit tests for check_flutter_setup_retried.py."""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_flutter_setup_retried",
    os.path.join(_HERE, "check_flutter_setup_retried.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

# Three attempts: the first two may fail without failing the job, the last
# one may not, so an outage that outlasts every retry still turns the job red.
GREEN_ACTION = """\
name: Set up Flutter
description: flutter-action, retried
inputs:
  flutter-version:
    required: true
runs:
  using: composite
  steps:
    - name: Set up Flutter (attempt 1)
      id: first
      uses: subosito/flutter-action@v2
      continue-on-error: true
      with:
        flutter-version: ${{ inputs.flutter-version }}

    - name: Wait before retrying
      if: steps.first.outcome == 'failure'
      shell: bash
      run: sleep 30

    - name: Set up Flutter (attempt 2)
      id: second
      if: steps.first.outcome == 'failure'
      uses: subosito/flutter-action@v2
      continue-on-error: true
      with:
        flutter-version: ${{ inputs.flutter-version }}

    - name: Set up Flutter (attempt 3)
      if: steps.second.outcome == 'failure'
      uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ inputs.flutter-version }}
"""

# A single attempt is exactly the arrangement that failed main in run
# 36852093336: one curl timeout and the whole job is red.
RED_ONE_ATTEMPT = """\
runs:
  using: composite
  steps:
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ inputs.flutter-version }}
"""

# Without continue-on-error, the first failure ends the action there and the
# retries below it never run.
RED_FIRST_NOT_TOLERATED = GREEN_ACTION.replace(
    "      id: first\n      uses: subosito/flutter-action@v2\n"
    "      continue-on-error: true\n",
    "      id: first\n      uses: subosito/flutter-action@v2\n",
)

# continue-on-error on the last attempt swallows a real outage: the job goes
# on with no Flutter on the PATH and fails later, somewhere confusing.
RED_LAST_TOLERATED = GREEN_ACTION.replace(
    "      if: steps.second.outcome == 'failure'\n"
    "      uses: subosito/flutter-action@v2\n",
    "      if: steps.second.outcome == 'failure'\n"
    "      uses: subosito/flutter-action@v2\n"
    "      continue-on-error: true\n",
)

GREEN_WORKFLOW = """\
name: CI/CD
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      # Retried: subosito/flutter-action is wrapped by the local action.
      - uses: ./.github/actions/setup-flutter
        with:
          flutter-version: '3.44.0'
"""

RED_WORKFLOW = """\
name: CI/CD
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
"""


class ActionTests(unittest.TestCase):
    def test_green_action_has_no_violations(self):
        self.assertEqual(guard.action_violations(GREEN_ACTION), [])

    def test_attempts_are_found_in_order(self):
        attempts = guard.flutter_attempts(GREEN_ACTION)
        self.assertEqual(len(attempts), 3)
        self.assertEqual(
            [guard.tolerates_failure(a) for a in attempts], [True, True, False]
        )

    def test_single_attempt_is_flagged(self):
        violations = guard.action_violations(RED_ONE_ATTEMPT)
        self.assertEqual(len(violations), 1)
        self.assertIn("1 attempt", violations[0])

    def test_no_attempt_is_flagged(self):
        violations = guard.action_violations("runs:\n  using: composite\n")
        self.assertEqual(len(violations), 1)
        self.assertIn("0 attempts", violations[0])

    def test_untolerated_early_attempt_is_flagged(self):
        violations = guard.action_violations(RED_FIRST_NOT_TOLERATED)
        self.assertEqual(len(violations), 1)
        self.assertIn("attempt 1", violations[0])

    def test_tolerated_final_attempt_is_flagged(self):
        violations = guard.action_violations(RED_LAST_TOLERATED)
        self.assertEqual(len(violations), 1)
        self.assertIn("final attempt", violations[0])

    def test_retry_gated_on_the_wrong_step_is_flagged(self):
        # A typo in the gate means the retry never runs, which is the same as
        # having no retry at all.
        text = GREEN_ACTION.replace(
            "      id: second\n      if: steps.first.outcome == 'failure'\n",
            "      id: second\n      if: steps.frist.outcome == 'failure'\n",
        )
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("attempt 2", violations[0])
        self.assertIn("steps.first.outcome", violations[0])

    def test_ungated_retry_is_flagged(self):
        text = GREEN_ACTION.replace(
            "      id: second\n      if: steps.first.outcome == 'failure'\n",
            "      id: second\n",
        )
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("attempt 2", violations[0])

    def test_attempt_without_id_cannot_gate_the_next(self):
        text = GREEN_ACTION.replace("      id: first\n", "")
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("attempt 1 has no id", violations[0])

    def test_gate_inside_an_expression_is_understood(self):
        text = GREEN_ACTION.replace(
            "      if: steps.second.outcome == 'failure'\n      uses:",
            "      if: ${{ steps.second.outcome == \"failure\" }}  # last\n      uses:",
        )
        self.assertEqual(guard.action_violations(text), [])

    def test_quoted_and_commented_keys_are_understood(self):
        text = GREEN_ACTION.replace(
            "continue-on-error: true\n", "continue-on-error: 'true'  # retry\n"
        ).replace(
            "uses: subosito/flutter-action@v2\n",
            "uses: 'subosito/flutter-action@v2'  # upstream\n",
        )
        self.assertEqual(guard.action_violations(text), [])

    def test_commented_out_attempt_does_not_count(self):
        text = RED_ONE_ATTEMPT + (
            "    # - uses: subosito/flutter-action@v2\n"
            "    #   continue-on-error: true\n"
        )
        self.assertIn("1 attempt", guard.action_violations(text)[0])

    def test_step_starting_with_uses_is_one_step(self):
        # `- uses:` opens the step on the same line as the key; the keys
        # below it still belong to that step.
        text = """\
runs:
  steps:
    - uses: subosito/flutter-action@v2
      id: first
      continue-on-error: true
    - uses: subosito/flutter-action@v2
      if: steps.first.outcome == 'failure'
"""
        self.assertEqual(guard.action_violations(text), [])

    def test_steps_end_at_a_shallower_key(self):
        # A list under a later, shallower key is not part of runs.steps.
        text = GREEN_ACTION + (
            "other:\n"
            "  - uses: subosito/flutter-action@v2\n"
        )
        self.assertEqual(len(guard.flutter_attempts(text)), 3)

    def test_steps_key_without_a_list_has_no_attempts(self):
        text = "runs:\n  steps:\n    name: not a list\n"
        self.assertEqual(guard.flutter_attempts(text), [])

    def test_keys_of_a_with_block_do_not_open_steps(self):
        attempts = guard.flutter_attempts(GREEN_ACTION)
        self.assertTrue(all("flutter-version" in "".join(a) for a in attempts))


class WorkflowTests(unittest.TestCase):
    def test_wrapped_workflow_has_no_direct_uses(self):
        self.assertEqual(guard.direct_uses(GREEN_WORKFLOW), [])

    def test_direct_use_is_reported_with_its_line(self):
        self.assertEqual(guard.direct_uses(RED_WORKFLOW), [8])

    def test_inline_step_use_is_reported(self):
        text = "    steps:\n      - uses: subosito/flutter-action@v2\n"
        self.assertEqual(guard.direct_uses(text), [2])

    def test_comment_naming_upstream_is_not_a_use(self):
        text = "      # uses: subosito/flutter-action@v2\n"
        self.assertEqual(guard.direct_uses(text), [])


class RepositoryTests(unittest.TestCase):
    def _repo(self, action, workflows):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root)
        if action is not None:
            os.makedirs(os.path.join(root, os.path.dirname(guard.ACTION_PATH)))
            with open(os.path.join(root, guard.ACTION_PATH), "w") as fh:
                fh.write(action)
        os.makedirs(os.path.join(root, guard.WORKFLOW_DIR))
        for name, text in workflows.items():
            with open(os.path.join(root, guard.WORKFLOW_DIR, name), "w") as fh:
                fh.write(text)
        return root

    def test_green_repository(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        self.assertEqual(guard.find_violations(root), [])

    def test_direct_use_in_any_workflow_is_flagged(self):
        root = self._repo(
            GREEN_ACTION,
            {"ci.yaml": GREEN_WORKFLOW, "build-all.yml": RED_WORKFLOW},
        )
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn(os.path.join(guard.WORKFLOW_DIR, "build-all.yml"), violations[0])
        self.assertIn(":8", violations[0])

    def test_direct_use_in_another_local_action_is_flagged(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        other = os.path.join(root, guard.ACTIONS_DIR, "setup-build")
        os.makedirs(other)
        with open(os.path.join(other, "action.yml"), "w") as fh:
            fh.write(RED_WORKFLOW)
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn(
            os.path.join(guard.ACTIONS_DIR, "setup-build", "action.yml") + ":8",
            violations[0],
        )

    def test_direct_use_in_a_nested_local_action_is_flagged(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        nested = os.path.join(root, guard.ACTIONS_DIR, "platform", "windows")
        os.makedirs(nested)
        with open(os.path.join(nested, "action.yaml"), "w") as fh:
            fh.write(RED_WORKFLOW)
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn(
            os.path.join(guard.ACTIONS_DIR, "platform", "windows", "action.yaml"),
            violations[0],
        )

    def test_non_workflow_files_are_ignored(self):
        root = self._repo(
            GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW, "notes.txt": RED_WORKFLOW}
        )
        self.assertEqual(guard.find_violations(root), [])

    def test_missing_action_is_flagged(self):
        root = self._repo(None, {"ci.yaml": GREEN_WORKFLOW})
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn(guard.ACTION_PATH, violations[0])

    def test_broken_action_is_flagged(self):
        root = self._repo(RED_ONE_ATTEMPT, {"ci.yaml": GREEN_WORKFLOW})
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn("1 attempt", violations[0])

    def test_missing_workflow_directory_is_flagged(self):
        root = self._repo(GREEN_ACTION, {})
        os.rmdir(os.path.join(root, guard.WORKFLOW_DIR))
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn("cannot list", violations[0])

    def test_main_passes_on_green(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["check", root])
        self.assertEqual(rc, 0)
        self.assertIn("PASS", buf.getvalue())

    def test_main_fails_on_red(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": RED_WORKFLOW})
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["check", root])
        self.assertEqual(rc, 1)
        self.assertIn("ci.yaml:8", buf.getvalue())

    def test_repository_is_retried(self):
        # The real thing: every workflow in this repository goes through the
        # retrying action, and the action really retries.
        self.assertEqual(guard.find_violations(os.path.dirname(_HERE)), [])


if __name__ == "__main__":
    unittest.main()
