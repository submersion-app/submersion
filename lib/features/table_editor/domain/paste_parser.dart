import 'package:flutter/foundation.dart';

/// A block of clipboard text as a spreadsheet copies it (#3422): rows on
/// newlines, cells on tabs, and a cell that holds a newline, a tab or a
/// quote wrapped in double quotes with every inner quote doubled. Cells
/// keep their text as pasted; the columns parse them.
@immutable
class PasteBlock {
  final List<List<String>> rows;

  const PasteBlock(this.rows);

  /// One cell with no tab or newline: pasted into the selected cell only.
  bool get isSingleValue => rows.length == 1 && rows.single.length == 1;

  int get columnCount => rows.fold(0, (w, r) => r.length > w ? r.length : w);
}

/// Splits on tabs and on Windows or Unix line endings, honouring quoted
/// cells, and drops the trailing empty lines a copy ends with.
PasteBlock parsePasteText(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        quoted = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    if (ch == '"' && cell.isEmpty) {
      quoted = true;
      i++;
      continue;
    }
    if (ch == '\t') {
      endCell();
      i++;
      continue;
    }
    if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      endRow();
      i += 2;
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      endRow();
      i++;
      continue;
    }
    cell.write(ch);
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  while (rows.isNotEmpty && rows.last.length == 1 && rows.last.single.isEmpty) {
    rows.removeLast();
  }
  return PasteBlock(rows);
}
