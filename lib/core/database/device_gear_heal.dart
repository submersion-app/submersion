import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';
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
/// no tombstone names. The async form of [gearIdAvoiding].
Future<String> liveGearId(
  DatabaseConnectionUser db,
  String firstId,
  String deviceKey,
) async {
  final hasLog = (await _columnsOf(db, 'deletion_log')).isNotEmpty;
  var id = firstId;
  for (var step = 0; step < 64; step++) {
    if (!hasLog || !await isEquipmentTombstoned(db, id)) return id;
    id = nextGearRemintId(deviceKey, id);
  }
  return id;
}

/// Gives every registered dive computer and every transmitter registry row
/// the Equipment item that is its one entry (issue #3676).
///
/// A device can lose its item three ways: a twin deleted before v315 (the
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
/// LOCAL-ONLY AND HLC-NEUTRAL, deliberately, as the v175 backfill is: every
/// input (computers, registry rows, equipment, tombstones) is synced and
/// every minted id is derived from them, so each device produces the same
/// rows on its own. Staging them would push one record per device from every
/// device in the fleet, to make peers agree on rows they each derive anyway.
Future<DeviceGearHealResult> ensureDeviceGearLinks(
  DatabaseConnectionUser db,
) async {
  final equipmentCols = await _columnsOf(db, 'equipment');
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
  final cols = await _columnsOf(db, 'dive_computers');
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
        'WHERE e.id IS NULL ORDER BY c.id',
      )
      .get();
  var linked = 0;
  var minted = 0;
  for (final row in unlinked) {
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
    );
    String? itemId = await _existingId(db, chainId);
    itemId ??= await _matchComputerItem(
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
      await _fillBlankSerial(db, itemId, serial);
    }
    await db.customStatement(
      'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
      [itemId, computerId],
    );
    linked++;
    if (mintedHere) await _linkComputerDives(db, computerId, itemId);
  }
  return (linked: linked, minted: minted);
}

/// The item a computer adopts: one match among the items no other computer
/// owns, or, by serial only, an item a computer with the same serial owns
/// (one physical device registered twice shares one item).
Future<String?> _matchComputerItem(
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
  final junction = await _columnsOf(db, 'dive_equipment');
  if (!junction.containsAll({'dive_id', 'equipment_id'})) return;
  if ((await _columnsOf(db, 'dives')).contains('computer_id')) {
    await db.customStatement(
      'INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id) '
      'SELECT id, ? FROM dives WHERE computer_id = ?',
      [itemId, computerId],
    );
  }
  if ((await _columnsOf(
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
  final cols = await _columnsOf(db, 'transmitters');
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
        'WHERE e.id IS NULL ORDER BY t.id',
      )
      .get();
  var linked = 0;
  var minted = 0;
  for (final row in unlinked) {
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
          )
        : await liveGearId(
            db,
            transmitterGearSeedId(diverId, serial),
            transmitterGearDeviceKey(diverId, serial),
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
    } else {
      await _fillBlankSerial(db, itemId, serial);
    }
    await db.customStatement(
      'UPDATE transmitters SET transmitter_equipment_id = ? WHERE id = ?',
      [itemId, rowId],
    );
    linked++;
  }
  return (linked: linked, minted: minted);
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

Future<void> _fillBlankSerial(
  DatabaseConnectionUser db,
  String itemId,
  String? serial,
) async {
  if (serial == null || serial.trim().isEmpty) return;
  await db.customStatement(
    'UPDATE equipment SET serial_number = ? WHERE id = ? '
    "AND (serial_number IS NULL OR TRIM(serial_number) = '')",
    [serial, itemId],
  );
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

Future<Set<String>> _columnsOf(DatabaseConnectionUser db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((c) => c.read<String>('name')).toSet();
}
