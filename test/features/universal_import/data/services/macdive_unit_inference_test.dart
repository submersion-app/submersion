import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_inference.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart'
    show MacDiveUnitSystem;

MacDiveRawLogbook _logbook({
  String? unitsPreference,
  List<MacDiveRawTank> tanks = const [],
  List<MacDiveRawTankAndGas> tankAndGases = const [],
}) {
  return MacDiveRawLogbook(
    dives: const [],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: {for (final t in tanks) t.pk: t},
    gasesByPk: const {},
    tankAndGases: tankAndGases,
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: unitsPreference,
  );
}

MacDiveRawTankAndGas _fill(double start, double end) => MacDiveRawTankAndGas(
  diveFk: 1,
  tankFk: 1,
  gasFk: 1,
  airStart: start,
  airEnd: end,
);

void main() {
  group('MacDiveUnitInference.resolve', () {
    test('prefers MacDive\'s own declaration', () {
      // Even though these pressures look metric, the declaration wins.
      expect(
        MacDiveUnitInference.resolve(
          _logbook(unitsPreference: 'Imperial', tankAndGases: [_fill(200, 50)]),
        ),
        MacDiveUnitSystem.imperial,
      );
      expect(
        MacDiveUnitInference.resolve(_logbook(unitsPreference: 'Metric')),
        MacDiveUnitSystem.metric,
      );
    });

    test('falls back to inference when the row is missing', () {
      // The 540-dive reference library has no SystemOfUnits row at all, which
      // is what made 3118 psi import as 3118 bar (#912).
      expect(
        MacDiveUnitInference.resolve(
          _logbook(tankAndGases: [_fill(3118, 1138)]),
        ),
        MacDiveUnitSystem.imperial,
      );
    });
  });

  group('MacDiveUnitInference.infer', () {
    test('reads fill pressures as psi above the bar ceiling', () {
      expect(
        MacDiveUnitInference.infer(_logbook(tankAndGases: [_fill(3000, 700)])),
        MacDiveUnitSystem.imperial,
      );
    });

    test('reads fill pressures as bar below the ceiling', () {
      expect(
        MacDiveUnitInference.infer(_logbook(tankAndGases: [_fill(232, 60)])),
        MacDiveUnitSystem.metric,
      );
    });

    test('uses working pressure when no dive has fill data', () {
      expect(
        MacDiveUnitInference.infer(
          _logbook(
            tanks: const [
              MacDiveRawTank(pk: 1, uuid: 't', workingPressure: 3000),
            ],
          ),
        ),
        MacDiveUnitSystem.imperial,
      );
      expect(
        MacDiveUnitInference.infer(
          _logbook(
            tanks: const [
              MacDiveRawTank(pk: 1, uuid: 't', workingPressure: 232),
            ],
          ),
        ),
        MacDiveUnitSystem.metric,
      );
    });

    test('ignores zero pressures, which MacDive uses for "not set"', () {
      // Only the 232 bar entry carries information.
      expect(
        MacDiveUnitInference.infer(
          _logbook(
            tanks: const [
              MacDiveRawTank(pk: 1, uuid: 't1', workingPressure: 0),
              MacDiveRawTank(pk: 2, uuid: 't2', workingPressure: 232),
            ],
          ),
        ),
        MacDiveUnitSystem.metric,
      );
    });

    test('falls back to cylinder size: cubic feet vs litres', () {
      expect(
        MacDiveUnitInference.infer(
          _logbook(tanks: const [MacDiveRawTank(pk: 1, uuid: 't', size: 80)]),
        ),
        MacDiveUnitSystem.imperial,
      );
      expect(
        MacDiveUnitInference.infer(
          _logbook(tanks: const [MacDiveRawTank(pk: 1, uuid: 't', size: 12)]),
        ),
        MacDiveUnitSystem.metric,
      );
    });

    test('stays unknown when nothing carries a signal', () {
      // Passthrough beats a coin flip.
      expect(MacDiveUnitInference.infer(_logbook()), MacDiveUnitSystem.unknown);
    });
  });
}
