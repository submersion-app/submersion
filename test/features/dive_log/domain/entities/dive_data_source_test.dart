import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

void main() {
  group('DiveDataSource', () {
    test('constructs with required fields', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      expect(source.id, 'r1');
      expect(source.diveId, 'd1');
      expect(source.isPrimary, true);
      expect(source.maxDepth, isNull);
      expect(source.computerModel, isNull);
      expect(source.sourceFileName, isNull);
      expect(source.sourceFileFormat, isNull);
    });

    test('constructs with all fields', () {
      final now = DateTime.now();
      final entry = DateTime(2026, 3, 19, 10, 0);
      final exit = DateTime(2026, 3, 19, 10, 42);
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        computerId: 'c1',
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN12345',
        sourceFormat: 'UDDF',
        sourceFileName: 'my_dives.uddf',
        sourceFileFormat: 'uddf',
        maxDepth: 30.2,
        avgDepth: 18.4,
        duration: 2535,
        waterTemp: 26.1,
        entryTime: entry,
        exitTime: exit,
        maxAscentRate: 9.5,
        maxDescentRate: 18.0,
        surfaceInterval: 65,
        cns: 12.0,
        otu: 22.0,
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gradientFactorLow: 30,
        gradientFactorHigh: 70,
        importedAt: now,
        createdAt: now,
      );

      expect(source.computerModel, 'Shearwater Perdix');
      expect(source.maxDepth, 30.2);
      expect(source.duration, 2535);
      expect(source.gradientFactorLow, 30);
      expect(source.sourceFileName, 'my_dives.uddf');
      expect(source.sourceFileFormat, 'uddf');
    });

    test('copyWith replaces specified fields', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        maxDepth: 30.2,
        computerModel: 'Shearwater Perdix',
        importedAt: now,
        createdAt: now,
      );

      final updated = source.copyWith(isPrimary: false, maxDepth: 29.8);

      expect(updated.isPrimary, false);
      expect(updated.maxDepth, 29.8);
      expect(updated.id, 'r1');
      expect(updated.computerModel, 'Shearwater Perdix');
    });

    test('copyWith preserves null fields when not specified', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      final updated = source.copyWith(isPrimary: false);

      expect(updated.maxDepth, isNull);
      expect(updated.computerModel, isNull);
      expect(updated.sourceFileName, isNull);
      expect(updated.sourceFileFormat, isNull);
    });

    test('displayName returns computerModel when set', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        importedAt: now,
        createdAt: now,
      );

      expect(source.displayName, 'Shearwater Perdix');
    });

    test('displayName returns Unknown Source when computerModel is null', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      expect(source.displayName, 'Unknown Source');
    });

    test('equality holds for identical field values', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final a = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        maxDepth: 30.0,
        importedAt: now,
        createdAt: now,
      );
      final b = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        maxDepth: 30.0,
        importedAt: now,
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality fails when a field differs', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final a = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );
      final b = DiveDataSource(
        id: 'r2',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        computerModel: 'Perdix',
        maxDepth: 30.0,
        importedAt: now,
        createdAt: now,
      );

      // 25 fields total in props list
      expect(source.props, hasLength(25));
      expect(source.props, contains('r1'));
      expect(source.props, contains('d1'));
      expect(source.props, contains(true));
      expect(source.props, contains('Perdix'));
      expect(source.props, contains(30.0));
    });

    test('copyWith handles sourceFileName and sourceFileFormat', () {
      final now = DateTime.now();
      final source = DiveDataSource(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      final updated = source.copyWith(
        sourceFileName: 'export.fit',
        sourceFileFormat: 'fit',
      );

      expect(updated.sourceFileName, 'export.fit');
      expect(updated.sourceFileFormat, 'fit');
    });
  });
}
