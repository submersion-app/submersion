import 'package:drift/drift.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/table_columns.dart';

/// Connection types a download writes, the provenance that marks a stored
/// serial as libdivecomputer's decimal.
const Set<String> _directConnectionTypes = {
  'bluetooth',
  'ble',
  'bluetoothclassic',
  'usb',
  'infrared',
};

/// Rewrite the serial of every DOWNLOADED Shearwater computer from the
/// decimal libdivecomputer reports to the 8-character uppercase hex the
/// computer shows (issue #3106). Returns how many rows changed.
///
/// Only download provenance identifies a decimal serial. A Shearwater Cloud
/// export keeps the hex text of the log filename, and an all-digit hex
/// serial such as `12345678` cannot be told from a decimal one by its
/// characters, so a row qualifies only when its connection type is a direct
/// transport or a `source_format = 'dive_computer'` data source points at it.
///
/// An 8-digit serial is ambiguous once this build has run: the hex it
/// stores for a download can be all digits (`0x12345678` is stored as
/// `12345678`), and a file import's all-digit hex can sit on a row a later
/// download rebound to Bluetooth. So an ordinary open converts only the
/// lengths a stored hex never has; [includeAmbiguous] adds the 8-digit
/// serials, and only the v279 rung passes it, once, before this build has
/// written any hex.
///
/// Local-only and idempotent: no HLC bump, no pending mark, `updated_at`
/// untouched. Every device on this version derives the same value, so a
/// synced fleet converges without traffic, and no device pushes a restamp
/// that could override a rename made elsewhere. Matching treats both forms
/// as one serial, so a peer that has not upgraded yet still lines up.
Future<int> healShearwaterDownloadSerials(
  DatabaseConnectionUser db, {
  bool includeAmbiguous = false,
}) async {
  // PRAGMA-guarded like every other self-heal: beforeOpen also runs on
  // minimal old-schema fixtures and databases caught mid-upgrade.
  Future<Set<String>> columnsOf(String table) => tableColumnNames(db, table);

  final computerCols = await columnsOf('dive_computers');
  if (!computerCols.containsAll({
    'id',
    'manufacturer',
    'model',
    'serial_number',
    'connection_type',
  })) {
    return 0;
  }
  final sourceCols = await columnsOf('dive_data_sources');
  final downloadedExpr =
      sourceCols.containsAll({'computer_id', 'source_format'})
      ? "EXISTS (SELECT 1 FROM dive_data_sources s WHERE s.computer_id = c.id "
            "AND s.source_format = 'dive_computer')"
      : '0';

  final rows = await db.customSelect('''
    SELECT c.id, c.manufacturer, c.model, c.serial_number, c.connection_type,
      $downloadedExpr AS downloaded
    FROM dive_computers c
    WHERE c.serial_number IS NOT NULL
  ''').get();

  var rewritten = 0;
  for (final row in rows) {
    final serial = row.read<String>('serial_number').trim();
    if (!isAllDigitsSerial(serial)) continue;
    if (serial.length == 8 && !includeAmbiguous) continue;
    if (!isShearwaterFamily(
      manufacturer: row.readNullable<String>('manufacturer'),
      model: row.readNullable<String>('model'),
    )) {
      continue;
    }
    final connection = row
        .readNullable<String>('connection_type')
        ?.trim()
        .toLowerCase();
    final downloaded =
        _directConnectionTypes.contains(connection) ||
        row.read<int>('downloaded') == 1;
    if (!downloaded) continue;

    final hex = canonicalDownloadedSerial(vendor: 'Shearwater', serial: serial);
    if (hex == null || hex == serial) continue;
    await db.customStatement(
      'UPDATE dive_computers SET serial_number = ? WHERE id = ?',
      [hex, row.read<String>('id')],
    );
    rewritten++;
  }
  return rewritten;
}
