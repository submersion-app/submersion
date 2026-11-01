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
  readOnlyColumn,
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
/// key column, or when there is no header, the block has at least two
/// columns, and every first-column value is a key of a row on the sheet. A
/// headerless single column is always positional, since a column of weights
/// would otherwise read as dive numbers. Keys are matched against the rows
/// on the sheet only: a key in [hiddenKeys] is reported as hidden, any other
/// miss as unknown, so a draft never lands on a row the diver cannot see.
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
}) {
  final skipped = <PasteSkip>[];
  final cells = <PastedCell<F>>[];
  if (block.rows.isEmpty) {
    return PastePlan(
      matching: PasteMatching.byPosition,
      hadHeader: false,
      cells: cells,
      skipped: skipped,
    );
  }

  // The header row, when the first row is all column labels (or names the
  // key column first).
  final first = block.rows.first;
  final keyHeader = first.isNotEmpty && isKeyHeader(first.first);
  final mapped = [for (final h in first) columnFromLabel(h)];
  final allLabels = first
      .asMap()
      .entries
      .where((e) => e.value.trim().isNotEmpty)
      .every((e) => mapped[e.key] != null || (e.key == 0 && keyHeader));
  final hadHeader = keyHeader || (first.isNotEmpty && allLabels);
  final data = hadHeader ? block.rows.sublist(1) : block.rows;

  // Which block column carries the key, and which sheet column each data
  // column lands in. A header picks them by label; otherwise columns fill
  // rightward from the selected one.
  final byNumber = rows.any((r) => r.number != null);
  final keyOf = byNumber
      ? (SheetRow r) => r.number?.toString()
      : (SheetRow r) => r.name?.toLowerCase();
  final rowByKey = <String, SheetRow>{for (final r in rows) ?keyOf(r): r};
  // A hidden row's key still reads as a key, so the row is reported as
  // hidden rather than the whole block sliding into position.
  final knownKeys = {
    ...rowByKey.keys,
    for (final k in hiddenKeys) k.toLowerCase(),
  };
  bool everyFirstIsKey() =>
      data.isNotEmpty &&
      data.every(
        (r) => r.isNotEmpty && knownKeys.contains(r.first.trim().toLowerCase()),
      );
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
      if (i == 0 && keyHeader) {
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
      final key = row.isEmpty ? '' : row.first.trim().toLowerCase();
      target = rowByKey[key];
      if (target == null) {
        final raw = row.isEmpty ? '' : row.first.trim();
        skipped.add(
          PasteSkip(
            hiddenKeys.contains(raw)
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
  return PastePlan(
    matching: matching,
    hadHeader: hadHeader,
    cells: cells,
    skipped: skipped,
  );
}
