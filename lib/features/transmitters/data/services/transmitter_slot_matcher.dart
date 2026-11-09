import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_tank_ref_router.dart';
import 'package:submersion/features/dive_import/data/services/stored_source_dive_finder.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_tank_fill.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// A dive computer a transmitter's serial was downloaded on.
class SlotComputer {
  final String computerId;
  final String computerName;

  const SlotComputer({required this.computerId, required this.computerName});
}

/// The serial-less cylinders on one computer's file-imported dives, by the
/// slot (T1 is 1) their source file says they came from.
class SlotCandidates {
  final SlotComputer computer;
  final Map<int, List<String>> tankIdsBySlot;
  final Map<String, String> _diveIdByTank;

  const SlotCandidates({
    required this.computer,
    required this.tankIdsBySlot,
    required Map<String, String> diveIdByTank,
  }) : _diveIdByTank = diveIdByTank;

  /// How many dives picking [slot] would fill.
  int divesFor(int slot) => {
    for (final id in tankIdsBySlot[slot] ?? const <String>[])
      ?_diveIdByTank[id],
  }.length;
}

/// Pressure agreement, in bar, between a stored cylinder and its parsed
/// source: both come from the same Pascal value, so only float noise differs.
const _pressureToleranceBar = 0.05;
const _gasTolerancePercent = 0.1;

/// Finds the cylinders a transmitter's setup could fill by computer slot when
/// they carry no serial (issue #4347): Shearwater Cloud UDDF dives label each
/// pressure series `T1` to `T4` but name no serial.
///
/// A candidate dive is the entry's diver's, attributed to a computer the
/// serial was downloaded on, imported from a stored UDDF file, has a cylinder
/// with no serial, and has no cylinder that already carries the serial. Its
/// stored file is re-parsed to learn each cylinder's slot, and parsed and
/// stored cylinders are paired by start and end pressure and gas. Anything
/// that does not pair exactly once is left out, never guessed.
class TransmitterSlotMatcher {
  TransmitterSlotMatcher({StoredSourceDiveFinder? finder}) : _finder = finder;

  final StoredSourceDiveFinder? _finder;

  AppDatabase get _db => DatabaseService.instance.database;

  /// The computers with candidate dives for [t]. SQL only, no file parse, so
  /// the apply dialog can decide quickly whether to offer slot matching.
  Future<List<SlotComputer>> computersWithCandidates(Transmitter t) async => [
    for (final entry in (await _candidateDives(t)).entries)
      if (entry.value.isNotEmpty) entry.key,
  ];

  /// The candidate cylinders of [t] by computer and slot, parsing each stored
  /// file once. Only cylinders the fill would change are kept.
  Future<List<SlotCandidates>> resolve(Transmitter t) async {
    final byComputer = await _candidateDives(t);
    final diveIds = {for (final dives in byComputer.values) ...dives.keys};
    if (diveIds.isEmpty) return const [];
    final parsed = await (_finder ?? StoredSourceDiveFinder(db: _db)).findMany(
      diveIds,
    );

    return [
      for (final MapEntry(key: computer, value: dives) in byComputer.entries)
        if (dives.isNotEmpty) _slotsOn(computer, dives, parsed, t),
    ];
  }

  SlotCandidates _slotsOn(
    SlotComputer computer,
    Map<String, List<DiveTank>> dives,
    Map<String, Map<String, dynamic>> parsed,
    Transmitter t,
  ) {
    final tankIdsBySlot = <int, List<String>>{};
    final diveIdByTank = <String, String>{};
    for (final MapEntry(key: diveId, value: stored) in dives.entries) {
      final parsedTanks = parsed[diveId]?['tanks'];
      if (parsedTanks is! List) continue;
      for (final MapEntry(key: row, value: slot) in _pair(
        parsedTanks.whereType<Map<String, dynamic>>().toList(),
        stored,
      ).entries) {
        if (transmitterFillFor(row, t) == null) continue;
        tankIdsBySlot.putIfAbsent(slot, () => []).add(row.id);
        diveIdByTank[row.id] = diveId;
      }
    }
    return SlotCandidates(
      computer: computer,
      tankIdsBySlot: tankIdsBySlot,
      diveIdByTank: diveIdByTank,
    );
  }

  /// Each serial-less stored cylinder that exactly one slotted parsed
  /// cylinder pairs with, and that pairs with only that one, to its slot.
  Map<DiveTank, int> _pair(
    List<Map<String, dynamic>> parsedTanks,
    List<DiveTank> stored,
  ) {
    final claims = <DiveTank, List<int>>{};
    for (final tank in parsedTanks) {
      final slot = tank[kUddfSourceSlotKey];
      if (slot is! int) continue;
      final matches = stored.where((row) => _samePressuresAndGas(tank, row));
      if (matches.length != 1) continue;
      claims.putIfAbsent(matches.single, () => []).add(slot);
    }
    return {
      for (final MapEntry(key: row, value: slots) in claims.entries)
        if (slots.length == 1) row: slots.single,
    };
  }

