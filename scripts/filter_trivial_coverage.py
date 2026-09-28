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
import shutil
import sys
import tempfile
import traceback

LIB_ROOT = "lib"

# Mirrors the ignore list in codecov.yml: these files never count toward a
# target, so there is nothing to filter in them.
_GENERATED = (".g.dart", ".freezed.dart")
_GENERATED_DIRS = ("lib/l10n/",)
_ANNOTATION = re.compile(r"^[ \t]*@\w+(?:\([^\n]*\))?[ \t\r]*$")
_NOT_NEWLINE = re.compile(r"[^\n]")

_PROPS = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?List<Object\?>[ \t]+get[ \t]+props\b", re.M
)
_EQUALS = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?bool[ \t]+operator[ \t]*==[ \t]*\(", re.M
)
_HASH_CODE = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?int[ \t]+get[ \t]+hashCode\b", re.M
)
_TO_STRING = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?String[ \t]+toString[ \t]*\([ \t]*\)", re.M
)
# Ends before the parameter list, so the body search starts at its bracket.
_COPY_WITH = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?(?P<type>[A-Za-z_]\w*)[\w<>?, \t]*[ \t]"
    r"copyWith[ \t]*(?=[(<])",
    re.M,
)
# A condition, a loop or a closure inside an expression. `?.`, `??` and `?[`
# are null-aware access, not a condition, and the braces of a string
# interpolation are not a closure body.
_LOGIC = re.compile(
    r"\b(?:if|for|while|switch|do|try|throw)\b|=>"
    r"|\)\s*(?:async\*?|sync\*)?\s*\{|(?<!\?)\?(?![.?\[=])"
)
_IDENTICAL_GUARD = re.compile(
    r"^if\s*\(\s*identical\s*\(\s*this\s*,\s*\w+\s*\)\s*\)\s*return\s+true\s*;"
)
# `name: name ?? this.name`, `name: this.name` or `name: name`; a positional
# argument may only be `name ?? this.name` or `this.name`.
_ARGUMENT = re.compile(
    r"^(?:(?P<to>\w+)\s*:\s*)?"
    r"(?:(?P<fallback>\w+)\s*\?\?\s*this\.(?P<field>\w+)"
    r"|this\.(?P<this>\w+)|(?P<bare>\w+))$"
)
_CONSTRUCTOR_CALL = re.compile(
    r"^(?:const\s+|new\s+)?(?P<type>[A-Za-z_]\w*)(?:<[^()]*>)?(?:\.\w+)?\s*\("
)


def mask(source):
    """source with comments and string contents blanked.

    Offsets and line breaks are kept, so a position in the result is the same
    position in the source. Code inside a string interpolation is kept.
    test/architecture/source_mask.dart masks the same way, and
    test/architecture/coverage_filter_mask_parity_test.dart holds the two
    to the same output.
    """
    return "".join(_masked_pieces(source))


def _masked_pieces(source):
    kept = 0
    for start, stop in _scan_code(source, 0):
        yield source[kept:start]
        yield _NOT_NEWLINE.sub(" ", source[start:stop])
        kept = stop
    yield source[kept:]


def _is_identifier(ch):
    return ch.isalnum() or ch in "_$"


def _scan_code(source, i, until_brace=False):
    """Yields the (start, stop) spans to blank, in order, from offset i.

    Returns the offset after the `}` that closes an interpolation when
    until_brace is set, and the end of source otherwise.
    """
    end = len(source)
    depth = 0
    while i < end:
        ch = source[i]
        if source.startswith("//", i):
            stop = source.find("\n", i)
            stop = end if stop < 0 else stop
            yield i, stop
            i = stop
        elif source.startswith("/*", i):
            stop = source.find("*/", i + 2)
            stop = end if stop < 0 else stop + 2
            yield i, stop
            i = stop
        elif ch in "'\"":
            i = yield from _scan_string(source, i)
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


