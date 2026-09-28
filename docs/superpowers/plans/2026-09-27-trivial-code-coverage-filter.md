# Trivial-Code Coverage Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the Codecov coverage targets from rewarding tests that only execute boilerplate, by removing trivial members from each CI shard's coverage report before upload.

**Architecture:** A standard-library Python script reads an lcov report, finds `copyWith` (when pure), Equatable `props`, `operator ==`, `hashCode` and `toString` in each `lib/` source file (comments and string contents masked first), drops their `DA:` lines and rewrites the `LF`/`LH` totals. The CI test job runs it between `Run tests` and `Upload coverage`. The coverage targets themselves do not change.

**Tech Stack:** Python 3 standard library (`unittest`, `re`), GitHub Actions, Codecov, Flutter lcov output.

**Spec:** `docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md`

## Global Constraints

- Worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/beautiful-galileo-db6f30`, branch `ericgriffin/coverage-trivial-filter`. Start every shell command with `cd` to that path.
- Targets unchanged: `codecov.yml` keeps patch 80% and project 70% (threshold 5%).
- Exempt only: pure `copyWith`, Equatable `props`, `operator ==`, `hashCode`, `toString`. `toJson` and `fromJson` stay counted.
- A `copyWith` is pure only when its body is one constructor call whose arguments are `x ?? this.x`, `this.x` or `x`, named or positional. A clear flag, conditional, computed value, local variable or second statement makes it count.
- The filter only removes lines. It never adds or changes a hit count.
- Python: standard library only, and it must run on Python 3.9.
- Generated files and `lib/l10n/` are skipped, as `codecov.yml` already ignores them.
- Writing: no em-dashes, no en-dashes as punctuation, no double hyphens or spaced hyphens as prose punctuation, no emojis, in code, comments, docs, commits and the PR.
- Attribution: no trailers, and no mention of any AI tool or its vendor, in commits, the PR or comments.
- Commits: conventional style, no issue line (the issue does not exist until Task 5; the PR body's `Closes #<n>` is what the PR Issue Link check reads). Stage explicit paths.
- After each task: `dart format .` and `flutter analyze` must stay clean (no Dart changes are planned, so this is a guard).

## Review Focus

1. **A member written across lines in an unusual way.** For example, a `copyWith` whose `return` is on one line and the constructor call on the next. If the filter misreads it, the member stays counted, which is today's behaviour, never hidden logic. Test: Task 1, `test_other_shapes_of_body_are_logic` and the pure-copy tests.
2. **An annotation above a member.** Dart coverage records a getter's hit on its `@override` line, so the span must include annotations directly above. Test: Task 1, `test_equatable_props_including_its_annotation`.
3. **Windows line endings.** 76 Dart files in the repo are CRLF. Test: Task 1, `test_windows_line_endings`.
4. **A shard whose tests failed before writing coverage.** The step runs with `if: always()` and must not turn a test failure into a filter error. Test: Task 1, `test_a_missing_report_is_not_an_error` and `test_an_empty_report_is_left_alone`.
5. **Generated code in the report.** Flutter's report includes `.g.dart` files full of `copyWith` and `==`. They must be skipped. Test: Task 1, `test_generated_and_localization_files_are_skipped`.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/filter_trivial_coverage.py` (new) | Mask a Dart source, find trivial members, rewrite an lcov report |
| `scripts/filter_trivial_coverage_test.py` (new) | Its unit tests |
| `.github/workflows/ci.yaml` | Run the filter in each test shard; run its tests in Script Tests |
| `docs/developer/testing.md` | The coverage policy, replacing stale tables |
| `docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md` | Correct the measured `copyWith` count |

---

### Task 1: The filter script

**Files:**
- Create: `scripts/filter_trivial_coverage.py`
- Create: `scripts/filter_trivial_coverage_test.py`
- Modify: `.github/workflows/ci.yaml` (Script Tests job, step `Run Python guard tests with coverage`)

**Interfaces:**
- Consumes: nothing.
- Produces: `python3 scripts/filter_trivial_coverage.py <lcov file>`, which rewrites the file in place, prints `Dropped N lines of trivial members from M files` (or `<path>: no coverage to filter`), and exits 0; exit 2 on a usage error. Module functions `mask(source)`, `trivial_lines(source) -> set[int]`, `filter_report(text, read_source) -> (text, removed, files)`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/filter_trivial_coverage_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for filter_trivial_coverage.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import textwrap
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "filter_trivial_coverage",
    os.path.join(_HERE, "filter_trivial_coverage.py"),
)
cov = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cov)


