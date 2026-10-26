import 'dart:math' as math;

import 'package:flutter/services.dart';

/// The line-start marks the notes editor's buttons toggle.
enum NotesLinePrefix { heading, bullet, numbered }

/// A heading, bullet (with an optional task box) or number at the start of
/// a line, after any indentation.
final _linePrefix = RegExp(r'^(\s*)(#{1,6} |[-*+] (?:\[[ xX]\] )?|\d+[.)] )?');

/// Wraps the selection in [mark] (`**` bold, `*` italic), or unwraps it when
/// it is already wrapped, inside or just outside the selection. With no
/// selection, inserts the pair with the caret between, ready to type.
TextEditingValue toggleInlineMark(TextEditingValue value, String mark) {
  final text = value.text;
  final sel = _hugWords(text, _normalized(value));
  final start = sel.start;
  final end = sel.end;

  if (sel.isCollapsed) {
    return TextEditingValue(
      text: text.replaceRange(start, start, '$mark$mark'),
      selection: TextSelection.collapsed(offset: start + mark.length),
    );
  }

  final before = text.substring(0, start);
  final inner = text.substring(start, end);
  final after = text.substring(end);

  // Marks just outside the selection.
  if (_carries(_trailingStars(before), mark) &&
      _carries(_leadingStars(after), mark)) {
    final newStart = start - mark.length;
    return TextEditingValue(
      text:
          before.substring(0, before.length - mark.length) +
          inner +
          after.substring(mark.length),
      selection: TextSelection(
        baseOffset: newStart,
        extentOffset: newStart + inner.length,
      ),
    );
  }

  // Marks inside the selection.
  if (inner.length > mark.length * 2 &&
      _carries(_leadingStars(inner), mark) &&
      _carries(_trailingStars(inner), mark)) {
    final unwrapped = inner.substring(mark.length, inner.length - mark.length);
    return TextEditingValue(
      text: before + unwrapped + after,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + unwrapped.length,
      ),
    );
  }

  return TextEditingValue(
    text: '$before$mark$inner$mark$after',
    selection: TextSelection(
      baseOffset: start + mark.length,
      extentOffset: end + mark.length,
    ),
  );
}

/// [sel] shrunk to leave whitespace at its edges outside: Markdown marks
/// only count when they touch the words (`**big **` stays literal), and a
/// double tap often selects the space after a word. A selection of nothing
/// but whitespace becomes a caret at its start.
TextSelection _hugWords(String text, TextSelection sel) {
  if (sel.isCollapsed) return sel;
  var start = sel.start;
  var end = sel.end;
  while (start < end && text[start].trim().isEmpty) {
    start++;
  }
  while (end > start && text[end - 1].trim().isEmpty) {
    end--;
  }
  if (start == end) return TextSelection.collapsed(offset: sel.start);
  return TextSelection(baseOffset: start, extentOffset: end);
}

/// Whether a run of [stars] asterisks contains [mark]: `*` lives in runs of
/// one or three (`***` is bold italic), `**` in runs of two or three.
bool _carries(int stars, String mark) =>
    mark == '**' ? stars == 2 || stars == 3 : stars == 1 || stars == 3;

int _leadingStars(String s) {
  var n = 0;
  while (n < s.length && s[n] == '*') {
    n++;
  }
  return n;
}

int _trailingStars(String s) {
  var n = 0;
  while (n < s.length && s[s.length - 1 - n] == '*') {
    n++;
  }
  return n;
}

