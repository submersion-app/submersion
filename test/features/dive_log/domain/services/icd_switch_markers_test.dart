import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/domain/services/icd_switch_markers.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

/// Issue #4530: gas switches that break, or nearly break, the rule of fifths
/// get a marker on the profile.
void main() {
  ProfileGasSegment oc(int start, {required double o2, double he = 0}) =>
      ProfileGasSegment(
        startTimestamp: start,
        fN2: (100 - o2 - he) / 100,
        fHe: he / 100,
      );

  double? at31(int _) => 3.1;

  group('icdSwitchMarkersOf', () {
    test('Tx 18/45 to EAN50 is a violation at the switch time', () {
      final markers = icdSwitchMarkersOf([
        oc(0, o2: 18, he: 45),
        oc(1200, o2: 50),
      ], ambientPressureAt: at31);

      expect(markers, hasLength(1));
      expect(markers.single.timestamp, 1200);
      expect(markers.single.severity, IcdSeverity.violation);
      expect(markers.single.from.he, closeTo(45, 1e-9));
      expect(markers.single.to.o2, closeTo(50, 1e-9));
    });

    test('Tx 21/35 to EAN50 is a caution', () {
      final markers = icdSwitchMarkersOf([
        oc(0, o2: 21, he: 35),
        oc(1500, o2: 50),
      ], ambientPressureAt: at31);

      expect(markers.single.severity, IcdSeverity.caution);
    });

    test('switches without helium and passing switches leave no marker', () {
      final markers = icdSwitchMarkersOf([
        oc(0, o2: 21),
        oc(900, o2: 50),
        oc(1500, o2: 100),
      ], ambientPressureAt: at31);

      expect(markers, isEmpty);
    });

    test(
      'a bailout from the loop compares the loop mix at the switch depth',
      () {
        // Loop at 1.3 bar setpoint on a 10/70 diluent at 3.1 bar: O2 about
        // 41.9 %, the inert rest split 70:20, so about 45 % He and 13 % N2.
        // Bailing out to EAN50 drops He by 45 and raises N2 by 37.
        final markers = icdSwitchMarkersOf([
          const ProfileGasSegment(
            startTimestamp: 0,
            fN2: 0.2,
            fHe: 0.7,
            setpoint: 1.3,
          ),
          oc(1800, o2: 50),
        ], ambientPressureAt: at31);

        expect(markers.single.severity, IcdSeverity.violation);
        expect(markers.single.from.he, closeTo(45.2, 0.1));
        expect(markers.single.from.n2, closeTo(12.9, 0.1));
      },
    );

    test('loop-to-loop and open-circuit-to-loop switches are not checked', () {
      final markers = icdSwitchMarkersOf([
        oc(0, o2: 18, he: 45),
        const ProfileGasSegment(
          startTimestamp: 600,
          fN2: 0.5,
          fHe: 0.0,
          setpoint: 0.7,
        ),
        const ProfileGasSegment(
          startTimestamp: 900,
          fN2: 0.5,
          fHe: 0.0,
          setpoint: 1.3,
        ),
      ], ambientPressureAt: at31);

      expect(markers, isEmpty);
    });

    test('a bailout without a known ambient pressure is skipped', () {
      final markers = icdSwitchMarkersOf([
        const ProfileGasSegment(
          startTimestamp: 0,
          fN2: 0.2,
          fHe: 0.7,
          setpoint: 1.3,
        ),
        oc(1800, o2: 50),
      ], ambientPressureAt: (_) => null);

      expect(markers, isEmpty);
    });

    test('fewer than two segments leave no marker', () {
      expect(icdSwitchMarkersOf(const [], ambientPressureAt: at31), isEmpty);
      expect(
        icdSwitchMarkersOf([oc(0, o2: 18, he: 45)], ambientPressureAt: at31),
        isEmpty,
      );
    });
  });
}