def lines_of(source):
    return cov.trivial_lines(textwrap.dedent(source).lstrip("\n"))


class RecognitionTest(unittest.TestCase):
    def test_equatable_props_including_its_annotation(self):
        source = """
            class A {
              final int a;

              @override
              List<Object?> get props => [
                a,
              ];
            }
            """
        self.assertEqual(lines_of(source), {4, 5, 6, 7})

    def test_operator_equals_in_block_form(self):
        source = """
            class A {
              @override
              bool operator ==(Object other) {
                return other is A;
              }
            }
            """
        self.assertEqual(lines_of(source), {2, 3, 4, 5})

    def test_hash_code_in_arrow_form(self):
        source = """
            class A {
              @override
              int get hashCode => Object.hash(a, b);
            }
            """
        self.assertEqual(lines_of(source), {2, 3})

    def test_to_string(self):
        source = """
            class A {
              @override
              String toString() => 'A($a)';
            }
            """
        self.assertEqual(lines_of(source), {2, 3})

    def test_ordinary_members_are_left_alone(self):
        source = """
            class A {
              int get total => a + b;
              String describe() => 'A';
              bool isValid() {
                return a > 0;
              }
            }
            """
        self.assertEqual(lines_of(source), set())

    def test_a_truncated_file_does_not_crash(self):
        self.assertEqual(
            cov.trivial_lines(
                "class A {\n  String toString() {\n    return 'A';\n"
            ),
            {2, 3},
        )
        self.assertEqual(
            cov.trivial_lines("class A {\n  String toString() => 'A'"), {2}
        )
        self.assertEqual(
            cov.trivial_lines("class A {\n  String toString()"), set()
        )

    def test_a_declaration_without_a_body_is_ignored(self):
        source = """
            abstract class A {
              List<Object?> get props;
              String toString();
            }
            """
        self.assertEqual(lines_of(source), set())


class CopyWithTest(unittest.TestCase):
    def test_pure_copying_in_block_form(self):
        source = """
            class A {
              A copyWith({int? a, String? b}) {
                return A(
                  a: a ?? this.a,
                  b: b ?? this.b,
                );
              }
            }
            """
        self.assertEqual(lines_of(source), {2, 3, 4, 5, 6, 7})

    def test_pure_copying_in_arrow_form(self):
        source = """
            class A {
              A copyWith({int? a}) => A(a: a ?? this.a);
            }
            """
        self.assertEqual(lines_of(source), {2})

    def test_const_named_and_positional_copies_are_pure(self):
        source = """
            class A {
              A copyWith({int? a}) {
                return const A._(this.b, a: a ?? this.a, c: c);
              }
            }
            """
        self.assertEqual(lines_of(source), {2, 3, 4})

    def test_a_generic_return_type_is_recognised(self):
        source = """
            class A<T> {
              A<T> copyWith({T? value}) => A<T>(value: value ?? this.value);
            }
            """
        self.assertEqual(lines_of(source), {2})

    def test_a_clear_flag_is_logic(self):
        source = """
            class A {
              A copyWith({int? a, bool clearA = false}) {
                return A(a: clearA ? null : (a ?? this.a));
              }
            }
            """
        self.assertEqual(lines_of(source), set())

    def test_a_computed_value_is_logic(self):
        source = """
            class A {
              A copyWith({List<int>? items}) =>
                  A(items: (items ?? this.items).take(3).toList());
            }
            """
        self.assertEqual(lines_of(source), set())

    def test_a_local_variable_is_logic(self):
        source = """
            class A {
              A copyWith({int? a}) {
                final next = a ?? this.a;
                return A(a: next);
              }
            }
            """
        self.assertEqual(lines_of(source), set())

    def test_other_shapes_of_body_are_logic(self):
        bodies = [
            "{\n    a = 1;\n    return A(a: a);\n  }",
            "{\n    throw StateError('no');\n  }",
            "{\n    return other;\n  }",
            "{\n    return A(a: a) + b;\n  }",
            "{\n    return a.b.c(x: x);\n  }",
            "{\n    return make(a: a)(b);\n  }",
        ]
        for body in bodies:
            source = "class A {\n  A copyWith({int? a}) %s\n}\n" % body
            self.assertEqual(cov.trivial_lines(source), set(), body)

    def test_a_call_to_copy_with_is_not_a_declaration(self):
        source = """
            class B {
              A update(A a) {
                return a.copyWith(a: 1);
              }
              final next = current.copyWith(a: 2);
            }
            """
        self.assertEqual(lines_of(source), set())


