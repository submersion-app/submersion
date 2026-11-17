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

/// A dive created by a new dive's sitting, written by the save service
/// rather than by [PaginatedDiveListNotifier.addDive], reaches the list as
/// addDive's would (issue #4527, plan 8).
void main() {
  late SharedPreferences prefs;
  late DiveRepository diveRepo;
  late ProviderContainer container;
  late String diverId;

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
    diverId = diver.id;
    await prefs.setString(currentDiverIdKey, diver.id);
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('the created dive is prepended and counted', () async {
    await diveRepo.createDive(
      Dive(id: 'old', diverId: diverId, dateTime: DateTime(2026, 5, 1)),
    );
    final notifier = container.read(paginatedDiveListProvider.notifier);
    await notifier.loadFirstPage();
    final before = container.read(paginatedDiveListProvider).value!;
    expect(before.dives.map((d) => d.id), ['old']);

    final created = await diveRepo.createDive(
      Dive(id: 'new', diverId: diverId, dateTime: DateTime(2026, 6, 1)),
    );
    await notifier.refreshAfterCreate(created);

    final after = container.read(paginatedDiveListProvider).value!;
    expect(after.dives.first.id, 'new');
    expect(after.totalCount, before.totalCount + 1);
    // The create starts the trip list's reload without awaiting it: let it
    // land before teardown disposes the container under it.
    await pumpEventQueue();
  });

  test('numbering info is read again', () async {
    final notifier = container.read(paginatedDiveListProvider.notifier);
    await notifier.loadFirstPage();
    var reads = 0;
    container.listen(diveNumberingInfoProvider, (_, _) => reads++);
    await container.read(diveNumberingInfoProvider.future);
    final settled = reads;

    final created = await diveRepo.createDive(
      Dive(id: 'new', diverId: diverId, dateTime: DateTime(2026, 6, 1)),
    );
    await notifier.refreshAfterCreate(created);
    await container.read(diveNumberingInfoProvider.future);

    expect(reads, greaterThan(settled));
    await pumpEventQueue();
  });

  // A dive made for another diver than the list's is not prepended: the
  // list is read again, and the dive is not in it (issue #4527, plan 8).
  test('a dive of another diver is not prepended', () async {
    final other = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'E',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    final notifier = container.read(paginatedDiveListProvider.notifier);
    await notifier.loadFirstPage();

    final created = await diveRepo.createDive(
      Dive(id: 'theirs', diverId: other.id, dateTime: DateTime(2026, 6, 1)),
    );
    await notifier.refreshAfterCreate(created);

    final after = container.read(paginatedDiveListProvider).value!;
    expect(after.dives.map((d) => d.id), isNot(contains('theirs')));
    await pumpEventQueue();
  });
}
