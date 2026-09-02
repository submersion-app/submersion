import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  manualPositionTests();
  late EnrichmentService service;
  late DateTime diveStartTime;

  setUp(() {
    service = const EnrichmentService();
    diveStartTime = DateTime(2024, 1, 15, 10, 0, 0);
  });

  group('EnrichmentService', () {
    group('calculateEnrichment', () {
      test('returns noProfile when profile is empty', () {
        final result = service.calculateEnrichment(
          profile: [],
          diveStartTime: diveStartTime,
          photoTime: diveStartTime.add(const Duration(minutes: 5)),
        );

        expect(result.matchConfidence, MatchConfidence.noProfile);
        expect(result.depthMeters, isNull);
        expect(result.temperatureCelsius, isNull);
        expect(result.elapsedSeconds, 300);
      });

      test('returns exact match when within 10 seconds of profile point', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 120,
            depth: 18.0,
            temperature: 20.0,
          ),
          const DiveProfilePoint(
            timestamp: 180,
            depth: 15.0,
            temperature: 19.0,
          ),
        ];

        // Photo at 65 seconds - within 10 seconds of 60-second point
        final photoTime = diveStartTime.add(const Duration(seconds: 65));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.matchConfidence, MatchConfidence.exact);
        expect(result.depthMeters, 10.0);
        expect(result.temperatureCelsius, 22.0);
        expect(result.elapsedSeconds, 65);
        expect(result.timestampOffsetSeconds, 5);
      });

      test('interpolates depth between two profile points', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 120,
            depth: 20.0,
            temperature: 20.0,
          ),
        ];

        // Photo at 90 seconds - halfway between 60 and 120 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 90));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.matchConfidence, MatchConfidence.interpolated);
        expect(result.depthMeters, closeTo(15.0, 0.01));
        expect(result.temperatureCelsius, closeTo(21.0, 0.01));
        expect(result.elapsedSeconds, 90);
      });

      test('returns estimated when gap is large (>60 seconds)', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 180,
            depth: 20.0,
            temperature: 18.0,
          ),
        ];

        // Photo at 120 seconds - between points 120 seconds apart
        final photoTime = diveStartTime.add(const Duration(seconds: 120));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.matchConfidence, MatchConfidence.estimated);
        expect(result.depthMeters, closeTo(15.0, 0.01));
        expect(result.temperatureCelsius, closeTo(20.0, 0.01));
        expect(result.elapsedSeconds, 120);
      });

      test('handles photo before first profile point', () {
        final profile = [
          const DiveProfilePoint(timestamp: 30, depth: 5.0, temperature: 23.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 120,
            depth: 18.0,
            temperature: 20.0,
          ),
        ];

        // Photo at 10 seconds - before first profile point at 30 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 10));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        // Should use first profile point values
        expect(result.matchConfidence, MatchConfidence.estimated);
        expect(result.depthMeters, 5.0);
        expect(result.temperatureCelsius, 23.0);
        expect(result.elapsedSeconds, 10);
        expect(result.timestampOffsetSeconds, -20);
      });

      test('handles photo after last profile point', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(timestamp: 120, depth: 5.0, temperature: 21.0),
        ];

        // Photo at 150 seconds - after last profile point at 120 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 150));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        // Should use last profile point values
        expect(result.matchConfidence, MatchConfidence.estimated);
        expect(result.depthMeters, 5.0);
        expect(result.temperatureCelsius, 21.0);
        expect(result.elapsedSeconds, 150);
        expect(result.timestampOffsetSeconds, 30);
      });

      test('interpolates temperature when both points have it', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0, temperature: 25.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 120,
            depth: 20.0,
            temperature: 18.0,
          ),
        ];

        // Photo at 90 seconds - halfway between 60 and 120 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 90));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.temperatureCelsius, closeTo(20.0, 0.01));
      });

      test('uses nearest temperature when only one point has it', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(timestamp: 120, depth: 20.0),
        ];

        // Photo at 90 seconds - between points where only one has temperature
        final photoTime = diveStartTime.add(const Duration(seconds: 90));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        // Should use the temperature from the point that has it (60s = 22.0)
        expect(result.temperatureCelsius, 22.0);
      });

      test('returns null temperature when neither point has it', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0),
          const DiveProfilePoint(timestamp: 120, depth: 20.0),
        ];

        // Photo at 90 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 90));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.temperatureCelsius, isNull);
      });

      test('handles exact match at first profile point', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.5, temperature: 24.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
        ];

        // Photo at exactly 0 seconds
        final photoTime = diveStartTime;
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.matchConfidence, MatchConfidence.exact);
        expect(result.depthMeters, 0.5);
        expect(result.temperatureCelsius, 24.0);
        expect(result.elapsedSeconds, 0);
        expect(result.timestampOffsetSeconds, 0);
      });

      test('handles exact match at last profile point', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0),
          const DiveProfilePoint(timestamp: 120, depth: 3.0, temperature: 21.0),
        ];

        // Photo at exactly 120 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 120));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.matchConfidence, MatchConfidence.exact);
        expect(result.depthMeters, 3.0);
        expect(result.temperatureCelsius, 21.0);
        expect(result.elapsedSeconds, 120);
      });

      test('handles single point profile', () {
        final profile = [
          const DiveProfilePoint(timestamp: 60, depth: 15.0, temperature: 20.0),
        ];

        // Photo at 90 seconds
        final photoTime = diveStartTime.add(const Duration(seconds: 90));
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        // With single point, should use that point's values
        expect(result.matchConfidence, MatchConfidence.estimated);
        expect(result.depthMeters, 15.0);
        expect(result.temperatureCelsius, 20.0);
      });

      test('correctly calculates elapsed seconds from dive start', () {
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 300, depth: 20.0),
        ];

        // Photo 7 minutes and 30 seconds into dive
        final photoTime = diveStartTime.add(
          const Duration(minutes: 7, seconds: 30),
        );
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: diveStartTime,
          photoTime: photoTime,
        );

        expect(result.elapsedSeconds, 450);
      });
    });

    group('calculateEnrichment with wall-clock-as-UTC dive times', () {
      // In production, diveStartTime is wall-clock-as-UTC (isUtc: true)
      // while photoTime from EXIF/gallery is local (isUtc: false).
      // The service must handle this mismatch correctly.

      test(
        'calculates correct elapsed seconds with UTC start and local photo',
        () {
          final utcStart = DateTime.utc(2024, 1, 15, 10, 0, 0);
          final profile = [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(
              timestamp: 300,
              depth: 20.0,
              temperature: 18.0,
            ),
          ];

          // Photo 2 minutes into dive, but as local DateTime
          final localPhoto = DateTime(2024, 1, 15, 10, 2, 0);
          final result = service.calculateEnrichment(
            profile: profile,
            diveStartTime: utcStart,
            photoTime: localPhoto,
          );

          // Should be 120 seconds regardless of timezone offset
          expect(result.elapsedSeconds, 120);
        },
      );

      test('finds exact match with UTC start and local photo', () {
        final utcStart = DateTime.utc(2024, 1, 15, 10, 0, 0);
        final profile = [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
          const DiveProfilePoint(
            timestamp: 120,
            depth: 18.0,
            temperature: 20.0,
          ),
        ];

        // Photo at ~60 seconds into dive (local time)
        final localPhoto = DateTime(2024, 1, 15, 10, 1, 5);
        final result = service.calculateEnrichment(
          profile: profile,
          diveStartTime: utcStart,
          photoTime: localPhoto,
        );

        expect(result.matchConfidence, MatchConfidence.exact);
        expect(result.depthMeters, 10.0);
        expect(result.elapsedSeconds, 65);
      });
    });

    group('EnrichmentResult', () {
      test('creates result with all fields', () {
        const result = EnrichmentResult(
          depthMeters: 15.5,
          temperatureCelsius: 20.0,
          elapsedSeconds: 300,
          matchConfidence: MatchConfidence.interpolated,
          timestampOffsetSeconds: 5,
        );

        expect(result.depthMeters, 15.5);
        expect(result.temperatureCelsius, 20.0);
        expect(result.elapsedSeconds, 300);
        expect(result.matchConfidence, MatchConfidence.interpolated);
        expect(result.timestampOffsetSeconds, 5);
      });

      test('creates result with minimal fields', () {
        const result = EnrichmentResult(
          elapsedSeconds: 300,
          matchConfidence: MatchConfidence.noProfile,
        );

        expect(result.depthMeters, isNull);
        expect(result.temperatureCelsius, isNull);
        expect(result.elapsedSeconds, 300);
        expect(result.matchConfidence, MatchConfidence.noProfile);
        expect(result.timestampOffsetSeconds, isNull);
      });

      test('supports equality comparison', () {
        const result1 = EnrichmentResult(
          depthMeters: 15.0,
          elapsedSeconds: 300,
          matchConfidence: MatchConfidence.exact,
        );
        const result2 = EnrichmentResult(
          depthMeters: 15.0,
          elapsedSeconds: 300,
          matchConfidence: MatchConfidence.exact,
        );

        expect(result1, equals(result2));
      });
    });

    group('threshold constants', () {
      test('exactMatchThreshold is 10 seconds', () {
        expect(EnrichmentService.exactMatchThreshold, 10);
      });

      test('interpolationThreshold is 60 seconds', () {
        expect(EnrichmentService.interpolationThreshold, 60);
      });
    });
  });
}

