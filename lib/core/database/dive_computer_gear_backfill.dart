import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// Seed a gear twin for every registered dive computer and link it to the dives
/// that computer logged (v175).
///
/// Ladder-only, never a `beforeOpen` backstop, for two independent reasons: it
/// is a full-table pass over every dive, and re-running it on every open would
/// resurrect a gear item the user deleted. That is the same rule
/// `_backfillLegacyServiceSchedules` and `_backfillBottomTimeFromProfile`
/// follow.
///
/// New rows land on a deterministic id ([diveComputerGearId]), so every device
/// in a synced fleet derives the same primary key and they converge under sync
/// upsert rather than duplicating.
///
/// LOCAL-ONLY AND HLC-NEUTRAL, deliberately. Nothing here marks a record
/// pending or stamps an HLC, so these writes never go out on an incremental
/// sync. That is the `_backfillDiveComputerIds` pattern and it is correct here
/// for the same reason: every input is already synced (`dive_computers`,
/// `dives`, `dive_data_sources`) and the twin id is derived, so every device
/// produces identical rows independently when its own ladder runs. Marking
/// them pending would push one record per computer plus one per (dive,
/// computer) pair from every device in the fleet, to make peers agree on rows
/// they will each derive anyway.
///
/// Two consequences worth knowing before "fixing" this:
///
///  * A base/full export passes `hlcSince == null` and therefore DOES carry
///    these rows, so a device adopting the cloud base is not missing them.
///  * A dive downloaded by a peer still on the previous schema and synced to an
///    already-migrated device is not linked on that device: its ladder has run,
///    the runtime linker fires only at local creation seams, and the peer's own
///    later backfill is HLC-neutral so it does not push. That is a missing join
///    row on one device during the rollout window, not divergence in the twin
///    itself, and it resolves the moment anyone edits that dive's gear.
///
/// The runtime paths are the opposite and mark pending as usual: the resolver
/// when it mints a twin, and `bulkAddEquipment` for every link the linker adds.
Future<void> backfillDiveComputerGearTwins(DatabaseConnectionUser db) async {
  // PRAGMA-guarded like every other backfill helper: the ladder runs against
  // minimal fixtures and against databases caught mid-upgrade. PRAGMA
  // table_info returns empty for a missing table, so probing the columns covers
  // both "table absent" and "column absent".
  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((c) => c.read<String>('name')).toSet();
  }

  final computerCols = await columnsOf('dive_computers');
  if (!computerCols.containsAll({
    'id',
    'diver_id',
    'name',
    'manufacturer',
    'model',
    'serial_number',
    'equipment_id',
  })) {
    return;
  }
  // Every column the INSERT below writes, not a subset: a guard that passes
  // and then throws on the insert is worse than no guard, because the caller
  // reads it as proof the write is safe.
  final equipmentCols = await columnsOf('equipment');
  if (!equipmentCols.containsAll({
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
  })) {
    return;
  }

  // Pass 1: resolve a twin per computer. Bounded by device count, a handful of
  // rows, so no event-loop yield is needed here.
  final computers = await db
      .customSelect(
        'SELECT id, diver_id, name, manufacturer, model, serial_number '
        'FROM dive_computers WHERE equipment_id IS NULL ORDER BY id',
      )
      .get();

  for (final computer in computers) {
    final id = computer.read<String>('id');
    final diverId = computer.read<String?>('diver_id');
    final name = computer.read<String>('name');
    final manufacturer = computer.read<String?>('manufacturer');
    final model = computer.read<String?>('model');
    final serial = computer.read<String?>('serial_number');

    final derivedId = diveComputerGearId(id);

    // Adopt the row already holding the derived id before matching on text:
    // the match reads each row's CURRENT text while the id derives from the
    // computer id, so a renamed gear item makes the match miss while the id
    // still collides.
    final byDerivedId = await db
        .customSelect(
          'SELECT id FROM equipment WHERE id = ?',
          variables: [Variable<String>(derivedId)],
        )
        .getSingleOrNull();

    var twinId = byDerivedId?.read<String>('id');

    if (twinId == null) {
      final candidateRows = await db
          .customSelect(
            'SELECT id, diver_id, brand, model, serial_number FROM equipment '
            "WHERE type = 'computer' AND is_active = 1 "
            'ORDER BY updated_at DESC, id',
          )
          .get();
      twinId = matchGearTwin(
        manufacturer: manufacturer,
        model: model,
        serialNumber: serial,
        diverId: diverId,
        candidates: candidateRows.map(
          (r) => GearTwinCandidate(
            id: r.read<String>('id'),
            diverId: r.read<String?>('diver_id'),
            brand: r.read<String?>('brand'),
            model: r.read<String?>('model'),
            serialNumber: r.read<String?>('serial_number'),
          ),
        ),
      )?.id;
    }

    if (twinId == null) {
      twinId = derivedId;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT OR IGNORE INTO equipment '
        '(id, diver_id, name, type, brand, model, serial_number, status, '
        'purchase_currency, notes, is_active, created_at, updated_at) '
        "VALUES (?, ?, ?, 'computer', ?, ?, ?, 'active', 'USD', '', 1, ?, ?)",
        [twinId, diverId, name, manufacturer, model, serial, now, now],
      );
    }

    await db.customStatement(
      'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
      [twinId, id],
    );
  }

  // Pass 2: link the dives. Set-based, so it needs no per-dive loop and no
  // event-loop yield: a per-dive loop during a migration runs as one unbroken
  // microtask chain and freezes the progress spinner.
  final junctionCols = await columnsOf('dive_equipment');
  if (!junctionCols.containsAll({'dive_id', 'equipment_id'})) return;

  // dives.computer_id holds only the PRIMARY computer, so it is unioned with
  // dive_data_sources: a dive logged on two computers must list both.
  final diveCols = await columnsOf('dives');
  if (diveCols.contains('computer_id')) {
    await db.customStatement('''
      INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id)
      SELECT d.id, c.equipment_id
        FROM dives d
        JOIN dive_computers c ON c.id = d.computer_id
       WHERE c.equipment_id IS NOT NULL
    ''');
  }

  final sourceCols = await columnsOf('dive_data_sources');
  if (sourceCols.containsAll({'dive_id', 'computer_id'})) {
    await db.customStatement('''
      INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id)
      SELECT s.dive_id, c.equipment_id
        FROM dive_data_sources s
        JOIN dive_computers c ON c.id = s.computer_id
       WHERE c.equipment_id IS NOT NULL
    ''');
  }
}
