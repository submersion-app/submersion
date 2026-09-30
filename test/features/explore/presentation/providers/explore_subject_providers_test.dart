import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });
  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<void> site(
    String id, {
    String diverId = 'me',
    bool shared = false,
    double? rating,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          diverId: Value(diverId),
          isShared: Value(shared),
          rating: Value(rating),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> dive(
    String id,
    String? siteId, {
    double depth = 10,
    String? tripId,
    String? centerId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: const Value('me'),
          siteId: Value(siteId),
          tripId: Value(tripId),
          diveCenterId: Value(centerId),
          maxDepth: Value(depth),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<ProviderContainer> container() async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...overrides,
        localeProvider.overrideWithValue('en'),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ].cast(),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<ExploreSubjectRow>> rows(ProviderContainer c) async {
    await c.read(exploreSubjectCountsProvider.future);
    for (var i = 0; i < 50; i++) {
      final v = c.read(exploreSubjectRowsProvider);
      if (v.hasValue) return v.value!;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('rows never loaded');
  }

  test('a subject alone ranks every row by its dives, then name', () async {
    await site('b');
    await site('a');
    await site('busy');
    await dive('1', 'busy');
    await dive('2', 'busy');
    await dive('3', 'b');
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;

    final r = await rows(c);
    expect(r.map((x) => x.id), ['busy', 'b', 'a']);
    expect(r.map((x) => x.dives), [2, 1, 0]);
  });

  test('the query narrows through the list and the scope ranks', () async {
    await site('good', rating: 5);
    await site('bad', rating: 1);
    await dive('1', 'good', depth: 30);
    await dive('2', 'good', depth: 5);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['rating']),
      QueryOp.gte,
      const NumberValue(4, null),
    );
    c.read(exploreDiveScopeProvider.notifier).state = ConditionNode(
      FieldPath(const ['depth']),
      QueryOp.gte,
      const NumberValue(20, null),
    );

    final r = await rows(c);
    expect(r.single.id, 'good');
    expect(r.single.dives, 1);
  });

  test(
    "another diver's shared site is a result, as the list shows it",
    () async {
      await site('mine');
      await site('theirs', diverId: 'other', shared: true);
      final c = await container();
      c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;

      expect((await rows(c)).map((x) => x.id).toSet(), {'mine', 'theirs'});
    },
  );

  test('retired gear is an answer when the sentence names retired', () async {
    // The equipment list's unset status hides retired gear; Explore lifts
    // the named status into that axis instead of contradicting it.
    for (final (id, status) in [('old', 'retired'), ('kit', 'active')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: now,
              updatedAt: now,
            ).copyWith(
              status: Value(status),
              isActive: Value(status == 'active'),
              diverId: const Value('me'),
            ),
          );
    }
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.equipment;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['status']),
      QueryOp.inList,
      ListValue(const [EnumValue('retired')]),
    );
    expect((await rows(c)).map((x) => x.id), ['old']);
  });

  test('trips rank by their dives in the scope', () async {
    for (final id in ['quiet', 'busy']) {
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: id,
              name: id,
              startDate: now,
              endDate: now,
              createdAt: now,
              updatedAt: now,
            ).copyWith(diverId: const Value('me')),
          );
    }
    await dive('1', null, tripId: 'busy');
    await dive('2', null, tripId: 'busy');
    await dive('3', null, tripId: 'quiet');
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.trips;

    final r = await rows(c);
    expect(r.map((x) => x.id), ['busy', 'quiet']);
    expect(r.map((x) => x.dives), [2, 1]);
  });

  test('buddies narrow by their own fields and rank by dives', () async {
    for (final (id, favourite) in [
      ('amy', true),
      ('bob', true),
      ('cy', false),
    ]) {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ).copyWith(
              diverId: const Value('me'),
              isFavorite: Value(favourite),
            ),
          );
    }
    await dive('1', null);
    for (final (id, buddy) in [('j1', 'bob'), ('j2', 'cy')]) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion.insert(
              id: id,
              diveId: '1',
              buddyId: buddy,
              createdAt: now,
            ),
          );
    }
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.buddies;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    );

    final r = await rows(c);
    expect(r.map((x) => x.id), ['bob', 'amy']);
    expect(r.map((x) => x.dives), [1, 0]);
  });

  test('centers rank by their dives in the scope', () async {
    for (final id in ['a', 'b']) {
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ).copyWith(diverId: const Value('me')),
          );
    }
    await dive('1', null, centerId: 'b', depth: 30);
    await dive('2', null, centerId: 'a', depth: 5);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.centers;
    c.read(exploreDiveScopeProvider.notifier).state = ConditionNode(
      FieldPath(const ['depth']),
      QueryOp.gte,
      const NumberValue(20, null),
    );

    final r = await rows(c);
    expect(r.map((x) => x.id), ['b', 'a']);
    expect(r.map((x) => x.dives), [1, 0]);
  });

  test('seen species rank by the dives they were seen on', () async {
    for (final id in ['turtle', 'ray']) {
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(id: id, commonName: id, category: 'fish'),
          );
    }
    await dive('1', null);
    await dive('2', null);
    for (final (id, d, sp) in [
      ('s1', '1', 'turtle'),
      ('s2', '2', 'turtle'),
      ('s3', '2', 'ray'),
    ]) {
      await db
          .into(db.sightings)
          .insert(SightingsCompanion.insert(id: id, diveId: d, speciesId: sp));
    }
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.species;

    final r = await rows(c);
    expect(r.map((x) => x.id), ['turtle', 'ray']);
    expect(r.map((x) => x.dives), [2, 1]);
  });

  test('another subject leaves the dive providers empty', () async {
    await site('a');
    await dive('1', 'a', depth: 30);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['maxDepth']),
      QueryOp.gte,
      const NumberValue(1, null),
    );
    expect(c.read(exploreFilterProvider).hasActiveFilters, isFalse);
    expect(await c.read(exploreResultsProvider.future), isEmpty);
  });

  test('publishing a parse sets the subject and the dive scope', () async {
    final c = await container();
    await c
        .read(exploreQueryProvider.notifier)
        .rerun(
          'buddies this year',
          const ParsedQuery(
            subject: ParsedSubject.buddies,
            time: QueryTime('this year'),
          ),
        );
    expect(c.read(exploreSubjectProvider), ParsedSubject.buddies);
    expect(c.read(exploreDiveScopeProvider), isA<AndNode>());

    c.read(exploreQueryProvider.notifier).clear();
    expect(c.read(exploreSubjectProvider), ParsedSubject.dives);
    expect(c.read(exploreDiveScopeProvider), isNull);
  });
}
