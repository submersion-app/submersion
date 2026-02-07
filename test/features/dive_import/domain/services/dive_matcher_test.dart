import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';

void main() {
  group('DiveMatcher', () {
    late DiveMatcher matcher;

    setUp(() {
      matcher = const DiveMatcher();
    });

    group('calculateMatchScore', () {
      test('returns high score for identical time, depth, duration', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        expect(score, greaterThan(0.9));
      });

      test('returns lower score for 8 min time difference', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 8),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        // Time score: 1.0 - ((8-5)/10) = 0.7
        // Depth score: 1.0, Duration score: 1.0
        // Composite: (0.7 * 0.5) + (1.0 * 0.3) + (1.0 * 0.2) = 0.85
        expect(score, greaterThan(0.7));
        expect(score, lessThan(0.95));
      });

      test('returns low score for 20 min time difference', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 20),
          existingMaxDepth: 18.5,
          existingDurationSeconds: 45 * 60,
        );

        // Time score: 0 (>= 15 min)
        // Depth score: 1.0, Duration score: 1.0
        // Composite: (0 * 0.5) + (1.0 * 0.3) + (1.0 * 0.2) = 0.5
        expect(score, lessThanOrEqualTo(0.5));
      });

      test('reduces score for depth difference > 10%', () {
        final perfectScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 20.0,
          existingDurationSeconds: 45 * 60,
        );

        final depthDiffScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 25.0,
          existingDurationSeconds: 45 * 60,
        );

        expect(depthDiffScore, lessThan(perfectScore));
      });

      test('reduces score for duration difference', () {
        final perfectScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 20.0,
          existingDurationSeconds: 45 * 60,
        );

        final durationDiffScore = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 20.0,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 20.0,
          existingDurationSeconds: 55 * 60, // 10 min difference
        );

        expect(durationDiffScore, lessThan(perfectScore));
      });

      test('handles zero existing depth gracefully', () {
        final score = matcher.calculateMatchScore(
          wearableStartTime: DateTime(2026, 1, 15, 10, 0),
          wearableMaxDepth: 18.5,
          wearableDurationSeconds: 45 * 60,
          existingStartTime: DateTime(2026, 1, 15, 10, 0),
          existingMaxDepth: 0.0,
          existingDurationSeconds: 45 * 60,
        );

        // Should not throw, should return a valid score
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });
    });

    group('isProbableDuplicate', () {
      test('returns true for score >= 0.7', () {
        expect(matcher.isProbableDuplicate(0.7), isTrue);
        expect(matcher.isProbableDuplicate(0.9), isTrue);
      });

      test('returns false for score < 0.7', () {
        expect(matcher.isProbableDuplicate(0.69), isFalse);
        expect(matcher.isProbableDuplicate(0.5), isFalse);
      });
    });

    group('isPossibleDuplicate', () {
      test('returns true for score >= 0.5', () {
        expect(matcher.isPossibleDuplicate(0.5), isTrue);
        expect(matcher.isPossibleDuplicate(0.7), isTrue);
      });

      test('returns false for score < 0.5', () {
        expect(matcher.isPossibleDuplicate(0.49), isFalse);
      });
    });
  });

  group('DiveMatchResult', () {
    test('isProbable returns true for score >= 0.7', () {
      const result = DiveMatchResult(
        diveId: 'dive-123',
        score: 0.75,
        timeDifferenceMs: 60000,
      );
      expect(result.isProbable, isTrue);
    });

    test('isProbable returns false for score < 0.7', () {
      const result = DiveMatchResult(
        diveId: 'dive-123',
        score: 0.65,
        timeDifferenceMs: 60000,
      );
      expect(result.isProbable, isFalse);
    });

    test('isPossible returns true for score >= 0.5', () {
      const result = DiveMatchResult(
        diveId: 'dive-123',
        score: 0.55,
        timeDifferenceMs: 60000,
      );
      expect(result.isPossible, isTrue);
    });

    test('isPossible returns false for score < 0.5', () {
      const result = DiveMatchResult(
        diveId: 'dive-123',
        score: 0.45,
        timeDifferenceMs: 60000,
      );
      expect(result.isPossible, isFalse);
    });
  });
}
