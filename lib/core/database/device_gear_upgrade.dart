import 'package:drift/drift.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// The ladder-only steps of the v316 upgrade (issue #3676), beside
/// [ensureDeviceGearLinks], which also runs on every open and after sync.
///
/// Ladder-only because each acts on history once: rerunning the name and
/// notes pass would keep appending notes, and rerunning the serial pass would
/// bring back a transmitter the diver deleted. Rows are written with a NULL
/// hlc, for the reason the heal gives: the next sync publishes them, so
/// devices that upgraded from different states converge.

/// Makes each linked computer and its item carry one name and one set of
/// notes. The name the diver chose wins: a row still named after the device
/// (its brand and model) gives way to the other. `updated_at` cannot decide
/// it, since every download bumps the computer's. When both were renamed the
/// item's name is kept, as the entry the diver edits from now on. Notes are never
/// dropped: blank item notes take the computer's, and when both differ the
/// computer's go below the item's, since the v175 twins were all seeded with
/// blank notes and the old computer edit dialog was where divers wrote them.
Future<void> alignComputerNamesAndNotes(DatabaseConnectionUser db) async {
  final computerCols = await _columnsOf(db, 'dive_computers');
  final equipmentCols = await _columnsOf(db, 'equipment');
  if (!computerCols.containsAll({
        'id',
        'name',
        'notes',
        'manufacturer',
        'model',
        'equipment_id',
      }) ||
      !equipmentCols.containsAll({'id', 'name', 'notes', 'brand', 'model'})) {
    return;
  }
  final pairs = await db
      .customSelect(
        'SELECT c.id AS cid, c.name AS cname, c.notes AS cnotes, '
        'c.manufacturer AS cmaker, c.model AS cmodel, e.id AS eid, '
        'e.brand AS ebrand, '
        'e.model AS emodel '
        'FROM dive_computers c JOIN equipment e ON e.id = c.equipment_id',
      )
      .get();
  for (final p in pairs) {
    final computerName = p.read<String>('cname');
    // Read the item afresh: two registrations can share one item, and the
    // first pair's write must not be overwritten from a stale copy.
    final current = await db
        .customSelect(
          'SELECT name, notes FROM equipment WHERE id = ?',
          variables: [Variable<String>(p.read<String>('eid'))],
        )
        .getSingle();
    final itemName = current.read<String>('name');
    final itemNotes = current.read<String>('notes');
    final itemIsDefault = _isDeviceName(
      itemName,
      brands: [p.read<String?>('ebrand'), p.read<String?>('cmaker')],
      models: [p.read<String?>('emodel'), p.read<String?>('cmodel')],
    );
    final computerIsDefault = _isDeviceName(
      computerName,
      brands: [p.read<String?>('cmaker'), p.read<String?>('ebrand')],
      models: [p.read<String?>('cmodel'), p.read<String?>('emodel')],
    );
    final name = itemIsDefault && !computerIsDefault ? computerName : itemName;
    final notes = _mergedNotes(
      itemNotes: itemNotes,
      computerNotes: p.read<String>('cnotes'),
    );
    // Only rows that change are written, each with a NULL hlc so the next
    // sync publishes it (see ensureDeviceGearLinks).
    if (name != itemName || notes != itemNotes) {
      await db.customStatement(
        'UPDATE equipment SET name = ?, notes = ?'
        '${await clearHlcSql(db, 'equipment')} WHERE id = ?',
        [name, notes, p.read<String>('eid')],
      );
    }
    if (name != computerName || notes != p.read<String>('cnotes')) {
      await db.customStatement(
        'UPDATE dive_computers SET name = ?, notes = ?'
        '${await clearHlcSql(db, 'dive_computers')} WHERE id = ?',
        [name, notes, p.read<String>('cid')],
      );
    }
  }
}

/// Whether [name] is just the device's own name, "Shearwater Teric" or
/// "Teric", rather than one the diver chose.
bool _isDeviceName(
  String name, {
  required List<String?> brands,
  required List<String?> models,
}) {
  final wanted = normalizeComputerIdentityPart(name);
  if (wanted.isEmpty) return true;
  for (final model in models) {
    if (normalizeComputerIdentityPart(model).isEmpty) continue;
    if (wanted == normalizeComputerIdentityPart(model)) return true;
    for (final brand in brands) {
      if (wanted == computerFullName(brand, model)) return true;
    }
  }
  return false;
}

String _mergedNotes({
  required String itemNotes,
  required String computerNotes,
}) {
  final item = itemNotes.trim();
  final computer = computerNotes.trim();
  if (computer.isEmpty || computer == item) return itemNotes;
  if (item.isEmpty) return computerNotes;
  return '$itemNotes\n\n$computerNotes';
}

