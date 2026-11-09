import 'package:drift/drift.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/shearwater_serial_heal.dart';
import 'package:submersion/core/database/table_columns.dart';

/// Brings the serial a download copied onto its `dive_data_sources` row and
/// its dive (`computer_serial`, `dives.dive_computer_serial`) in line with
/// the computer it came from (issue #4368). Returns how many rows changed.
///
/// Those copies are written while the dives are saved and never again, so a
/// copy can disagree with the computer record in two ways:
///
/// * **Empty.** libdivecomputer reports the serial only when a download
///   completes, so a computer's first download saved its dives before the
///   record knew its serial.
/// * **Decimal.** A Shearwater download stored libdivecomputer's decimal
///   until issue #3106 switched to the hex the computer shows, and that
///   switch rewrote only the computer record.
///
/// A copy on a row linked to a computer takes that computer's serial when it
/// is empty or names the same serial in the other radix. Copying from the
/// record, rather than converting digits, settles the 8-digit case the
/// characters cannot: `12345678` is a decimal or an all-digit hex, and only
/// the computer's own spelling says which. A copy that names a different
/// serial is not replaced, since it records which unit actually answered.
///
/// Any downloaded Shearwater copy still in decimal after that (no computer,
/// a computer with no serial, or another unit's serial) is converted to hex
/// by its characters, which is safe only for the lengths a stored hex never
/// has; an 8-digit copy is left as it is, the rule
/// `healShearwaterDownloadSerials` keeps on an ordinary open.
///
/// Dives are touched only when a downloaded source on the dive is from the
/// same computer (or, for the conversion, from any computer), so a file
/// import's dive attributed by model alone never gains a serial it was not
/// given.
///
/// Local-only and idempotent: no HLC bump, no pending mark, `updated_at`
/// untouched. Every device on this version derives the same value, so a
/// synced fleet converges without traffic, and it runs again after an
/// inbound sync apply for rows a peer below this version sends.
/// [computerId] limits it to the copies linked to one computer, as saving
/// that computer does; the conversion by characters then waits for the next
/// whole-library run.
Future<int> healDownloadedSnapshotSerials(
  DatabaseConnectionUser db, {
  String? computerId,
}) async {
  final computerCols = await tableColumnNames(db, 'dive_computers');
  final sourceCols = await tableColumnNames(db, 'dive_data_sources');
  if (!computerCols.containsAll(const {
        'id',
        'manufacturer',
        'model',
        'serial_number',
      }) ||
      !sourceCols.containsAll(const {
        'id',
        'dive_id',
        'computer_id',
        'computer_serial',
        'source_format',
      })) {
    return 0;
  }
  final diveCols = await tableColumnNames(db, 'dives');
  final hasDiveCopies = diveCols.containsAll(const {
    'id',
    'computer_id',
    'dive_computer_serial',
  });

  var changed = await _healLinked(db, _sourceCopies, computerId);
  if (hasDiveCopies) {
    changed += await _healLinked(db, _diveCopies, computerId);
  }
  if (computerId != null) return changed;

  final hasVendor = sourceCols.containsAll(const {
    'descriptor_vendor',
    'descriptor_product',
  });
  final sourceModel = sourceCols.contains('computer_model')
      ? (hasVendor
            ? 'COALESCE(s.computer_model, s.descriptor_product)'
            : 's.computer_model')
      : (hasVendor ? 's.descriptor_product' : 'NULL');
  changed += await _convertDecimal(
    db,
    table: 'dive_data_sources',
    column: 'computer_serial',
    vendorExpr: hasVendor ? 's.descriptor_vendor' : 'NULL',
    modelExpr: sourceModel,
    where: "s.source_format = 'dive_computer'",
  );
  if (hasDiveCopies && diveCols.contains('dive_computer_model')) {
    changed += await _convertDecimal(
      db,
      table: 'dives',
      column: 'dive_computer_serial',
      vendorExpr: 'NULL',
      modelExpr: 's.dive_computer_model',
      where: _hasDownloadedSource(sameComputer: false),
    );
  }
  return changed;
}

