import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveProfileEventsCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The entity-backed surfaces (dive table view, activity map, heat map) all
/// read [filteredDivesProvider]. Their dives come from getAllDives, which does
/// not hydrate profiles, so the decompression axis has to be resolved in SQL.
/// These tests pin that: the deco filter must select the same dives here as it
/// does on the paginated list, including the event-only dive that never
/// reaches the entity at all.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiverRepository diverRepo;
  late String diverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    diverRepo = DiverRepository();

    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    diverId = diver.id;
    await prefs.setString(currentDiverIdKey, diverId);

    await diveRepo.createDive(
      Dive(
        id: 'deco',
        diverId: diverId,
        dateTime: DateTime(2026, 1, 1),
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 30, decoType: 0),
          DiveProfilePoint(timestamp: 60, depth: 30, decoType: 2),
        ],
      ),
    );
    await diveRepo.createDive(
      Dive(
        id: 'noDeco',
        diverId: diverId,
        dateTime: DateTime(2026, 1, 2),
        profile: const [DiveProfilePoint(timestamp: 0, depth: 18, decoType: 0)],
      ),
    );
    // Deco recorded only as an event: invisible to the entity entirely.
    await diveRepo.createDive(
      Dive(
        id: 'eventOnly',
        diverId: diverId,
        dateTime: DateTime(2026, 1, 3),
        profile: const [DiveProfilePoint(timestamp: 0, depth: 30)],
      ),
    );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: const Value('e-1'),
            diveId: const Value('eventOnly'),
            timestamp: const Value(0),
            eventType: const Value('decoStopStart'),
            createdAt: Value(DateTime(2026, 1, 3).millisecondsSinceEpoch),
          ),
        );
    await diveRepo.createDive(
      Dive(id: 'unrecorded', diverId: diverId, dateTime: DateTime(2026, 1, 4)),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Reads [filteredDivesProvider] once both the dive list and the deco id set
  /// have settled.
  Future<List<String>> filteredIds(ProviderContainer container) async {
    for (var i = 0; i < 100; i++) {
      final value = container.read(filteredDivesProvider);
      if (value.hasValue) return value.value!.map((d) => d.id).toList();
      if (value.hasError) fail('filteredDivesProvider failed: ${value.error}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('filteredDivesProvider never produced a value');
  }

  test('no deco filter leaves every dive in the list', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await filteredIds(container), hasLength(4));
  });

  test('decoOnly: true keeps deco dives, event-only included', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    // Settle the unfiltered list first, mirroring a user turning the filter on
    // from the already-rendered list.
    await filteredIds(container);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: true,
    );

    expect((await filteredIds(container)).toSet(), {'deco', 'eventOnly'});
  });

  test('decoOnly: false keeps only recorded no-deco dives', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    await filteredIds(container);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: false,
    );

    expect((await filteredIds(container)).toSet(), {'noDeco'});
  });

  test('flipping the deco polarity does not reuse the other set', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    await filteredIds(container);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: true,
    );
    expect((await filteredIds(container)).toSet(), {'deco', 'eventOnly'});

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: false,
    );
    expect((await filteredIds(container)).toSet(), {'noDeco'});
  });

  test('the deco axis combines with the in-memory axes', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    await filteredIds(container);

    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      decoOnly: true,
      startDate: DateTime(2026, 1, 3),
    );

    expect((await filteredIds(container)).toSet(), {'eventOnly'});
  });
}
