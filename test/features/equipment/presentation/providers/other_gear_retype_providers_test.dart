import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/other_gear_retype_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  ProviderContainer containerFor(
    String? diverId, {
    List<riverpod.Override> extra = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<EquipmentItem> add(String name) => repo.createEquipment(
    EquipmentItem(id: '', diverId: 'd1', name: name, type: EquipmentType.other),
  );

  group('otherGearRetypeCandidatesProvider', () {
    test("lists the active diver's candidates", () async {
      await add('Apeks fins');
      await add('Hydros Pro');
      final container = containerFor('d1');

      final candidates = await container.read(
        otherGearRetypeCandidatesProvider.future,
      );

      expect(candidates!.map((c) => c.item.name), ['Apeks fins']);
    });

    test('is null when there is no diver', () async {
      final container = containerFor(null);

      expect(
        await container.read(otherGearRetypeCandidatesProvider.future),
        isNull,
      );
    });

    test('follows equipment writes', () async {
      final container = containerFor('d1');
      final sub = container.listen(
        otherGearRetypeCandidatesProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(otherGearRetypeCandidatesProvider.future),
        isEmpty,
      );

      await add('Apeks fins');
      await pumpEventQueue();

      final candidates = await container.read(
        otherGearRetypeCandidatesProvider.future,
      );
      expect(candidates!.map((c) => c.item.name), ['Apeks fins']);
    });
  });

  group('refreshAfterOtherGearRetype', () {
    test('rebuilds the Suit Thickness statistic', () async {
      var builds = 0;
      final container = containerFor(
        'd1',
        extra: [
          divesBySuitThicknessProvider.overrideWith((ref) async {
            builds++;
            return (
              byThickness: const <({double mm, int count})>[],
              unknownThicknessCount: 0,
              drysuitCount: 0,
            );
          }),
        ],
      );
      final sub = container.listen(divesBySuitThicknessProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(divesBySuitThicknessProvider.future);

      refreshAfterOtherGearRetype(container);
      await container.read(divesBySuitThicknessProvider.future);

      expect(builds, 2);
    });

    test('reloads the equipment list notifier when it is in use', () async {
      final container = containerFor('d1');
      final sub = container.listen(equipmentListNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(container.read(equipmentListNotifierProvider).value, isEmpty);

      await add('Apeks fins');
      refreshAfterOtherGearRetype(container);
      await pumpEventQueue();

      expect(
        container.read(equipmentListNotifierProvider).value!.map((e) => e.name),
        ['Apeks fins'],
      );
    });
  });
}
