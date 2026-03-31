import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart'
    as csv;
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  const testPresetA = CsvPreset(
    id: 'preset_a',
    name: 'Preset A',
    sourceApp: SourceApp.subsurface,
  );

  const testPresetB = CsvPreset(
    id: 'preset_b',
    name: 'Preset B',
    sourceApp: SourceApp.macdive,
  );

  group('DetectionResult (CSV)', () {
    group('constructor and properties', () {
      test('constructs with default values', () {
        const result = csv.DetectionResult();

        expect(result.matchedPreset, isNull);
        expect(result.sourceApp, isNull);
        expect(result.confidence, 0.0);
        expect(result.rankedMatches, isEmpty);
        expect(result.hasAdditionalFileRoles, isFalse);
      });

      test('constructs with all fields', () {
        const match = csv.PresetMatch(
          preset: testPresetA,
          score: 0.95,
          matchedHeaders: 8,
          totalSignatureHeaders: 10,
        );

        const result = csv.DetectionResult(
          matchedPreset: testPresetA,
          sourceApp: SourceApp.subsurface,
          confidence: 0.95,
          rankedMatches: [match],
          hasAdditionalFileRoles: true,
        );

        expect(result.matchedPreset, testPresetA);
        expect(result.sourceApp, SourceApp.subsurface);
        expect(result.confidence, 0.95);
        expect(result.rankedMatches, hasLength(1));
        expect(result.hasAdditionalFileRoles, isTrue);
      });
    });

    group('isDetected', () {
      test('returns true when preset is matched and confidence > 0.5', () {
        const result = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.75,
        );

        expect(result.isDetected, isTrue);
      });

      test('returns true at high confidence', () {
        const result = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 1.0,
        );

        expect(result.isDetected, isTrue);
      });

      test('returns false when confidence is exactly 0.5', () {
        const result = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.5,
        );

        expect(result.isDetected, isFalse);
      });

      test('returns false when confidence is below 0.5', () {
        const result = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.3,
        );

        expect(result.isDetected, isFalse);
      });

      test('returns false when no matched preset', () {
        const result = csv.DetectionResult(confidence: 0.9);

        expect(result.isDetected, isFalse);
      });

      test('returns false when both preset is null and confidence is low', () {
        const result = csv.DetectionResult();

        expect(result.isDetected, isFalse);
      });
    });

    group('hasAdditionalFileRoles', () {
      test('defaults to false', () {
        const result = csv.DetectionResult();

        expect(result.hasAdditionalFileRoles, isFalse);
      });

      test('returns true when set', () {
        const result = csv.DetectionResult(hasAdditionalFileRoles: true);

        expect(result.hasAdditionalFileRoles, isTrue);
      });
    });

    group('Equatable', () {
      test('equal objects are equal', () {
        const a = csv.DetectionResult(
          matchedPreset: testPresetA,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        );
        const b = csv.DetectionResult(
          matchedPreset: testPresetA,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different confidence produces inequality', () {
        const a = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.9,
        );
        const b = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.5,
        );

        expect(a, isNot(equals(b)));
      });

      test('different preset produces inequality', () {
        const a = csv.DetectionResult(
          matchedPreset: testPresetA,
          confidence: 0.9,
        );
        const b = csv.DetectionResult(
          matchedPreset: testPresetB,
          confidence: 0.9,
        );

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('PresetMatch', () {
    group('constructor and properties', () {
      test('constructs with required fields', () {
        const match = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );

        expect(match.preset, testPresetA);
        expect(match.score, 0.8);
        expect(match.matchedHeaders, 6);
        expect(match.totalSignatureHeaders, 10);
      });
    });

    group('Equatable', () {
      test('equal objects are equal', () {
        const a = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );
        const b = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different score produces inequality', () {
        const a = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );
        const b = csv.PresetMatch(
          preset: testPresetA,
          score: 0.5,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );

        expect(a, isNot(equals(b)));
      });

      test('different matchedHeaders produces inequality', () {
        const a = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 6,
          totalSignatureHeaders: 10,
        );
        const b = csv.PresetMatch(
          preset: testPresetA,
          score: 0.8,
          matchedHeaders: 4,
          totalSignatureHeaders: 10,
        );

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('rankedMatches ordering', () {
    test('matches are stored in provided order', () {
      const matchHigh = csv.PresetMatch(
        preset: testPresetA,
        score: 0.95,
        matchedHeaders: 9,
        totalSignatureHeaders: 10,
      );
      const matchLow = csv.PresetMatch(
        preset: testPresetB,
        score: 0.4,
        matchedHeaders: 3,
        totalSignatureHeaders: 10,
      );

      const result = csv.DetectionResult(
        matchedPreset: testPresetA,
        confidence: 0.95,
        rankedMatches: [matchHigh, matchLow],
      );

      expect(result.rankedMatches, hasLength(2));
      expect(result.rankedMatches.first.score, 0.95);
      expect(result.rankedMatches.last.score, 0.4);
      expect(
        result.rankedMatches.first.score,
        greaterThan(result.rankedMatches.last.score),
      );
    });

    test('empty rankedMatches is valid', () {
      const result = csv.DetectionResult(
        matchedPreset: testPresetA,
        confidence: 0.8,
      );

      expect(result.rankedMatches, isEmpty);
    });
  });
}
