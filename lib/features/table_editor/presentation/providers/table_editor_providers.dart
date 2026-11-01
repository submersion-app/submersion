import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/bulk_dive_edit_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/narrow_dives.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/table_editor/data/table_editor_save_service.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/entities/center_table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/site_table_editor_entity.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

/// The table editor's state (#3422). Everything here is the editor's own:
/// its filters, column layouts and drafts never touch the list views'.

enum TableEditorTab { dives, sites, centers }

/// Not autoDispose: a tab's sheet is torn down when the diver switches tab
/// or narrows the window, and its drafts must outlive that. The page clears
/// them when it is left.
final tableEditorDraftsProvider =
    StateNotifierProvider.family<
      TableDraftsNotifier,
      TableDraftState,
      TableEditorTab
    >((ref, tab) => TableDraftsNotifier());

// ---------------------------------------------------------------------------
// Filters, one per tab
// ---------------------------------------------------------------------------

// Each watches the diver, so a diver switch starts the next sheet unfiltered.
final tableEditorDiveFilterProvider = StateProvider<DiveFilterState>((ref) {
  ref.watch(currentDiverIdProvider);
  return const DiveFilterState();
});
final tableEditorSiteQueryProvider = StateProvider<QueryNode?>((ref) {
  ref.watch(currentDiverIdProvider);
  return null;
});
final tableEditorCenterQueryProvider = StateProvider<QueryNode?>((ref) {
  ref.watch(currentDiverIdProvider);
  return null;
});

// ---------------------------------------------------------------------------
// Column layouts, one per tab, stored apart from the list views'
// ---------------------------------------------------------------------------

/// The dive tab starts from the diver's dive table layout, then keeps its
/// own under `table_editor_dives`.
final tableEditorDiveConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<DiveField>,
      EntityTableViewConfig<DiveField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<DiveField>(
        defaultConfig: ref.read(tableViewConfigProvider).toEntityConfig(),
        fieldFromName: (n) => diveFieldFromName(n) ?? DiveField.diveNumber,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_editor_dives');
      }
      return notifier;
    });

final tableEditorSiteConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<SiteField>,
      EntityTableViewConfig<SiteField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<SiteField>(
        defaultConfig: EntityTableViewConfig<SiteField>(
          columns: [
            EntityTableColumnConfig(field: SiteField.siteName, isPinned: true),
            EntityTableColumnConfig(field: SiteField.country),
            EntityTableColumnConfig(field: SiteField.region),
            EntityTableColumnConfig(field: SiteField.latitude),
            EntityTableColumnConfig(field: SiteField.longitude),
            EntityTableColumnConfig(field: SiteField.maxDepth),
            EntityTableColumnConfig(field: SiteField.waterType),
          ],
        ),
        fieldFromName: SiteFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_editor_sites');
      }
      return notifier;
    });

final tableEditorCenterConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<DiveCenterField>,
      EntityTableViewConfig<DiveCenterField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<DiveCenterField>(
        defaultConfig: EntityTableViewConfig<DiveCenterField>(
          columns: [
            EntityTableColumnConfig(
              field: DiveCenterField.centerName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: DiveCenterField.city),
            EntityTableColumnConfig(field: DiveCenterField.country),
            EntityTableColumnConfig(field: DiveCenterField.phone),
            EntityTableColumnConfig(field: DiveCenterField.email),
            EntityTableColumnConfig(field: DiveCenterField.rating),
          ],
        ),
        fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_editor_centers');
      }
      return notifier;
    });

// ---------------------------------------------------------------------------
// Rows, one list per tab, narrowed by the tab's filter
// ---------------------------------------------------------------------------

/// The dive list narrowed by the editor's filter, as the list loads it:
/// without weight rows.
final tableEditorListedDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final filter = ref.watch(tableEditorDiveFilterProvider);
  return narrowDivesByIds(
    ref.watch(diveListNotifierProvider),
    ref.watch(queryFilteredDiveIdsProvider(filter)),
  );
});

/// Weight rows for the dives on the sheet: the list never loads them, and
/// the weight cell needs the row count and the single row's amount.
final tableEditorWeightsProvider =
    FutureProvider<Map<String, List<DiveWeight>>>((ref) async {
      final dives = ref.watch(tableEditorListedDivesProvider).value ?? const [];
      final repository = ref.watch(diveRepositoryProvider);
      // Weight rows change under a save, an undo or a sync pull.
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      if (dives.isEmpty) return const {};
      return repository.getWeightsForDives([for (final d in dives) d.id]);
    });