class MaskingTest(unittest.TestCase):
    def test_a_string_holding_a_signature_is_not_code(self):
        source = """
            const fixture = '''
              List<Object?> get props => [a];
              bool operator ==(Object other) => true;
            ''';
            """
        self.assertEqual(lines_of(source), set())

    def test_a_comment_holding_a_signature_is_not_code(self):
        source = """
            // String toString() => 'x';
            /* int get hashCode => 1; */
            void main() {}
            """
        self.assertEqual(lines_of(source), set())

    def test_braces_in_a_string_do_not_end_a_body(self):
        source = """
            class A {
              @override
              String toString() {
                return '} { $a }';
              }
              int get total => 1;
            }
            """
        self.assertEqual(lines_of(source), {2, 3, 4, 5})

    def test_interpolation_keeps_its_code(self):
        self.assertEqual(
            cov.mask("f('a ${b.c} d');"),
            "f('  ${b.c}  ');",
        )

    def test_masking_keeps_offsets_and_line_breaks(self):
        source = "a = 'x\\ny';\n// c\nb = 1;\n"
        masked = cov.mask(source)
        self.assertEqual(len(masked), len(source))
        self.assertEqual(masked.count("\n"), source.count("\n"))

    def test_a_raw_string_ends_at_its_first_quote(self):
        self.assertEqual(cov.mask(r"f(r'\'); c"), "f(r' '); c")

    def test_an_identifier_ending_in_r_does_not_make_a_string_raw(self):
        self.assertEqual(cov.mask(r"bar'a\'b'; c"), "bar'    '; c")

    def test_an_unterminated_string_stops_at_the_line_end(self):
        self.assertEqual(cov.mask("a = 'oops\nb = 1;"), "a = '    \nb = 1;")

    def test_an_unterminated_multi_line_string_runs_to_the_end(self):
        self.assertEqual(cov.mask('a = """open'), 'a = """    ')

    def test_windows_line_endings(self):
        source = (
            "class A {\r\n"
            "  @override\r\n"
            "  String toString() => 'A';\r\n"
            "}\r\n"
        )
        self.assertEqual(cov.trivial_lines(source), {2, 3})


REPORT = (
    "SF:lib/a.dart\n"
    "DA:1,1\n"
    "DA:2,0\n"
    "DA:3,4\n"
    "DA:5,0\n"
    "LF:4\n"
    "LH:2\n"
    "end_of_record\n"
    "SF:lib/b.dart\n"
    "DA:1,0\n"
    "LF:1\n"
    "LH:0\n"
    "end_of_record\n"
)

A_SOURCE = (
    "class A {\n"
    "  @override\n"
    "  String toString() => 'A';\n"
    "  int total() => 1;\n"
    "  int get x => 2;\n"
)


class ReportTest(unittest.TestCase):
    def read(self, path):
        return {"lib/a.dart": A_SOURCE, "lib/b.dart": "void f() {}\n"}.get(path)

    def test_only_trivial_lines_go_and_totals_follow(self):
        text, removed, files = cov.filter_report(REPORT, self.read)
        self.assertEqual(removed, 2)
        self.assertEqual(files, 1)
        self.assertIn(
            "SF:lib/a.dart\nDA:1,1\nDA:5,0\nLF:2\nLH:1\nend_of_record\n", text
        )

    def test_records_without_trivial_lines_are_untouched(self):
        text, _, _ = cov.filter_report(REPORT, self.read)
        self.assertIn(
            "SF:lib/b.dart\nDA:1,0\nLF:1\nLH:0\nend_of_record\n", text
        )

    def test_a_record_that_misses_every_trivial_line_is_kept(self):
        report = "SF:lib/a.dart\nDA:4,1\nLF:1\nLH:1\nend_of_record\n"
        result = cov.filter_report(report, self.read)
        self.assertEqual(result, (report, 0, 0))

    def test_a_record_whose_source_is_unavailable_is_kept(self):
        text, removed, _ = cov.filter_report(REPORT, lambda path: None)
        self.assertEqual(text, REPORT)
        self.assertEqual(removed, 0)

    def test_an_empty_report_stays_empty(self):
        self.assertEqual(cov.filter_report("", self.read), ("", 0, 0))


