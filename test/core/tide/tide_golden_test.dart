import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/tide/tide.dart';

void main() {
  group('M2 frequency regression', () {
    test('M2-only prediction has the true M2 period of 12.4206 hours', () {
      // The pre-fix engine double-counted the time evolution and cycled
      // M2 at ~6.1 hours. Average the high-to-high spacing over 10 days.
      final calculator = TideCalculator(
        constituents: {
          'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
        },
      );
      final extremes = calculator.findExtremes(
        start: DateTime.utc(2026, 6, 1),
        end: DateTime.utc(2026, 6, 11),
      );
      final highs = extremes
          .where((e) => e.type == TideExtremeType.high)
          .toList();
      expect(highs.length, greaterThan(15));
      final spanMinutes =
          highs.last.time.difference(highs.first.time).inSeconds / 60.0;
      final periodMinutes = spanMinutes / (highs.length - 1);
      expect(periodMinutes, closeTo(12.4206 * 60, 1.0));
    });
  });

  group('Golden reference: NOAA published predictions', () {
    // Fixtures fetched 2026-08-09 from NOAA CO-OPS (harcon + datums +
    // hilo predictions). Constituents in, published extremes out: any
    // error in astronomy, tables, or phase math fails these.
    const stations = [
      'noaa_station_9414290', // San Francisco, mixed
      'noaa_station_8443970', // Boston, semi-diurnal
      'noaa_station_8729840', // Pensacola, diurnal
    ];

    for (final fixtureName in stations) {
      test('$fixtureName extremes within 20 min / 0.15 m of NOAA', () {
        final fixture =
            json.decode(
                  File(
                    'test/core/tide/fixtures/$fixtureName.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        final constituents = <String, TideConstituent>{};
        (fixture['constituents'] as Map<String, dynamic>).forEach((name, c) {
          constituents[name] = TideConstituent(
            name: name,
            amplitude: (c['amplitude'] as num).toDouble(),
            phase: (c['phase'] as num).toDouble(),
          );
        });
        final calculator = TideCalculator(
          constituents: constituents,
          z0: (fixture['z0MetersAboveMllw'] as num).toDouble(),
        );

        final expected = (fixture['expectedExtremes'] as List)
            .cast<Map<String, dynamic>>();

        // Compute extremes over each fixture window (two 2-day windows).
        final windows = [
          (DateTime.utc(2026, 9, 14, 21), DateTime.utc(2026, 9, 17, 3)),
          (DateTime.utc(2027, 6, 14, 21), DateTime.utc(2027, 6, 17, 3)),
        ];
        final ours = <TideExtreme>[];
        for (final (start, end) in windows) {
          ours.addAll(calculator.findExtremes(start: start, end: end));
        }

        for (final e in expected) {
          final time = DateTime.parse(e['time'] as String);
          final type = e['type'] == 'H'
              ? TideExtremeType.high
              : TideExtremeType.low;
          final height = (e['height'] as num).toDouble();

          final match = ours
              .where((o) => o.type == type)
              .reduce(
                (a, b) =>
                    a.time.difference(time).abs() <
                        b.time.difference(time).abs()
                    ? a
                    : b,
              );

          expect(
            match.time.difference(time).abs().inMinutes,
            lessThanOrEqualTo(20),
            reason: '${fixture['name']}: $type at $time matched ${match.time}',
          );
          expect(
            match.heightMeters,
            closeTo(height, 0.15),
            reason: '${fixture['name']}: $type height at $time',
          );
        }
      });
    }
  });
}