  bool _samePressuresAndGas(Map<String, dynamic> tank, DiveTank row) {
    final start = (tank['startPressure'] as num?)?.toDouble();
    final end = (tank['endPressure'] as num?)?.toDouble();
    final storedStart = row.startPressure;
    final storedEnd = row.endPressure;
    if (start == null || end == null) return false;
    if (storedStart == null || storedEnd == null) return false;
    final gas = tank['gasMix'] is GasMix
        ? tank['gasMix'] as GasMix
        : const GasMix();
    return (start - storedStart).abs() < _pressureToleranceBar &&
        (end - storedEnd).abs() < _pressureToleranceBar &&
        (gas.o2 - row.o2Percent).abs() < _gasTolerancePercent &&
        (gas.he - row.hePercent).abs() < _gasTolerancePercent;
  }

  /// For each computer the serial was downloaded on, its candidate dives and
  /// each one's serial-less cylinders.
  Future<Map<SlotComputer, Map<String, List<DiveTank>>>> _candidateDives(
    Transmitter t,
  ) async {
    final serial = normalizeTransmitterSerial(t.transmitterSerial);
    if (serial == null) return const {};

    final result = <SlotComputer, Map<String, List<DiveTank>>>{};
    for (final computer in await _computersOf(serial, t.diverId)) {
      final diveIds = await _uddfDivesOn(computer.computerId, t.diverId);
      if (diveIds.isEmpty) {
        result[computer] = const {};
        continue;
      }
      final tanks = await (_db.select(
        _db.diveTanks,
      )..where((d) => d.diveId.isIn(diveIds))).get();
      final byDive = <String, List<DiveTank>>{};
      for (final row in tanks) {
        byDive.putIfAbsent(row.diveId, () => []).add(row);
      }
      result[computer] = {
        for (final MapEntry(key: diveId, value: rows) in byDive.entries)
          if (!rows.any(
            (r) => normalizeTransmitterSerial(r.transmitterSerial) == serial,
          ))
            diveId: [
              for (final r in rows)
                if (normalizeTransmitterSerial(r.transmitterSerial) == null) r,
            ],
      }..removeWhere((_, rows) => rows.isEmpty);
    }
    return result;
  }

  /// The computers [serial] was downloaded on, for [diverId]'s dives.
  Future<List<SlotComputer>> _computersOf(
    String serial,
    String? diverId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT COALESCE(dt.computer_id, d.computer_id) AS cid, '
          'dt.transmitter_serial AS serial, c.name AS name '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'JOIN dive_computers c '
          'ON c.id = COALESCE(dt.computer_id, d.computer_id) '
          'WHERE dt.transmitter_serial IS NOT NULL '
          'AND (? IS NULL OR d.diver_id = ?)',
          variables: [Variable<String>(diverId), Variable<String>(diverId)],
          readsFrom: {_db.diveTanks, _db.dives, _db.diveComputers},
        )
        .get();
    final byId = <String, SlotComputer>{};
    for (final row in rows) {
      if (normalizeTransmitterSerial(row.read<String>('serial')) != serial) {
        continue;
      }
      final id = row.read<String>('cid');
      byId[id] = SlotComputer(
        computerId: id,
        computerName: row.read<String>('name'),
      );
    }
    final computers = byId.values.toList()
      ..sort((a, b) => a.computerName.compareTo(b.computerName));
    return computers;
  }

  /// [diverId]'s dives on [computerId] whose primary source is a stored
  /// UDDF file.
  Future<List<String>> _uddfDivesOn(String computerId, String? diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT d.id AS id FROM dives d '
          'JOIN dive_data_sources s ON s.dive_id = d.id '
          'AND s.is_primary = 1 AND s.imported_file_id IS NOT NULL '
          "AND s.source_file_format = 'uddf' "
          'WHERE (d.computer_id = ? OR EXISTS (SELECT 1 FROM dive_tanks x '
          'WHERE x.dive_id = d.id AND x.computer_id = ?)) '
          'AND (? IS NULL OR d.diver_id = ?)',
          variables: [
            Variable<String>(computerId),
            Variable<String>(computerId),
            Variable<String>(diverId),
            Variable<String>(diverId),
          ],
          readsFrom: {_db.dives, _db.diveDataSources, _db.diveTanks},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }
}