class SourceLookupTest(unittest.TestCase):
    def setUp(self):
        self._previous = os.getcwd()
        self._temp = tempfile.TemporaryDirectory()
        os.chdir(self._temp.name)
        os.makedirs(os.path.join("lib", "l10n"))
        os.makedirs("test")
        for path in ("lib/a.dart", "lib/a.g.dart", "lib/l10n/x.dart",
                     "test/a_test.dart"):
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("class A {}\n")

    def tearDown(self):
        os.chdir(self._previous)
        self._temp.cleanup()

    def test_a_source_under_lib_is_read(self):
        self.assertEqual(cov._source_for("lib/a.dart"), "class A {}\n")

    def test_an_absolute_path_is_read(self):
        path = os.path.join(os.getcwd(), "lib", "a.dart")
        self.assertEqual(cov._source_for(path), "class A {}\n")

    def test_generated_and_localization_files_are_skipped(self):
        self.assertIsNone(cov._source_for("lib/a.g.dart"))
        self.assertIsNone(cov._source_for("lib/l10n/x.dart"))

    def test_files_outside_lib_are_skipped(self):
        self.assertIsNone(cov._source_for("test/a_test.dart"))

    def test_a_missing_file_is_skipped(self):
        self.assertIsNone(cov._source_for("lib/gone.dart"))


