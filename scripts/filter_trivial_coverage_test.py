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

    def test_covered_trivial_lines_no_longer_prop_up_a_total(self):
        report = (
            "SF:lib/a.dart\nDA:3,5\nDA:4,0\nLF:2\nLH:1\nend_of_record\n"
        )
        text, _, _ = cov.filter_report(report, self.read)
        self.assertIn("DA:4,0\nLF:1\nLH:0\n", text)

    def test_an_end_of_record_with_trailing_space_still_ends_the_record(self):
        report = (
            "SF:lib/a.dart\nDA:3,1\nLF:1\nLH:1\nend_of_record \n"
            "SF:lib/b.dart\nDA:2,1\nDA:3,1\nLF:2\nLH:2\nend_of_record\n"
        )
        sources = {"lib/a.dart": A_SOURCE, "lib/b.dart": "\nint real() {\n  return 1;\n}\n"}
        text, removed, files = cov.filter_report(report, sources.get)
        self.assertEqual((removed, files), (1, 1))
        self.assertIn("SF:lib/b.dart\nDA:2,1\nDA:3,1\nLF:2\nLH:2\n", text)

    def test_a_new_source_file_starts_a_new_record(self):
        report = (
            "SF:lib/a.dart\nDA:3,1\nLF:1\nLH:1\n"
            "SF:lib/b.dart\nDA:2,1\nDA:3,1\nLF:2\nLH:2\nend_of_record\n"
        )
        sources = {"lib/a.dart": A_SOURCE, "lib/b.dart": "\nint real() {\n  return 1;\n}\n"}
        text, removed, _ = cov.filter_report(report, sources.get)
        self.assertEqual(removed, 1)
        self.assertIn("SF:lib/b.dart\nDA:2,1\nDA:3,1\nLF:2\nLH:2\n", text)

    def test_a_last_record_without_end_of_record_is_still_filtered(self):
        report = "SF:lib/a.dart\nDA:3,1\nDA:4,0\nLF:2\nLH:1"
        text, removed, _ = cov.filter_report(report, self.read)
        self.assertEqual(removed, 1)
        self.assertEqual(text, "SF:lib/a.dart\nDA:4,0\nLF:1\nLH:0")

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

    def test_a_report_it_cannot_read_is_left_alone_and_does_not_fail(self):
        # DA:4 has no hit count, which the totals cannot be computed from.
        broken = "SF:lib/a.dart\nDA:3,1\nDA:4\nend_of_record\n"
        with open("lcov.info", "w", encoding="utf-8") as handle:
            handle.write(broken)
        code, _, err = self.run_main("lcov.info")
        self.assertEqual(code, 0)
        self.assertIn("left the report unchanged", err)
        with open("lcov.info", encoding="utf-8") as handle:
            self.assertEqual(handle.read(), broken)

    def test_the_wrong_number_of_arguments_is_a_usage_error(self):
        code, _, err = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn("usage:", err)


if __name__ == "__main__":
    unittest.main()
