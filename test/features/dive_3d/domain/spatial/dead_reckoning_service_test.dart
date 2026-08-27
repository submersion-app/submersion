import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';

const _service = DeadReckoningService();

void main() {
  test('constant north heading advances north, not east', () {
    const n = 60;
    final times = [for (var i = 0; i < n; i++) (i * 10).toDouble()];
    final depths = [for (var i = 0; i < n; i++) 20.0];
    final headings = [for (var i = 0; i < n; i++) 0.0]; // due north
    final path = _service.reckon(
      times: times,
      depths: depths,
      headings: headings,
      swimSpeedMps: 0.5,
    );
    expect(path.reconstructed, isTrue);
    expect(path.points.last.north, greaterThan(50));
    expect(path.points.last.east.abs(), lessThan(1e-6));
  });

  test('east heading advances east', () {
    const n = 30;
    final times = [for (var i = 0; i < n; i++) (i * 10).toDouble()];
    final depths = [for (var i = 0; i < n; i++) 15.0];
    final headings = [for (var i = 0; i < n; i++) 90.0]; // due east
    final path = _service.reckon(
      times: times,
      depths: depths,
      headings: headings,
      swimSpeedMps: 0.5,
    );
    expect(path.points.last.east, greaterThan(50));
    expect(path.points.last.north.abs(), lessThan(1e-6));
  });

  test('rubber-bands the path to the exit offset', () {
    const n = 40;
    final times = [for (var i = 0; i < n; i++) (i * 10).toDouble()];
    final depths = [for (var i = 0; i < n; i++) 20.0];
    final headings = [for (var i = 0; i < n; i++) 0.0]; // north, but...
    final path = _service.reckon(
      times: times,
      depths: depths,
      headings: headings,
      exitOffset: (east: 30.0, north: 0.0), // exit is due east
    );
    // The end lands on the exit fix despite the northward headings.
    expect(path.points.last.east, closeTo(30.0, 1e-6));
    expect(path.points.last.north, closeTo(0.0, 1e-6));
    expect(path.points.first.east, closeTo(0.0, 1e-6));
  });

  test('falls back to a straight line without headings', () {
    const n = 20;
    final times = [for (var i = 0; i < n; i++) (i * 10).toDouble()];
    final depths = [for (var i = 0; i < n; i++) 18.0];
    final headings = [for (var i = 0; i < n; i++) null];
    final path = _service.reckon(
      times: times,
      depths: depths,
      headings: headings,
      exitOffset: (east: 10.0, north: 20.0),
    );
    expect(path.reconstructed, isFalse);
    expect(path.points.last.east, closeTo(10.0, 1e-6));
    expect(path.points.last.north, closeTo(20.0, 1e-6));
    // Midpoint is halfway.
    expect(path.points[n ~/ 2].east, closeTo(10.0 * (n ~/ 2) / (n - 1), 1e-6));
  });

  test('empty input is safe', () {
    final path = _service.reckon(times: [], depths: [], headings: []);
    expect(path.isEmpty, isTrue);
  });

  test('exposes horizontal and depth extent', () {
    final path = _service.reckon(
      times: const [0, 10, 20],
      depths: const [0, 30, 0],
      headings: const [90, 90, 90],
      swimSpeedMps: 1.0,
    );
    expect(path.maxDepth, 30);
    expect(path.eastSpan, greaterThan(0));
    expect(path.durationSeconds, 20);
  });
}
