import 'package:drift/drift.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
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
/// serial is left alone, since it records which unit actually answered.
///
/// A downloaded Shearwater copy with no linked computer to compare against
/// is converted from decimal to hex by its characters, which is safe only
/// for the lengths a stored hex never has; an 8-digit copy is left as it is,
/// the same rule `healShearwaterDownloadSerials` keeps on an ordinary open.
///
/// Dives are touched only when a downloaded source on the dive links the
/// same computer, so a file import's dive attributed by model alone never
/// gains a serial it was not given.
///
/// Local-only and idempotent: no HLC bump, no pending mark, `updated_at`
/// untouched. Every device on this version derives the same value, so a
/// synced fleet converges without traffic, and it runs again after an
/// inbound sync apply for rows a peer below this version sends. [computerId]
/// limits it to one computer's rows, as a download that just learned its
/// serial does.
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

  var changed = await _healLinkedSources(db, computerId);
  changed += await _healUnlinkedShearwaterSources(db, sourceCols, computerId);
  final diveCols = await tableColumnNames(db, 'dives');
  if (diveCols.containsAll(const {
    'id',
    'computer_id',
    'dive_computer_serial',
  })) {
    changed += await _healLinkedDives(db, computerId);
    if (computerId == null && diveCols.contains('dive_computer_model')) {
      changed += await _healUnlinkedShearwaterDives(db);
    }
  }
  return changed;
}

/// The hex for a downloaded Shearwater [serial] stored in decimal, or null
/// when it is not one: an 8-digit value is ambiguous and stays.
String? _unlinkedShearwaterHex(String serial, {String? vendor, String? model}) {
  if (!isAllDigitsSerial(serial) || serial.length == 8) return null;
  if (!isShearwaterFamily(manufacturer: vendor, model: model)) return null;
  final hex = canonicalDownloadedSerial(vendor: 'Shearwater', serial: serial);
  return hex == serial ? null : hex;
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

Future<int> _healLinkedSources(
  DatabaseConnectionUser db,
  String? computerId,
) async {
  final rows = await db
      .customSelect(
        'SELECT s.id, s.computer_serial, c.serial_number, c.manufacturer, '
        'c.model FROM dive_data_sources s '
        'JOIN dive_computers c ON c.id = s.computer_id '
        "WHERE s.source_format = 'dive_computer' "
        "AND TRIM(COALESCE(c.serial_number, '')) <> '' "
        'AND (s.computer_serial IS NULL OR s.computer_serial <> c.serial_number)'
        '${computerId == null ? '' : ' AND c.id = ?'}',
        variables: [if (computerId != null) Variable<String>(computerId)],
      )
      .get();
  var changed = 0;
  for (final row in rows) {
    final target = _linkedTarget(
      current: row.readNullable<String>('computer_serial'),
      computerSerial: row.read<String>('serial_number').trim(),
      shearwater: isShearwaterFamily(
        manufacturer: row.readNullable<String>('manufacturer'),
        model: row.readNullable<String>('model'),
      ),
    );
    if (target == null) continue;
    await db.customStatement(
      'UPDATE dive_data_sources SET computer_serial = ? WHERE id = ?',
      [target, row.read<String>('id')],
    );
    changed++;
  }
  return changed;
}

Future<int> _healUnlinkedShearwaterSources(
  DatabaseConnectionUser db,
  Set<String> sourceCols,
  String? computerId,
) async {
  // Scoped to one computer, the linked pass above has done all there is.
  if (computerId != null) return 0;
  final hasModel = sourceCols.contains('computer_model');
  final hasVendor = sourceCols.containsAll(const {
    'descriptor_vendor',
    'descriptor_product',
  });
  final rows = await db.customSelect('''
    SELECT s.id, s.computer_serial,
      ${hasModel ? 's.computer_model' : 'NULL'} AS computer_model,
      ${hasVendor ? 's.descriptor_vendor' : 'NULL'} AS descriptor_vendor,
      ${hasVendor ? 's.descriptor_product' : 'NULL'} AS descriptor_product
    FROM dive_data_sources s
    WHERE s.source_format = 'dive_computer'
      AND s.computer_serial IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dive_computers c WHERE c.id = s.computer_id
        AND TRIM(COALESCE(c.serial_number, '')) <> '')
  ''').get();
  var changed = 0;
  for (final row in rows) {
    final hex = _unlinkedShearwaterHex(
      row.read<String>('computer_serial').trim(),
      vendor: row.readNullable<String>('descriptor_vendor'),
      model:
          row.readNullable<String>('computer_model') ??
          row.readNullable<String>('descriptor_product'),
    );
    if (hex == null) continue;
    await db.customStatement(
      'UPDATE dive_data_sources SET computer_serial = ? WHERE id = ?',
      [hex, row.read<String>('id')],
    );
    changed++;
  }
  return changed;
}

Future<int> _healLinkedDives(
  DatabaseConnectionUser db,
  String? computerId,
) async {
  final rows = await db
      .customSelect(
        'SELECT d.id, d.dive_computer_serial, c.serial_number, '
        'c.manufacturer, c.model FROM dives d '
        'JOIN dive_computers c ON c.id = d.computer_id '
        "WHERE TRIM(COALESCE(c.serial_number, '')) <> '' "
        'AND (d.dive_computer_serial IS NULL '
        'OR d.dive_computer_serial <> c.serial_number) '
        'AND EXISTS (SELECT 1 FROM dive_data_sources s '
        'WHERE s.dive_id = d.id AND s.computer_id = d.computer_id '
        "AND s.source_format = 'dive_computer')"
        '${computerId == null ? '' : ' AND c.id = ?'}',
        variables: [if (computerId != null) Variable<String>(computerId)],
      )
      .get();
  var changed = 0;
  for (final row in rows) {
    final target = _linkedTarget(
      current: row.readNullable<String>('dive_computer_serial'),
      computerSerial: row.read<String>('serial_number').trim(),
      shearwater: isShearwaterFamily(
        manufacturer: row.readNullable<String>('manufacturer'),
        model: row.readNullable<String>('model'),
      ),
    );
    if (target == null) continue;
    await db.customStatement(
      'UPDATE dives SET dive_computer_serial = ? WHERE id = ?',
      [target, row.read<String>('id')],
    );
    changed++;
  }
  return changed;
}

/// A downloaded dive whose computer record has no serial to copy, or none
/// at all, still converts a decimal Shearwater serial by its characters.
Future<int> _healUnlinkedShearwaterDives(DatabaseConnectionUser db) async {
  final rows = await db.customSelect('''
    SELECT d.id, d.dive_computer_serial, d.dive_computer_model
    FROM dives d
    WHERE d.dive_computer_serial IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dive_computers c WHERE c.id = d.computer_id
        AND TRIM(COALESCE(c.serial_number, '')) <> '')
      AND EXISTS (SELECT 1 FROM dive_data_sources s
        WHERE s.dive_id = d.id AND s.source_format = 'dive_computer')
  ''').get();
  var changed = 0;
  for (final row in rows) {
    final hex = _unlinkedShearwaterHex(
      row.read<String>('dive_computer_serial').trim(),
      model: row.readNullable<String>('dive_computer_model'),
    );
    if (hex == null) continue;
    await db.customStatement(
      'UPDATE dives SET dive_computer_serial = ? WHERE id = ?',
      [hex, row.read<String>('id')],
    );
    changed++;
  }
  return changed;
}
