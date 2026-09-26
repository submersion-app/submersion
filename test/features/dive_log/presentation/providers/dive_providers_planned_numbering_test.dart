import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;
  late DiveRepository diveRepo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    diveRepo = DiveRepository();
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
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('addDive leaves a planned dive unnumbered', () async {
    await diveRepo.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 1), diveNumber: 3),
    );
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final planned = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
    );
    expect((await diveRepo.getDiveById(planned.id))?.diveNumber, isNull);
    expect((await diveRepo.getDiveById(planned.id))?.isPlanned, isTrue);
  });

  test('addDive still numbers an unnumbered logged dive', () async {
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final logged = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1)),
    );
    expect((await diveRepo.getDiveById(logged.id))?.diveNumber, isNotNull);
  });

  // A caller decides what the dive may carry (a site, say) for the diver
  // current when it calls, so a switch while addDive awaits must not move
  // the dive to the new diver.
  Future<Diver> createOtherDiver() => DiverRepository().createDiver(
    Diver(
      id: '',
      name: 'E',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  );

  test('addDive keeps the diver current when it was called', () async {
    final callerDiverId = container.read(currentDiverIdProvider);
    final other = await createOtherDiver();
    final notifier = container.read(paginatedDiveListProvider.notifier);

    final pending = notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(other.id);

    final created = await pending;
    // addDive starts the trip list's reload without awaiting it, and the
    // switch starts another; let them land before teardown disposes the
    // container under them.
    await pumpEventQueue();
    expect(created.diverId, callerDiverId);
  });

  test(
    'addDive does not prepend to a list switched to another diver',
    () async {
      final divers = _GatedDiverRepository();
      final gated = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diverRepositoryProvider.overrideWithValue(divers),
        ],
      );
      addTearDown(gated.dispose);
      final other = await createOtherDiver();
      final notifier = gated.read(paginatedDiveListProvider.notifier);
      await pumpEventQueue();

      // Hold addDive in its diver check while the other diver's list loads in
      // full, so it resumes with that list, not a loading state, in hand.
      final release = Completer<void>();
      divers.gate = release;
      final pending = notifier.addDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
      );
      await gated
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(other.id);
      await pumpEventQueue();
      expect(gated.read(paginatedDiveListProvider).hasValue, isTrue);

      release.complete();
      final created = await pending;
      // Read before the dives-table tick's reload can paper over a prepend.
      final shown = gated.read(paginatedDiveListProvider).value!.dives;
      expect(shown.map((d) => d.id), isNot(contains(created.id)));
      await pumpEventQueue();
    },
  );

  test(
    'the legacy list notifier keeps the diver current when called',
    () async {
      final callerDiverId = container.read(currentDiverIdProvider);
      final other = await createOtherDiver();
      final notifier = container.read(diveListNotifierProvider.notifier);

      final pending = notifier.addDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
      );
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(other.id);

      final created = await pending;
      // addDive starts the trip list's reload without awaiting it, and the
      // switch starts another; let them land before teardown disposes the
      // container under them.
      await pumpEventQueue();
      expect(created.diverId, callerDiverId);
    },
  );

  test('the legacy list notifier numbers an unnumbered logged dive', () async {
    final notifier = container.read(diveListNotifierProvider.notifier);
    final logged = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1)),
    );
    expect((await diveRepo.getDiveById(logged.id))?.diveNumber, isNotNull);
  });

  test('the legacy list notifier leaves a planned dive unnumbered', () async {
    final notifier = container.read(diveListNotifierProvider.notifier);
    final planned = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
    );
    expect((await diveRepo.getDiveById(planned.id))?.diveNumber, isNull);
  });
}

/// Holds the next [getDiverById] until [gate] completes, then behaves as the
/// real repository.
class _GatedDiverRepository extends DiverRepository {
  Completer<void>? gate;

  @override
  Future<Diver?> getDiverById(String id) async {
    final held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    return super.getDiverById(id);
  }
}
