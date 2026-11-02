import 'dart:ui' show Locale;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart'
    show DiveWeightsCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as sites;

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The editor's filters and column layouts are its own (#3422): a migration
/// setup never changes the diver's everyday lists.
void main() {
  providerIntegration();
  test('the editor dive filter leaves diveFilterProvider untouched', () {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final rule = ConditionNode(
      FieldPath(const ['notes']),
      QueryOp.isEmpty,
      null,
    );

    container.read(tableEditorDiveFilterProvider.notifier).state =
        DiveFilterState(query: rule);

    expect(container.read(tableEditorDiveFilterProvider).query, rule);
    expect(container.read(diveFilterProvider).query, isNull);
    expect(container.read(tableEditorSiteQueryProvider), isNull);
    expect(container.read(tableEditorCenterQueryProvider), isNull);
  });

  test('each tab keeps its own drafts', () {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier)
        .setSelected(null);
    expect(
      container
          .read(tableEditorDraftsNotifierProvider(TableEditorTab.sites))
          .isEmpty,
      isTrue,
    );
  });

  test('the editor dive config has its own storage key and leaves the dive '
      'list config alone', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    // No diver row: the view config's diver foreign key is not the point.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final diver = MockCurrentDiverIdNotifier();
    final container = ProviderContainer(
      overrides: [currentDiverIdProvider.overrideWith((ref) => diver)],
    );
    addTearDown(container.dispose);
    await diver.setCurrentDiver('me');

    final notifier = container.read(tableEditorDiveConfigProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    notifier.setSortField(DiveField.maxDepth);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final repo = container.read(viewConfigRepositoryProvider);
    expect(await repo.getRawConfig('me', 'table_editor_dives'), isNotNull);
    expect(await repo.getRawConfig('me', 'table'), isNull);
    expect(
      container.read(tableViewConfigProvider).sortField,
      isNot(DiveField.maxDepth),
    );
  });

  test('a diver switch starts every tab with no drafts', () {
    final diver = MockCurrentDiverIdNotifier();
    final container = ProviderContainer(
      overrides: [currentDiverIdProvider.overrideWith((ref) => diver)],
    );
    addTearDown(container.dispose);
    diver.setCurrentDiver('a');
    container
        .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier)
        .put(
          const TableDraft(
            entityId: 'd1',
            fieldName: 'notes',
            original: null,
            value: 'x',
          ),
        );
    expect(
      container
          .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives))
          .count,
      1,
    );

    diver.setCurrentDiver('b');

    expect(
      container
          .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives))
          .isEmpty,
      isTrue,
    );
  });
}

