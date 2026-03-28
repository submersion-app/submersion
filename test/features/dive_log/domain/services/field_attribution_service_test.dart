import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';

DiveDataSource _makeSource({
  required String id,
  required String diveId,
  required bool isPrimary,
  String? computerModel,
  String? sourceFormat,
  double? maxDepth,
  double? avgDepth,
  int? duration,
  double? waterTemp,
  int? surfaceInterval,
  double? cns,
  double? otu,
}) {
  final now = DateTime(2024, 1, 1);
  return DiveDataSource(
    id: id,
    diveId: diveId,
    isPrimary: isPrimary,
    computerModel: computerModel,
    sourceFormat: sourceFormat,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    duration: duration,
    waterTemp: waterTemp,
    surfaceInterval: surfaceInterval,
    cns: cns,
    otu: otu,
    importedAt: now,
    createdAt: now,
  );
}

void main() {
  const diveId = 'dive-1';

  group('FieldAttributionService.computeAttribution', () {
    test('returns empty map for single-source dive', () {
      final sources = [
        _makeSource(
          id: 's1',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Suunto D5',
          sourceFormat: 'suunto',
          maxDepth: 30.0,
        ),
      ];

      final result = FieldAttributionService.computeAttribution(sources);

      expect(result, isEmpty);
    });

    test('returns empty map for empty sources list', () {
      final result = FieldAttributionService.computeAttribution([]);

      expect(result, isEmpty);
    });

    test('attributes fields to primary source by default', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
        avgDepth: 18.0,
        duration: 3600,
        waterTemp: 24.0,
        surfaceInterval: 120,
        cns: 12.0,
        otu: 5.0,
      );
      final secondary = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Petrel',
        sourceFormat: 'shearwater',
        maxDepth: 31.0,
        avgDepth: 19.0,
        duration: 3700,
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        secondary,
      ]);

      expect(result['maxDepth'], equals('Suunto D5'));
      expect(result['avgDepth'], equals('Suunto D5'));
      expect(result['bottomTime'], equals('Suunto D5'));
      expect(result['waterTemp'], equals('Suunto D5'));
      expect(result['surfaceInterval'], equals('Suunto D5'));
      expect(result['cns'], equals('Suunto D5'));
      expect(result['otu'], equals('Suunto D5'));
    });

    test('attributes heart rate to HR-capable source (Apple Watch)', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
      );
      final watch = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Apple Watch Ultra',
        sourceFormat: 'appleWatch',
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        watch,
      ]);

      expect(result['heartRate'], equals('Apple Watch Ultra'));
    });

    test('attributes heart rate to Garmin when present', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
      );
      final garmin = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Garmin Descent Mk2',
        sourceFormat: 'garmin',
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        garmin,
      ]);

      expect(result['heartRate'], equals('Garmin Descent Mk2'));
    });

    test('attributes GPS to GPS-capable source (Apple Watch)', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
      );
      final watch = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Apple Watch Ultra',
        sourceFormat: 'appleWatch',
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        watch,
      ]);

      expect(result['gps'], equals('Apple Watch Ultra'));
    });

    test(
      'falls back heartRate and gps to active source when no capable source',
      () {
        final primary = _makeSource(
          id: 's1',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Suunto D5',
          sourceFormat: 'suunto',
          maxDepth: 30.0,
        );
        final secondary = _makeSource(
          id: 's2',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Shearwater Petrel',
          sourceFormat: 'shearwater',
        );

        final result = FieldAttributionService.computeAttribution([
          primary,
          secondary,
        ]);

        expect(result['heartRate'], equals('Suunto D5'));
        expect(result['gps'], equals('Suunto D5'));
      },
    );

    test(
      'with viewedSourceId, attributes standard fields to viewed source',
      () {
        final primary = _makeSource(
          id: 's1',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Suunto D5',
          sourceFormat: 'suunto',
          maxDepth: 30.0,
          avgDepth: 18.0,
          duration: 3600,
        );
        final secondary = _makeSource(
          id: 's2',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Shearwater Petrel',
          sourceFormat: 'shearwater',
          maxDepth: 31.0,
          avgDepth: 19.0,
          duration: 3700,
        );

        final result = FieldAttributionService.computeAttribution([
          primary,
          secondary,
        ], viewedSourceId: 's2');

        expect(result['maxDepth'], equals('Shearwater Petrel'));
        expect(result['avgDepth'], equals('Shearwater Petrel'));
        expect(result['bottomTime'], equals('Shearwater Petrel'));
      },
    );

    test('falls back to primary when viewedSourceId not found', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
      );
      final secondary = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Petrel',
        sourceFormat: 'shearwater',
        maxDepth: 31.0,
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        secondary,
      ], viewedSourceId: 'nonexistent-id');

      expect(result['maxDepth'], equals('Suunto D5'));
    });

    test('falls back to first source when no primary marked', () {
      final first = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
        duration: 3600,
      );
      final second = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Petrel',
        sourceFormat: 'shearwater',
        maxDepth: 31.0,
        duration: 3700,
      );

      final result = FieldAttributionService.computeAttribution([
        first,
        second,
      ]);

      expect(result['maxDepth'], equals('Suunto D5'));
      expect(result['bottomTime'], equals('Suunto D5'));
    });

    test('omits field keys for fields with null values on active source', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: 'Suunto D5',
        sourceFormat: 'suunto',
        maxDepth: 30.0,
        // avgDepth, waterTemp, cns, otu, surfaceInterval all null
      );
      final secondary = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Petrel',
        sourceFormat: 'shearwater',
        maxDepth: 31.0,
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        secondary,
      ]);

      expect(result.containsKey('maxDepth'), isTrue);
      expect(result.containsKey('avgDepth'), isFalse);
      expect(result.containsKey('waterTemp'), isFalse);
      expect(result.containsKey('cns'), isFalse);
      expect(result.containsKey('otu'), isFalse);
      expect(result.containsKey('surfaceInterval'), isFalse);
    });

    test('uses Unknown Source display name when computerModel is null', () {
      final primary = _makeSource(
        id: 's1',
        diveId: diveId,
        isPrimary: true,
        computerModel: null,
        sourceFormat: 'suunto',
        maxDepth: 30.0,
      );
      final secondary = _makeSource(
        id: 's2',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Petrel',
        sourceFormat: 'shearwater',
      );

      final result = FieldAttributionService.computeAttribution([
        primary,
        secondary,
      ]);

      expect(result['maxDepth'], equals('Unknown Source'));
    });
  });
}
