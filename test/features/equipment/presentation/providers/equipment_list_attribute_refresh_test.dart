import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, EquipmentAttributesCompanion, EquipmentCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The equipment list filters in memory on hydrated attributes (#1805), so
/// its source providers must refresh when only `equipment_attributes` is
/// written (saveAttributes, a sync pull), not just on `equipment` writes.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: const Value('hose'),
            diverId: Value(diver.id),
            name: const Value('Gauge hose'),
            type: const Value('hose'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final sources = <String, ProviderListenable<AsyncValue<List<EquipmentItem>>>>{
    'activeEquipmentProvider': activeEquipmentProvider,
    'equipmentByStatusProvider(null)': equipmentByStatusProvider(null),
    'allEquipmentProvider': allEquipmentProvider,
  };

  for (final entry in sources.entries) {
    test('${entry.key} refreshes on an attribute-only write', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(entry.value, (_, _) {});
      addTearDown(sub.close);

      String? hoseType() => container
          .read(entry.value)
          .value
          ?.singleOrNull
          ?.attrText('hose_type');

      for (var i = 0; i < 100; i++) {
        if (container.read(entry.value).hasValue) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(entry.value).value, hasLength(1));
      expect(hoseType(), isNull);

      await db
          .into(db.equipmentAttributes)
          .insert(
            EquipmentAttributesCompanion(
              id: const Value('attr_hose_hose_type'),
              equipmentId: const Value('hose'),
              attrKey: const Value('hose_type'),
              valueText: const Value('hp'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      for (var i = 0; i < 150 && hoseType() != 'hp'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(hoseType(), 'hp');
    });
  }
}