/// The sheet's dives: the listed dives with their weight rows merged in, so
/// the weight column and the stale check read the row itself. A refetch of
/// the weights keeps the previous rows, so the sheet never drops to a
/// spinner mid-edit.
final tableEditorDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final listed = ref.watch(tableEditorListedDivesProvider);
  final weights = ref.watch(tableEditorWeightsProvider);
  if (!weights.hasValue) return const AsyncValue.loading();
  final byDive = weights.value ?? const <String, List<DiveWeight>>{};
  return listed.whenData(
    (dives) => [
      for (final d in dives) d.copyWith(weights: byDive[d.id] ?? const []),
    ],
  );
});

final tableEditorSitesProvider = Provider<AsyncValue<List<SiteWithCount>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(sitesWithCountsProvider),
    siteQueryEntity,
    ref.watch(tableEditorSiteQueryProvider),
    (s) => s.site.id,
  ),
);

/// Whether the profile may edit each library site on the sheet, resolved
/// once so a cell's editability stays synchronous.
final tableEditorEditableLibrarySitesProvider =
    FutureProvider<Map<String, bool>>((ref) async {
      final sites = ref.watch(tableEditorSitesProvider).value ?? const [];
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      await ref.watch(sharedLibrariesProvider.future);
      final stamper = LibraryEditStamper();
      return {
        for (final s in sites)
          if (s.site.isLibrarySite)
            s.site.id: await stamper.mayEdit(s.site.id, actingDiverId: diverId),
      };
    });

final tableEditorCentersProvider = Provider<AsyncValue<List<DiveCenterRow>>>((
  ref,
) {
  final centers = narrowByQuery(
    ref,
    ref.watch(diveCenterListNotifierProvider),
    diveCenterQueryEntity,
    ref.watch(tableEditorCenterQueryProvider),
    (c) => c.id,
  );
  final counts = ref.watch(diveCenterDiveCountsProvider).value ?? const {};
  return centers.whenData(
    (rows) => [for (final c in rows) (center: c, diveCount: counts[c.id] ?? 0)],
  );
});

// ---------------------------------------------------------------------------
// Descriptors and the save service
// ---------------------------------------------------------------------------

final tableEditorSaveServiceProvider = Provider<TableEditorSaveService>(
  (ref) => TableEditorSaveService(),
);

/// The dive descriptor, once its pick lists and the sheet's weights are in.
final tableEditorDiveEntityProvider =
    Provider<AsyncValue<DiveTableEditorEntity>>((ref) {
      final sites = ref.watch(sitesProvider);
      final centers = ref.watch(allDiveCentersProvider);
      final trips = ref.watch(allTripsProvider);
      if (!sites.hasValue || !centers.hasValue || !trips.hasValue) {
        return const AsyncValue.loading();
      }
      final dives = ref.watch(tableEditorDivesProvider).value ?? const [];
      return AsyncValue.data(
        DiveTableEditorEntity(
          diveRepo: ref.watch(diveRepositoryProvider),
          bulk: ref.watch(bulkDiveEditServiceProvider),
          sites: [
            for (final s in sites.value ?? const []) ChoiceOption(s.id, s.name),
          ],
          centers: [
            for (final c in centers.value ?? const [])
              ChoiceOption(c.id, c.name),
          ],
          trips: [
            for (final t in trips.value ?? const []) ChoiceOption(t.id, t.name),
          ],
          defaultWeightType: DiveTableEditorEntity.latestWeightType(dives),
        ),
      );
    });

final tableEditorSiteEntityProvider =
    Provider<AsyncValue<SiteTableEditorEntity>>((ref) {
      final editable = ref.watch(tableEditorEditableLibrarySitesProvider);
      if (!editable.hasValue) return const AsyncValue.loading();
      return AsyncValue.data(
        SiteTableEditorEntity(
          repo: ref.watch(siteRepositoryProvider),
          editableLibrarySites: editable.value ?? const {},
          actingDiverId: ref.watch(currentDiverIdProvider),
        ),
      );
    });

final tableEditorCenterEntityProvider = Provider<CenterTableEditorEntity>(
  (ref) =>
      CenterTableEditorEntity(repo: ref.watch(diveCenterRepositoryProvider)),
);