/// A table that holds a download's serial copy beside a `computer_id` link.
typedef _Copies = ({String table, String column, String where});

const _Copies _sourceCopies = (
  table: 'dive_data_sources',
  column: 'computer_serial',
  where: "s.source_format = 'dive_computer'",
);

final _Copies _diveCopies = (
  table: 'dives',
  column: 'dive_computer_serial',
  where: _hasDownloadedSource(sameComputer: true),
);

/// SQL true for a dive (aliased `s`) with a downloaded source, from its own
/// computer when [sameComputer].
String _hasDownloadedSource({required bool sameComputer}) =>
    'EXISTS (SELECT 1 FROM dive_data_sources x WHERE x.dive_id = s.id '
    "${sameComputer ? 'AND x.computer_id = s.computer_id ' : ''}"
    "AND x.source_format = 'dive_computer')";

/// Copies a linked computer's serial onto the [copies] it should replace.
Future<int> _healLinked(
  DatabaseConnectionUser db,
  _Copies copies,
  String? computerId,
) async {
  final column = 's.${copies.column}';
  final rows = await db
      .customSelect(
        'SELECT s.id, $column AS copy, c.serial_number, c.manufacturer, '
        'c.model FROM ${copies.table} s '
        'JOIN dive_computers c ON c.id = s.computer_id '
        'WHERE ${copies.where} '
        "AND TRIM(COALESCE(c.serial_number, '')) <> '' "
        'AND ($column IS NULL OR $column <> c.serial_number)'
        '${computerId == null ? '' : ' AND c.id = ?'}',
        variables: [if (computerId != null) Variable<String>(computerId)],
      )
      .get();
  var changed = 0;
  for (final row in rows) {
    final target = _linkedTarget(
      current: row.readNullable<String>('copy'),
      computerSerial: row.read<String>('serial_number').trim(),
      shearwater: isShearwaterFamily(
        manufacturer: row.readNullable<String>('manufacturer'),
        model: row.readNullable<String>('model'),
      ),
    );
    if (target == null) continue;
    await db.customStatement(
      'UPDATE ${copies.table} SET ${copies.column} = ? WHERE id = ?',
      [target, row.read<String>('id')],
    );
    changed++;
  }
  return changed;
}

/// The serial [current] should become to match a computer stored as
/// [computerSerial], or null to leave it.
String? _linkedTarget({
  required String? current,
  required String computerSerial,
  required bool shearwater,
}) {
  final value = current?.trim() ?? '';
  if (value.isEmpty) return computerSerial;
  if (value == computerSerial) return null;
  return computerSerialsMatch(value, computerSerial, shearwater: shearwater)
      ? computerSerial
      : null;
}

/// Converts the decimal Shearwater copies in [table] (aliased `s`) that
/// match [where] to hex, by their characters. A copy that is its linked
/// computer's own serial is settled already and never reconverted.
Future<int> _convertDecimal(
  DatabaseConnectionUser db, {
  required String table,
  required String column,
  required String vendorExpr,
  required String modelExpr,
  required String where,
}) async {
  final rows = await db.customSelect('''
    SELECT s.id, s.$column AS copy, $vendorExpr AS vendor, $modelExpr AS model
    FROM $table s
    WHERE $where AND ${decimalSerialCandidateSql('s.$column')}
      AND NOT EXISTS (SELECT 1 FROM dive_computers c
        WHERE c.id = s.computer_id AND c.serial_number = s.$column)
  ''').get();
  var changed = 0;
  for (final row in rows) {
    final hex = downloadedShearwaterSerialHex(
      row.read<String>('copy'),
      manufacturer: row.readNullable<String>('vendor'),
      model: row.readNullable<String>('model'),
    );
    if (hex == null) continue;
    await db.customStatement('UPDATE $table SET $column = ? WHERE id = ?', [
      hex,
      row.read<String>('id'),
    ]);
    changed++;
  }
  return changed;
}
