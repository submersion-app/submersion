import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/core/profile/tank_pressure_mixing.dart';

/// One recording: [start] bar at [offset] s, draining 0.05 bar/s, every 10 s.
List<PressureReading> recording({
  double start = 200,
  int offset = 0,
  int count = 200,
}) => [
  for (var i = 0; i < count; i++) (t: offset + i * 10, bar: start - i * 0.5),
];

/// Two recordings merged in time order, as the v182 packer left them.
List<PressureReading> interleave(
  List<PressureReading> a,
  List<PressureReading> b,
) {
  final all = [...a, ...b];
  final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])]
    ..sort((x, y) {
      final byTime = x.$2.t.compareTo(y.$2.t);
      return byTime != 0 ? byTime : x.$1.compareTo(y.$1);
    });
  return [for (final e in indexed) e.$2];
}

void main() {
  group('looksLikeInterleavedSources', () {
    test('a single clean recording is not mixed', () {
      expect(looksLikeInterleavedSources(recording()), isFalse);
    });

    test('two recordings of different cylinders interleaved are mixed', () {
      // Tank 2 and tank 1 readings alternating, ~50 bar apart.
      final series = interleave(
        recording(start: 162, offset: 0),
        recording(start: 109, offset: 2),
      );
      expect(looksLikeInterleavedSources(series), isTrue);
    });

    test('two recordings of one cylinder a few bar apart are mixed', () {
      // Two computers reading the same transmitter with a 6 bar offset.
      final series = interleave(
        recording(start: 192.5, offset: 1),
        recording(start: 186.8, offset: 0),
      );
      expect(looksLikeInterleavedSources(series), isTrue);
    });

    test('the same recording twice, shifted in time, is mixed', () {
      // Identical readings 50 s apart on the same 10 s grid: every timestamp
      // is read twice with different values.
      final series = interleave(
        recording(start: 200, offset: 0),
        recording(start: 197.5, offset: 0),
      );
      expect(looksLikeInterleavedSources(series), isTrue);
    });

    test('a recording with a few dropouts is not mixed', () {
      final base = recording();
      final series = [
        for (var i = 0; i < base.length; i++)
          (i == 50 || i == 51 || i == 120) ? (t: base[i].t, bar: 0.8) : base[i],
      ];
      expect(looksLikeInterleavedSources(series), isFalse);
    });

    test('a recording with two transient dips is not mixed', () {
      final base = recording(start: 57, count: 80);
      final series = [
        for (var i = 0; i < base.length; i++)
          i == 30 || i == 60 ? (t: base[i].t, bar: base[i].bar - 8) : base[i],
      ];
      expect(looksLikeInterleavedSources(series), isFalse);
    });

    // A transmitter that loses its signal can log a near-zero reading at
    // the same second as a real one. That is a dropout, not a second
    // recording, the same way the track split passes over near-zero
    // readings.
    test('dropouts logged at the second of a real reading are not mixed', () {
      final base = recording(start: 57, count: 80);
      final series = [
        for (var i = 0; i < base.length; i++) ...[
          base[i],
          if (i == 20 || i == 40 || i == 60) (t: base[i].t, bar: 0.8),
        ],
      ];
      expect(looksLikeInterleavedSources(series), isFalse);
    });

    test('an empty series is not mixed', () {
      expect(looksLikeInterleavedSources(const []), isFalse);
    });
  });
}
