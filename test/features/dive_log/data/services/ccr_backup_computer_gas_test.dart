import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

/// Issue #4020: a Perdix carried as a backup on a CCR dive, in CC/BO mode, with
/// no transmitters. Its gas list holds the open-circuit gases first, so the
/// cylinder listed first is a bailout and the diluent comes last.
void main() {
  const diluentUsage = 2; // DC_USAGE_DILUENT
  const ean40 = 0;
  const air = 2;

  final parsed = pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 10,
    dateTimeDay: 20,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 42,
    avgDepthMeters: 30,
    durationSeconds: 3600,
    diveMode: 'ccr',
    samples: [
      for (var t = 10; t <= 3600; t += 10)
        pigeon.ProfileSample(
          timeSeconds: t,
          depthMeters: 40,
          gasMixIndex: air,
          setpoint: 1.3,
        ),
    ],
    tanks: const [],
    gasMixes: [
      pigeon.GasMix(index: ean40, o2Percent: 40, hePercent: 0),
      pigeon.GasMix(index: 1, o2Percent: 15, hePercent: 50),
      pigeon.GasMix(
        index: air,
        o2Percent: 21,
        hePercent: 0,
        usage: diluentUsage,
      ),
    ],
    events: const [],
  );

  final tanks = [
    for (final (order, tank) in resolveParsedTanks(parsed).indexed)
      DiveTank(
        id: 'tank-${tank.index}',
        order: order,
        role: TankRole.values.byName(tank.role!),
        gasMix: GasMix(o2: tank.o2Percent, he: tank.hePercent),
      ),
  ];

  test('the download keeps the logged cylinders and no gas switch', () {
    expect(tanks.map((t) => t.role), [
      TankRole.stage,
      TankRole.bailout,
      TankRole.diluent,
    ]);
    expect(tanks.first.gasMix.o2, 40);
    expect(resolveGasSwitches(parsed), isEmpty);
  });

  test('the gas timeline shows the diluent, not the first cylinder', () {
    final segments = buildGasUsageSegments(
      tanks: tanks,
      gasSwitches: const [],
      diveDurationSeconds: 3600,
      firstSampleSeconds: 10,
    );

    expect(segments.single.gasMix.isAir, isTrue);
  });

  test('the cylinder breathed is the diluent, not the first cylinder', () {
    final active = activeTankAt(
      tanks: tanks,
      gasSwitches: const [],
      timestamp: 1800,
      diveStart: 10,
      onLoop: true,
    );

    expect(active?.role, TankRole.diluent);
  });

  test('the switches editor starts the dive on the diluent', () {
    final start = startingTankOf(
      tanks: tanks,
      switches: const [],
      diveStart: 0,
      onLoop: true,
    );

    expect(start?.role, TankRole.diluent);
  });

  test('the fixture dive starts on its Air diluent, not cylinder 1', () async {
    final bytes = await File(
      'test/dives/issue_4020_ccr_backup_computer_bailout_listed_first.ssrf.xml',
    ).readAsBytes();
    final result = await SubsurfaceXmlParser().parse(Uint8List.fromList(bytes));
    final dive = result.entitiesOf(ImportEntityType.dives).single;
    final tanks = [
      for (final (order, tank) in (dive['tanks'] as List).indexed)
        DiveTank(
          id: 'tank-$order',
          order: order,
          role: tank['role'] as TankRole,
          gasMix: tank['gasMix'] as GasMix,
        ),
    ];

    expect(dive['diveMode'], DiveMode.ccr);
    expect(tanks.first.gasMix.o2, 40);
    expect(
      startingTankOf(
        tanks: tanks,
        switches: const [],
        diveStart: 0,
        onLoop: true,
      )?.role,
      TankRole.diluent,
    );
    expect(
      buildGasUsageSegments(
        tanks: tanks,
        gasSwitches: const [],
        diveDurationSeconds: 3900,
      ).single.gasMix.isAir,
      isTrue,
    );
  });
}
