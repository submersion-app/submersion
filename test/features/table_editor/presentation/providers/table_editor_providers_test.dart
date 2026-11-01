import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
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
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';

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
        .read(tableEditorDraftsProvider(TableEditorTab.dives).notifier)
        .setSelected(null);
    expect(
      container.read(tableEditorDraftsProvider(TableEditorTab.sites)).isEmpty,
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
        .read(tableEditorDraftsProvider(TableEditorTab.dives).notifier)
        .put(
          const TableDraft(
            entityId: 'd1',
            fieldName: 'notes',
            original: null,
            value: 'x',
          ),
        );
    expect(
      container.read(tableEditorDraftsProvider(TableEditorTab.dives)).count,
      1,
    );

    diver.setCurrentDiver('b');

    expect(
      container.read(tableEditorDraftsProvider(TableEditorTab.dives)).isEmpty,
      isTrue,
    );
  });
}

/// The real row and descriptor providers over a test database (#3422):
/// dives arrive with their weight rows merged, and every tab's descriptor
/// resolves once its lists are in.
void providerIntegration() {
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
          weightType: WeightType.belt,
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
      overrides: [currentDiverIdProvider.overrideWith((ref) => diver)],
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