def _scan_string(source, at):
    """Yields the spans of the string opening at `at`; returns its end."""
    end = len(source)
    raw = at > 0 and source[at - 1] == "r" and (
        at < 2 or not _is_identifier(source[at - 2])
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
            yield start, i
            i = yield from _scan_code(source, i + 2, until_brace=True)
            start = i
        elif source.startswith(close, i):
            yield start, i
            return i + len(close)
        elif not triple and ch == "\n":
            yield start, i
            return i
        else:
            i += 1
    yield start, end
    return end


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


def _single_expression(code, body_start, body_end, guard=False):
    """The one expression a body returns, or None if the body does more.

    An arrow body qualifies, and so does a block holding a single `return`.
    With guard, the block may open with
    `if (identical(this, other)) return true;`.
    """
    body = code[body_start:body_end + 1].strip()
    if body.startswith("=>"):
        expression = body[2:].strip()
        return expression[:-1].strip() if expression.endswith(";") else expression
    inner = (body[1:-1] if body.endswith("}") else body[1:]).strip()
    early_return = _IDENTICAL_GUARD.match(inner) if guard else None
    if early_return:
        inner = inner[early_return.end():].strip()
    if (
        not re.match(r"return\s", inner)
        or not inner.endswith(";")
        or inner.count(";") != 1
    ):
        return None
    return inner[len("return"):-1].strip()


def _top_level_commas(text):
    depth = 0
    for i, ch in enumerate(text):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            yield i


def _split_arguments(text):
    """Top-level comma separated parts of text."""
    cuts = [-1, *_top_level_commas(text), len(text)]
    parts = (text[a + 1:b].strip() for a, b in zip(cuts, cuts[1:]))
    return [part for part in parts if part]


def is_pure_copy(code, body_start, body_end, type_name):
    """Whether a copyWith body only copies fields into a type_name constructor."""
    expression = _single_expression(code, body_start, body_end)
    call = _CONSTRUCTOR_CALL.match(expression) if expression else None
    if not call or call["type"] != type_name or not expression.endswith(")"):
        return False
    open_paren = call.end() - 1
    if _matching(expression, open_paren, "(", ")") != len(expression) - 1:
        return False
    arguments = _split_arguments(expression[open_paren + 1:-1])
    return all(_is_copied(argument) for argument in arguments)


def _is_copied(argument):
    """Whether one argument copies a value into the field of the same name."""
    match = _ARGUMENT.match(argument)
    if not match:
        return False
    if match["fallback"] and match["fallback"] != match["field"]:
        return False
    names = {match[key] for key in ("fallback", "this", "bare") if match[key]}
    if match["to"]:
        return names == {match["to"]}
    return not match["bare"]


def is_simple(code, body_start, body_end):
    """Whether an ==, hashCode or toString body is one plain expression.

    See _single_expression for the shapes of body that qualify. The expression
    may not hold a condition, a loop or a closure.
    """
    expression = _single_expression(code, body_start, body_end, guard=True)
    return expression is not None and not _LOGIC.search(expression)


# Each kind of trivial member, and the test its body must pass.
_MEMBERS = (
    (_PROPS, lambda code, match, body: True),
    (_EQUALS, lambda code, match, body: is_simple(code, *body)),
    (_HASH_CODE, lambda code, match, body: is_simple(code, *body)),
    (_TO_STRING, lambda code, match, body: is_simple(code, *body)),
    (_COPY_WITH, lambda code, match, body: is_pure_copy(code, *body, match["type"])),
)


def _ends_its_line(code, offset):
    """Whether nothing but blanks follows offset on its line."""
    newline = code.find("\n", offset + 1)
    return not code[offset + 1:newline if newline >= 0 else len(code)].strip()


def _trivial_spans(code):
    for pattern, is_trivial in _MEMBERS:
        for match in pattern.finditer(code):
            body = member_body(code, match.end())
            # lcov counts whole lines, so a member that shares its last line
            # with other code cannot be dropped without dropping that code.
            if body and _ends_its_line(code, body[1]) and is_trivial(code, match, body):
                yield match.start(), body[1]


def _line_range(code, code_lines, start, stop):
    first = code.count("\n", 0, start) + 1
    last = code.count("\n", 0, stop) + 1
    # Coverage can record a member's hit on an annotation above it.
    while first > 1 and _ANNOTATION.match(code_lines[first - 2]):
        first -= 1
    return range(first, last + 1)


def trivial_lines(source):
    """The 1-based line numbers that belong to trivial members of source."""
    code = mask(source)
    code_lines = code.split("\n")
    return set().union(
        *(_line_range(code, code_lines, start, stop)
          for start, stop in _trivial_spans(code))
    )


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


def _records(lines):
    """lines split into lcov records.

    A record ends at its end_of_record line. A new source file also ends the
    one before, even if its end_of_record line is missing, so one file's lines
    are never judged by another's.
    """
    start = 0
    for i, line in enumerate(lines):
        if line.startswith("SF:") and i > start:
            yield lines[start:i]
            start = i
        if line.strip() == "end_of_record":
            yield lines[start:i + 1]
            start = i + 1
    if start < len(lines):
        yield lines[start:]


def filter_report(text, read_source=_source_for):
    """text, an lcov report, with trivial members' lines removed.

    Returns (new_text, removed_line_count, touched_file_count).
    """
    results = [
        _filter_record(record, read_source)
        for record in _records(text.splitlines())
    ]
    result = "\n".join(line for record, _ in results for line in record)
    if text.endswith("\n") and result:
        result += "\n"
    removed = sum(dropped for _, dropped in results)
    files = sum(1 for _, dropped in results if dropped)
    return result, removed, files


def _line_number(line):
    return int(line[3:].split(",", 1)[0])


def _total(line, found, hit):
    if line.startswith("LF:"):
        return "LF:%d" % found
    if line.startswith("LH:"):
        return "LH:%d" % hit
    return line


def _filter_record(record, read_source):
    path = next((line[3:] for line in record if line.startswith("SF:")), None)
    source = read_source(path) if path else None
    trivial = trivial_lines(source) if source is not None else set()
    kept = [
        line for line in record
        if not (line.startswith("DA:") and _line_number(line) in trivial)
    ]
    dropped = len(record) - len(kept)
    if not dropped:
        return record, 0
    hits = [line for line in kept if line.startswith("DA:")]
    hit = sum(1 for line in hits if int(line.split(",")[1]) > 0)
    return [_total(line, len(hits), hit) for line in kept], dropped


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        print("usage: filter_trivial_coverage.py <lcov file>", file=sys.stderr)
        return 2
    path = argv[0]
    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        print("%s: no coverage to filter" % path)
        return 0
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        result, removed, files = filter_report(text)
        _replace(path, result)
    except Exception:  # noqa: BLE001 (a filter bug must not fail the shard)
        # The tests have already run and passed or failed on their own. A
        # report this script cannot read or rewrite is uploaded as it is,
        # rather than turning a green shard red.
        traceback.print_exc()
        print("%s: could not filter; left the report unchanged" % path,
              file=sys.stderr)
        return 0
    print("Dropped %d lines of trivial members from %d files" % (removed, files))
    return 0


def _replace(path, text):
    """Write text to path whole or not at all.

    The text goes to a temporary file beside path, which then takes path's
    place in one step, so a failed write never leaves a truncated report.
    """
    fd, temporary = tempfile.mkstemp(
        dir=os.path.dirname(os.path.abspath(path)), suffix=".tmp"
    )
    try:
        try:
            handle = open(fd, "w", encoding="utf-8", newline="\n")
        except BaseException:
            os.close(fd)
            raise
        with handle:
            handle.write(text)
        shutil.copymode(path, temporary)
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
