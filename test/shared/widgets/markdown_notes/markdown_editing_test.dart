import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/markdown_notes/markdown_editing.dart';

/// A value written with `|` for a collapsed caret, or `[` and `]` around a
/// selection, so each case reads as text.
TextEditingValue v(String marked) {
  final caret = marked.indexOf('|');
  if (caret >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
  final start = marked.indexOf('[');
  final end = marked.indexOf(']') - 1;
  return TextEditingValue(
    text: marked.replaceFirst('[', '').replaceFirst(']', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );
}

/// [value] written back in the same notation.
String show(TextEditingValue value) {
  final s = value.selection;
  final t = value.text;
  if (s.isCollapsed) {
    return '${t.substring(0, s.start)}|${t.substring(s.start)}';
  }
  return '${t.substring(0, s.start)}[${t.substring(s.start, s.end)}]'
      '${t.substring(s.end)}';
}

void main() {
  group('toggleInlineMark', () {
    test('wraps the selection and keeps it selected', () {
      expect(
        show(toggleInlineMark(v('a [big] turtle'), '**')),
        'a **[big]** turtle',
      );
    });

    test('unwraps a selection that is already wrapped', () {
      expect(
        show(toggleInlineMark(v('a **[big]** turtle'), '**')),
        'a [big] turtle',
      );
    });

    test('unwraps a selection that includes its marks', () {
      expect(
        show(toggleInlineMark(v('a [**big**] turtle'), '**')),
        'a [big] turtle',
      );
    });

    test('with no selection inserts the pair around the caret', () {
      expect(show(toggleInlineMark(v('ab|'), '*')), 'ab*|*');
    });

    test('italic does not unwrap bold', () {
      expect(
        show(toggleInlineMark(v('a **[big]** b'), '*')),
        'a ***[big]*** b',
      );
    });
  });

  group('toggleLinePrefix', () {
    test('heading on and off', () {
      expect(
        show(toggleLinePrefix(v('Descent|'), NotesLinePrefix.heading)),
        '# Descent|',
      );
      expect(
        show(toggleLinePrefix(v('# Descent|'), NotesLinePrefix.heading)),
        'Descent|',
      );
    });

    test('acts on the caret line only', () {
      expect(
        show(toggleLinePrefix(v('a\nb|\nc'), NotesLinePrefix.heading)),
        'a\n# b|\nc',
      );
    });

    test('bullets every selected line, then removes them', () {
      final on = toggleLinePrefix(v('[a\nb]'), NotesLinePrefix.bullet);
      expect(on.text, '- a\n- b');
      expect(toggleLinePrefix(on, NotesLinePrefix.bullet).text, 'a\nb');
    });

    test('numbers selected lines in order', () {
      expect(
        toggleLinePrefix(v('[a\nb\nc]'), NotesLinePrefix.numbered).text,
        '1. a\n2. b\n3. c',
      );
    });

    test('a bullet replaces numbering', () {
      expect(toggleLinePrefix(v('1. a|'), NotesLinePrefix.bullet).text, '- a');
    });

    test('a heading replaces a bullet', () {
      expect(toggleLinePrefix(v('- a|'), NotesLinePrefix.heading).text, '# a');
    });

    test('the caret moves with the inserted prefix', () {
      expect(
        show(toggleLinePrefix(v('ab|c'), NotesLinePrefix.bullet)),
        '- ab|c',
      );
    });
  });

  group('NotesListContinuationFormatter', () {
    final formatter = NotesListContinuationFormatter();
    TextEditingValue enter(String before) {
      final old = v(before);
      final caret = old.selection.start;
      final typed = TextEditingValue(
        text: '${old.text.substring(0, caret)}\n${old.text.substring(caret)}',
        selection: TextSelection.collapsed(offset: caret + 1),
      );
      return formatter.formatEditUpdate(old, typed);
    }

    test('continues a bullet', () {
      expect(show(enter('- a|')), '- a\n- |');
    });

    test('continues numbering', () {
      expect(show(enter('2. b|')), '2. b\n3. |');
    });

    test('continues a task with an empty box', () {
      expect(show(enter('- [x] a|')), '- [x] a\n- [ ] |');
    });

    test('keeps a nested item indented', () {
      expect(show(enter('  - a|')), '  - a\n  - |');
    });

    test('Enter on an empty item ends the list', () {
      expect(show(enter('- a\n- |')), '- a\n|');
      expect(show(enter('- a\n2. |')), '- a\n|');
    });

    test('a plain line is untouched', () {
      expect(show(enter('plain|')), 'plain\n|');
    });

    test('a paste with several lines is untouched', () {
      final old = v('- a|');
      const pasted = TextEditingValue(
        text: '- a\nx\ny',
        selection: TextSelection.collapsed(offset: 9),
      );
      expect(formatter.formatEditUpdate(old, pasted), pasted);
    });
  });

  test('a selection ending at a line start leaves that line alone', () {
    const value = TextEditingValue(
      text: 'a\nb',
      selection: TextSelection(baseOffset: 0, extentOffset: 2),
    );
    expect(toggleLinePrefix(value, NotesLinePrefix.bullet).text, '- a\nb');
  });

  test('marks hug the words, leaving selected edge spaces outside', () {
    expect(
      show(toggleInlineMark(v('a [big ]turtle'), '**')),
      'a **[big]** turtle',
    );
  });
}
