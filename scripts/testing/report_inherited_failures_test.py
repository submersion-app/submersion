#!/usr/bin/env python3
"""Unit tests for report_inherited_failures.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "report_inherited_failures",
    os.path.join(_HERE, "report_inherited_failures.py"),
)
report = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(report)

BASE_SHA = "b" * 40
OLDER_SHA = "a" * 40


def job(name, conclusion):
    return {"name": name, "conclusion": conclusion}


def run(run_id, sha, conclusion="failure", status="completed"):
    return {
        "id": run_id,
        "head_sha": sha,
        "status": status,
        "conclusion": conclusion,
        "html_url": f"https://github.com/o/r/actions/runs/{run_id}",
    }


class FailedJobNamesTest(unittest.TestCase):
    def test_keeps_failed_and_timed_out_jobs_only(self):
        jobs = [
            job("Analyze & Format", "success"),
            job("Test (shard 1)", "failure"),
            job("Test (shard 2)", "timed_out"),
            job("Build iOS", "skipped"),
            job("Build Linux", "cancelled"),
        ]
        self.assertEqual(
            report.failed_job_names(jobs), ["Test (shard 1)", "Test (shard 2)"]
        )

    def test_excludes_the_gate_job_itself(self):
        jobs = [job("CI Success", "failure"), job("Code Generation", "failure")]
        self.assertEqual(report.failed_job_names(jobs), ["Code Generation"])

    def test_deduplicates_names(self):
        jobs = [job("Code Generation", "failure"), job("Code Generation", "failure")]
        self.assertEqual(report.failed_job_names(jobs), ["Code Generation"])


class UsableRunTest(unittest.TestCase):
    def test_accepts_a_finished_run_with_a_verdict(self):
        self.assertTrue(report.usable_run(run(1, BASE_SHA, conclusion="success")))
        self.assertTrue(report.usable_run(run(1, BASE_SHA, conclusion="failure")))

    def test_skips_a_cancelled_run(self):
        # Superseded on main by concurrency: its jobs say nothing about main.
        self.assertFalse(report.usable_run(run(1, BASE_SHA, conclusion="cancelled")))

    def test_skips_a_run_still_in_progress(self):
        self.assertFalse(
            report.usable_run(run(1, BASE_SHA, conclusion=None, status="in_progress"))
        )


class ClassifyTest(unittest.TestCase):
    def test_splits_inherited_from_new(self):
        main_jobs = [
            job("Code Generation", "failure"),
            job("Test (shard 3)", "timed_out"),
            job("Analyze & Format", "success"),
        ]
        inherited, new, unknown = report.classify(
            ["Analyze & Format", "Code Generation", "Test (shard 3)"], main_jobs
        )
        self.assertEqual(inherited, ["Code Generation", "Test (shard 3)"])
        self.assertEqual(new, ["Analyze & Format"])
        self.assertEqual(unknown, [])

    def test_test_shards_compare_as_one_job(self):
        # Shards are load-balanced over test weights, so a pull request that
        # adds or resizes a test file can move main's broken file from shard 4
        # to shard 1. The shard number says nothing about which test failed.
        main_jobs = [job("Test (shard 4)", "failure"), job("Test (shard 1)", "success")]
        inherited, new, unknown = report.classify(["Test (shard 1)"], main_jobs)
        self.assertEqual(inherited, ["Test (shard 1)"])
        self.assertEqual(new, [])
        self.assertEqual(unknown, [])

    def test_other_jobs_still_compare_by_exact_name(self):
        main_jobs = [job("Build iOS", "failure"), job("Build macOS", "success")]
        inherited, new, unknown = report.classify(["Build macOS"], main_jobs)
        self.assertEqual(inherited, [])
        self.assertEqual(new, ["Build macOS"])
        self.assertEqual(unknown, [])

    def test_a_job_main_never_ran_is_unknown(self):
        inherited, new, unknown = report.classify(["Build Windows"], [])
        self.assertEqual((inherited, new), ([], []))
        self.assertEqual(unknown, ["Build Windows"])

    def test_a_job_main_skipped_is_unknown(self):
        # A docs-only commit on main skips codegen and everything after it,
        # which says nothing about whether main would pass those jobs.
        main_jobs = [job("Code Generation", "skipped"), job("Test (shard 0)", "skipped")]
        inherited, new, unknown = report.classify(
            ["Code Generation", "Test (shard 2)"], main_jobs
        )
        self.assertEqual((inherited, new), ([], []))
        self.assertEqual(unknown, ["Code Generation", "Test (shard 2)"])


class EscapeTest(unittest.TestCase):
    def test_escapes_workflow_command_data(self):
        self.assertEqual(report.escape_data("50%\nnext\r"), "50%25%0Anext%0D")

    def test_escapes_workflow_command_properties(self):
        self.assertEqual(report.escape_property("a:b,c%"), "a%3Ab%2Cc%25")


class ApiGetTest(unittest.TestCase):
    """api_get builds the request; urlopen is stubbed, nothing leaves the host."""

    def call(self, env):
        seen = {}

        def fake_urlopen(request, timeout):
            seen["request"] = request
            seen["timeout"] = timeout
            return io.BytesIO(b'{"ok": true}')

        with mock.patch.object(report.urllib.request, "urlopen", fake_urlopen):
            body = report.api_get("/repos/o/r/actions/runs/1/jobs", env)
        return body, seen["request"], seen["timeout"]

    def test_sends_the_token_and_decodes_the_body(self):
        body, request, timeout = self.call({"GH_TOKEN": "t0k"})
        self.assertEqual(body, {"ok": True})
        self.assertEqual(
            request.full_url, "https://api.github.com/repos/o/r/actions/runs/1/jobs"
        )
        self.assertEqual(request.get_header("Authorization"), "Bearer t0k")
        self.assertEqual(request.get_header("Accept"), "application/vnd.github+json")
        self.assertGreater(timeout, 0)

    def test_falls_back_to_github_token_and_honors_the_api_url(self):
        _, request, _ = self.call(
            {"GITHUB_TOKEN": "gh", "GITHUB_API_URL": "https://ghe.example/api/v3"}
        )
        self.assertTrue(request.full_url.startswith("https://ghe.example/api/v3/"))
        self.assertEqual(request.get_header("Authorization"), "Bearer gh")

    def test_omits_authorization_without_a_token(self):
        _, request, _ = self.call({})
        self.assertIsNone(request.get_header("Authorization"))


class FakeApi:
    """Serves canned API responses keyed by path prefix."""

    def __init__(self, responses):
        self.responses = responses
        self.paths = []

    def __call__(self, path):
        self.paths.append(path)
        for prefix, body in self.responses.items():
            if path.startswith(prefix):
                return body
        raise AssertionError(f"unexpected API path: {path}")


def env_for(summary_path, **extra):
    env = {
        "GITHUB_REPOSITORY": "o/r",
        "GITHUB_RUN_ID": "99",
        "GITHUB_WORKFLOW_REF": "o/r/.github/workflows/ci.yaml@refs/pull/7/merge",
        "BASE_SHA": BASE_SHA,
        "GITHUB_STEP_SUMMARY": summary_path,
    }
    env.update(extra)
    return env


class MainTest(unittest.TestCase):
    def setUp(self):
        handle, self.summary = tempfile.mkstemp()
        os.close(handle)
        self.addCleanup(os.remove, self.summary)

    def run_main(self, api, **extra):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = report.main(env=env_for(self.summary, **extra), fetch=api)
        with open(self.summary, encoding="utf-8") as handle:
            summary = handle.read()
        return status, out.getvalue(), summary

    def standard_api(self, pr_jobs, main_jobs):
        return FakeApi({
            "/repos/o/r/actions/runs/99/jobs": {
                "total_count": len(pr_jobs), "jobs": pr_jobs,
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {
                "workflow_runs": [run(5, BASE_SHA)],
            },
            "/repos/o/r/actions/runs/5/jobs": {
                "total_count": len(main_jobs), "jobs": main_jobs,
            },
        })

    def test_marks_a_failure_main_shares_as_inherited(self):
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure"), job("CI Success", "failure")],
            main_jobs=[job("Code Generation", "failure")],
        )
        status, out, summary = self.run_main(api)
        self.assertEqual(status, 0)
        self.assertIn("::warning title=Also failing on main::Code Generation", out)
        self.assertIn("https://github.com/o/r/actions/runs/5", out)
        self.assertIn("Code Generation", summary)
        self.assertIn("inherited", summary.lower())

    def test_marks_a_failure_main_does_not_share_as_new(self):
        api = self.standard_api(
            pr_jobs=[job("Analyze & Format", "failure")],
            main_jobs=[job("Analyze & Format", "success")],
        )
        status, out, summary = self.run_main(api)
        self.assertEqual(status, 0)
        self.assertNotIn("::warning", out)
        self.assertIn("::notice title=Not failing on main::Analyze & Format", out)
        self.assertIn("Analyze & Format", summary)

    def test_asks_only_for_finished_push_runs_on_main(self):
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure")],
            main_jobs=[job("Code Generation", "failure")],
        )
        self.run_main(api)
        runs_query = next(p for p in api.paths if "/workflows/" in p)
        for part in ("branch=main", "event=push", "status=completed"):
            self.assertIn(part, runs_query)

    def test_reports_a_job_main_skipped_as_unknown(self):
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure")],
            main_jobs=[job("Code Generation", "skipped")],
        )
        status, out, summary = self.run_main(api)
        self.assertEqual(status, 0)
        self.assertNotIn("Not failing on main", out)
        self.assertIn("::notice title=No result on main::Code Generation", out)
        self.assertIn("no result on main", summary)

    def test_looks_up_the_base_commit_directly(self):
        # A long-lived branch's base can be older than any recent-runs page.
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure")],
            main_jobs=[job("Code Generation", "failure")],
        )
        self.run_main(api)
        runs_query = next(p for p in api.paths if "/workflows/" in p)
        self.assertIn(f"head_sha={BASE_SHA}", runs_query)

    def test_falls_back_to_recent_runs_without_one_at_the_base(self):
        api = FakeApi({
            "/repos/o/r/actions/runs/99/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
            f"/repos/o/r/actions/workflows/ci.yaml/runs?head_sha={BASE_SHA}": {
                "workflow_runs": [],
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {
                "workflow_runs": [run(6, OLDER_SHA)],
            },
            "/repos/o/r/actions/runs/6/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
        })
        _, out, _ = self.run_main(api)
        self.assertIn("::warning title=Also failing on main::Code Generation", out)
        self.assertIn("newest finished run", out)

    def skipped_base_api(self, recent, jobs_by_run):
        responses = {
            "/repos/o/r/actions/runs/99/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
            f"/repos/o/r/actions/workflows/ci.yaml/runs?head_sha={BASE_SHA}": {
                "workflow_runs": [run(5, BASE_SHA, conclusion="success")],
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {"workflow_runs": recent},
        }
        for run_id, jobs in jobs_by_run.items():
            responses[f"/repos/o/r/actions/runs/{run_id}/jobs"] = {
                "total_count": len(jobs), "jobs": jobs,
            }
        return FakeApi(responses)

    def test_moves_past_a_main_run_that_skipped_the_jobs(self):
        # The base is a docs-only commit: codegen and everything after it were
        # skipped, so the previous code commit's run is the one with results.
        api = self.skipped_base_api(
            recent=[run(5, BASE_SHA, conclusion="success"), run(4, OLDER_SHA)],
            jobs_by_run={
                5: [job("Code Generation", "skipped")],
                4: [job("Code Generation", "failure")],
            },
        )
        _, out, summary = self.run_main(api)
        self.assertIn("::warning title=Also failing on main::Code Generation", out)
        self.assertIn("aaaaaaaaa", out)
        self.assertIn("newest finished run that ran these jobs", out)
        self.assertIn("runs/4", summary)

    def test_tries_a_bounded_number_of_main_runs(self):
        recent = [run(i, f"{i:040d}", conclusion="success") for i in range(10, 0, -1)]
        api = self.skipped_base_api(
            recent=recent,
            jobs_by_run={i: [job("Code Generation", "skipped")] for i in range(1, 11)},
        )
        _, out, _ = self.run_main(api)
        job_lists = [p for p in api.paths if "/runs/" in p and "/runs/99/" not in p]
        self.assertLessEqual(len(job_lists), report.MAX_BASELINE_RUNS)
        self.assertIn("::notice title=No result on main::Code Generation", out)

    def test_names_the_newest_run_when_no_run_has_results(self):
        api = FakeApi({
            "/repos/o/r/actions/runs/99/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
            f"/repos/o/r/actions/workflows/ci.yaml/runs?head_sha={BASE_SHA}": {
                "workflow_runs": [],
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {
                "workflow_runs": [run(6, OLDER_SHA, conclusion="success")],
            },
            "/repos/o/r/actions/runs/6/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "skipped")],
            },
        })
        _, out, _ = self.run_main(api)
        self.assertIn(
            "Code Generation has no result on main in its newest finished run "
            "(aaaaaaaaa)",
            out,
        )

    def test_does_not_list_recent_runs_when_the_base_has_results(self):
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure")],
            main_jobs=[job("Code Generation", "failure")],
        )
        self.run_main(api)
        runs_queries = [p for p in api.paths if "/workflows/" in p]
        self.assertEqual(len(runs_queries), 1)
        self.assertIn("head_sha=", runs_queries[0])

    def test_reads_the_latest_attempt_of_each_job(self):
        api = self.standard_api(
            pr_jobs=[job("Code Generation", "failure")],
            main_jobs=[job("Code Generation", "failure")],
        )
        self.run_main(api)
        for path in api.paths:
            if path.endswith("/jobs") or "/jobs?" in path:
                self.assertIn("filter=latest", path)

    def test_pages_through_a_long_job_list(self):
        first = [job(f"Job {i}", "success") for i in range(100)]
        api = FakeApi({
            "/repos/o/r/actions/runs/99/jobs?filter=latest&per_page=100&page=1": {
                "total_count": 101, "jobs": first,
            },
            "/repos/o/r/actions/runs/99/jobs?filter=latest&per_page=100&page=2": {
                "total_count": 101, "jobs": [job("Code Generation", "failure")],
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {
                "workflow_runs": [run(5, BASE_SHA)],
            },
            "/repos/o/r/actions/runs/5/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
        })
        _, out, _ = self.run_main(api)
        self.assertIn("::warning title=Also failing on main::Code Generation", out)

    def test_says_nothing_when_no_job_failed(self):
        api = self.standard_api(
            pr_jobs=[job("Analyze & Format", "success")], main_jobs=[]
        )
        status, out, summary = self.run_main(api)
        self.assertEqual(status, 0)
        self.assertNotIn("::warning", out)
        self.assertNotIn("::notice", out)
        self.assertEqual(summary, "")

    def test_reports_when_main_has_no_run_to_compare(self):
        api = FakeApi({
            "/repos/o/r/actions/runs/99/jobs": {
                "total_count": 1, "jobs": [job("Code Generation", "failure")],
            },
            "/repos/o/r/actions/workflows/ci.yaml/runs": {"workflow_runs": []},
        })
        status, out, _ = self.run_main(api)
        self.assertEqual(status, 0)
        self.assertIn("::notice", out)
        self.assertIn("No finished CI/CD run on main", out)

    def test_never_fails_the_step_when_the_api_errors(self):
        def broken(path):
            raise OSError("network unreachable")

        status, out, _ = self.run_main(broken)
        self.assertEqual(status, 0)
        self.assertIn("::notice", out)
        self.assertIn("network unreachable", out)

    def test_never_fails_the_step_without_its_environment(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = report.main(env={}, fetch=FakeApi({}))
        self.assertEqual(status, 0)
        self.assertIn("::notice", out.getvalue())


if __name__ == "__main__":
    unittest.main()