class MainTest(unittest.TestCase):
    def setUp(self):
        self._previous = os.getcwd()
        self._temp = tempfile.TemporaryDirectory()
        os.chdir(self._temp.name)
        os.makedirs("lib")
        with open(os.path.join("lib", "a.dart"), "w", encoding="utf-8") as handle:
            handle.write(A_SOURCE)

    def tearDown(self):
        os.chdir(self._previous)
        self._temp.cleanup()

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cov.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_the_report_is_rewritten_in_place(self):
        with open("lcov.info", "w", encoding="utf-8") as handle:
            handle.write(REPORT)
        code, out, _ = self.run_main("lcov.info")
        self.assertEqual(code, 0)
        self.assertIn("Dropped 2 lines of trivial members from 1 files", out)
        with open("lcov.info", encoding="utf-8") as handle:
            self.assertIn("LF:2\nLH:1\n", handle.read())

    def test_a_missing_report_is_not_an_error(self):
        code, out, _ = self.run_main("nope.info")
        self.assertEqual(code, 0)
        self.assertIn("no coverage to filter", out)

    def test_an_empty_report_is_left_alone(self):
        open("lcov.info", "w").close()
        code, _, _ = self.run_main("lcov.info")
        self.assertEqual(code, 0)
        self.assertEqual(os.path.getsize("lcov.info"), 0)

    def test_the_wrong_number_of_arguments_is_a_usage_error(self):
        code, _, err = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn("usage:", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 scripts/filter_trivial_coverage_test.py`
Expected: FAIL with `FileNotFoundError` naming `scripts/filter_trivial_coverage.py`.

- [ ] **Step 3: Write the script**

Create `scripts/filter_trivial_coverage.py`:

```python
#!/usr/bin/env python3
"""Drop trivial members from a Flutter lcov report before it is uploaded.

copyWith, Equatable props, operator ==, hashCode and toString are boilerplate.
A test that only executes them asserts that a field copies or that two equal
objects are equal, and would almost never catch a bug. Removing their lines
from the report means no coverage target can be met by writing such tests.

A copyWith counts as trivial only when its body is plain field copying, and
an ==, hashCode or toString only when its body is one plain expression; one
with any other logic stays in the report. Everything else is untouched. A
percentage can therefore move either way: it falls when covered boilerplate was
propping it up, which is the point, and rises when uncovered boilerplate was
holding it down.

Usage:
    python3 scripts/filter_trivial_coverage.py coverage/lcov.info

Rewrites the report in place. A missing or empty report is left alone, so a
shard whose tests failed before writing coverage still reports the tests.
Standard library only.
"""

import os
import re
import sys

LIB_ROOT = "lib"

# Mirrors the ignore list in codecov.yml: these files never count toward a
# target, so there is nothing to filter in them.
_GENERATED = (".g.dart", ".freezed.dart")
_GENERATED_DIRS = ("lib/l10n/",)
_ANNOTATION = re.compile(r"^[ \t]*@\w+(?:\([^\n]*\))?[ \t\r]*$")

_SIGNATURES = [
    re.compile(r"^[ \t]*(?:@override[ \t]+)?List<Object\?>[ \t]+get[ \t]+props\b", re.M),
    re.compile(r"^[ \t]*(?:@override[ \t]+)?bool[ \t]+operator[ \t]*==[ \t]*\(", re.M),
    re.compile(r"^[ \t]*(?:@override[ \t]+)?int[ \t]+get[ \t]+hashCode\b", re.M),
    re.compile(r"^[ \t]*(?:@override[ \t]+)?String[ \t]+toString[ \t]*\([ \t]*\)", re.M),
]
_COPY_WITH = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?[A-Za-z_][\w<>?, \t]*[ \t]copyWith[ \t]*[(<]", re.M
)
_ARGUMENT = re.compile(
    r"^(?:\w+\s*:\s*)?(?:\w+\s*\?\?\s*this\.\w+|this\.\w+|\w+)$"
)
_CONSTRUCTOR_CALL = re.compile(
    r"^(?:return\s+)?(?:const\s+|new\s+)?[A-Za-z_]\w*(?:<[^()]*>)?(?:\.\w+)?\s*\($",
    re.S,
)


def mask(source):
    """source with comments and string contents blanked.

    Offsets and line breaks are kept, so a position in the result is the same
    position in the source. Code inside a string interpolation is kept.
    """
    out = list(source)
    end = len(source)

    def blank(start, stop):
        for k in range(start, min(stop, end)):
            if out[k] != "\n":
                out[k] = " "

    def is_identifier(ch):
        return ch.isalnum() or ch in "_$"

    def skip_string(at):
        raw = at > 0 and source[at - 1] == "r" and (
            at < 2 or not is_identifier(source[at - 2])
        )
        quote = source[at]
        triple = source.startswith(quote * 3, at)
        close = quote * 3 if triple else quote
        i = at + len(close)
        start = i
        while i < end:
            ch = source[i]
            if not raw and ch == "\\":
                i += 2
            elif not raw and ch == "$" and i + 1 < end and source[i + 1] == "{":
                blank(start, i)
                i = skip_code(i + 2, until_brace=True)
                start = i
            elif source.startswith(close, i):
                blank(start, i)
                return i + len(close)
            elif not triple and ch == "\n":
                blank(start, i)
                return i
            else:
                i += 1
        blank(start, end)
        return end

    def skip_code(i, until_brace=False):
        depth = 0
        while i < end:
            ch = source[i]
            if source.startswith("//", i):
                stop = source.find("\n", i)
                stop = end if stop < 0 else stop
                blank(i, stop)
                i = stop
            elif source.startswith("/*", i):
                stop = source.find("*/", i + 2)
                stop = end if stop < 0 else stop + 2
                blank(i, stop)
                i = stop
            elif ch in "'\"":
                i = skip_string(i)
            elif ch == "{":
                depth += 1
                i += 1
            elif ch == "}":
                if until_brace and depth == 0:
                    return i + 1
                depth -= 1
                i += 1
            else:
                i += 1
        return end

    skip_code(0)
    return "".join(out)


def _matching(code, start, open_ch, close_ch):
    """Offset of the bracket that closes the one at start."""
    depth = 0
    for i in range(start, len(code)):
        if code[i] == open_ch:
            depth += 1
        elif code[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return len(code) - 1


def member_body(code, start):
    """(body_start, body_end) of the member declared at start, or None.

    body_start is the offset of the `{` or `=>` that opens the body, and
    body_end the offset of the `}` or `;` that ends it. None for a
    declaration with no body.
    """
    i = start
    depth = 0
    while i < len(code):
        ch = code[i]
        if ch in "([<":
            depth += 1
        elif ch in ")]>":
            depth -= 1
        elif depth <= 0 and ch == "{":
            return i, _matching(code, i, "{", "}")
        elif depth <= 0 and code.startswith("=>", i):
            j = i + 2
            nesting = 0
            while j < len(code):
                if code[j] in "([{":
                    nesting += 1
                elif code[j] in ")]}":
                    nesting -= 1
                elif code[j] == ";" and nesting <= 0:
                    return i, j
                j += 1
            return i, len(code) - 1
        elif depth <= 0 and ch == ";":
            return None
        i += 1
    return None


def _split_arguments(text):
    """Top-level comma separated parts of text."""
    parts, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(text[start:i])
            start = i + 1
    parts.append(text[start:])
    return [part.strip() for part in parts if part.strip()]


def is_pure_copy(code, body_start, body_end):
    """Whether a copyWith body only copies fields into a constructor call."""
    body = code[body_start:body_end + 1].strip()
    if body.startswith("=>"):
        body = body[2:].strip()
        if body.endswith(";"):
            body = body[:-1].strip()
    else:
        body = body[1:-1].strip()
        if not body.endswith(";") or body.count(";") != 1:
            return False
        body = body[:-1].strip()
        if not body.startswith("return"):
            return False
    open_paren = body.find("(")
    if open_paren < 0 or not body.endswith(")"):
        return False
    if not _CONSTRUCTOR_CALL.match(body[:open_paren + 1]):
        return False
    if _matching(body, open_paren, "(", ")") != len(body) - 1:
        return False
    arguments = _split_arguments(body[open_paren + 1:-1])
    return all(_ARGUMENT.match(argument) for argument in arguments)


def trivial_lines(source):
    """The 1-based line numbers that belong to trivial members of source."""
    code = mask(source)
    spans = []
    for pattern in _SIGNATURES:
        for match in pattern.finditer(code):
            body = member_body(code, match.end())
            if body:
                spans.append((match.start(), body[1]))
    for match in _COPY_WITH.finditer(code):
        body = member_body(code, match.end() - 1)
        if body and is_pure_copy(code, body[0], body[1]):
            spans.append((match.start(), body[1]))
    code_lines = code.split("\n")
    lines = set()
    for start, stop in spans:
        first = code.count("\n", 0, start) + 1
        last = code.count("\n", 0, stop) + 1
        # Coverage can record a member's hit on an annotation above it.
        while first > 1 and _ANNOTATION.match(code_lines[first - 2]):
            first -= 1
        lines.update(range(first, last + 1))
    return lines


def _source_for(path):
    """The source text for an SF: path, or None if it is not ours to filter."""
    relative = os.path.relpath(path) if os.path.isabs(path) else path
    relative = relative.replace(os.sep, "/")
    if not relative.startswith(LIB_ROOT + "/") or not os.path.isfile(relative):
        return None
    if relative.endswith(_GENERATED) or relative.startswith(_GENERATED_DIRS):
        return None
    with open(relative, encoding="utf-8", errors="replace", newline="") as handle:
        return handle.read()


def filter_report(text, read_source=_source_for):
    """text, an lcov report, with trivial members' lines removed.

    Returns (new_text, removed_line_count, touched_file_count).
    """
    out = []
    removed = files = 0
    record = []
    for line in text.splitlines():
        record.append(line)
        if line != "end_of_record":
            continue
        new_record, dropped = _filter_record(record, read_source)
        out.extend(new_record)
        if dropped:
            removed += dropped
            files += 1
        record = []
    out.extend(record)
    result = "\n".join(out)
    if text.endswith("\n") and result:
        result += "\n"
    return result, removed, files


def _filter_record(record, read_source):
    path = next((line[3:] for line in record if line.startswith("SF:")), None)
    source = read_source(path) if path else None
    if source is None:
        return record, 0
    trivial = trivial_lines(source)
    if not trivial:
        return record, 0
    kept = []
    dropped = 0
    for line in record:
        if line.startswith("DA:"):
            number = int(line[3:].split(",", 1)[0])
            if number in trivial:
                dropped += 1
                continue
        kept.append(line)
    if not dropped:
        return record, 0
    hits = [line for line in kept if line.startswith("DA:")]
    found = str(len(hits))
    hit = str(sum(1 for line in hits if int(line.split(",")[1]) > 0))
    rewritten = []
    for line in kept:
        if line.startswith("LF:"):
            line = "LF:" + found
        elif line.startswith("LH:"):
            line = "LH:" + hit
        rewritten.append(line)
    return rewritten, dropped


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        print("usage: filter_trivial_coverage.py <lcov file>", file=sys.stderr)
        return 2
    path = argv[0]
    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        print("%s: no coverage to filter" % path)
        return 0
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    result, removed, files = filter_report(text)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(result)
    print("Dropped %d lines of trivial members from %d files" % (removed, files))
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass, with full coverage**

```bash
python3 scripts/filter_trivial_coverage_test.py
python3 -m coverage run --include='scripts/filter_trivial_coverage.py' scripts/filter_trivial_coverage_test.py
python3 -m coverage report -m --include='scripts/filter_trivial_coverage.py'
```

Expected: `Ran 40 tests` and `OK`, then `100%`. If `coverage` is not installed locally, `python3 -m pip install --user coverage` first.

- [ ] **Step 5: Try it on a real report**

```bash
flutter test --coverage --coverage-path /tmp/cov_sample.info test/features/tags
python3 scripts/filter_trivial_coverage.py /tmp/cov_sample.info
awk '/^SF:lib\/features\/tags\/domain\/entities\/tag.dart/,/end_of_record/' /tmp/cov_sample.info
rm /tmp/cov_sample.info
```

Expected: `Dropped` about 2,800 lines from about 160 files, and the `tag.dart` record has no `DA:` line from 80 to 109 (its `copyWith` and `props`), with `LF` and `LH` equal to the remaining count.

- [ ] **Step 6: Run its tests in CI**

In `.github/workflows/ci.yaml`, step `Run Python guard tests with coverage` of the `script-tests` job: append `,scripts/filter_trivial_coverage.py` inside the quotes of the `guards='...'` line, after `scripts/bundle_tests.py`, and insert these two lines directly above `python3 -m coverage report -m --include="$guards"`:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/filter_trivial_coverage_test.py
```

Check: `python3 scripts/check_ci_success_gate.py` prints `PASS`.

- [ ] **Step 7: Commit**

```bash
git add scripts/filter_trivial_coverage.py scripts/filter_trivial_coverage_test.py .github/workflows/ci.yaml
git commit -m "test(ci): add a filter that drops trivial members from coverage reports"
```

---

### Task 2: Filter each shard's report in CI

**Files:**
- Modify: `.github/workflows/ci.yaml` (the `test` job, between `Run tests` and `Upload coverage`)

**Interfaces:**
- Consumes: the script from Task 1.
- Produces: shard reports uploaded to Codecov without trivial members.

- [ ] **Step 1: Add the step**

Insert directly above `      - name: Upload coverage` in the `test` job:

```yaml
      - name: Drop trivial members from coverage
        # Plain copyWith, props, ==, hashCode and toString count toward no
        # coverage target, so no one writes a test only to execute them. A PR whose
        # coverage came mostly from such lines sees its patch status fall,
        # which is the intent (see scripts/filter_trivial_coverage.py and
        # docs/developer/testing.md).
        # Runs even when the tests failed, like the upload: a missing or empty
        # report passes through untouched.
        if: always()
        run: python3 scripts/filter_trivial_coverage.py coverage/lcov.info
```

- [ ] **Step 2: Check the workflow**

```bash
python3 -c "import yaml; t = yaml.safe_load(open('.github/workflows/ci.yaml'))['jobs']['test']; print([s.get('name') for s in t['steps']][-3:])"
python3 scripts/check_ci_success_gate.py
```

Expected: `['Run tests', 'Drop trivial members from coverage', 'Upload coverage']`, then `PASS`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: drop trivial members from each shard's coverage before upload"
```

---

### Task 3: Document the policy

**Files:**
- Modify: `docs/developer/testing.md` (the `## Overview` table near the top, and `## Coverage Goals` at the end)
- Modify: `docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md` (the measured `copyWith` count)

**Interfaces:**
- Consumes: the step name from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Replace the Overview table**

In `docs/developer/testing.md`, replace

```markdown
Submersion has comprehensive test coverage including unit, widget, integration, and performance tests.

## Overview

| Test Type | Count | Coverage |
|-----------|-------|----------|
| **Unit Tests** | 165+ | 80%+ |
| **Widget Tests** | 48+ | Critical paths |
| **Integration Tests** | 2+ | Full workflows |
| **Performance Tests** | 6+ | Large datasets |
```

with

```markdown
Submersion has unit, widget, integration and performance tests. See
[Coverage](#coverage) for what the coverage numbers measure and what they do
not ask for.
```

- [ ] **Step 2: Replace Coverage Goals**

Replace the whole `## Coverage Goals` section, from its heading to the end of the file, with:

````markdown
## Coverage

Codecov reports two numbers on every PR:

| Status | Target | Measures |
|---|---|---|
| `codecov/patch` | 80% | The lines the PR adds or changes |
| `codecov/project` | 70%, within 5 points | The whole of `lib/` |

Neither blocks a merge: only `CI Success` is required. They are there to show
when new logic went untested.

### What counts

Before each test shard uploads its report, CI removes the lines of trivial
members (`scripts/filter_trivial_coverage.py`):

- `copyWith`, when its body only copies fields into a constructor
  (`name: name ?? this.name`, `name: this.name`);
- Equatable `props`;
- `operator ==`, `hashCode` and `toString`.

A `copyWith` with any other logic, such as a clear flag or a computed value,
still counts, and so do `toJson` and `fromJson`. Generated files and
`lib/l10n/` are not counted at all.

Test behaviour, not lines. A test that only checks that a field copies, or
that two equal objects are equal, would almost never catch a bug, and the
target no longer asks for one.

### Checking patch coverage locally

```bash
flutter test --coverage test/path/to/the/tests/you/changed
python3 scripts/filter_trivial_coverage.py coverage/lcov.info
```

Then compare the lines your change adds (`git diff --unified=0 origin/main...HEAD -- lib/`)
with the `DA:` records in `coverage/lcov.info`, the way Codecov does.
````

- [ ] **Step 3: Correct the spec's measurement**

In `docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md`, replace

```markdown
Measured on main: 198 of 225 `copyWith` methods are pure, about 2,800 lines;
with the other four kinds the exemption covers roughly 6,000 lines, about 1% of
the hand-written code.
```

with

```markdown
Measured on main: 134 of 226 `copyWith` methods are pure. Most of the rest use
a clear flag or a sentinel value, which counts as logic. With the other four
kinds the exemption covers about 6,200 lines in 334 files, just under 1% of
the hand-written code.
```

- [ ] **Step 4: Check and commit**

```bash
grep -n -E "—|–" docs/developer/testing.md docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md
git add docs/developer/testing.md docs/superpowers/specs/2026-09-27-trivial-code-coverage-filter-design.md
git commit -m "docs(testing): describe what the coverage targets count"
```

Expected: the `grep` prints nothing.

---

### Task 4: Session guidance outside the repository

**Files:**
- Modify: `/Users/ericgriffin/.claude/projects/-Users-ericgriffin-repos-submersion-app-submersion/memory/project_measuring_codecov_patch_coverage_locally.md`

**Interfaces:**
- Consumes: the script from Task 1.
- Produces: nothing in the repository; no commit.

- [ ] **Step 1: Update the note**

Read the file first. Insert after its first paragraph:

```markdown
**Since the trivial-member filter (Track 2 of the test-suite work):** run
`python3 scripts/filter_trivial_coverage.py coverage/lcov.info` before
measuring, as CI does. Pure `copyWith`, `props`, `==`, `hashCode` and
`toString` no longer count, so NEVER add a test whose only purpose is to
execute them. If the patch number is low, find the untested BEHAVIOUR in the
missed lines and test that, or leave the number low and say why in the PR.
```

Update the `description:` line to mention the filter, and keep the index line in `MEMORY.md` pointing at it.

---

### Task 5: Issue, PR and the first CI run

**Files:** none.

**Interfaces:**
- Consumes: everything above.
- Produces: a merged-ready PR.

- [ ] **Step 1: Open the issue**

Write the body to a scratch file: the problem (boilerplate counts toward the targets, filler tests follow), the decision (filter trivial members before upload, targets unchanged), and what is exempt. Then:

```bash
gh issue create --title "Coverage counts boilerplate, which rewards filler tests" --body-file <file> --label ci
gh api -X PATCH repos/submersion-app/submersion/issues/<n> -f type=Task --jq '.type.name'
```

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin ericgriffin/coverage-trivial-filter
gh pr create --base main --head ericgriffin/coverage-trivial-filter --title "ci: stop counting boilerplate toward coverage" --body-file <file>
```

The body follows `.github/PULL_REQUEST_TEMPLATE.md`, starts with `Closes #<n>`, deletes the Screenshots section, and states that project coverage will jump once because about 6,200 mostly covered lines leave the total.

- [ ] **Step 3: Read the first run**

When CI finishes: every `Drop trivial members from coverage` step printed a `Dropped ...` line, every shard uploaded, and the `codecov/patch` and `codecov/project` statuses settled. Record the project coverage before and after in a PR comment.
