import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Overrides only the three members the notifier touches, so nothing reaches
/// the database.
class _FakeSettingsRepository extends AppSettingsRepository {
  _FakeSettingsRepository({this.stored, this.failWrite = false});

  EquipmentArrangement? stored;
  bool failWrite;
  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async => stored;

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    if (failWrite) throw StateError('write failed');
    written.add(arrangement);
    stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

void main() {
  ProviderContainer containerWith(_FakeSettingsRepository fake) {
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts at the defaults before the stored value arrives', () {
    final container = containerWith(_FakeSettingsRepository());

    expect(
      container.read(equipmentArrangementNotifierProvider),
      EquipmentArrangement.defaults,
    );
  });

  test('adopts the stored arrangement once loaded', () async {
    final fake = _FakeSettingsRepository(
      stored: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );
    final container = containerWith(fake);

    await container.read(equipmentArrangementNotifierProvider.notifier).loaded;

    expect(
      container.read(equipmentArrangementNotifierProvider).typeOrder,
      EquipmentTypeOrder.headToToe,
    );
  });

  test('keeps the defaults when nothing is stored', () async {
    final container = containerWith(_FakeSettingsRepository());

    await container.read(equipmentArrangementNotifierProvider.notifier).loaded;

    expect(
      container.read(equipmentArrangementNotifierProvider),
      EquipmentArrangement.defaults,
    );
  });

  test('setArrangement writes through and updates state', () async {
    final fake = _FakeSettingsRepository();
    final container = containerWith(fake);

    await container
        .read(equipmentArrangementNotifierProvider.notifier)
        .setArrangement(
          EquipmentArrangement.defaults.copyWith(groupByType: false),
        );

    expect(fake.written.single.groupByType, isFalse);
    expect(
      container.read(equipmentArrangementNotifierProvider).groupByType,
      isFalse,
    );
  });

  test(
    'a failed write leaves the previous state in place and rethrows',
    () async {
      final fake = _FakeSettingsRepository(failWrite: true);
      final container = containerWith(fake);

      await expectLater(
        container
            .read(equipmentArrangementNotifierProvider.notifier)
            .setArrangement(
              EquipmentArrangement.defaults.copyWith(groupByType: false),
            ),
        throwsA(isA<StateError>()),
      );

      expect(
        container.read(equipmentArrangementNotifierProvider),
        EquipmentArrangement.defaults,
      );
    },
  );

  test(
    'a settings tick re-reads, so a synced change lands without a restart',
    () async {
      final fake = _FakeSettingsRepository();
      final container = containerWith(fake);
      await container
          .read(equipmentArrangementNotifierProvider.notifier)
          .loaded;

      fake.stored = EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
        itemSortField: EquipmentItemSortField.purchaseDate,
      );
      fake.settingsTicks.add(null);
      await pumpEventQueue();

      expect(
        container.read(equipmentArrangementNotifierProvider).typeOrder,
        EquipmentTypeOrder.dressingOrder,
      );
    },
  );

  test('the subscription is cancelled on dispose', () async {
    final fake = _FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    container.read(equipmentArrangementNotifierProvider);

    container.dispose();
    await pumpEventQueue();

    expect(fake.settingsTicks.hasListener, isFalse);
  });
}
