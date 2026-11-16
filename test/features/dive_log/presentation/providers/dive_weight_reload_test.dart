import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveWeightsCompanion, EquipmentAttributesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The dive table's Total weight and the dive page's Weights card both read
/// `Dive.recordedWeightKg`: the weight rows plus the lead carried as weights
/// gear (#4442). A sync pull of a weight row, or an edit of a weights item's
/// dry weight, writes only those tables, never the dive row, so the list and
/// the dive page must reload on them as well as on `dives`.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

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
    final plate = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: 'plate',
        name: 'Weighted backplate',
        type: EquipmentType.weights,
        attributes: [
          EquipmentAttribute(
            id: 'plate-dry',
            equipmentId: 'plate',
            key: EquipmentAttrKeys.dryWeightKg,
            valueNum: 2.5,
          ),
        ],
      ),
    );
    await DiveRepository().createDive(
      Dive(
        id: 'dive',
        diverId: diver.id,
        dateTime: DateTime(2026, 1, 1),
        gear: looseGear([plate]),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<double?> listedWeight(
    ProviderContainer container,
    bool Function(double?) done,
  ) async {
    double? read() => container
        .read(diveListNotifierProvider)
        .value
        ?.singleOrNull
        ?.recordedWeightKg;
    for (var i = 0; i < 200; i++) {
      final value = read();
      if (done(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return read();
  }

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(diveListNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  test('a weight row written alone reaches the list', () async {
    final c = container();
    expect(await listedWeight(c, (kg) => kg == 2.5), 2.5);

    await db
        .into(db.diveWeights)
        .insert(
          const DiveWeightsCompanion(
            id: Value('belt'),
            diveId: Value('dive'),
            weightType: Value('belt'),
            amountKg: Value(4.5),
            createdAt: Value(1),
          ),
        );

    expect(
      await listedWeight(c, (kg) => kg == 7.0),
      7.0,
      reason: 'the dives tick never fires for a weight-row-only write',
    );
  });

  test("a weights item's dry weight edited alone reaches the list", () async {
    final c = container();
    expect(await listedWeight(c, (kg) => kg == 2.5), 2.5);

    final updated =
        await (db.update(db.equipmentAttributes)..where(
              (a) =>
                  a.equipmentId.equals('plate') &
                  a.attrKey.equals(EquipmentAttrKeys.dryWeightKg),
            ))
            .write(const EquipmentAttributesCompanion(valueNum: Value(3.5)));
    expect(updated, 1);

    expect(
      await listedWeight(c, (kg) => kg == 3.5),
      3.5,
      reason: 'the dives tick never fires for an attribute-only write',
    );
  });

  test('a weight row written alone reaches the dive page', () async {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(diveProvider('dive'), (_, _) {});
    addTearDown(sub.close);
    Future<double?> shownWeight(double expected) async {
      double? read() => c.read(diveProvider('dive')).value?.recordedWeightKg;
      for (var i = 0; i < 200 && read() != expected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return read();
    }

    expect(await shownWeight(2.5), 2.5);

    await db
        .into(db.diveWeights)
        .insert(
          const DiveWeightsCompanion(
            id: Value('belt'),
            diveId: Value('dive'),
            weightType: Value('belt'),
            amountKg: Value(4.5),
            createdAt: Value(1),
          ),
        );

    expect(
      await shownWeight(7.0),
      7.0,
      reason: 'the detail tick never fires for a weight-row-only write',
    );
  });
}