/// Registers every transmitter serial seen on a diver's downloaded tanks that
/// the diver has no registry row for, as a download now does: a row the
/// diver has not configured yet, and its Transmitter item (an existing one
/// with that serial when exactly one exists). Returns the rows created.
///
/// The rung cannot read the app's localizations, so the stored name is the
/// English placeholder; the diver renames it when setting it up.
Future<int> registerUnassignedSerials(DatabaseConnectionUser db) async {
  final txCols = await _columnsOf(db, 'transmitters');
  final tankCols = await _columnsOf(db, 'dive_tanks');
  if (!txCols.containsAll({
        'id',
        'diver_id',
        'transmitter_serial',
        'label',
        'tank_role',
        'transmitter_equipment_id',
        'is_configured',
        'created_at',
        'updated_at',
      }) ||
      !tankCols.containsAll({'dive_id', 'transmitter_serial', 'tank_role'}) ||
      !(await _columnsOf(
        db,
        'dives',
      )).containsAll({'id', 'diver_id', 'dive_date_time'})) {
    return 0;
  }
  final known = <String>{
    for (final r
        in await db
            .customSelect(
              'SELECT diver_id, transmitter_serial FROM transmitters',
            )
            .get())
      if (normalizeTransmitterSerial(r.read<String?>('transmitter_serial'))
          case final s?)
        '${r.read<String?>('diver_id') ?? ''}|$s',
  };
  // Newest dive first, so the role recorded is the latest one the computer
  // reported for that transmitter.
  final seen = await db
      .customSelect(
        'SELECT d.diver_id AS diver_id, dt.transmitter_serial AS serial, '
        'dt.tank_role AS role FROM dive_tanks dt '
        'JOIN dives d ON d.id = dt.dive_id '
        'WHERE dt.transmitter_serial IS NOT NULL '
        'ORDER BY d.dive_date_time DESC, d.id',
      )
      .get();
  var created = 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  final hasLog = (await _columnsOf(db, 'deletion_log')).isNotEmpty;
  for (final r in seen) {
    final serial = normalizeTransmitterSerial(r.read<String?>('serial'));
    if (serial == null) continue;
    final diverId = r.read<String?>('diver_id');
    if (!known.add('${diverId ?? ''}|$serial')) continue;
    // A peer that upgraded first registered it and the diver deleted it
    // there: re-creating it here would publish it back to every device.
    final rowId = autoTransmitterRowId(diverId, serial);
    if (hasLog && await _isTombstoned(db, 'transmitters', rowId)) continue;

    final name = 'Transmitter $serial';
    final itemId =
        await matchTransmitterItem(db, serial: serial, diverId: diverId) ??
        await liveGearId(
          db,
          transmitterGearSeedId(diverId, serial),
          transmitterGearDeviceKey(diverId, serial),
          type: 'transmitter',
        );
    await mintDeviceGearItem(
      db,
      id: itemId,
      diverId: diverId,
      name: name,
      type: 'transmitter',
      serial: serial,
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO transmitters (id, diver_id, transmitter_serial, '
      'label, tank_role, transmitter_equipment_id, is_configured, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)',
      [
        rowId,
        diverId,
        serial,
        name,
        r.read<String?>('role') ?? 'backGas',
        itemId,
        now,
        now,
      ],
    );
    created++;
  }
  return created;
}

/// Puts every transmitter item on the gear of each dive whose tanks carry
/// one of its rows' serials, as v175 did for computers.
Future<void> linkTransmitterGearToDives(DatabaseConnectionUser db) async {
  final junction = await _columnsOf(db, 'dive_equipment');
  final txCols = await _columnsOf(db, 'transmitters');
  if (!junction.containsAll({'dive_id', 'equipment_id'}) ||
      !txCols.containsAll({
        'diver_id',
        'transmitter_serial',
        'transmitter_equipment_id',
      }) ||
      !(await _columnsOf(
        db,
        'dive_tanks',
      )).containsAll({'dive_id', 'transmitter_serial'}) ||
      !(await _columnsOf(db, 'dives')).containsAll({'id', 'diver_id'})) {
    return;
  }
  final items = <String, String>{};
  for (final r
      in await db
          .customSelect(
            'SELECT diver_id, transmitter_serial, transmitter_equipment_id '
            'FROM transmitters WHERE transmitter_equipment_id IS NOT NULL',
          )
          .get()) {
    final serial = normalizeTransmitterSerial(
      r.read<String?>('transmitter_serial'),
    );
    if (serial == null) continue;
    items['${r.read<String?>('diver_id') ?? ''}|$serial'] = r.read<String>(
      'transmitter_equipment_id',
    );
  }
  if (items.isEmpty) return;
  final tanks = await db
      .customSelect(
        'SELECT dt.dive_id AS dive_id, d.diver_id AS diver_id, '
        'dt.transmitter_serial AS serial FROM dive_tanks dt '
        'JOIN dives d ON d.id = dt.dive_id '
        'WHERE dt.transmitter_serial IS NOT NULL',
      )
      .get();
  for (final t in tanks) {
    final serial = normalizeTransmitterSerial(t.read<String?>('serial'));
    if (serial == null) continue;
    final itemId = items['${t.read<String?>('diver_id') ?? ''}|$serial'];
    if (itemId == null) continue;
    await db.customStatement(
      'INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id) '
      'VALUES (?, ?)',
      [t.read<String>('dive_id'), itemId],
    );
  }
}

Future<bool> _isTombstoned(
  DatabaseConnectionUser db,
  String entityType,
  String id,
) async =>
    await db
        .customSelect(
          'SELECT 1 FROM deletion_log WHERE entity_type = ? '
          'AND record_id = ? LIMIT 1',
          variables: [Variable<String>(entityType), Variable<String>(id)],
        )
        .getSingleOrNull() !=
    null;

Future<Set<String>> _columnsOf(DatabaseConnectionUser db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((c) => c.read<String>('name')).toSet();
}
