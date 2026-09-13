#!/usr/bin/env python3
"""Unit tests for check_pr_issue_link.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_pr_issue_link",
    os.path.join(_HERE, "check_pr_issue_link.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

REPO = "submersion-app/submersion"
TEMPLATE = os.path.join(_HERE, os.pardir, ".github", "PULL_REQUEST_TEMPLATE.md")


def closing(body):
    return guard.closing_refs(body, REPO)


def linked(body):
    return guard.linking_refs(body, REPO)


class ClosingRefsTest(unittest.TestCase):
    def test_every_github_closing_keyword_is_recognised(self):
        for keyword in (
            "close", "closes", "closed",
            "fix", "fixes", "fixed",
            "resolve", "resolves", "resolved",
        ):
            with self.subTest(keyword=keyword):
                self.assertEqual(closing(f"{keyword} #10"), {"#10"})

    def test_keywords_are_case_insensitive(self):
        self.assertEqual(closing("CLOSES #10"), {"#10"})
        self.assertEqual(closing("Fixes #10"), {"#10"})

    def test_a_colon_after_the_keyword_is_allowed(self):
        self.assertEqual(closing("Closes: #10"), {"#10"})
        self.assertEqual(closing("Closes:#10"), {"#10"})

    def test_keyword_must_be_separated_from_the_reference(self):
        self.assertEqual(closing("Closes#10"), set())

    def test_each_issue_needs_its_own_keyword(self):
        # GitHub closes only #1 here; the check must not promise more.
        self.assertEqual(closing("Fixes #1, #2"), {"#1"})
        self.assertEqual(closing("Fixes #1, fixes #2"), {"#1", "#2"})

    def test_keyword_must_be_a_whole_word(self):
        self.assertEqual(closing("prefixes #3"), set())
        self.assertEqual(closing("unresolved #3"), set())

    def test_reference_must_end_at_a_word_boundary(self):
        self.assertEqual(closing("Fixes #12abc"), set())
        self.assertEqual(closing("Fixes #12."), {"#12"})

    def test_cross_repository_reference_keeps_its_repository(self):
        self.assertEqual(
            closing("Fixes octo-org/octo-repo#100"), {"octo-org/octo-repo#100"}
        )

    def test_same_repository_long_form_normalises_to_short_form(self):
        self.assertEqual(closing("Fixes Submersion-App/Submersion#7"), {"#7"})

    def test_mentions_without_a_keyword_do_not_close(self):
        self.assertEqual(closing("Follows up on #1790 and #1806."), set())

    def test_keywords_inside_html_comments_are_ignored(self):
        self.assertEqual(closing("<!-- Closes #123 -->"), set())
        self.assertEqual(closing("<!--\nCloses #123\n-->\nFixes #4"), {"#4"})

    def test_text_after_a_one_line_comment_is_kept(self):
        self.assertEqual(closing("<!-- template note --> Closes #1800"), {"#1800"})
        self.assertEqual(
            closing("<!-- a --> Closes #1 <!-- Fixes #2 --> fixes #3"),
            {"#1", "#3"},
        )

    def test_text_after_a_multi_line_comment_closes_is_kept(self):
        body = "<!--\nCloses #5\n--> Closes #1800"
        self.assertEqual(closing(body), {"#1800"})

    def test_an_unterminated_html_comment_hides_the_rest(self):
        self.assertEqual(closing("Fixes #4\n<!-- Closes #5"), {"#4"})

    def test_keywords_inside_fenced_code_are_ignored(self):
        body = "```markdown\nCloses #123\n```\nFixes #4\n~~~\nFixes #5\n~~~"
        self.assertEqual(closing(body), {"#4"})

    def test_an_unclosed_fence_hides_the_rest(self):
        self.assertEqual(closing("Fixes #4\n```\nCloses #5"), {"#4"})

    def test_a_fence_with_an_info_string_does_not_close_the_block(self):
        body = "```\nCloses #1\n```text\nCloses #2\n```\nFixes #3"
        self.assertEqual(closing(body), {"#3"})

    def test_keywords_inside_inline_code_are_ignored(self):
        self.assertEqual(closing("Write `Closes #123` in the body."), set())
        self.assertEqual(closing("Use ``Closes #1`` then Fixes #2"), {"#2"})

    def test_an_inline_html_comment_is_ignored(self):
        self.assertEqual(closing("See <!-- Closes #5 --> Fixes #4"), {"#4"})

    def test_a_comment_opener_inside_inline_code_is_literal(self):
        # Whichever construct starts first wins: here the code span does, so
        # the `<!--` inside it must not hide the rest of the description.
        body = "Moves the examples into a `<!--` comment.\n\nCloses #1800"
        self.assertEqual(closing(body), {"#1800"})

    def test_a_comment_opener_inside_a_fence_is_literal(self):
        body = "```\n<!-- start\n```\nCloses #1800"
        self.assertEqual(closing(body), {"#1800"})

    def test_an_unmatched_comment_opener_mid_line_is_literal(self):
        self.assertEqual(closing("Use <!-- to start one.\nCloses #1800"), {"#1800"})

    def test_an_unmatched_backtick_is_literal(self):
        self.assertEqual(closing("A stray ` backtick. Closes #1800"), {"#1800"})

    def test_a_backtick_run_with_backticks_after_it_is_inline_code(self):
        # A backtick fence's info string cannot contain a backtick, so this
        # line is an inline code span, not an unclosed fenced block.
        self.assertEqual(closing("```x``` then Closes #1800"), {"#1800"})

    def test_non_ascii_digits_are_not_references(self):
        self.assertEqual(closing("Closes #١٢"), set())


class LinkingRefsTest(unittest.TestCase):
    def test_every_non_closing_form_is_recognised(self):
        for phrase in ("Refs", "Part of", "Related to"):
            with self.subTest(phrase=phrase):
                self.assertEqual(linked(f"{phrase} #5"), {"#5"})

    def test_non_closing_forms_are_case_insensitive_and_allow_a_colon(self):
        self.assertEqual(linked("refs: #5"), {"#5"})
        self.assertEqual(linked("PART OF #5"), {"#5"})
        self.assertEqual(linked("related  to #5"), {"#5"})

    def test_passing_prose_is_not_a_declaration(self):
        self.assertEqual(linked("see #5, like #6 did"), set())

    def test_closing_keywords_are_not_counted_as_non_closing(self):
        self.assertEqual(linked("Closes #5"), set())

    def test_non_closing_forms_inside_comments_are_ignored(self):
        self.assertEqual(linked("<!-- Refs #5 -->"), set())


class BranchIssueTest(unittest.TestCase):
    def test_issue_worktree_branch(self):
        self.assertEqual(
            guard.branch_issue("ericgriffin/github-issue-1800-6a78c2"), "#1800"
        )

    def test_feature_request_worktree_branch(self):
        self.assertEqual(
            guard.branch_issue("ericgriffin/feature-request-1803-9f1671"), "#1803"
        )

    def test_conventional_issue_branch(self):
        self.assertEqual(guard.branch_issue("fix/issue-12"), "#12")
        self.assertEqual(guard.branch_issue("issue-12-short-name"), "#12")

    def test_branches_without_an_issue_number(self):
        for branch in ("ericgriffin/bulk-use-set-1754", "tissue-5", "main", ""):
            with self.subTest(branch=branch):
                self.assertIsNone(guard.branch_issue(branch))


class EvaluateTest(unittest.TestCase):
    def evaluate(self, body, branch="feature/x", author_type="User"):
        return guard.evaluate(body, branch, author_type, REPO)

    def test_bot_authored_prs_pass_without_a_link(self):
        ok, lines = self.evaluate("", author_type="Bot")
        self.assertTrue(ok)
        self.assertIn("bot", " ".join(lines).lower())

    def test_empty_description_fails(self):
        ok, _ = self.evaluate("")
        self.assertFalse(ok)

    def test_missing_description_fails(self):
        ok, _ = self.evaluate(None)
        self.assertFalse(ok)

    def test_prose_mention_alone_fails(self):
        ok, lines = self.evaluate("Builds on #1790 to finish the export.")
        self.assertFalse(ok)
        self.assertTrue(any("Closes #N" in line for line in lines))

    def test_closing_keyword_passes(self):
        ok, lines = self.evaluate("Fixes #1800")
        self.assertTrue(ok)
        self.assertIn("#1800", " ".join(lines))

    def test_non_closing_link_passes(self):
        ok, _ = self.evaluate("Part of #1487")
        self.assertTrue(ok)

    def test_branch_issue_closed_by_the_description_passes(self):
        ok, _ = self.evaluate(
            "Closes #1800", branch="ericgriffin/github-issue-1800-6a78c2"
        )
        self.assertTrue(ok)

    def test_branch_issue_referenced_without_closing_passes(self):
        # A follow-up PR on the same branch, like #1742 after #1733.
        ok, _ = self.evaluate(
            "Refs #1729", branch="ericgriffin/github-issue-1729-55db0b"
        )
        self.assertTrue(ok)

    def test_branch_issue_missing_from_the_description_fails(self):
        ok, lines = self.evaluate(
            "Closes #1801", branch="ericgriffin/github-issue-1800-6a78c2"
        )
        self.assertFalse(ok)
        self.assertTrue(any("#1800" in line for line in lines))

    def test_untouched_pull_request_template_fails(self):
        # The template's examples live in HTML comments, so a description left
        # as the bare template must not satisfy the check by accident.
        with open(TEMPLATE, encoding="utf-8") as fh:
            ok, _ = self.evaluate(fh.read())
        self.assertFalse(ok)


class MainTest(unittest.TestCase):
    def run_main(self, body, *extra):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "body.md")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(body)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = guard.main(
                    ["check_pr_issue_link.py", "--body-file", path,
                     "--repo", REPO, *extra]
                )
        return code, out.getvalue()

    def test_linked_description_exits_zero(self):
        code, out = self.run_main("Closes #10", "--branch", "feature/x")
        self.assertEqual(code, 0)
        self.assertIn("PASS", out)

    def test_unlinked_description_exits_one_with_an_error_annotation(self):
        code, out = self.run_main("No issue here.", "--branch", "feature/x")
        self.assertEqual(code, 1)
        self.assertIn("::error::", out)

    def test_bot_author_type_exits_zero(self):
        code, _ = self.run_main("", "--author-type", "Bot")
        self.assertEqual(code, 0)

    def test_unreadable_body_file_exits_one(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = guard.main(
                ["check_pr_issue_link.py", "--body-file", "/nonexistent/body.md"]
            )
        self.assertEqual(code, 1)
        self.assertIn("::error::", out.getvalue())


if __name__ == "__main__":
    unittest.main()
