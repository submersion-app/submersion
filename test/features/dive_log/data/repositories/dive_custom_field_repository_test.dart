import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide DiveCustomField;
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

void main() {
  late AppDatabase db;
  late DiveCustomFieldRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DiveCustomFieldRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createTestDiver(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Only insert if not already present
    final existing = await (db.select(
      db.divers,
    )..where((d) => d.id.equals(diverId))).getSingleOrNull();
    if (existing != null) return;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String> createTestDive(String id, {String? diverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (diverId != null) {
      await createTestDiver(diverId);
    }
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  group('DiveCustomFieldRepository', () {
    test('getFieldsForDive returns empty list when no fields', () async {
      await createTestDive('d-1');
      final fields = await repository.getFieldsForDive('d-1');
      expect(fields, isEmpty);
    });

    test('replaceFieldsForDive inserts fields', () async {
      await createTestDive('d-1');
      final fields = [
        const DiveCustomField(
          id: 'cf-1',
          key: 'mood',
          value: 'great',
          sortOrder: 0,
        ),
        const DiveCustomField(
          id: 'cf-2',
          key: 'camera',
          value: 'GoPro',
          sortOrder: 1,
        ),
      ];

      await repository.replaceFieldsForDive('d-1', fields);
      final result = await repository.getFieldsForDive('d-1');

      expect(result.length, 2);
      expect(result[0].key, 'mood');
      expect(result[0].value, 'great');
      expect(result[1].key, 'camera');
    });

    test('replaceFieldsForDive replaces existing fields', () async {
      await createTestDive('d-1');
      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-2', key: 'camera', value: 'Sony'),
      ]);

      final result = await repository.getFieldsForDive('d-1');
      expect(result.length, 1);
      expect(result[0].key, 'camera');
    });

    test('getDistinctKeysForDiver returns unique keys across dives', () async {
      await createTestDive('d-1', diverId: 'diver-1');
      await createTestDive('d-2', diverId: 'diver-1');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
        const DiveCustomField(id: 'cf-2', key: 'camera', value: 'GoPro'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-3', key: 'mood', value: 'tired'),
        const DiveCustomField(id: 'cf-4', key: 'task', value: 'nav drill'),
      ]);

      final keys = await repository.getDistinctKeysForDiver('diver-1');
      expect(keys, containsAll(['mood', 'camera', 'task']));
      expect(keys.length, 3);
    });

    test('getDistinctKeysForDiver filters by diver', () async {
      await createTestDive('d-1', diverId: 'diver-1');
      await createTestDive('d-2', diverId: 'diver-2');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-2', key: 'secret', value: 'hidden'),
      ]);

      final keys = await repository.getDistinctKeysForDiver('diver-1');
      expect(keys, ['mood']);
      expect(keys, isNot(contains('secret')));
    });

    test('fields are deleted when parent dive is deleted', () async {
      await createTestDive('d-1');
      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);

      await (db.delete(db.dives)..where((d) => d.id.equals('d-1'))).go();
      final result = await repository.getFieldsForDive('d-1');
      expect(result, isEmpty);
    });

    test('getFieldsForDiveIds batch loads fields grouped by dive', () async {
      await createTestDive('d-1');
      await createTestDive('d-2');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-2', key: 'task', value: 'nav'),
        const DiveCustomField(id: 'cf-3', key: 'camera', value: 'Sony'),
      ]);

      final result = await repository.getFieldsForDiveIds(['d-1', 'd-2']);
      expect(result['d-1']?.length, 1);
      expect(result['d-2']?.length, 2);
    });
  });
}
