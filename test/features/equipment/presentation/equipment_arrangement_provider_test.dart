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
  _FakeSettingsRepository({this.stored, this.failWrite = false}) {
    // Self-registering so no construction site can forget it, and a new
    // one cannot reintroduce the leak.
    addTearDown(settingsTicks.close);
  }

  EquipmentArrangement? stored;
  bool failWrite;
  bool failRead = false;
  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async {
    if (failRead) throw StateError('read failed');
    return stored;
  }

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    if (failWrite) throw StateError('write failed');
    written.add(arrangement);
    stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

/// Hands out reads the test completes by hand, so two loads can be put in
/// flight and finished out of order.
class _OrderedFakeRepository extends AppSettingsRepository {
  _OrderedFakeRepository() {
    // Self-registering so no construction site can forget it, and a new
    // one cannot reintroduce the leak.
    addTearDown(settingsTicks.close);
  }

  final List<Completer<EquipmentArrangement?>> pending = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() {
    final completer = Completer<EquipmentArrangement?>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> setEquipmentArrangement(
    EquipmentArrangement arrangement,
  ) async {}

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

  test('a slow earlier read cannot clobber a newer one', () async {
    // The settings subscription starts a read per tick without awaiting the
    // one before it, so two can be in flight at once. If the earlier read
    // finishes last, its stale value must not win.
    final fake = _OrderedFakeRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    container.read(equipmentArrangementNotifierProvider);
    await pumpEventQueue();
    expect(fake.pending, hasLength(1), reason: 'the constructor read');

    fake.settingsTicks.add(null);
    await pumpEventQueue();
    expect(fake.pending, hasLength(2), reason: 'the tick read');

    // Newest read lands first, then the stale one.
    fake.pending[1].complete(
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
      ),
    );
    await pumpEventQueue();
    fake.pending[0].complete(
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );
    await pumpEventQueue();

    expect(
      container.read(equipmentArrangementNotifierProvider).typeOrder,
      EquipmentTypeOrder.dressingOrder,
    );
  });

  test('a read returning null reverts to the defaults', () async {
    // getEquipmentArrangement returns null when the key is absent. A fresh
    // launch would then show the defaults, so a tick that finds it absent
    // must not leave the session showing something storage no longer has.
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

    fake.stored = null;
    fake.settingsTicks.add(null);
    await pumpEventQueue();

    expect(
      container.read(equipmentArrangementNotifierProvider),
      EquipmentArrangement.defaults,
    );
  });

  test('a read that THROWS keeps the arrangement already loaded', () async {
    // Distinct from the null case: "we could not read" is not "there is
    // nothing stored", and a transient failure must not cost the diver their
    // customization.
    final fake = _FakeSettingsRepository(
      stored: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
      ),
    );
    final container = containerWith(fake);
    await container.read(equipmentArrangementNotifierProvider.notifier).loaded;

    fake.failRead = true;
    fake.settingsTicks.add(null);
    await pumpEventQueue();

    expect(
      container.read(equipmentArrangementNotifierProvider).typeOrder,
      EquipmentTypeOrder.dressingOrder,
    );
  });

  test(
    'a read before the first load completes gives only the defaults',
    () async {
      // This is why the PDF export path awaits `loaded`. A one-shot consumer
      // that reads synchronously bakes the defaults into its output over
      // whatever the diver actually saved, and unlike a screen it never
      // rebuilds to correct itself.
      final fake = _OrderedFakeRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(equipmentArrangementProvider),
        EquipmentArrangement.defaults,
      );
      expect(fake.pending, hasLength(1));

      fake.pending[0].complete(
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.dressingOrder,
        ),
      );
      await container
          .read(equipmentArrangementNotifierProvider.notifier)
          .loaded;

      expect(
        container.read(equipmentArrangementProvider).typeOrder,
        EquipmentTypeOrder.dressingOrder,
      );
    },
  );

  test('loaded settles only when a load actually publishes', () async {
    // The sequence guard makes a superseded load return without publishing.
    // If `loaded` is simply the first call's future it completes anyway, so a
    // one-shot consumer awaiting it (the PDF export) resumes while the state
    // is still the defaults, which is the whole thing the await was added to
    // prevent.
    final fake = _OrderedFakeRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      equipmentArrangementNotifierProvider.notifier,
    );
    var settled = false;
    unawaited(notifier.loaded.then((_) => settled = true));
    await pumpEventQueue();
    expect(fake.pending, hasLength(1), reason: 'the constructor read');

    // A tick supersedes the constructor's read before it lands.
    fake.settingsTicks.add(null);
    await pumpEventQueue();
    expect(fake.pending, hasLength(2));

    // The stale read finishes first and must neither publish nor settle.
    fake.pending[0].complete(
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );
    await pumpEventQueue();
    expect(
      settled,
      isFalse,
      reason: 'a superseded load has not decided anything',
    );
    expect(
      container.read(equipmentArrangementProvider),
      EquipmentArrangement.defaults,
    );

    // The winner publishes, and only then does the await resume.
    fake.pending[1].complete(
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
      ),
    );
    await pumpEventQueue();

    expect(settled, isTrue);
    expect(
      container.read(equipmentArrangementProvider).typeOrder,
      EquipmentTypeOrder.dressingOrder,
    );
  });

  test('loaded settles when the read fails, so a caller cannot hang', () async {
    final fake = _FakeSettingsRepository()..failRead = true;
    final container = containerWith(fake);

    await container
        .read(equipmentArrangementNotifierProvider.notifier)
        .loaded
        .timeout(const Duration(seconds: 5));

    expect(
      container.read(equipmentArrangementProvider),
      EquipmentArrangement.defaults,
    );
  });

  test('disposing releases anyone awaiting loaded', () async {
    // Otherwise a one-shot consumer whose container goes away mid-read waits
    // forever on a notifier that no longer exists.
    final fake = _OrderedFakeRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    final loaded = container
        .read(equipmentArrangementNotifierProvider.notifier)
        .loaded;
    await pumpEventQueue();
    expect(fake.pending, hasLength(1), reason: 'the read is still in flight');

    container.dispose();

    await loaded.timeout(const Duration(seconds: 5));
  });
}
