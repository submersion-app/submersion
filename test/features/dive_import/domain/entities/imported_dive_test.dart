import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

void main() {
  group('ImportedDive', () {
    test('creates instance with required fields', () {
      final dive = ImportedDive(
        sourceId: 'healthkit-uuid-123',
        source: ImportSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.sourceId, 'healthkit-uuid-123');
      expect(dive.source, ImportSource.appleWatch);
      expect(dive.maxDepth, 18.5);
    });

    test('calculates duration correctly', () {
      final dive = ImportedDive(
        sourceId: 'test',
        source: ImportSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.duration, const Duration(minutes: 45));
    });

    test('ImportedProfileSample creates with all fields', () {
      const sample = ImportedProfileSample(
        timeSeconds: 120,
        depth: 15.5,
        temperature: 22.0,
        heartRate: 72,
      );

      expect(sample.timeSeconds, 120);
      expect(sample.depth, 15.5);
      expect(sample.temperature, 22.0);
      expect(sample.heartRate, 72);
    });

    test('ImportedGasSwitch supports value equality', () {
      const a = ImportedGasSwitch(timeSeconds: 2474, tankIndex: 1, depth: 21);
      const b = ImportedGasSwitch(timeSeconds: 2474, tankIndex: 1, depth: 21);
      const c = ImportedGasSwitch(timeSeconds: 2474, tankIndex: 2, depth: 21);

      expect(a, b);
      expect(a, isNot(c));
      expect(a.depth, 21);
      expect(const ImportedGasSwitch(timeSeconds: 0, tankIndex: 0).depth, null);
    });
  });

  group('computer tissue fields', () {
    test('ImportedProfileSample carries gf99 and n2Load', () {
      const sample = ImportedProfileSample(
        timeSeconds: 60,
        depth: 20.0,
        gf99: 42,
        n2Load: 37,
      );

      expect(sample.gf99, 42);
      expect(sample.n2Load, 37);
      expect(const ImportedProfileSample(timeSeconds: 0, depth: 0).gf99, null);
      expect(
        const ImportedProfileSample(timeSeconds: 0, depth: 0).n2Load,
        null,
      );
    });

    test('ImportedProfileSample copyWith keeps and overrides gf99/n2Load', () {
      const sample = ImportedProfileSample(
        timeSeconds: 60,
        depth: 20.0,
        gf99: 42,
        n2Load: 37,
      );

      final kept = sample.copyWith(depth: 21.0);
      expect(kept.gf99, 42);
      expect(kept.n2Load, 37);

      final changed = sample.copyWith(gf99: 50, n2Load: 40);
      expect(changed.gf99, 50);
      expect(changed.n2Load, 40);
    });

    test('ImportedProfileSample equality includes gf99 and n2Load', () {
      const a = ImportedProfileSample(timeSeconds: 0, depth: 1, gf99: 10);
      const b = ImportedProfileSample(timeSeconds: 0, depth: 1, gf99: 10);
      const c = ImportedProfileSample(timeSeconds: 0, depth: 1, gf99: 11);
      const d = ImportedProfileSample(timeSeconds: 0, depth: 1, n2Load: 11);

      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });

    test('ImportedDive carries a computer tissue snapshot', () {
      const snapshot = ComputerTissueSnapshot(
        algorithm: 'Suunto Fused2 RGBM',
        end: ComputerTissueState(n2Bar: [0.89665], cnsPercent: 13.2),
      );
      final dive = ImportedDive(
        sourceId: 'suunto-1',
        source: ImportSource.suunto,
        startTime: DateTime(2024, 1, 1, 10),
        endTime: DateTime(2024, 1, 1, 10, 40),
        maxDepth: 30.0,
        profile: const [],
        computerTissue: snapshot,
      );
      final bare = ImportedDive(
        sourceId: 'suunto-1',
        source: ImportSource.suunto,
        startTime: DateTime(2024, 1, 1, 10),
        endTime: DateTime(2024, 1, 1, 10, 40),
        maxDepth: 30.0,
        profile: const [],
      );

      expect(dive.computerTissue, snapshot);
      expect(bare.computerTissue, isNull);
      expect(dive, isNot(bare));
    });
  });
}