/// A manual position (issue #1090) starts from a dive offset the diver
/// chose, not from a capture time, so the wall-clock normalisation never
/// runs and the confidence is always [MatchConfidence.manual]: the profile
/// lookup is the same, but the diver's placement is not an estimate.
void manualPositionTests() {
  const service = EnrichmentService();
  final profile = [
    const DiveProfilePoint(timestamp: 0, depth: 0.0),
    const DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
    const DiveProfilePoint(timestamp: 120, depth: 18.0, temperature: 20.0),
  ];

  group('calculateEnrichmentAtElapsed', () {
    test('snaps to a profile point within the exact threshold', () {
      final result = service.calculateEnrichmentAtElapsed(
        profile: profile,
        elapsedSeconds: 65,
      );
      expect(result.elapsedSeconds, 65);
      expect(result.depthMeters, 10.0);
      expect(result.temperatureCelsius, 22.0);
      expect(result.timestampOffsetSeconds, 5);
      expect(result.matchConfidence, MatchConfidence.manual);
    });

    test('interpolates between bracketing points', () {
      final result = service.calculateEnrichmentAtElapsed(
        profile: profile,
        elapsedSeconds: 90,
      );
      expect(result.depthMeters, 14.0);
      expect(result.temperatureCelsius, 21.0);
      expect(result.matchConfidence, MatchConfidence.manual);
    });

    test('uses the first point before the profile starts', () {
      final result = service.calculateEnrichmentAtElapsed(
        profile: profile,
        elapsedSeconds: -30,
      );
      expect(result.depthMeters, 0.0);
      expect(result.elapsedSeconds, -30);
      expect(result.matchConfidence, MatchConfidence.manual);
    });

    test('uses the last point after the profile ends', () {
      final result = service.calculateEnrichmentAtElapsed(
        profile: profile,
        elapsedSeconds: 500,
      );
      expect(result.depthMeters, 18.0);
      expect(result.matchConfidence, MatchConfidence.manual);
    });

    test('reports noProfile for an empty profile', () {
      final result = service.calculateEnrichmentAtElapsed(
        profile: const [],
        elapsedSeconds: 90,
      );
      expect(result.matchConfidence, MatchConfidence.noProfile);
      expect(result.depthMeters, isNull);
      expect(result.elapsedSeconds, 90);
    });
  });
}
