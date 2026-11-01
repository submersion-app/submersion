import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The editor's filters and column layouts are its own (#3422): a migration
/// setup never changes the diver's everyday lists.
void main() {
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
