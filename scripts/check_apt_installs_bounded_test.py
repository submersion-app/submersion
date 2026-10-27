#!/usr/bin/env python3
"""Unit tests for check_apt_installs_bounded.py."""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_apt_installs_bounded",
    os.path.join(_HERE, "check_apt_installs_bounded.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

# The shape of the real action: the update and the download run under a time
# limit inside a retry loop, and the install that follows may not download.
GREEN_ACTION = """\
name: Install apt packages
runs:
  using: composite
  steps:
    - name: Download and install
      shell: bash
      run: |
        packages=($PACKAGES)
        sudo apt-get clean
        attempts=3
        for attempt in $(seq 1 "$attempts"); do
          if { [ "$attempt" -eq 1 ] && [ -e "$lists_fetched" ]; } \\
            || sudo timeout --kill-after=10 60 apt-get update; then
            if sudo timeout --kill-after=10 120 \\
              apt-get install -y --download-only "${packages[@]}"; then
              break
            fi
          fi
          sleep 10
        done
        sudo apt-get install -y --no-download "${packages[@]}"

    - name: Collect downloaded packages
      shell: bash
      run: |
        # autoclean never reaches the network.
        sudo apt-get autoclean
"""

GREEN_WORKFLOW = """\
name: CI/CD
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      # Not `sudo apt-get install -y clang`: the local action bounds it.
      - name: Install Linux dependencies
        uses: ./.github/actions/install-apt-packages
        with:
          packages: clang cmake
"""

# The arrangement run 40535224550 timed out in: nothing bounds the download.
RED_WORKFLOW = """\
name: CI/CD
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \\
            clang \\
            cmake
"""

UNCACHED_STEP = """\
name: Build all
jobs:
  build-linux:
    runs-on: ubuntu-24.04
    steps:
      - name: Install Linux dependencies
        uses: ./.github/actions/install-apt-packages
        with:
          cache: false
          packages: clang
      - name: Build
        run: flutter build linux
"""


class ActionTests(unittest.TestCase):
    def test_green_action_has_no_violations(self):
        self.assertEqual(guard.action_violations(GREEN_ACTION), [])

    def test_unbounded_update_is_flagged(self):
        text = GREEN_ACTION.replace(
            "sudo timeout --kill-after=10 60 apt-get update", "sudo apt-get update"
        )
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("apt-get update", violations[0])

    def test_unbounded_download_is_flagged(self):
        text = GREEN_ACTION.replace(
            "if sudo timeout --kill-after=10 120 \\\n", "if sudo \\\n"
        )
        violations = guard.action_violations(text)
        self.assertIn("apt-get install", violations[0])
        self.assertTrue(any("never downloads" in v for v in violations))

    def test_install_that_may_download_is_flagged(self):
        # Without --no-download the final install would fetch, unbounded,
        # whatever the bounded download left out.
        text = GREEN_ACTION.replace(" --no-download", "")
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("without a time limit", violations[0])

    def test_time_limit_around_the_whole_install_is_flagged(self):
        # A limit that can kill dpkg mid-unpack leaves a broken package
        # database for the retry to trip over.
        text = GREEN_ACTION.replace(
            "apt-get install -y --download-only", "apt-get install -y"
        )
        violations = guard.action_violations(text)
        self.assertTrue(any("dpkg" in v for v in violations))
        self.assertTrue(any("never downloads" in v for v in violations))

    def test_single_attempt_is_flagged(self):
        text = GREEN_ACTION.replace("attempts=3", "attempts=1")
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("1 attempt", violations[0])

    def test_missing_retry_loop_is_flagged(self):
        text = GREEN_ACTION.replace("        attempts=3\n", "")
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("retry", violations[0])

    def test_download_outside_the_retry_loop_is_flagged(self):
        # attempts=3 alone retries nothing: the download has to sit in the loop.
        text = GREEN_ACTION.replace(
            '        for attempt in $(seq 1 "$attempts"); do\n', "        if true; then\n"
        ).replace("        done\n", "        fi\n")
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("not inside", violations[0])

    def test_inner_loop_does_not_close_the_retry_loop(self):
        text = GREEN_ACTION.replace(
            "          sleep 10\n",
            "          for p in a b; do\n            echo $p\n          done\n"
            "          sleep 10\n",
        )
        self.assertEqual(guard.action_violations(text), [])

    def test_other_network_subcommand_needs_a_limit(self):
        text = GREEN_ACTION + "        sudo apt-get dist-upgrade -y\n"
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("apt-get dist-upgrade", violations[0])

    def test_commented_out_call_is_ignored(self):
        text = GREEN_ACTION + "        # sudo apt-get install -y clang\n"
        self.assertEqual(guard.action_violations(text), [])

    def test_limit_on_another_command_does_not_count(self):
        # `timeout` bounds only the command it runs, not one chained after it.
        text = GREEN_ACTION.replace(
            "sudo timeout --kill-after=10 60 apt-get update",
            "timeout 60 true && sudo apt-get update",
        )
        violations = guard.action_violations(text)
        self.assertEqual(len(violations), 1)
        self.assertIn("apt-get update", violations[0])


class CallTests(unittest.TestCase):
    def test_continued_lines_are_one_call(self):
        calls = guard.apt_calls(RED_WORKFLOW)
        self.assertEqual(
            [(c.line, c.subcommand, c.packages) for c in calls],
            [(8, "update", []), (9, "install", ["clang", "cmake"])],
        )

    def test_chained_calls_are_split(self):
        calls = guard.apt_calls(
            "run: sudo apt-get update && sudo apt-get install -y xvfb; echo ok\n"
        )
        self.assertEqual([c.subcommand for c in calls], ["update", "install"])
        self.assertEqual(calls[1].packages, ["xvfb"])

    def test_long_options_with_an_argument_are_skipped(self):
        calls = guard.apt_calls(
            "run: sudo apt-get --target-release noble-backports install -y jq\n"
        )
        self.assertEqual(calls[0].subcommand, "install")
        self.assertEqual(calls[0].packages, ["jq"])

    def test_options_before_the_subcommand_are_skipped(self):
        calls = guard.apt_calls(
            "run: sudo apt-get -o Acquire::Retries=3 install -y jq\n"
        )
        self.assertEqual(calls[0].subcommand, "install")
        self.assertEqual(calls[0].packages, ["jq"])

    def test_bare_apt_counts(self):
        calls = guard.apt_calls("run: sudo apt install -y jq\n")
        self.assertEqual([c.subcommand for c in calls], ["install"])

    def test_prose_outside_a_run_script_is_ignored(self):
        # An action's description may well say "apt-get install".
        text = "description: >\n  apt-get install with a time limit\n"
        self.assertEqual(guard.apt_calls(text), [])

    def test_run_block_ends_at_a_shallower_key(self):
        text = (
            "      - run: |\n"
            "          sudo apt-get update\n"
            "        env:\n"
            "          NOTE: apt-get install is described here\n"
        )
        self.assertEqual([c.subcommand for c in guard.apt_calls(text)], ["update"])

    def test_continuation_on_the_last_line_still_counts(self):
        calls = guard.apt_calls("run: |\n  sudo apt-get install -y jq \\\n")
        self.assertEqual(calls[0].packages, ["jq"])

    def test_apt_without_a_subcommand_is_not_a_call(self):
        self.assertEqual(guard.apt_calls("run: apt-get --version\n"), [])

    def test_names_that_merely_contain_apt_are_ignored(self):
        self.assertEqual(guard.apt_calls("run: ./adapt-get install x\n"), [])


class WorkflowTests(unittest.TestCase):
    def test_wrapped_workflow_has_no_direct_calls(self):
        self.assertEqual(guard.direct_calls(GREEN_WORKFLOW), [])

    def test_direct_calls_are_reported_with_their_lines(self):
        # The update reaches the mirror as well as the install.
        self.assertEqual(guard.direct_calls(RED_WORKFLOW), [8, 9])

    def test_upgrade_is_reported(self):
        text = "        run: sudo apt-get dist-upgrade -y\n"
        self.assertEqual(guard.direct_calls(text), [1])

    def test_install_of_a_variable_is_reported(self):
        text = '        run: sudo apt-get install -y "${packages[@]}"\n'
        self.assertEqual(guard.direct_calls(text), [1])

    def test_local_subcommands_are_not_reported(self):
        text = "        run: |\n          sudo apt-get clean\n          apt list --installed\n"
        self.assertEqual(guard.direct_calls(text), [])

    def test_cached_step_in_an_uncached_workflow_is_reported(self):
        text = UNCACHED_STEP.replace("          cache: false\n", "")
        self.assertEqual(guard.cached_uses(text), [7])

    def test_uncached_step_is_not_reported(self):
        self.assertEqual(guard.cached_uses(UNCACHED_STEP), [])

    def test_quoted_false_counts(self):
        text = UNCACHED_STEP.replace("cache: false", "cache: 'false'  # release")
        self.assertEqual(guard.cached_uses(text), [])

    def test_cache_key_of_the_next_step_does_not_count(self):
        text = UNCACHED_STEP.replace("          cache: false\n", "").replace(
            "        run: flutter build linux\n",
            "        with:\n          cache: false\n",
        )
        self.assertEqual(guard.cached_uses(text), [7])

    def test_use_outside_a_step_list_is_not_a_step(self):
        text = "uses: ./.github/actions/install-apt-packages\n"
        self.assertEqual(guard.cached_uses(text), [])

    def test_inline_step_use_is_reported(self):
        text = (
            "    steps:\n"
            "      - uses: ./.github/actions/install-apt-packages\n"
            "        with:\n"
            "          packages: clang\n"
        )
        self.assertEqual(guard.cached_uses(text), [2])


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
        root = self._repo(
            GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW, "build-all.yml": UNCACHED_STEP}
        )
        self.assertEqual(guard.find_violations(root), [])

    def test_direct_install_in_any_workflow_is_flagged(self):
        root = self._repo(
            GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW, "native.yml": RED_WORKFLOW}
        )
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 2)
        self.assertIn(os.path.join(guard.WORKFLOW_DIR, "native.yml") + ":8", violations[0])
        self.assertIn(os.path.join(guard.WORKFLOW_DIR, "native.yml") + ":9", violations[1])

    def test_direct_install_in_another_local_action_is_flagged(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        other = os.path.join(root, guard.ACTIONS_DIR, "setup-linux")
        os.makedirs(other)
        with open(os.path.join(other, "action.yaml"), "w") as fh:
            fh.write(RED_WORKFLOW)
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 2)
        self.assertIn(
            os.path.join(guard.ACTIONS_DIR, "setup-linux", "action.yaml") + ":9",
            violations[1],
        )

    def test_cache_in_an_uncached_workflow_is_flagged(self):
        root = self._repo(
            GREEN_ACTION,
            {"build-all.yml": UNCACHED_STEP.replace("          cache: false\n", "")},
        )
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn("build-all.yml:7", violations[0])

    def test_cache_elsewhere_is_allowed(self):
        root = self._repo(GREEN_ACTION, {"ci.yaml": GREEN_WORKFLOW})
        self.assertEqual(guard.find_violations(root), [])

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
        root = self._repo(
            GREEN_ACTION.replace("attempts=3", "attempts=1"),
            {"ci.yaml": GREEN_WORKFLOW},
        )
        violations = guard.find_violations(root)
        self.assertEqual(len(violations), 1)
        self.assertIn(guard.ACTION_PATH, violations[0])

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
        self.assertIn("ci.yaml:9", buf.getvalue())

    def test_repository_is_bounded(self):
        # The real thing: every workflow in this repository installs through
        # the bounded action, and the action really bounds its downloads.
        self.assertEqual(guard.find_violations(os.path.dirname(_HERE)), [])


if __name__ == "__main__":
    unittest.main()
