import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('DetectionResult', () {
    test('constructs with required fields', () {
      const result = DetectionResult(
        format: ImportFormat.uddf,
        confidence: 0.95,
      );

      expect(result.format, ImportFormat.uddf);
      expect(result.confidence, 0.95);
      expect(result.sourceApp, isNull);
      expect(result.suggestedMapping, isNull);
      expect(result.warnings, isEmpty);
      expect(result.csvHeaders, isNull);
    });

    test('constructs with all fields', () {
      const result = DetectionResult(
        format: ImportFormat.csv,
        sourceApp: SourceApp.subsurface,
        confidence: 0.9,
        suggestedMapping: {'col1': 'maxDepth'},
        warnings: ['Truncated file'],
        csvHeaders: ['date', 'depth', 'time'],
      );

      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.subsurface);
      expect(result.confidence, 0.9);
      expect(result.suggestedMapping, {'col1': 'maxDepth'});
      expect(result.warnings, ['Truncated file']);
      expect(result.csvHeaders, ['date', 'depth', 'time']);
    });

    group('isHighConfidence', () {
      test('returns true when confidence >= 0.85', () {
        const result = DetectionResult(
          format: ImportFormat.uddf,
          confidence: 0.85,
        );

        expect(result.isHighConfidence, isTrue);
      });

      test('returns true when confidence > 0.85', () {
        const result = DetectionResult(
          format: ImportFormat.uddf,
          confidence: 0.95,
        );

        expect(result.isHighConfidence, isTrue);
      });

      test('returns false when confidence < 0.85', () {
        const result = DetectionResult(
          format: ImportFormat.uddf,
          confidence: 0.84,
        );

        expect(result.isHighConfidence, isFalse);
      });
    });

    group('isFormatSupported', () {
      test('returns true for supported formats', () {
        const result = DetectionResult(
          format: ImportFormat.uddf,
          confidence: 0.9,
        );

        expect(result.isFormatSupported, isTrue);
      });

      test('returns false for unsupported formats', () {
        const result = DetectionResult(
          format: ImportFormat.divingLogXml,
          confidence: 0.9,
        );

        expect(result.isFormatSupported, isFalse);
      });
    });

    group('description', () {
      test('includes source app name when source app is set', () {
        const result = DetectionResult(
          format: ImportFormat.uddf,
          sourceApp: SourceApp.shearwater,
          confidence: 0.95,
        );

        expect(result.description, 'Detected Shearwater UDDF file');
      });

      test('uses format only when source app is null', () {
        const result = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.7,
        );

        expect(result.description, 'Detected CSV file');
      });

      test('does not include confidence percentage', () {
        const result = DetectionResult(
          format: ImportFormat.fit,
          sourceApp: SourceApp.garminConnect,
          confidence: 0.92,
        );

        expect(result.description, isNot(contains('%')));
        expect(result.description, isNot(contains('confidence')));
      });
    });

    group('Equatable', () {
      test('equal objects have same props', () {
        const a = DetectionResult(
          format: ImportFormat.uddf,
          sourceApp: SourceApp.shearwater,
          confidence: 0.95,
        );
        const b = DetectionResult(
          format: ImportFormat.uddf,
          sourceApp: SourceApp.shearwater,
          confidence: 0.95,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different format produces inequality', () {
        const a = DetectionResult(format: ImportFormat.uddf, confidence: 0.95);
        const b = DetectionResult(format: ImportFormat.csv, confidence: 0.95);

        expect(a, isNot(equals(b)));
      });

      test('different confidence produces inequality', () {
        const a = DetectionResult(format: ImportFormat.uddf, confidence: 0.95);
        const b = DetectionResult(format: ImportFormat.uddf, confidence: 0.50);

        expect(a, isNot(equals(b)));
      });

      test('props includes all fields', () {
        const result = DetectionResult(
          format: ImportFormat.csv,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
          suggestedMapping: {'col1': 'maxDepth'},
          warnings: ['warning'],
          csvHeaders: ['date'],
        );

        expect(result.props, hasLength(6));
      });

      test('different sourceApp produces inequality', () {
        const a = DetectionResult(
          format: ImportFormat.csv,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        );
        const b = DetectionResult(
          format: ImportFormat.csv,
          sourceApp: SourceApp.macdive,
          confidence: 0.9,
        );

        expect(a, isNot(equals(b)));
      });

      test('null vs non-null sourceApp produces inequality', () {
        const a = DetectionResult(format: ImportFormat.csv, confidence: 0.9);
        const b = DetectionResult(
          format: ImportFormat.csv,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        );

        expect(a, isNot(equals(b)));
      });

      test('different suggestedMapping produces inequality', () {
        const a = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          suggestedMapping: {'col1': 'maxDepth'},
        );
        const b = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          suggestedMapping: {'col1': 'waterTemp'},
        );

        expect(a, isNot(equals(b)));
      });

      test('different warnings produces inequality', () {
        const a = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          warnings: ['Truncated'],
        );
        const b = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          warnings: ['Missing headers'],
        );

        expect(a, isNot(equals(b)));
      });

      test('different csvHeaders produces inequality', () {
        const a = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          csvHeaders: ['date', 'depth'],
        );
        const b = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          csvHeaders: ['time', 'temp'],
        );

        expect(a, isNot(equals(b)));
      });

      test('null vs non-null csvHeaders produces inequality', () {
        const a = DetectionResult(format: ImportFormat.csv, confidence: 0.9);
        const b = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          csvHeaders: ['date'],
        );

        expect(a, isNot(equals(b)));
      });

      test('null vs non-null suggestedMapping produces inequality', () {
        const a = DetectionResult(format: ImportFormat.csv, confidence: 0.9);
        const b = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          suggestedMapping: {'col': 'field'},
        );

        expect(a, isNot(equals(b)));
      });

      test('empty warnings equals default empty warnings', () {
        const a = DetectionResult(
          format: ImportFormat.csv,
          confidence: 0.9,
          warnings: [],
        );
        const b = DetectionResult(format: ImportFormat.csv, confidence: 0.9);

        expect(a, equals(b));
      });
    });
  });
}
