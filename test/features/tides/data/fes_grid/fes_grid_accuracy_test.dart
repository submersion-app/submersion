import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// tide.dart also exports constituentSpeeds.
import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

/// Documented exceptions to the 12-minute limit. Vieques has a near-flat
/// mixed tide (0.5 cm height error), so its extreme times are poorly
/// defined. Komodo sits mid-strait, where the M2 phase spans 73 to 123
/// degrees across one 11 km cell; its mixed tide has shallow secondary
/// extremes whose times move a lot for a 2 degree phase difference, while
/// its heights stay within 4 cm. The Maldives atolls fall below the mask's
/// resolution and use the 1-degree global layer.
const _timeLimitMinutes = {'Vieques': 40.0, 'Komodo': 25.0, 'Maldives': 15.0};

double _p90(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * 0.9).round()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reader = FesGridReader.bundled();
  final vectors =
      json.decode(
            File(
              p.join(
                'test',
                'features',
                'tides',
                'data',
                'fixtures',
                'fes_native_vectors.json',
              ),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test(
    'the bundled grid only carries constituents the engine can predict',
    () async {
      final manifest = await reader.manifest();
      expect(manifest, isNotNull);
      expect(manifest!.constituents, hasLength(25));
      expect(
        manifest.constituents.toSet().difference(
          constituentSpeeds.keys.toSet(),
        ),
        isEmpty,
      );
    },
  );

  test('a salt-water site geocoded deep inland has no model data', () async {
    expect(await reader.sampleAt(23.0, 12.0), isNull); // central Sahara
  });

  for (final site in (vectors['sites'] as List).cast<Map<String, dynamic>>()) {
    final name = site['name'] as String;
    test('$name matches native FES2022 within tolerance', () async {
      final sample = await reader.sampleAt(
        (site['lat'] as num).toDouble(),
        (site['lon'] as num).toDouble(),
      );
      expect(sample, isNotNull, reason: '$name has no grid data');
      final native = TideCalculator(
        constituents: {
          for (final entry
              in (site['constituents'] as Map<String, dynamic>).entries)
            entry.key: TideConstituent(
              name: entry.key,
              amplitude: ((entry.value as Map)['amplitude'] as num).toDouble(),
              phase: ((entry.value as Map)['phase'] as num).toDouble(),
            ),
        },
      );
      final ours = TideCalculator(constituents: sample!.constituents);
      final start = DateTime.utc(2026, 6, 1);
      final end = DateTime.utc(2026, 6, 16);
      final expected = native.findExtremes(start: start, end: end);
      final actual = ours.findExtremes(start: start, end: end);

      final timeErrors = <double>[];
      final heightErrors = <double>[];
      for (final e in expected) {
        TideExtreme? best;
        for (final a in actual) {
          if (a.type != e.type) continue;
          if (best == null ||
              a.time.difference(e.time).abs() <
                  best.time.difference(e.time).abs()) {
            best = a;
          }
        }
        if (best == null ||
            best.time.difference(e.time).abs() > const Duration(hours: 3)) {
          continue;
        }
        timeErrors.add(best.time.difference(e.time).inSeconds.abs() / 60);
        heightErrors.add((best.heightMeters - e.heightMeters).abs());
      }

      expect(timeErrors.length, greaterThanOrEqualTo(expected.length * 0.9));
      expect(_p90(heightErrors), lessThanOrEqualTo(0.05), reason: name);
      expect(
        _p90(timeErrors),
        lessThanOrEqualTo(_timeLimitMinutes[name] ?? 12.0),
        reason: name,
      );
    });
  }
}
