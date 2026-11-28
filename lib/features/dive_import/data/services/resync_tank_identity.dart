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
      switch ((t as Map)['startPressure']) {
        final num bar => bar.toDouble(),
        _ => null,
      },
  ];
}

/// Whether stored [row] is the cylinder a file tank with [serial] reads
/// (issue #4665): the same transmitter when both name one, else a start
/// pressure that agrees with one of [startPressures]. Shearwater Cloud tanks
/// carry no order, so resync pairs them with stored cylinders by position.
bool isSameStoredCylinder(
  DiveTank row,
  String? serial,
  List<double?> startPressures,
) {
  final storedSerial = normalizeTransmitterSerial(row.transmitterSerial);
  if (storedSerial != null && serial != null) return storedSerial == serial;
  final stored = row.startPressure;
  if (stored == null) return false;
  return startPressures.any(
    (p) => p != null && sameCylinderStartPressure(stored, p),
  );
}
