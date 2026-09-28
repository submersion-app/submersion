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

_ALWAYS = [
    re.compile(r"^[ \t]*(?:@override[ \t]+)?List<Object\?>[ \t]+get[ \t]+props\b", re.M),
]
# Exempt only when simple: see is_simple.
_WHEN_SIMPLE = [
    re.compile(r"^[ \t]*(?:@override[ \t]+)?bool[ \t]+operator[ \t]*==[ \t]*\(", re.M),
    re.compile(r"^[ \t]*(?:@override[ \t]+)?int[ \t]+get[ \t]+hashCode\b", re.M),
    re.compile(r"^[ \t]*(?:@override[ \t]+)?String[ \t]+toString[ \t]*\([ \t]*\)", re.M),
]
# A condition, a loop or a closure inside an expression. `?.`, `??` and `?[`
# are null-aware access, not a condition, and the braces of a string
# interpolation are not a closure body.
_LOGIC = re.compile(
    r"\b(?:if|for|while|switch|do|try|throw)\b|=>|\)\s*\{|(?<!\?)\?(?![.?\[=])"
)
_IDENTICAL_GUARD = re.compile(
    r"^if\s*\(\s*identical\s*\(\s*this\s*,\s*\w+\s*\)\s*\)\s*return\s+true\s*;"
)
_COPY_WITH = re.compile(
    r"^[ \t]*(?:@override[ \t]+)?[A-Za-z_][\w<>?, \t]*[ \t]copyWith[ \t]*[(<]", re.M
)
# `name: name ?? this.name`, `name: this.name` or `name: name`; a positional
# argument may only be `name ?? this.name` or `this.name`.
_ARGUMENT = re.compile(
    r"^(?:(?P<to>\w+)\s*:\s*)?"
    r"(?:(?P<fallback>\w+)\s*\?\?\s*this\.(?P<field>\w+)"
    r"|this\.(?P<this>\w+)|(?P<bare>\w+))$"
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

    An arrow body qualifies, and so does a block holding one return, after an
    optional `if (identical(this, other)) return true;`. The expression may not
    hold a condition, a loop or a closure.
    """
    body = code[body_start:body_end + 1].strip()
    if body.startswith("=>"):
        expression = body[2:].strip()
        if expression.endswith(";"):
            expression = expression[:-1]
    else:
        inner = body[1:]
        if inner.endswith("}"):
            inner = inner[:-1]
        inner = inner.strip()
        guard = _IDENTICAL_GUARD.match(inner)
        if guard:
            inner = inner[guard.end():].strip()
        if (
            not re.match(r"return\s", inner)
            or not inner.endswith(";")
            or inner.count(";") != 1
        ):
            return False
        expression = inner[len("return"):-1]
    return not _LOGIC.search(expression)


def trivial_lines(source):
    """The 1-based line numbers that belong to trivial members of source."""
    code = mask(source)
    spans = []
    for pattern in _ALWAYS:
        for match in pattern.finditer(code):
            body = member_body(code, match.end())
            if body:
                spans.append((match.start(), body[1]))
    for pattern in _WHEN_SIMPLE:
        for match in pattern.finditer(code):
            body = member_body(code, match.end())
            if body and is_simple(code, body[0], body[1]):
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

    def close():
        nonlocal removed, files
        new_record, dropped = _filter_record(record, read_source)
        out.extend(new_record)
        if dropped:
            removed += dropped
            files += 1

    for line in text.splitlines():
        # A new source file ends the one before, even if its end_of_record
        # line is missing, so one file's lines are never judged by another's.
        if line.startswith("SF:") and record:
            close()
            record = []
        record.append(line)
        if line.strip() == "end_of_record":
            close()
            record = []
    if record:
        close()
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
        with open(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        shutil.copymode(path, temporary)
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
