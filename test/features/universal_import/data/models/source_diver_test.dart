import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';

void main() {
  group('ImportPayload.needsDiverMapping', () {
    ImportPayload withDivers(List<SourceDiver> divers) =>
        ImportPayload(entities: const {}, sourceDivers: divers);

    test('is false with no source divers', () {
      expect(withDivers(const []).needsDiverMapping, isFalse);
    });

    test('is false for one diver plus dives with no diver', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 503),
        SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 37),
      ]);
      expect(payload.needsDiverMapping, isFalse);
    });

    test('is true for two divers with records', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 3),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray', certificationCount: 1),
      ]);
      expect(payload.needsDiverMapping, isTrue);
    });

    test('ignores a diver with no records', () {
      final payload = withDivers(const [
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 3),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray'),
      ]);
      expect(payload.needsDiverMapping, isFalse);
    });
  });

  group('orderedDiverRows', () {
    test('orders by dive count then name, unowned last, empty dropped', () {
      final rows = orderedDiverRows(const [
        SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 9),
        SourceDiver(key: 'macdive:c', name: 'Cy Park', diveCount: 2),
        SourceDiver(key: 'macdive:b', name: 'Bo Ray', diveCount: 5),
        SourceDiver(key: 'macdive:a', name: 'Ann Lee', diveCount: 2),
        SourceDiver(key: 'macdive:z', name: 'Zed'),
      ]);
      expect(rows.map((r) => r.key), [
        'macdive:b',
        'macdive:a',
        'macdive:c',
        SourceDiver.unownedKey,
      ]);
    });
  });

  test('copyWith changes only the counts', () {
    const ann = SourceDiver(
      key: 'macdive:a',
      name: 'Ann Lee',
      diveCount: 1,
      email: 'ann@example.com',
    );
    expect(
      ann.copyWith(diveCount: 4, certificationCount: 2),
      const SourceDiver(
        key: 'macdive:a',
        name: 'Ann Lee',
        diveCount: 4,
        certificationCount: 2,
        email: 'ann@example.com',
      ),
    );
  });
}