/// Toggles [prefix] at the start of the caret's line, or of every line the
/// selection touches. When every touched line already has it, it is
/// removed; otherwise each line gets it, replacing any other prefix
/// (numbered lines are numbered from 1). Blank lines in a multi-line
/// selection are left alone.
TextEditingValue toggleLinePrefix(
  TextEditingValue value,
  NotesLinePrefix prefix,
) {
  final text = value.text;
  final sel = _normalized(value);
  final blockStart = sel.start == 0
      ? 0
      : text.lastIndexOf('\n', sel.start - 1) + 1;
  // A selection ending just after a newline (a whole selected line) does
  // not reach into the next line.
  final end =
      !sel.isCollapsed && sel.end > sel.start && text[sel.end - 1] == '\n'
      ? sel.end - 1
      : sel.end;
  final newline = text.indexOf('\n', end);
  final blockEnd = newline < 0 ? text.length : newline;
  final lines = text.substring(blockStart, blockEnd).split('\n');
  final multi = lines.length > 1;

  bool has(String line) {
    final mark = _linePrefix.firstMatch(line)!.group(2) ?? '';
    return switch (prefix) {
      NotesLinePrefix.heading => mark.startsWith('#'),
      NotesLinePrefix.bullet => RegExp(r'^[-*+] ').hasMatch(mark),
      NotesLinePrefix.numbered => RegExp(r'^\d').hasMatch(mark),
    };
  }

  final targets = [
    for (final line in lines)
      if (!multi || line.trim().isNotEmpty) line,
  ];
  final removing = targets.isNotEmpty && targets.every(has);

  var number = 1;
  final deltas = <int>[];
  final rewritten = <String>[];
  for (final line in lines) {
    if (multi && line.trim().isEmpty) {
      rewritten.add(line);
      deltas.add(0);
      continue;
    }
    final match = _linePrefix.firstMatch(line)!;
    final indent = match.group(1) ?? '';
    final oldMark = match.group(2) ?? '';
    final body = line.substring(match.end);
    final newMark = removing
        ? ''
        : switch (prefix) {
            NotesLinePrefix.heading => '# ',
            NotesLinePrefix.bullet => '- ',
            NotesLinePrefix.numbered => '${number++}. ',
          };
    rewritten.add('$indent$newMark$body');
    deltas.add(newMark.length - oldMark.length);
  }

  final replaced = rewritten.join('\n');
  final newText = text.replaceRange(blockStart, blockEnd, replaced);
  if (sel.isCollapsed) {
    final firstLineStart = blockStart;
    final prefixEnd =
        firstLineStart + _linePrefix.firstMatch(rewritten.first)!.end;
    final caret = math.max(sel.start + deltas.first, prefixEnd);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: math.min(caret, firstLineStart + rewritten.first.length),
      ),
    );
  }
  return TextEditingValue(
    text: newText,
    selection: TextSelection(
      baseOffset: blockStart,
      extentOffset: blockStart + replaced.length,
    ),
  );
}

TextSelection _normalized(TextEditingValue value) {
  final s = value.selection;
  if (!s.isValid) return TextSelection.collapsed(offset: value.text.length);
  return TextSelection(baseOffset: s.start, extentOffset: s.end);
}

final _bulletItem = RegExp(r'^(\s*)([-*+]) (\[[ xX]\] )?(.*)$');
final _numberedItem = RegExp(r'^(\s*)(\d+)([.)]) (.*)$');

/// Continues a list when Enter is pressed in a list item: the new line
/// starts with the next bullet, number or an empty task box. Enter on an
/// item with nothing typed after its marker ends the list instead,
/// removing the marker. Works for hardware and on-screen keyboards alike,
/// since it sees the inserted newline rather than a key.
class NotesListContinuationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final old = oldValue.selection;
    if (!old.isValid || !old.isCollapsed || !newValue.selection.isCollapsed) {
      return newValue;
    }
    final caret = old.start;
    final text = oldValue.text;
    final expected = '${text.substring(0, caret)}\n${text.substring(caret)}';
    if (newValue.text != expected) return newValue;

    final lineStart = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
    final line = text.substring(lineStart, caret);

    final bullet = _bulletItem.firstMatch(line);
    final numbered = bullet == null ? _numberedItem.firstMatch(line) : null;
    if (bullet == null && numbered == null) return newValue;

    final body = (bullet?.group(4) ?? numbered!.group(4))!;
    final restOfLine = text.indexOf('\n', caret) < 0
        ? text.substring(caret)
        : text.substring(caret, text.indexOf('\n', caret));
    if (body.trim().isEmpty && restOfLine.trim().isEmpty) {
      // An empty item: end the list by clearing the marker.
      return TextEditingValue(
        text: text.replaceRange(lineStart, caret, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    final String marker;
    if (bullet != null) {
      final task = bullet.group(3) != null ? '[ ] ' : '';
      marker = '${bullet.group(1)}${bullet.group(2)} $task';
    } else {
      final next = int.parse(numbered!.group(2)!) + 1;
      marker = '${numbered.group(1)}$next${numbered.group(3)} ';
    }
    final insertAt = caret + 1;
    return TextEditingValue(
      text: newValue.text.replaceRange(insertAt, insertAt, marker),
      selection: TextSelection.collapsed(offset: insertAt + marker.length),
    );
  }
}
