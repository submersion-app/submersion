import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/profile_overlap_match.dart';

OffsetDepthSample _s(int offsetSeconds, double depth) =>
    (offsetSeconds: offsetSeconds, depth: depth);

void main() {
  group('compareProfileOverlap', () {
    test(
      'a segment whose samples exactly retrace part of a longer profile is a strong match',
      () {
        // "Existing" is a 40-minute consolidated dive (already merged from
        // another app). "Incoming" is the raw second segment the watch
        // itself recorded separately, starting 20 minutes into existing's
        // timeline -- the Dunkerque scenario.
        final existing = [
          for (var t = 0; t <= 2400; t += 30) _s(t, 5 + 3 * (t % 300) / 300),
        ];
        const incomingOffset = 1200; // 20 minutes in.
        final incoming = [
          for (final e in existing)
            if (e.offsetSeconds >= incomingOffset &&
                e.offsetSeconds <= incomingOffset + 780)
              _s(e.offsetSeconds - incomingOffset, e.depth),
        ];

        final result = compareProfileOverlap(
          existing: existing,
          incoming: incoming,
          incomingOffsetSeconds: incomingOffset,
        );

        expect(result, isNotNull);
        expect(result!.isStrongMatch, isTrue);
        expect(result.coverage, closeTo(1.0, 0.001));
        expect(result.meanAbsDepthErrorMeters, closeTo(0.0, 0.001));
      },
    );

    test('two unrelated dives with similar depths are not a strong match', () {
      final existing = [
        for (var t = 0; t <= 1200; t += 30) _s(t, 10 + (t % 120) / 12),
      ];
      // A different dive, same rough depth range, but not the same trace,
      // placed as if it started 5 minutes into "existing".
      final incoming = [
        for (var t = 0; t <= 600; t += 30) _s(t, 8 + (t % 90) / 9),
      ];

      final result = compareProfileOverlap(
        existing: existing,
        incoming: incoming,
        incomingOffsetSeconds: 300,
      );

      expect(result, isNotNull);
      expect(result!.isStrongMatch, isFalse);
    });

    test(
      'a segment that starts after existing profile ends has no overlap',
      () {
        final existing = [for (var t = 0; t <= 600; t += 30) _s(t, 10.0)];
        final incoming = [for (var t = 0; t <= 300; t += 30) _s(t, 10.0)];

        // incoming starts 1000s after existing's start -- well past existing's
        // last sample at 600s.
        final result = compareProfileOverlap(
          existing: existing,
          incoming: incoming,
          incomingOffsetSeconds: 1000,
        );

        expect(result, isNull);
      },
    );

    test('too few samples on either side is not judged', () {
      expect(
        compareProfileOverlap(
          existing: [_s(0, 10.0)],
          incoming: [_s(0, 10.0), _s(30, 10.0)],
          incomingOffsetSeconds: 0,
        ),
        isNull,
      );
      expect(
        compareProfileOverlap(
          existing: [_s(0, 10.0), _s(30, 10.0)],
          incoming: [_s(0, 10.0)],
          incomingOffsetSeconds: 0,
        ),
        isNull,
      );
    });

    test('fewer overlapping samples than the minimum is not judged', () {
      final existing = [for (var t = 0; t <= 60; t += 30) _s(t, 10.0)];
      final incoming = [for (var t = 0; t <= 60; t += 30) _s(t, 10.0)];

      // Only the last incoming sample (offset 60) lands inside existing's
      // 0-60 span once shifted by 50s; that is 1 comparable sample, under
      // the default minimum of 4.
      final result = compareProfileOverlap(
        existing: existing,
        incoming: incoming,
        incomingOffsetSeconds: 50,
      );

      expect(result, isNull);
    });

    test('interpolates between existing samples rather than snapping', () {
      final existing = [_s(0, 0.0), _s(100, 10.0)];
      final incoming = [_s(0, 5.0), _s(50, 5.2), _s(100, 5.0), _s(150, 5.0)];

      final result = compareProfileOverlap(
        existing: existing,
        incoming: incoming,
        incomingOffsetSeconds: 0,
        minOverlapSamples: 1,
      );

      // Only offsets 0, 50 and 100 land inside existing's 0-100 span
      // (interpolated depths 0.0, 5.0, 10.0); offset 150 is outside and
      // excluded. Errors: |5.0-0.0|=5.0, |5.2-5.0|=0.2, |5.0-10.0|=5.0.
      expect(result, isNotNull);
      expect(result!.comparedSamples, 3);
      expect(result.coverage, closeTo(3 / 4, 0.001));
      expect(
        result.meanAbsDepthErrorMeters,
        closeTo((5.0 + 0.2 + 5.0) / 3, 0.01),
      );
    });

    test(
      'two existing samples sharing a timestamp resolve to the first depth',
      () {
        // A degenerate but real-world input: noisy raw data can log two
        // samples at the same offset. Division by a zero span must not
        // happen; the first of the tied pair wins. Existing starts AT the
        // tie (no earlier bracket to resolve it first), so a lookup at that
        // exact offset can only be answered by the tie branch itself.
        final existing = [_s(50, 5.0), _s(50, 9.0), _s(100, 3.0)];
        final incoming = [_s(0, 5.0), _s(50, 3.0)];

        final result = compareProfileOverlap(
          existing: existing,
          incoming: incoming,
          incomingOffsetSeconds: 50,
          minOverlapSamples: 1,
        );

        expect(result, isNotNull);
        expect(result!.comparedSamples, 2);
        // Offset 50 (on existing's clock) hits the tie, taking 5.0 -- not
        // 9.0 -- and offset 100 interpolates normally to 3.0. Both incoming
        // samples match exactly.
        expect(result.meanAbsDepthErrorMeters, closeTo(0.0, 0.001));
      },
    );
  });
}
