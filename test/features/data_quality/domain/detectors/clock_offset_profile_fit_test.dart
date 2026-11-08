import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/clock_offset_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

import '../../helpers/quality_test_helpers.dart';

/// A multilevel reef dive sampled every 10 s, starting at [start] on the
/// primary's timeline, with [lead] seconds at the surface first.
List<QualitySample> _reef({int start = 0, int lead = 0}) {
  const knots = <(int, double)>[
    (0, 0),
    (120, 18),
    (240, 22),
    (600, 21),
    (900, 16),
    (1300, 14),
    (1700, 10),
    (2200, 8),
    (2400, 5),
    (2580, 5),
    (2760, 4.8),
    (2880, 0),
  ];
  double at(int t) {
    for (var i = 1; i < knots.length; i++) {
      final (t0, d0) = knots[i - 1];
      final (t1, d1) = knots[i];
      if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
    return 0;
  }

  return [
    for (var t = 0; t <= 2880 + lead; t += 10)
      QualitySample(t: start + t, depth: t < lead ? 0 : at(t - lead)),
  ];
}

void main() {
  const det = ClockOffsetDetector();
  final entry = DateTime.utc(2026, 7, 1, 10);

  List<DiveDataSource> twoSources() => [
    DiveDataSource(
      id: 's-primary',
      diveId: 'd1',
      isPrimary: true,
      entryTime: entry,
      importedAt: entry,
      createdAt: entry,
    ),
    DiveDataSource(
      id: 's-second',
      diveId: 'd1',
      computerId: 'comp-2',
      isPrimary: false,
      entryTime: entry.subtract(const Duration(minutes: 20)),
      importedAt: entry,
      createdAt: entry,
    ),
  ];

  List<QualityFinding> fitFindings(List<QualitySample> second) => [
    for (final f in det.detect(
      makeContext(
        dive: makeTestDive(entry: entry),
        sources: twoSources(),
        samples: _reef(),
        sourceSamples: {'s-second': second},
      ),
    ))
      if (f.params.containsKey('profileOffsetSeconds')) f,
  ];

  group('a source placed away from where its profile fits (#4296)', () {
    test('a source placed by a clock 20 minutes slow is flagged with the '
        'shift that lines it up', () {
      // Its samples belong at -40 s (40 s at the surface before the
      // descent), but sit at -1200 s, where its clock put them.
      final out = fitFindings(_reef(start: -1200, lead: 40));
      expect(out, hasLength(1));
      final f = out.single;
      expect(f.detectorId, 'clock_offset');
      expect(f.computerId, 'comp-2');
      expect(f.severity, QualitySeverity.warning);
      expect(f.params['sourceId'], 's-second');
      expect(f.params['profileOffsetSeconds'], 1160);
    });

    test('a source whose clock runs fast is flagged the other way', () {
      final out = fitFindings(_reef(start: 1800, lead: 40));
      expect(out.single.params['profileOffsetSeconds'], -1840);
    });

    test('a source placed where its profile fits is not flagged', () {
      expect(fitFindings(_reef(start: -40, lead: 40)), isEmpty);
    });

    test('a placement within the clock tolerance is not flagged', () {
      // 4 minutes off: clocks set by hand a few minutes apart.
      expect(fitFindings(_reef(start: -280, lead: 40)), isEmpty);
    });

    test('a source whose trace matches the primary nowhere is not flagged', () {
      expect(
        fitFindings([
          for (var t = -1200; t <= 1680; t += 10) QualitySample(t: t, depth: 5),
        ]),
        isEmpty,
      );
    });

    test('a later segment of a joined dive, placed after the primary, is '
        'not pulled onto it', () {
      // Two sequential records joined into one dive: the second starts
      // after the first ends, and looks just like it.
      expect(fitFindings(_reef(start: 3000)), isEmpty);
      expect(fitFindings(_reef(start: -3200)), isEmpty);
    });

    test('a source with no samples is not flagged', () {
      expect(fitFindings(const []), isEmpty);
    });

    test('the primary is never checked against itself', () {
      final out = det.detect(
        makeContext(
          dive: makeTestDive(entry: entry),
          sources: twoSources(),
          samples: _reef(),
          sourceSamples: {'s-primary': _reef(start: -1200)},
        ),
      );
      expect(
        out.where((f) => f.params.containsKey('profileOffsetSeconds')),
        isEmpty,
      );
    });
  });
}
