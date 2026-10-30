import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/database/table_columns.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// What one [ensureDeviceGearLinks] pass changed.
typedef DeviceGearHealResult = ({
  int computersLinked,
  int computerItemsMinted,
  int transmittersLinked,
  int transmitterItemsMinted,
});

/// The chain key every transmitter item minted from a serial uses, so the
/// heal, the upgrade and a download walk the same [nextGearRemintId] chain.
String transmitterGearDeviceKey(String? diverId, String normalizedSerial) =>
    'tx:${diverId ?? ''}:$normalizedSerial';

/// Whether [id] was deleted as an equipment row, here or on a peer: every
/// device logs the tombstones it applies, so all of them answer alike.
Future<bool> isEquipmentTombstoned(DatabaseConnectionUser db, String id) async {
  final row = await db
      .customSelect(
        "SELECT 1 FROM deletion_log WHERE entity_type = 'equipment' "
        'AND record_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      )
      .getSingleOrNull();
  return row != null;
}

/// [firstId], or the first id after it in the [nextGearRemintId] chain that
/// no tombstone names and no item of another type holds (a twin the diver
/// retyped before v316 locked the type, issue #3676); [type] is the
/// `equipment.type` the device's item needs. Bounded at 64 steps, far past
/// any real number of deletions of one device's item; the last id walked is
/// returned then.
Future<String> liveGearId(
  DatabaseConnectionUser db,
  String firstId,
  String deviceKey, {
  required String type,
}) async {
  final hasLog = (await tableColumnNames(db, 'deletion_log')).isNotEmpty;
  var id = firstId;
  for (var step = 0; step < 64; step++) {
    final tombstoned = hasLog && await isEquipmentTombstoned(db, id);
    if (!tombstoned && !await _heldByOtherType(db, id, type)) return id;
    id = nextGearRemintId(deviceKey, id);
  }
  return id;
}

Future<bool> _heldByOtherType(
  DatabaseConnectionUser db,
  String id,
  String type,
) async {
  final row = await db
      .customSelect(
        'SELECT type FROM equipment WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingleOrNull();
  return row != null && row.read<String>('type') != type;
}

/// Gives every registered dive computer and every transmitter registry row
/// the Equipment item that is its one entry (issue #3676).
///
/// A device can lose its item three ways: a twin deleted before v316 (the
/// FK nulled the link and nothing re-created it then), an older peer that
/// still deletes twins as "unlink only", and a sync that applies a computer
/// whose item this device never had. Each pass resolves, in order:
///
///   1. the stored link, when its row still exists (nothing to do)
///   2. the row at the device's live chain id, which a peer may have minted
///   3. exactly one identity match ([matchGearTwin] for computers, the
///      canonical serial for transmitters), any status except `wanted`
///   4. a new item at the live chain id
///
/// Safe to run on every open and after every sync: a linked device is never
/// touched, so a second pass changes nothing.
///
/// Every row it writes is left with a NULL hlc, unlike the v175 backfill, so
/// the next sync's `backfillMissingHlc` stamps and publishes it. The ids are
/// derived, so devices healing from the same state agree on their own; but a
/// device can heal before it has pulled a peer's item, or after the fleet has
/// collected an old tombstone, and then only publishing lets last-writer-wins
/// bring the fleet back to one link. The cost is a handful of records, once.
/// No clock is issued here: this runs inside migrations and beforeOpen, where
/// the sync clock may not be configured yet.
Future<DeviceGearHealResult> ensureDeviceGearLinks(
  DatabaseConnectionUser db,
) async {
  final equipmentCols = await tableColumnNames(db, 'equipment');
  if (!equipmentCols.containsAll(_mintColumns)) {
    return (
      computersLinked: 0,
      computerItemsMinted: 0,
      transmittersLinked: 0,
      transmitterItemsMinted: 0,
    );
  }
  final computers = await _healComputers(db);
  final transmitters = await _healTransmitters(db);
  return (
    computersLinked: computers.linked,
    computerItemsMinted: computers.minted,
    transmittersLinked: transmitters.linked,
    transmitterItemsMinted: transmitters.minted,
  );
}

const _mintColumns = {
  'id',
  'diver_id',
  'name',
  'type',
  'brand',
  'model',
  'serial_number',
  'status',
  'purchase_currency',
  'notes',
  'is_active',
  'created_at',
  'updated_at',
};

Future<({int linked, int minted})> _healComputers(
  DatabaseConnectionUser db,
) async {
  final cols = await tableColumnNames(db, 'dive_computers');
  if (!cols.containsAll({
    'id',
    'diver_id',
    'name',
    'manufacturer',
    'model',
    'serial_number',
    'equipment_id',
  })) {
    return (linked: 0, minted: 0);
  }
  final unlinked = await db
      .customSelect(
        'SELECT c.id, c.diver_id, c.name, c.manufacturer, c.model, '
        'c.serial_number FROM dive_computers c '
        'LEFT JOIN equipment e ON e.id = c.equipment_id '
        // An item of another type is no entry for the device either: it
        // would keep the computer out of the Dive Computers list.
        "WHERE e.id IS NULL OR e.type != 'computer' ORDER BY c.id",
      )
      .get();
  var linked = 0;
  var minted = 0;
  for (final row in unlinked) {
    // One row's failure (a dangling diver, say) skips that row only: the
    // heal runs inside the v316 migration and beforeOpen, and must never
    // stop the library opening.
    try {
      // One transaction per row: a failure part way leaves no item minted
      // without its device linked to it.
      final healed = await db.transaction(() => _healComputer(db, row));
      linked += healed.linked;
      minted += healed.minted;
    } catch (e, st) {
      developer.log(
        'Device gear heal skipped computer ${row.read<String>('id')}',
        error: e,
        stackTrace: st,
      );
    }
  }
  return (linked: linked, minted: minted);
}

Future<({int linked, int minted})> _healComputer(
  DatabaseConnectionUser db,
  QueryRow row,
) async {
  var linked = 0;
  var minted = 0;
  final computerId = row.read<String>('id');
  final diverId = row.read<String?>('diver_id');
  final name = row.read<String>('name');
  final manufacturer = row.read<String?>('manufacturer');
  final model = row.read<String?>('model');
  final serial = row.read<String?>('serial_number');

  final chainId = await liveGearId(
    db,
    diveComputerGearId(computerId),
    computerId,
    type: 'computer',
  );
  String? itemId = await _existingId(db, chainId);
  itemId ??= await matchComputerItem(
    db,
    manufacturer: manufacturer,
    model: model,
    serial: serial,
    diverId: diverId,
  );
  var mintedHere = false;
  if (itemId == null) {
    itemId = chainId;
    await _mint(
      db,
      id: itemId,
      diverId: diverId,
      name: name,
      type: 'computer',
      brand: manufacturer,
      model: model,
      serial: serial,
    );
    mintedHere = true;
    minted++;
  } else {
    await fillBlankItemSerial(db, itemId, serial);
  }
  await db.customStatement(
    'UPDATE dive_computers SET equipment_id = ?'
    '${await clearHlcSql(db, 'dive_computers')} WHERE id = ?',
    [itemId, computerId],
  );
  linked++;
  if (mintedHere) await _linkComputerDives(db, computerId, itemId);
  return (linked: linked, minted: minted);
}

/// The item a computer adopts: one match among the items no other computer
/// owns, or, by serial only, an item a computer with the same serial owns
/// (one physical device registered twice shares one item). Shared with
/// `DiveComputerGearResolver`, so discovery and the heal agree.
Future<String?> matchComputerItem(
  DatabaseConnectionUser db, {
  required String? manufacturer,
  required String? model,
  required String? serial,
  required String? diverId,
}) async {
  Future<List<GearTwinCandidate>> candidates({required bool owned}) async {
    final rows = await db
        .customSelect(
          'SELECT id, diver_id, brand, model, serial_number FROM equipment '
          "WHERE type = 'computer' AND status != 'wanted' AND id "
          '${owned ? 'IN' : 'NOT IN'} (SELECT equipment_id FROM dive_computers '
          'WHERE equipment_id IS NOT NULL) ORDER BY updated_at DESC, id',
        )
        .get();
    return [
      for (final r in rows)
        GearTwinCandidate(
          id: r.read<String>('id'),
          diverId: r.read<String?>('diver_id'),
          brand: r.read<String?>('brand'),
          model: r.read<String?>('model'),
          serialNumber: r.read<String?>('serial_number'),
        ),
    ];
  }

  final free = matchGearTwin(
    manufacturer: manufacturer,
    model: model,
    serialNumber: serial,
    diverId: diverId,
    candidates: await candidates(owned: false),
  );
  if (free != null) return free.id;
  if ((serial ?? '').trim().isEmpty) return null;
  // Owned items with a serial only: the blank-serial fallback filters the
  // rest out, so nothing but the serial tier can adopt one.
  return matchGearTwin(
    manufacturer: manufacturer,
    model: model,
    serialNumber: serial,
    diverId: diverId,
    candidates: [
      for (final c in await candidates(owned: true))
        if ((c.serialNumber ?? '').trim().isNotEmpty) c,
    ],
  )?.id;
}

Future<void> _linkComputerDives(
  DatabaseConnectionUser db,
  String computerId,
  String itemId,
) async {
  final junction = await tableColumnNames(db, 'dive_equipment');
  if (!junction.containsAll({'dive_id', 'equipment_id'})) return;
  if ((await tableColumnNames(db, 'dives')).contains('computer_id')) {
    await db.customStatement(
      'INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id) '
      'SELECT id, ? FROM dives WHERE computer_id = ?',
      [itemId, computerId],
    );
  }
  if ((await tableColumnNames(
    db,
    'dive_data_sources',
  )).containsAll({'dive_id', 'computer_id'})) {
    await db.customStatement(
      'INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id) '
      'SELECT DISTINCT dive_id, ? FROM dive_data_sources WHERE computer_id = ?',
      [itemId, computerId],
    );
  }
}

Future<({int linked, int minted})> _healTransmitters(
  DatabaseConnectionUser db,
) async {
  final cols = await tableColumnNames(db, 'transmitters');
  if (!cols.containsAll({
    'id',
    'diver_id',
    'transmitter_serial',
    'label',
    'transmitter_equipment_id',
  })) {
    return (linked: 0, minted: 0);
  }
  final unlinked = await db
      .customSelect(
        'SELECT t.id, t.diver_id, t.transmitter_serial, t.label '
        'FROM transmitters t '
        'LEFT JOIN equipment e ON e.id = t.transmitter_equipment_id '
        "WHERE e.id IS NULL OR e.type != 'transmitter' ORDER BY t.id",
      )
      .get();
  var linked = 0;
  var minted = 0;
  for (final row in unlinked) {
    // Per row, in its own transaction, as for computers.
    try {
      final healed = await db.transaction(() => _healTransmitter(db, row));
      linked += healed.linked;
      minted += healed.minted;
    } catch (e, st) {
      developer.log(
        'Device gear heal skipped transmitter row ${row.read<String>('id')}',
        error: e,
        stackTrace: st,
      );
    }
  }
  return (linked: linked, minted: minted);
}

Future<({int linked, int minted})> _healTransmitter(
  DatabaseConnectionUser db,
  QueryRow row,
) async {
  var linked = 0;
  var minted = 0;
  final rowId = row.read<String>('id');
  final diverId = row.read<String?>('diver_id');
  final serial = normalizeTransmitterSerial(
    row.read<String?>('transmitter_serial'),
  );
  final label = row.read<String>('label');

  final chainId = serial == null
      ? await liveGearId(
          db,
          nextGearRemintId('tx-row:$rowId', rowId),
          'tx-row:$rowId',
          type: 'transmitter',
        )
      : await liveGearId(
          db,
          transmitterGearSeedId(diverId, serial),
          transmitterGearDeviceKey(diverId, serial),
          type: 'transmitter',
        );
  String? itemId = await _existingId(db, chainId);
  if (itemId == null && serial != null) {
    itemId = await matchTransmitterItem(db, serial: serial, diverId: diverId);
  }
  if (itemId == null) {
    itemId = chainId;
    await _mint(
      db,
      id: itemId,
      diverId: diverId,
      name: label,
      type: 'transmitter',
      serial: serial,
    );
    minted++;
    if (serial != null) {
      await _linkTransmitterDives(db, serial, diverId, itemId);
    }
  } else {
    await fillBlankItemSerial(db, itemId, serial);
  }
  await db.customStatement(
    'UPDATE transmitters SET transmitter_equipment_id = ?'
    '${await clearHlcSql(db, 'transmitters')} WHERE id = ?',
    [itemId, rowId],
  );
  linked++;
  return (linked: linked, minted: minted);
}

/// Puts a just-minted transmitter item on the dives of [diverId] whose tanks
/// carry [serial] (canonical, so trimmed), as a minted computer item joins
/// its computer's dives.
Future<void> _linkTransmitterDives(
  DatabaseConnectionUser db,
  String serial,
  String? diverId,
  String itemId,
) async {
  final junction = await tableColumnNames(db, 'dive_equipment');
  if (!junction.containsAll({'dive_id', 'equipment_id'}) ||
      !(await tableColumnNames(
        db,
        'dive_tanks',
      )).containsAll({'dive_id', 'transmitter_serial'}) ||
      !(await tableColumnNames(db, 'dives')).containsAll({'id', 'diver_id'})) {
    return;
  }
  await db.customStatement(
    'INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id) '
    'SELECT DISTINCT dt.dive_id, ? FROM dive_tanks dt '
    'JOIN dives d ON d.id = dt.dive_id '
    'WHERE TRIM(dt.transmitter_serial) = ? AND d.diver_id IS ?',
    [itemId, serial, diverId],
  );
}

/// The one Transmitter item of [diverId] whose canonical serial is [serial],
/// any status except `wanted`; null when none or several match.
Future<String?> matchTransmitterItem(
  DatabaseConnectionUser db, {
  required String serial,
  required String? diverId,
}) async {
  final rows = await db
      .customSelect(
        'SELECT id, serial_number FROM equipment '
        "WHERE type = 'transmitter' AND status != 'wanted' "
        'AND diver_id IS ? AND serial_number IS NOT NULL',
        variables: [Variable<String>(diverId)],
      )
      .get();
  final hits = [
    for (final r in rows)
      if (normalizeTransmitterSerial(r.read<String?>('serial_number')) ==
          serial)
        r.read<String>('id'),
  ];
  return hits.length == 1 ? hits.single : null;
}

/// Inserts an Active equipment row, ignoring one already at [id] (a peer's
/// copy can land between the check and the write, as in the v175 backfill).
Future<void> mintDeviceGearItem(
  DatabaseConnectionUser db, {
  required String id,
  required String? diverId,
  required String name,
  required String type,
  String? brand,
  String? model,
  String? serial,
}) => _mint(
  db,
  id: id,
  diverId: diverId,
  name: name,
  type: type,
  brand: brand,
  model: model,
  serial: serial,
);

Future<void> _mint(
  DatabaseConnectionUser db, {
  required String id,
  required String? diverId,
  required String name,
  required String type,
  String? brand,
  String? model,
  String? serial,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.customStatement(
    'INSERT OR IGNORE INTO equipment '
    '(id, diver_id, name, type, brand, model, serial_number, status, '
    'purchase_currency, notes, is_active, created_at, updated_at) '
    "VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 'USD', '', 1, ?, ?)",
    [id, diverId, name, type, brand, model, serial, now, now],
  );
}

/// Writes [serial] onto item [itemId] when the item has none, as adopting a
/// hand-added item through the blank-serial fallback does. Returns whether
/// it wrote.
Future<bool> fillBlankItemSerial(
  DatabaseConnectionUser db,
  String itemId,
  String? serial,
) async {
  if (serial == null || serial.trim().isEmpty) return false;
  await db.customStatement(
    'UPDATE equipment SET serial_number = ?'
    '${await clearHlcSql(db, 'equipment')} WHERE id = ? '
    "AND (serial_number IS NULL OR TRIM(serial_number) = '')",
    [serial, itemId],
  );
  final changed = await db
      .customSelect('SELECT changes() AS changed')
      .getSingle();
  return changed.read<int>('changed') > 0;
}

Future<String?> _existingId(DatabaseConnectionUser db, String id) async {
  final row = await db
      .customSelect(
        'SELECT id FROM equipment WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingleOrNull();
  return row?.read<String>('id');
}

/// `, hlc = NULL` for [table], so the next sync's `backfillMissingHlc`
/// publishes the row; empty on a pre-HLC fixture or mid-ladder database
/// whose table has no clock column yet.
Future<String> clearHlcSql(DatabaseConnectionUser db, String table) async =>
    (await tableColumnNames(db, table)).contains('hlc') ? ', hlc = NULL' : '';
