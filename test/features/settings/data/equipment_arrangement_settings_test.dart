import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late AppSettingsRepository repository;

  const key = 'equipment_arrangement';

  Future<void> storeRaw(String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(
          key: const Value(key),
          value: Value(value),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = AppSettingsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('returns null before anything is stored', () async {
    expect(await repository.getEquipmentArrangement(), isNull);
  });

  test('round-trips a stored arrangement', () async {
    const arrangement = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.headToToe,
      groupByType: false,
      itemSortField: EquipmentItemSortField.dateAdded,
      itemSortDirection: SortDirection.descending,
    );

    await repository.setEquipmentArrangement(arrangement);

    expect(await repository.getEquipmentArrangement(), arrangement);
  });

  test('a corrupt stored value reads as null rather than throwing', () async {
    await storeRaw('not json at all');

    expect(await repository.getEquipmentArrangement(), isNull);
  });

  test('a JSON value that is not an object reads as null', () async {
    await storeRaw('[1, 2, 3]');

    expect(await repository.getEquipmentArrangement(), isNull);
  });

  test('a write marks the record pending for sync', () async {
    await repository.setEquipmentArrangement(EquipmentArrangement.defaults);

    final pending = await db.select(db.syncRecords).get();

    expect(
      pending.where((r) => r.entityType == 'settings' && r.recordId == key),
      isNotEmpty,
    );
  });
}
