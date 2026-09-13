import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveEquipmentCompanion,
        EquipmentAttributesCompanion,
        EquipmentCompanion;
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// With an equipment-attribute filter active, the paginated list's SQL reads
/// the gear tables, which its list tick does not watch. An attribute-only
/// write (saveAttributes, a sync pull) must still re-run the page and count
/// (#1805 review).
/// Counts page loads and forwards everything the paginator calls to the real
/// repository. [DiveRepository]'s only public constructor is a factory, so
/// this delegates rather than extends.
class _CountingRepository implements DiveRepository {
  _CountingRepository(this._inner);

  final DiveRepository _inner;
  int summaryCalls = 0;

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) {
    summaryCalls++;
    return _inner.getDiveSummaries(
      diverId: diverId,
      filter: filter,
      cursor: cursor,
      offset: offset,
      limit: limit,
      sort: sort,
      disabledSafetyRules: disabledSafetyRules,
    );
  }

  @override
  Future<int> getDiveCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _inner.getDiveCount(diverId: diverId, filter: filter);

  @override
  Stream<void> watchDiveListChanges() => _inner.watchDiveListChanges();

  @override
  Stream<void> watchEquipmentAttrFilterChanges() =>
      _inner.watchEquipmentAttrFilterChanges();

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) => _inner.getBatchProfileSummaries(diveIds, maxSamples: maxSamples);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertHose(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion(
          id: Value(id),
          name: Value(id),
          type: Value(EquipmentType.hose.name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> setHoseType(String id, String kind) => db
      .into(db.equipmentAttributes)
      .insert(
        EquipmentAttributesCompanion(
          id: Value('attr_${id}_hose_type'),
          equipmentId: Value(id),
          attrKey: const Value('hose_type'),
          valueText: Value(kind),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion(
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

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
    final diveRepo = DiveRepository();
    for (final (id, day) in [('hpDive', 1), ('untypedDive', 2)]) {
      await diveRepo.createDive(
        Dive(id: id, diverId: diver.id, dateTime: DateTime(2026, 1, day)),
      );
    }
    await insertHose('hpHose');
    await setHoseType('hpHose', 'hp');
    await insertHose('untypedHose');
    await link('hpDive', 'hpHose');
    await link('untypedDive', 'untypedHose');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Set<String> listedIds(ProviderContainer container) =>
      container
          .read(paginatedDiveListProvider)
          .value
          ?.dives
          .map((d) => d.id)
          .toSet() ??
      const {};

  Future<Set<String>> waitFor(
    ProviderContainer container,
    bool Function(Set<String>) done,
  ) async {
    for (var i = 0; i < 200; i++) {
      final ids = listedIds(container);
      if (done(ids)) return ids;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return listedIds(container);
  }

  test('an attribute-only write reloads the filtered page and count', () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
    );
    expect(await waitFor(container, (ids) => ids.length == 1), {'hpDive'});

    // Typing the second hose writes equipment_attributes and nothing else.
    await setHoseType('untypedHose', 'hp');

    expect(await waitFor(container, (ids) => ids.length == 2), {
      'hpDive',
      'untypedDive',
    }, reason: 'the list tick does not watch equipment_attributes');
    expect(container.read(paginatedDiveListProvider).value!.totalCount, 2);
  });
  test('clearing the last condition stops following the gear tick', () async {
    final counting = _CountingRepository(DiveRepository());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveRepositoryProvider.overrideWithValue(counting),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [EquipmentAttrCondition(key: 'hose_type')],
    );
    await waitFor(container, (ids) => ids.length == 1);
    container.read(diveFilterProvider.notifier).state = const DiveFilterState();
    await waitFor(container, (ids) => ids.length == 2);
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    final before = counting.summaryCalls;

    // An unfiltered list does not read the gear tables, so a gear write must
    // not reload it.
    await setHoseType('untypedHose', 'lp');
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 300),
    );
    expect(counting.summaryCalls, before);
  });
  test('an attribute-only write refreshes detail-page neighbor ids', () async {
    // getOrderedDiveIds shares the list's WHERE builder, so previous/next
    // navigation reads the gear tables while a condition is set.
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(orderedDiveIdsProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(key: 'hose_type', choices: {'hp'}),
      ],
    );

    Future<List<String>?> orderedIds(bool Function(List<String>) done) async {
      for (var i = 0; i < 200; i++) {
        final ids = container.read(orderedDiveIdsProvider).value;
        if (ids != null && done(ids)) return ids;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return container.read(orderedDiveIdsProvider).value;
    }

    expect(await orderedIds((ids) => ids.length == 1), ['hpDive']);

    await setHoseType('untypedHose', 'hp');

    expect((await orderedIds((ids) => ids.length == 2))?.toSet(), {
      'hpDive',
      'untypedDive',
    }, reason: 'the dives tick never fires for an attribute-only write');
  });
}
