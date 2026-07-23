import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

List<DiveProfilePoint> _profile(List<int> timestamps) => [
  for (final t in timestamps) DiveProfilePoint(timestamp: t, depth: 1.0),
];

void main() {
  group('shouldDrawSurfaceLeadIn', () {
    test('true when the first sample sits one interval in', () {
      expect(shouldDrawSurfaceLeadIn(_profile([10, 20, 30])), isTrue);
    });

    test('false when the profile already starts at zero', () {
      expect(shouldDrawSurfaceLeadIn(_profile([0, 1, 2])), isFalse);
    });

    test('false when the gap exceeds one sample interval', () {
      expect(shouldDrawSurfaceLeadIn(_profile([600, 610, 620])), isFalse);
    });

    test('boundary: one interval yes, one second more no', () {
      expect(shouldDrawSurfaceLeadIn(_profile([10, 20])), isTrue);
      expect(shouldDrawSurfaceLeadIn(_profile([11, 21])), isFalse);
    });

    test('false for profiles too short to establish an interval', () {
      expect(shouldDrawSurfaceLeadIn(const []), isFalse);
      expect(shouldDrawSurfaceLeadIn(_profile([10])), isFalse);
    });

    test('false when the first two samples share a timestamp', () {
      expect(shouldDrawSurfaceLeadIn(_profile([10, 10, 20])), isFalse);
    });
  });

  group('ambientPressureBar', () {
    test('1 bar at the surface', () {
      expect(ambientPressureBar(0), 1.0);
    });

    test('adds 1 bar per 10 m of seawater', () {
      expect(ambientPressureBar(10), 2.0);
      expect(ambientPressureBar(20), 3.0);
      expect(ambientPressureBar(25), closeTo(3.5, 1e-9));
    });
  });

  group('surfaceValueAtOneBar', () {
    test('recovers the gas fraction from a partial pressure at depth', () {
      // Air ppO2 of 0.63 bar at 20 m (3 bar ambient) is 0.21 at the surface.
      expect(surfaceValueAtOneBar(0.63, 20), closeTo(0.21, 1e-9));
      // ppN2 0.79 * 3 = 2.37 at 20 m recovers 0.79.
      expect(surfaceValueAtOneBar(2.37, 20), closeTo(0.79, 1e-9));
    });

    test('is a no-op when the first sample is already at the surface', () {
      expect(surfaceValueAtOneBar(0.21, 0), 0.21);
    });
  });
}
