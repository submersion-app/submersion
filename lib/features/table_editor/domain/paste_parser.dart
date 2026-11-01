import 'package:flutter/foundation.dart';

/// A block of clipboard text as a spreadsheet copies it (#3422): rows on
/// newlines, cells on tabs. Cells keep their text as pasted; the columns
/// parse them.
@immutable
class PasteBlock {
  final List<List<String>> rows;

  const PasteBlock(this.rows);

  /// One cell with no tab or newline: pasted into the selected cell only.
  bool get isSingleValue => rows.length == 1 && rows.single.length == 1;

  int get columnCount => rows.fold(0, (w, r) => r.length > w ? r.length : w);
}

/// Splits on Windows or Unix line endings, drops the trailing empty line a
/// copy always ends with, and splits every row on tabs.
PasteBlock parsePasteText(String text) {
  final lines = text.split(RegExp('\r?\n'));
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return PasteBlock([for (final line in lines) line.split('\t')]);
}