/// The real row and descriptor providers over a test database (#3422):
/// dives arrive with their weight rows merged, and every tab's descriptor
/// resolves once its lists are in.
void providerIntegration() {
  group('the sheet\'s weights', () {
    Future<void> settleOn(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue, reason: 'never settled');
    }

    final dive = domain.Dive(
      id: 'd1',
      diverId: 'me',
      dateTime: DateTime(2026, 1, 1),
      notes: '',
    );

    test('a list reload leaves every dive its weights', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await insertDiver(db, 'me');
      final repo = DiveRepository();
      await repo.createDive(dive);
      await repo.bulkAddWeights(
        ['d1'],
        const [
          domain.DiveWeight(
            id: '',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 5,
          ),
        ],
      );
      final listed = StateProvider<AsyncValue<List<domain.Dive>>>(
        (ref) => AsyncValue.data([dive]),
      );
      final diver = MockCurrentDiverIdNotifier();
      await diver.setCurrentDiver('me');
      final container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diver),
          tableEditorListedDivesProvider.overrideWith(
            (ref) => ref.watch(listed),
          ),
        ],
      );
      addTearDown(container.dispose);
      final rows = <int>[];
      final sub = container.listen(tableEditorDivesProvider, (_, next) {
        if (next.value case final dives?) rows.add(dives.single.weights.length);
      });
      addTearDown(sub.close);
      await settleOn(() => rows.contains(1));
      rows.clear();

      container.read(listed.notifier).state = const AsyncValue.loading();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      container.read(listed.notifier).state = AsyncValue.data([dive]);
      await settleOn(() => rows.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(rows, everyElement(1));
    });

    test('a weight row that changes on its own reaches the sheet', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await insertDiver(db, 'me');
      final repo = DiveRepository();
      await repo.createDive(dive);
      final diver = MockCurrentDiverIdNotifier();
      await diver.setCurrentDiver('me');
      final container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diver),
          tableEditorListedDivesProvider.overrideWithValue(
            AsyncValue.data([dive]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(tableEditorWeightsProvider, (_, _) {});
      addTearDown(sub.close);
      await settleOn(() => container.read(tableEditorWeightsProvider).hasValue);

      // As a sync pull lands one: the row alone, the dive untouched.
      await db
          .into(db.diveWeights)
          .insert(
            const DiveWeightsCompanion(
              id: Value('w1'),
              diveId: Value('d1'),
              weightType: Value('belt'),
              amountKg: Value(7),
              createdAt: Value(0),
            ),
          );

      await settleOn(
        () => container
            .read(tableEditorWeightsProvider)
            .requireValue
            .containsKey('d1'),
      );
    });
  });

  group('a load that fails reads as failed, not as still loading', () {
    ProviderContainer containerWith(List<dynamic> overrides) {
      final diver = MockCurrentDiverIdNotifier();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diver),
          ...overrides.cast(),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('the weights behind the rows', () async {
      final container = containerWith([
        tableEditorListedDivesProvider.overrideWithValue(
          const AsyncValue.data(<domain.Dive>[]),
        ),
        tableEditorWeightsProvider.overrideWith(
          (ref) async => throw StateError('no weights'),
        ),
      ]);
      final sub = container.listen(tableEditorDivesProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(tableEditorDivesProvider).hasError, isTrue);
    });

    test('a pick list behind the dive descriptor', () async {
      final container = containerWith([
        tableEditorNewWeightTypeProvider.overrideWith(
          (ref) async => throw StateError('no type'),
        ),
      ]);
      final sub = container.listen(tableEditorDiveEntityProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(tableEditorDiveEntityProvider).hasError, isTrue);
    });

    test('the library rights behind the site descriptor', () async {
      final container = containerWith([
        tableEditorEditableLibrarySitesProvider.overrideWith(
          (ref) async => throw StateError('no rights'),
        ),
      ]);
      final sub = container.listen(tableEditorSiteEntityProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(tableEditorSiteEntityProvider).hasError, isTrue);
    });
  });

  test('the real providers load rows, weights and descriptors', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await insertDiver(db, 'me');
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('me');
    final diveRepo = DiveRepository();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        diverId: 'me',
        dateTime: DateTime(2026, 1, 1),
        notes: '',
      ),
    );
    await diveRepo.bulkAddWeights(
      ['d1'],
      const [
        domain.DiveWeight(
          id: '',
          diveId: '',
          weightType: WeightType.integrated,
          amountKg: 5,
        ),
      ],
    );
    await SiteRepository().createSite(
      const sites.DiveSite(id: 's1', name: 'Reef', diverId: 'me'),
    );
    await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: 'c1',
        name: 'Blue',
        diverId: 'me',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => diver),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(gasModel: GasModel.ideal, locale: 'de'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    Future<T> settle<T>(T? Function() read) async {
      for (var i = 0; i < 100; i++) {
        final v = read();
        if (v != null) return v;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      fail('provider never settled');
    }

    final dives = await settle(() {
      // The weights arrive one load after the dives; wait for the merge.
      final v = container.read(tableEditorDivesProvider).value;
      return v == null || v.isEmpty || v.single.weights.isEmpty ? null : v;
    });
    expect(dives.single.weights.single.amountKg, 5);
    final entity = await settle(
      () => container.read(tableEditorDiveEntityProvider).value,
    );
    expect(entity.columns, isNotEmpty);
    // The sheet reads a dive as the list does, in the diver's language.
    expect(entity.adapter.gasModel, GasModel.ideal);
    expect(
      entity.adapter.diveTypeLabel?.call('wreck'),
      diveTypeLabel(lookupAppLocalizations(const Locale('de')), 'wreck'),
    );
    expect(
      (await container.read(tableEditorNewWeightTypeProvider.future)),
      WeightType.integrated,
    );
    final rows = await settle(
      () => container.read(tableEditorSitesProvider).value,
    );
    expect(rows.map((r) => r.site.name), ['Reef']);
    final centers = await settle(
      () => container.read(tableEditorCentersProvider).value,
    );
    expect(centers.map((r) => r.center.name), ['Blue']);
    final siteEntity = await settle(
      () => container.read(tableEditorSiteEntityProvider).value,
    );
    expect(siteEntity.columns, isNotEmpty);
    expect(container.read(tableEditorCenterEntityProvider).columns, isNotEmpty);
    expect(container.read(tableEditorSaveServiceProvider), isNotNull);
    container.read(tableEditorSiteConfigProvider);
    container.read(tableEditorCenterConfigProvider);
  });
}
