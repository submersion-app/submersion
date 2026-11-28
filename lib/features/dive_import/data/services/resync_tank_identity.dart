import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/universal_import/data/services/tank_pressure_glitch_normalizer.dart';

/// The name of a role a parser wrote as a [TankRole] or its name; a name
/// this build does not know is none.
String? parsedTankRoleName(Object? role) => switch (role) {
  final TankRole r => r.name,
  final String name => TankRole.values.asNameMap()[name]?.name,
  _ => null,
};

/// For each of the file's tanks, the start pressures a stored cylinder that
/// is that tank may hold (issue #4665): the file's raw start (an import from
/// before the pressure clean-up, issue #2441, stored it as it was), the
/// deglitched one in [tanksData], and, for a file with an Avelo Hydrotank,
/// the one the import stored while it took every tank for back gas.
///
/// [tanksData] are the file's tanks as resync writes them, deglitched with
/// their own roles; [rawDiveData] is the file as parsed.
List<List<double?>> storedStartCandidates({
  required Map<String, dynamic> rawDiveData,
  required List<Map<String, dynamic>> tanksData,
}) {
  final rawTanks =
      (rawDiveData['tanks'] as List?)?.cast<Map<String, dynamic>>() ??
      tanksData;
  final hasHydrotank = tanksData.any(
    (t) => parsedTankRoleName(t['role']) == TankRole.hydrotank.name,
  );
  final asImported = hasHydrotank
      ? _backGasImportStarts(rawDiveData, rawTanks)
      : const <double?>[];
  double? startOf(List<Object?> tanks, int i) =>
      i < tanks.length ? _bar((tanks[i] as Map)['startPressure']) : null;

  return [
    for (var i = 0; i < tanksData.length; i++)
      [startOf(rawTanks, i), startOf(tanksData, i), startOf(asImported, i)],
  ];
}

/// Each file tank's start pressure as the import stored it while it took
/// every tank for back gas: resync deglitches with the file's Hydrotank
/// role, which spares a pump-in at the start, while before the Hydrotank
/// role the import's deglitch read that pump-in as a lead-in glitch. Each
/// entry is a tank map holding only its `startPressure`.
List<Map<String, dynamic>> _backGasImportStarts(
  Map<String, dynamic> diveData,
  List<Map<String, dynamic>> tanksData,
) {
  final asImported = deglitchDiveTankPressures({
    ...diveData,
    'tanks': [
      for (final t in tanksData)
        {
          for (final e in t.entries)
            if (e.key != 'role') e.key: e.value,
        },
    ],
  });
  return [
    for (final t in asImported['tanks'] as List)
      {'startPressure': (t as Map)['startPressure']},
  ];
}

double? _bar(Object? value) => value is num ? value.toDouble() : null;

/// Pairs the file tanks the `order` pass left unplaced ([fileIndexes], in
/// file order) with the stored cylinders it left unclaimed ([rows], in
/// stored order), by what tells a cylinder apart, never by position alone
/// (issue #4665): Shearwater Cloud and Subsurface tanks carry no order, and
/// a diver who removed or reordered a cylinder shifts every position after
/// it. Returns the stored row for each file index it places.
///
/// When every unplaced tank lines up with an unclaimed row in order and no
/// pair contradicts itself (serials that differ, or a stored start pressure
/// that agrees with none of the tank's [starts]), they pair in order, which
/// settles two cylinders filled to the same pressure as Cloud import pairs
/// them. Otherwise a tank pairs with the one row whose transmitter serial it
/// names, or else with the one row whose start pressure agrees and whose
/// serial does not contradict it, and only when no other unplaced tank
/// points at that row too. Anything less certain stays unplaced.
Map<int, DiveTank> pairUnorderedTanks({
  required List<int> fileIndexes,
  required List<DiveTank> rows,
  required List<String?> serials,
  required List<List<double?>> starts,
}) {
  String? storedSerial(DiveTank row) =>
      normalizeTransmitterSerial(row.transmitterSerial);
  bool sameSerial(DiveTank row, int i) {
    final stored = storedSerial(row);
    return stored != null && serials[i] != null && stored == serials[i];
  }

  bool serialsConflict(DiveTank row, int i) {
    final stored = storedSerial(row);
    return stored != null && serials[i] != null && stored != serials[i];
  }

  bool pressureAgrees(DiveTank row, int i) {
    final bar = row.startPressure;
    return bar != null &&
        starts[i].any((p) => p != null && sameCylinderStartPressure(bar, p));
  }

  final inOrder =
      rows.length == fileIndexes.length &&
      [for (var k = 0; k < rows.length; k++) (rows[k], fileIndexes[k])].every(
        (pair) =>
            !serialsConflict(pair.$1, pair.$2) &&
            (sameSerial(pair.$1, pair.$2) ||
                pair.$1.startPressure == null ||
                pressureAgrees(pair.$1, pair.$2)),
      );
  if (inOrder) {
    return {for (var k = 0; k < rows.length; k++) fileIndexes[k]: rows[k]};
  }

  List<DiveTank> candidatesFor(int i) {
    final bySerial = [
      for (final row in rows)
        if (sameSerial(row, i)) row,
    ];
    if (bySerial.isNotEmpty) return bySerial;
    return [
      for (final row in rows)
        if (!serialsConflict(row, i) && pressureAgrees(row, i)) row,
    ];
  }

  final candidates = {for (final i in fileIndexes) i: candidatesFor(i)};
  return {
    for (final MapEntry(key: i, value: rowsFor) in candidates.entries)
      if (rowsFor case [final row]
          when candidates.values
                  .where((others) => others.any((r) => r.id == row.id))
                  .length ==
              1)
        i: row,
  };
}
