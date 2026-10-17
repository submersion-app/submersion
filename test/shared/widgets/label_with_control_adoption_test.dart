// pre-push: scans lib/
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A `ListTile` lays its trailing widget out first, against the whole row's
/// width, and gives the title only what is left. A dropdown there takes the
/// width of its longest item, so in a longer translation the title was left
/// a few pixels and broke one character per line (#3358). Guard the whole
/// tree, because the next settings tile will be somewhere new.
void main() {
  final trailingArg = RegExp(r'^(\s*)trailing:\s*(.*)$');
  final dropdown = RegExp(r'^DropdownButton\b');

  // The trailing value, which `dart format` may put on the next code line
  // (after a comment, say) rather than beside `trailing:`.
  String trailingValue(List<String> lines, int index, String sameLine) {
    if (sameLine.isNotEmpty && !sameLine.startsWith('//')) return sameLine;
    for (var i = index + 1; i < lines.length; i++) {
      final next = lines[i].trim();
      if (next.isEmpty || next.startsWith('//')) continue;
      return next;
    }
    return '';
  }

  final listTileCall = RegExp(r'\bListTile(\.adaptive)?\(');

  // The call a named argument belongs to is the nearest line above it that
  // is indented less, as `dart format` lays arguments out.
  String? enclosingLine(List<String> lines, int index, int indent) {
    for (var i = index - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final lineIndent = line.length - line.trimLeft().length;
      if (lineIndent < indent) return line;
    }
    return null;
  }

  test('no ListTile puts a DropdownButton in trailing', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = trailingArg.firstMatch(lines[i]);
        if (match == null) continue;
        final value = trailingValue(lines, i, match.group(2)!.trim());
        if (!dropdown.hasMatch(value)) continue;
        final owner = enclosingLine(lines, i, match.group(1)!.length);
        if (owner != null && listTileCall.hasMatch(owner)) {
          offenders.add('${p.normalize(entity.path)}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Put the label and the dropdown in the title with LabelWithControl '
          '(lib/shared/widgets/label_with_control.dart), which moves the '
          'dropdown below the label when they cannot share a line.',
    );
  });
}
