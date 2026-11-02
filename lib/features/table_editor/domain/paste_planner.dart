import 'package:flutter/foundation.dart';

import 'package:submersion/features/table_editor/domain/paste_parser.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// How a pasted block's rows found their records.
enum PasteMatching { byNumber, byName, byPosition }

/// One row of the sheet, in sheet order, with the keys a paste can match.
@immutable
class SheetRow {
  final String id;
  final int? number;
  final String? name;

  const SheetRow({required this.id, this.number, this.name});
}

enum PasteSkipReason {
  unknownRow,
  hiddenRow,
  ambiguousRow,
  readOnlyColumn,
  readOnlyCell,
  unknownColumn,
  truncated,
}

/// Something the paste could not place, for the summary.
@immutable
class PasteSkip {
  final PasteSkipReason reason;

  /// The key, header or column name concerned; empty for [truncated].
  final String detail;

  /// Rows or columns dropped, for [truncated].
  final int count;

  const PasteSkip(this.reason, {this.detail = '', this.count = 0});
}

/// A pasted cell: the record it lands on, the column, and the raw text.
typedef PastedCell<F> = ({String entityId, F field, String text});

@immutable
class PastePlan<F extends EntityField> {
  final PasteMatching matching;
  final bool hadHeader;
  final List<PastedCell<F>> cells;
  final List<PasteSkip> skipped;

  const PastePlan({
    required this.matching,
    required this.hadHeader,
    required this.cells,
    required this.skipped,
  });
}

