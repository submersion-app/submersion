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

  /// Stores the value, then throws: a write that changed the settings row
  /// but failed a later step (the pending-sync mark).
  bool failAfterStoring = false;
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
    if (failAfterStoring) throw StateError('failed after storing');
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

/// Holds every read and write until the test settles it, so edits can be
/// made before the launch read lands and while earlier writes are in flight.
class _GatedFakeRepository extends AppSettingsRepository {
  _GatedFakeRepository() {
    addTearDown(settingsTicks.close);
  }

  final List<Completer<EquipmentArrangement?>> reads = [];
  final List<({EquipmentArrangement value, Completer<void> gate})> writes = [];

  /// Only the writes that succeeded, in the order they landed.
  final List<EquipmentArrangement> stored = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() {
    final completer = Completer<EquipmentArrangement?>();
    reads.add(completer);
    return completer.future;
  }

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    final gate = Completer<void>();
    writes.add((value: arrangement, gate: gate));
    await gate.future;
    stored.add(arrangement);
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

/// Lets queued microtasks and chained futures run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

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

  test('updates issued back to back apply cumulatively, in order', () async {
    // The sort sheet stays open, so a second change can be made before the
    // first write lands. Each change must build on the one before it.
    final fake = _FakeSettingsRepository();
    final container = containerWith(fake);
    final notifier = container.read(
      equipmentArrangementNotifierProvider.notifier,
    );

    final first = notifier.updateArrangement(
      (current) => current.copyWith(groupByType: false),
    );
    final second = notifier.updateArrangement(
      (current) => current.copyWith(typeOrder: EquipmentTypeOrder.headToToe),
    );
    await Future.wait([first, second]);

    expect(fake.written.map((a) => a.groupByType).toList(), [false, false]);
    expect(fake.written.last.typeOrder, EquipmentTypeOrder.headToToe);
    expect(
      container.read(equipmentArrangementNotifierProvider),
      EquipmentArrangement.defaults.copyWith(
        groupByType: false,
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );
  });

  test('after a failed update the next one builds on what is stored', () async {
    // A change that never reached storage must not ride along on the next
    // write, or it would appear after the diver was told it failed.
    final fake = _FakeSettingsRepository(failWrite: true);
    final container = containerWith(fake);
    final notifier = container.read(
      equipmentArrangementNotifierProvider.notifier,
    );

    await expectLater(
      notifier.updateArrangement(
        (current) => current.copyWith(groupByType: false),
      ),
      throwsA(isA<StateError>()),
    );
    fake.failWrite = false;
    await notifier.updateArrangement(
      (current) => current.copyWith(typeOrder: EquipmentTypeOrder.headToToe),
    );

    expect(fake.written.single.groupByType, isTrue);
    expect(fake.written.single.typeOrder, EquipmentTypeOrder.headToToe);
  });

  test(
    'an edit made before the stored arrangement loads builds on it',
    () async {
      // The notifier starts at the defaults and adopts storage when the launch
      // read lands. A sheet opened in that window must not turn one edit into
      // a write of the defaults for every axis the diver did not touch.
      final gated = _GatedFakeRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(gated)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      const headToToe = EquipmentArrangement(
        typeOrder: EquipmentTypeOrder.headToToe,
        groupByType: true,
        itemSortField: EquipmentItemSortField.purchaseDate,
        itemSortDirection: SortDirection.descending,
      );

      final edit = notifier.updateArrangement(
        (current) => current.copyWith(groupByType: false),
      );
      await _settle();
      gated.reads.single.complete(headToToe);
      await _settle();
      gated.writes.single.gate.complete();
      await edit;

      expect(gated.stored.single, headToToe.copyWith(groupByType: false));
    },
  );

  test('a change that fails while a later one is queued does not ride along '
      'on it', () async {
    // B is asked for while A is still saving. When A then fails, B must be
    // written on top of what storage actually holds, not on top of A.
    final gated = _GatedFakeRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(gated)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      equipmentArrangementNotifierProvider.notifier,
    );
    gated.reads.single.complete(null);
    await notifier.loaded;

    final a = notifier.updateArrangement(
      (current) => current.copyWith(groupByType: false),
    );
    final b = notifier.updateArrangement(
      (current) => current.copyWith(typeOrder: EquipmentTypeOrder.headToToe),
    );
    await _settle();
    gated.writes.first.gate.completeError(StateError('write failed'));
    await expectLater(a, throwsA(isA<StateError>()));
    await _settle();
    // A write that failed may have changed the row, so B reads storage
    // before building. A never stored anything here.
    expect(gated.reads, hasLength(2), reason: 'B re-reads after the failure');
    gated.reads.last.complete(null);
    await _settle();
    gated.writes.last.gate.complete();
    await b;

    expect(
      gated.stored.single,
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );
    expect(
      container.read(equipmentArrangementNotifierProvider),
      gated.stored.single,
    );
  });

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

