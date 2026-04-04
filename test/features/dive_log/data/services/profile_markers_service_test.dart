import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('ProfileMarkersService.getPressureThresholdMarkers', () {
    final profile = [
      const DiveProfilePoint(timestamp: 0, depth: 0.0),
      const DiveProfilePoint(timestamp: 300, depth: 20.0),
      const DiveProfilePoint(timestamp: 600, depth: 20.0),
      const DiveProfilePoint(timestamp: 900, depth: 10.0),
      const DiveProfilePoint(timestamp: 1200, depth: 0.0),
    ];

    test('estimates pressure thresholds from tank start/end pressure', () {
      const tank = DiveTank(
        id: 't1',
        name: 'AL80',
        volume: 11.1,
        startPressure: 200.0,
        endPressure: 50.0,
      );

      final markers = ProfileMarkersService.getPressureThresholdMarkers(
        profile: profile,
        tanks: [tank],
      );

      // Should find crossings for 2/3 (~133), 1/2 (100), 1/3 (~67)
      expect(markers, isNotEmpty);
      final types = markers.map((m) => m.type).toSet();
      expect(types, contains(ProfileMarkerType.pressureHalf));
    });

    test('returns empty when tanks have no start pressure', () {
      const tank = DiveTank(id: 't1');
      final markers = ProfileMarkersService.getPressureThresholdMarkers(
        profile: profile,
        tanks: [tank],
      );
      expect(markers, isEmpty);
    });

    test('returns empty for empty profile', () {
      const tank = DiveTank(id: 't1', startPressure: 200.0, endPressure: 50.0);
      final markers = ProfileMarkersService.getPressureThresholdMarkers(
        profile: [],
        tanks: [tank],
      );
      expect(markers, isEmpty);
    });

    test('estimates pressure markers linearly when no profile pressure', () {
      // Profile without pressure data
      final noPressureProfile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 600, depth: 20.0),
        const DiveProfilePoint(timestamp: 1200, depth: 0.0),
      ];

      const tank = DiveTank(id: 't1', startPressure: 200.0, endPressure: 50.0);

      final markers = ProfileMarkersService.getPressureThresholdMarkers(
        profile: noPressureProfile,
        tanks: [tank],
      );

      // Should estimate crossings linearly
      expect(markers, isNotEmpty);
    });

    test('handles per-tank pressure data', () {
      const tank = DiveTank(
        id: 't1',
        name: 'AL80',
        startPressure: 200.0,
        endPressure: 50.0,
      );

      final tankPressures = {
        't1': [
          const TankPressurePoint(
            id: '1',
            tankId: 't1',
            timestamp: 0,
            pressure: 200.0,
          ),
          const TankPressurePoint(
            id: '2',
            tankId: 't1',
            timestamp: 600,
            pressure: 100.0,
          ),
          const TankPressurePoint(
            id: '3',
            tankId: 't1',
            timestamp: 1200,
            pressure: 50.0,
          ),
        ],
      };

      final markers = ProfileMarkersService.getPressureThresholdMarkers(
        profile: profile,
        tanks: [tank],
        tankPressures: tankPressures,
      );

      expect(markers, isNotEmpty);
    });
  });
}