/// Decides where every cell of [block] lands (#3422).
///
/// Rows match by key (dive number or name) when the block's header names the
/// key column, in any position, or when there is no header, the block has at
/// least two columns, and every filled row's first value is a key of a row on
/// the sheet. A headerless single column is always positional, since a column
/// of weights would otherwise read as dive numbers. Keys are matched against
/// the rows on the sheet only: a key in [hiddenKeys] is reported as hidden, or
/// as ambiguous when a row on the sheet shares it, and any other miss as
/// unknown, so a draft never lands on a row the diver cannot see.
///
/// Columns map through a header's labels, or fill rightward from the
/// selected column, skipping read-only ones. Positional rows fill downward
/// from the selected row; what runs past the sheet is reported as truncated.
PastePlan<F> planPaste<F extends EntityField>({
  required PasteBlock block,
  required List<SheetRow> rows,
  required int selectedRowIndex,
  required List<F> visibleColumns,
  required int selectedColumnIndex,
  required bool Function(F field) isEditableColumn,
  required F? Function(String header) columnFromLabel,
  required bool Function(String header) isKeyHeader,
  Set<String> hiddenKeys = const {},
  F? keyField,
}) {
  final skipped = <PasteSkip>[];
  final cells = <PastedCell<F>>[];
  // A selection that left the sheet (a filter or a save moved it) places
  // nothing rather than guess a cell; the page turns Paste off for it.
  final offSheet = selectedRowIndex < 0 || selectedColumnIndex < 0;
  if (block.rows.isEmpty || offSheet) {
    return PastePlan(
      matching: PasteMatching.byPosition,
      hadHeader: false,
      cells: cells,
      skipped: skipped,
    );
  }

  // The header row, when the first row is all column labels, holds at least
  // two among columns the sheet does not know, or names the key column beside
  // at least one of them. One label in a row of unknowns is not enough: "Boat"
  // is a label and an entry method. Nor is a key word alone: "No" is a key word
  // and a toggle value, and a lone column has nothing for a key to address.
  final first = block.rows.first;
  final mapped = [for (final h in first) columnFromLabel(h)];
  final keyWord = block.columnCount >= 2 ? first.indexWhere(isKeyHeader) : -1;
  final keyHeader =
      keyWord >= 0 &&
      mapped.indexed.any((c) => c.$1 != keyWord && c.$2 != null);
  final keyColumn = keyHeader ? keyWord : 0;
  final allLabels = first
      .asMap()
      .entries
      .where((e) => e.value.trim().isNotEmpty)
      .every((e) => mapped[e.key] != null || (e.key == keyWord && keyHeader));
  // A row of nothing but blanks is data (a sparse column starts that way),
  // never a header, and neither is one value, whatever it says.
  final hasLabel = first.any((h) => h.trim().isNotEmpty);
  final severalLabels = mapped.nonNulls.length >= 2;
  final hadHeader =
      !block.isSingleValue &&
      (keyHeader || severalLabels || (hasLabel && allLabels));
  final data = hadHeader ? block.rows.sublist(1) : block.rows;

  // Which block column carries the key, and which sheet column each data
  // column lands in. A header picks them by label; otherwise columns fill
  // rightward from the selected one.
  final byNumber = rows.any((r) => r.number != null);
  final keyOf = byNumber
      ? (SheetRow r) => r.number?.toString()
      : (SheetRow r) => r.name?.toLowerCase();
  final rowByKey = <String, SheetRow>{};
  final ambiguous = <String>{};
  for (final r in rows) {
    final k = keyOf(r);
    if (k == null) continue;
    if (rowByKey.containsKey(k)) {
      ambiguous.add(k);
    } else {
      rowByKey[k] = r;
    }
  }
  // A hidden row's key still reads as a key, so the row is reported as
  // hidden rather than the whole block sliding into position.
  final hidden = {for (final k in hiddenKeys) k.toLowerCase()};
  // A key a hidden row shares could mean either record, so it means neither.
  ambiguous.addAll(rowByKey.keys.where(hidden.contains));
  final knownKeys = {...rowByKey.keys, ...hidden, ...ambiguous};
  // A blank line between rows addresses nothing, here as in the rows below.
  bool everyFirstIsKey() {
    final filled = data.where((r) => r.any((c) => c.trim().isNotEmpty));
    return filled.isNotEmpty &&
        filled.every((r) => knownKeys.contains(r.first.trim().toLowerCase()));
  }

  final keyed =
      keyHeader || (!hadHeader && block.columnCount >= 2 && everyFirstIsKey());
  final matching = !keyed
      ? PasteMatching.byPosition
      : byNumber
      ? PasteMatching.byNumber
      : PasteMatching.byName;

  // Column targets per block column index; null drops the column.
  final targets = <F?>[];
  final reported = <F>{};
  final firstDataColumn = keyed ? 1 : 0;
  if (hadHeader) {
    for (var i = 0; i < first.length; i++) {
      if (i == keyColumn && keyHeader) {
        targets.add(null);
        continue;
      }
      final f = mapped[i];
      if (f == null) {
        if (first[i].trim().isNotEmpty) {
          skipped.add(
            PasteSkip(PasteSkipReason.unknownColumn, detail: first[i]),
          );
        }
        targets.add(null);
      } else if (!isEditableColumn(f)) {
        if (reported.add(f)) {
          skipped.add(
            PasteSkip(PasteSkipReason.readOnlyColumn, detail: f.name),
          );
        }
        targets.add(null);
      } else {
        targets.add(f);
      }
    }
  } else if (block.isSingleValue) {
    // One value goes into the selected cell, or nowhere.
    final f = selectedColumnIndex < visibleColumns.length
        ? visibleColumns[selectedColumnIndex]
        : null;
    if (f != null && !isEditableColumn(f)) {
      skipped.add(PasteSkip(PasteSkipReason.readOnlyColumn, detail: f.name));
    }
    targets.add(f != null && isEditableColumn(f) ? f : null);
  } else {
    var sheetIndex = selectedColumnIndex;
    var dropped = 0;
    for (var i = 0; i < block.columnCount; i++) {
      if (i < firstDataColumn) {
        targets.add(null);
        continue;
      }
      F? target;
      // Past the last sheet column there is nothing to skip, only to drop.
      if (sheetIndex >= visibleColumns.length) dropped++;
      while (sheetIndex < visibleColumns.length) {
        final f = visibleColumns[sheetIndex++];
        // The block's key names the row; it is never the block's own target,
        // or a selection in that column would rename every record.
        if (keyed && f == keyField) continue;
        if (isEditableColumn(f)) {
          target = f;
          break;
        }
        if (reported.add(f)) {
          skipped.add(
            PasteSkip(PasteSkipReason.readOnlyColumn, detail: f.name),
          );
        }
      }
      targets.add(target);
    }
    if (dropped > 0) {
      skipped.add(PasteSkip(PasteSkipReason.truncated, count: dropped));
    }
  }

  // Rows.
  var truncatedRows = 0;
  for (var r = 0; r < data.length; r++) {
    final row = data[r];
    final SheetRow? target;
    if (keyed) {
      // A blank line between rows addresses nothing.
      if (row.every((c) => c.trim().isEmpty)) continue;
      final raw = keyColumn < row.length ? row[keyColumn].trim() : '';
      final key = raw.toLowerCase();
      if (ambiguous.contains(key)) {
        skipped.add(PasteSkip(PasteSkipReason.ambiguousRow, detail: raw));
        continue;
      }
      target = rowByKey[key];
      if (target == null) {
        skipped.add(
          PasteSkip(
            hidden.contains(key)
                ? PasteSkipReason.hiddenRow
                : PasteSkipReason.unknownRow,
            detail: raw,
          ),
        );
        continue;
      }
    } else {
      final index = selectedRowIndex + r;
      if (index >= rows.length) {
        truncatedRows++;
        continue;
      }
      target = rows[index];
    }
    for (var c = 0; c < row.length && c < targets.length; c++) {
      final f = targets[c];
      if (f == null) continue;
      cells.add((entityId: target.id, field: f, text: row[c]));
    }
  }
  if (truncatedRows > 0) {
    skipped.add(PasteSkip(PasteSkipReason.truncated, count: truncatedRows));
  }
  // Past the header's last cell there is no label to say where a cell goes.
  if (hadHeader && block.columnCount > first.length) {
    skipped.add(
      PasteSkip(
        PasteSkipReason.truncated,
        count: block.columnCount - first.length,
      ),
    );
  }
  return PastePlan(
    matching: matching,
    hadHeader: hadHeader,
    cells: cells,
    skipped: skipped,
  );
}