  test(
    'an edit made while a synced change is being read builds on it',
    () async {
      // After launch, a change synced from another device ticks the settings
      // table and starts a re-read. An edit made in that window must wait for
      // the read, or it writes the pre-sync axes back over the synced ones.
      final fake = _OrderedFakeRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      fake.pending.single.complete(null);
      await notifier.loaded;

      fake.settingsTicks.add(null);
      await pumpEventQueue();
      expect(fake.pending, hasLength(2), reason: 'the sync re-read is out');
      final edit = notifier.updateArrangement(
        (current) => current.copyWith(groupByType: false),
      );
      await pumpEventQueue();

      fake.pending[1].complete(
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.dressingOrder,
        ),
      );
      await edit;

      expect(
        container.read(equipmentArrangementNotifierProvider),
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.dressingOrder,
          groupByType: false,
        ),
      );
    },
  );

  test('with three reads out of order, the newest success wins', () async {
    // Read 2 succeeds and stands aside for read 3; read 3 fails; read 1, the
    // oldest, lands last. Read 2 is the freshest thing storage gave, so it
    // must be the one published, not read 1.
    final fake = _OrderedFakeRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    container.read(equipmentArrangementNotifierProvider);
    await pumpEventQueue();
    fake.settingsTicks.add(null);
    await pumpEventQueue();
    fake.settingsTicks.add(null);
    await pumpEventQueue();
    expect(fake.pending, hasLength(3));

    fake.pending[1].complete(
      EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
      ),
    );
    await pumpEventQueue();
    fake.pending[2].completeError(StateError('read failed'));
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

  test('a newer read that fails defers to the read still in flight', () async {
    // "Could not read" decides nothing. If a tick's read fails while the
    // launch read is still out, the launch read must still get to publish,
    // and `loaded` must wait for it: an edit queued behind `loaded` would
    // otherwise build on the defaults and write them over the stored axes.
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

    fake.settingsTicks.add(null);
    await pumpEventQueue();
    expect(fake.pending, hasLength(2));
    final edit = notifier.updateArrangement(
      (current) => current.copyWith(groupByType: false),
    );

    fake.pending[1].completeError(StateError('read failed'));
    await pumpEventQueue();
    expect(settled, isFalse, reason: 'the launch read is still out');

    const stored = EquipmentArrangement(
      typeOrder: EquipmentTypeOrder.headToToe,
      groupByType: true,
      itemSortField: EquipmentItemSortField.purchaseDate,
      itemSortDirection: SortDirection.descending,
    );
    fake.pending[0].complete(stored);
    await edit;

    expect(settled, isTrue);
    expect(
      container.read(equipmentArrangementNotifierProvider),
      stored.copyWith(groupByType: false),
    );
  });

  test(
    'a read that deferred to a newer one is used when that one fails',
    () async {
      // The older read landed first and stood aside for the newer one. The
      // newer one then failed, so the older value is the best storage gave.
      final fake = _OrderedFakeRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      await pumpEventQueue();
      fake.settingsTicks.add(null);
      await pumpEventQueue();

      fake.pending[0].complete(
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.dressingOrder,
        ),
      );
      await pumpEventQueue();
      fake.pending[1].completeError(StateError('read failed'));
      await notifier.loaded.timeout(const Duration(seconds: 5));

      expect(
        container.read(equipmentArrangementNotifierProvider).typeOrder,
        EquipmentTypeOrder.dressingOrder,
      );
    },
  );

  test(
    'after a failed launch read, an edit re-reads before building',
    () async {
      // A failed read leaves the stored arrangement unknown, not "the
      // defaults". An edit built on the defaults would save them over every
      // axis the diver did not touch, so it reads again first.
      final fake = _FakeSettingsRepository(
        stored: EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.headToToe,
        ),
      )..failRead = true;
      final container = containerWith(fake);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      await notifier.loaded;

      fake.failRead = false;
      await notifier.updateArrangement(
        (current) => current.copyWith(groupByType: false),
      );

      expect(
        fake.written.single,
        EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.headToToe,
          groupByType: false,
        ),
      );
    },
  );

  test(
    'an edit is refused while the stored arrangement stays unknown',
    () async {
      final fake = _FakeSettingsRepository(
        stored: EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.headToToe,
        ),
      )..failRead = true;
      final container = containerWith(fake);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      await notifier.loaded;

      await expectLater(
        notifier.updateArrangement(
          (current) => current.copyWith(groupByType: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        fake.written,
        isEmpty,
        reason: 'nothing saved over the real value',
      );
      expect(
        container.read(equipmentArrangementNotifierProvider),
        EquipmentArrangement.defaults,
      );
    },
  );

  test(
    'after a write that failed partway, the next edit reads first',
    () async {
      // The write stored the row and then failed, so storage holds the change
      // while state does not. The next edit must build on what storage holds,
      // or it overwrites the first change's other axes.
      final fake = _FakeSettingsRepository()..failAfterStoring = true;
      final container = containerWith(fake);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );

      await expectLater(
        notifier.updateArrangement(
          (current) => current.copyWith(groupByType: false),
        ),
        throwsA(isA<StateError>()),
      );
      fake.failAfterStoring = false;
      await notifier.updateArrangement(
        (current) => current.copyWith(typeOrder: EquipmentTypeOrder.headToToe),
      );

      expect(
        fake.stored,
        EquipmentArrangement.defaults.copyWith(
          groupByType: false,
          typeOrder: EquipmentTypeOrder.headToToe,
        ),
      );
    },
  );

  test(
    'an edit does not wait on an older read that can no longer publish',
    () async {
      // Read 1 stalls; read 2 lands and publishes. Read 1 can no longer change
      // state (it is older than what published), so an edit must not wait
      // for it.
      final fake = _OrderedFakeRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        equipmentArrangementNotifierProvider.notifier,
      );
      await pumpEventQueue();
      fake.settingsTicks.add(null);
      await pumpEventQueue();
      fake.pending[1].complete(null);
      await notifier.loaded;

      await notifier
          .updateArrangement((current) => current.copyWith(groupByType: false))
          .timeout(const Duration(seconds: 5));

      expect(
        container.read(equipmentArrangementNotifierProvider).groupByType,
        isFalse,
      );
    },
  );

  test('after a failed re-read, the next edit reads again first', () async {
    // A settings tick can follow a change synced from another device. If
    // that re-read fails, state may be behind storage, so the next edit
    // must read again rather than save the pre-sync axes over the synced
    // ones. What is on screen stays meanwhile.
    final fake = _FakeSettingsRepository();
    final container = containerWith(fake);
    final notifier = container.read(
      equipmentArrangementNotifierProvider.notifier,
    );
    await notifier.loaded;

    final synced = EquipmentArrangement.defaults.copyWith(
      typeOrder: EquipmentTypeOrder.headToToe,
    );
    fake
      ..stored = synced
      ..failRead = true;
    fake.settingsTicks.add(null);
    await pumpEventQueue();
    expect(
      container.read(equipmentArrangementNotifierProvider),
      EquipmentArrangement.defaults,
      reason: 'the failed re-read keeps what is on screen',
    );

    fake.failRead = false;
    await notifier.updateArrangement(
      (current) => current.copyWith(groupByType: false),
    );

    expect(fake.written.single, synced.copyWith(groupByType: false));
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
