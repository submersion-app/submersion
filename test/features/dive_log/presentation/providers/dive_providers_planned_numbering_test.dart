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

  test('the legacy list notifier leaves a planned dive unnumbered', () async {
    final notifier = container.read(diveListNotifierProvider.notifier);
    final planned = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
    );
    expect((await diveRepo.getDiveById(planned.id))?.diveNumber, isNull);
  });
}
