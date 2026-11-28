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

/// Each file tank's start pressure as the import stored it while it took
/// every tank for back gas (issue #4665): resync deglitches with the file's
/// Hydrotank role, which spares a pump-in at the start, while before the
/// Hydrotank role the import's deglitch read that pump-in as a lead-in
/// glitch.
List<double?> backGasImportStartPressures(
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
      _bar((t as Map)['startPressure']),
  ];
}

/// For each tank of a file with an Avelo Hydrotank, whether the stored row
/// resync paired it with is known to be that cylinder (see
/// [identifiedPairings]); none is when the file has no Hydrotank.
///
/// [tanksData] are the file's tanks as resync writes them, deglitched with
/// their own roles; [rawDiveData] is the file as parsed. A stored start
/// pressure is compared with the raw start (an import from before the
/// pressure clean-up, issue #2441, stored it as it was), the deglitched one,
/// and the one the import stored while it took the Hydrotank for back gas.
List<bool> identifiedHydrotankPairings({
  required Map<String, dynamic> rawDiveData,
  required List<Map<String, dynamic>> tanksData,
  required List<DiveTank?> matched,
  required List<DiveTank> stored,
}) {
  final hasHydrotank = tanksData.any(
    (t) => parsedTankRoleName(t['role']) == TankRole.hydrotank.name,
  );
  if (!hasHydrotank) return List<bool>.filled(tanksData.length, false);

  final rawTanks =
      (rawDiveData['tanks'] as List?)?.cast<Map<String, dynamic>>() ??
      tanksData;
  final asImported = backGasImportStartPressures(rawDiveData, rawTanks);
  double? startOf(List<Map<String, dynamic>> tanks, int i) =>
      i < tanks.length ? _bar(tanks[i]['startPressure']) : null;

  return identifiedPairings(
    matched: matched,
    stored: stored,
    serials: [
      for (final t in tanksData)
        normalizeTransmitterSerial(t['transmitterSerial'] as String?),
    ],
    starts: [
      for (var i = 0; i < tanksData.length; i++)
        [
          startOf(rawTanks, i),
          startOf(tanksData, i),
          i < asImported.length ? asImported[i] : null,
        ],
    ],
  );
}

double? _bar(Object? value) => value is num ? value.toDouble() : null;

/// For each file tank, whether the stored row resync paired it with
/// ([matched], by position for Shearwater Cloud, whose tanks carry no order)
/// is known to be that cylinder (issue #4665).
///
/// A transmitter serial both name settles it. Otherwise the stored start
/// pressure must agree with one of the tank's [starts] (raw, or as the
/// import stored it), and that agreement must say which cylinder it is:
/// either every stored cylinder pairs in order and every pair agrees, which
/// settles two cylinders filled to the same pressure as Cloud import pairs
/// them, or the pressure matches this one tank and this one stored row
/// only. A pressure another cylinder shares names neither.
List<bool> identifiedPairings({
  required List<DiveTank?> matched,
  required List<DiveTank> stored,
  required List<String?> serials,
  required List<List<double?>> starts,
}) {
  bool agrees(DiveTank row, List<double?> candidates) {
    final bar = row.startPressure;
    return bar != null &&
        candidates.any((p) => p != null && sameCylinderStartPressure(bar, p));
  }

  // Whether serials both sides name contradict each other: the pair is then
  // two different cylinders, and the order they sit in proves nothing.
  bool serialsConflict(DiveTank row, String? serial) {
    final storedSerial = normalizeTransmitterSerial(row.transmitterSerial);
    return storedSerial != null && serial != null && storedSerial != serial;
  }

  var inSlotOrder = stored.length == matched.length;
  for (var i = 0; inSlotOrder && i < matched.length; i++) {
    final row = matched[i];
    inSlotOrder =
        row != null &&
        !serialsConflict(row, serials[i]) &&
        agrees(row, starts[i]);
  }

  return [
    for (var i = 0; i < matched.length; i++)
      if (matched[i] case final row?)
        switch ((
          normalizeTransmitterSerial(row.transmitterSerial),
          serials[i],
        )) {
          (final String storedSerial, final String serial) =>
            storedSerial == serial,
          _ =>
            agrees(row, starts[i]) &&
                (inSlotOrder ||
                    (stored.where((r) => agrees(r, starts[i])).length == 1 &&
                        starts.where((s) => agrees(row, s)).length == 1)),
        }
      else
        false,
  ];
}
