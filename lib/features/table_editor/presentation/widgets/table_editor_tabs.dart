import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/column_rules.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_table_menus.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/table/entity_column_menus.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/features/table_editor/presentation/widgets/table_editor_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

/// The three tabs of the table editor (#3422): each wires its entity's
/// filter chips and column menus around one [TableEditorSheet].

/// The dive tab reuses the dive list's own header and cell menus over the
/// editor's filter, so every rule the list offers works here too.
class DiveEditorTab extends ConsumerStatefulWidget {
  final void Function(String id) onOpenRecord;
  const DiveEditorTab({super.key, required this.onOpenRecord});

  @override
  ConsumerState<DiveEditorTab> createState() => _DiveEditorTabState();
}

class _DiveEditorTabState extends ConsumerState<DiveEditorTab> {
  /// The rows last shown: a reload after a save keeps them on screen
  /// instead of a spinner.
  List<Dive>? _lastRows;

  @override
  Widget build(BuildContext context) {
    final onOpenRecord = widget.onOpenRecord;
    final entityAsync = ref.watch(tableEditorDiveEntityProvider);
    final rowsAsync = ref.watch(tableEditorDivesProvider);
    final filter = ref.watch(tableEditorDiveFilterProvider);
    final entity = entityAsync.value;
    final rows = _lastRows = rowsAsync.value ?? _lastRows;
    if (entity == null || rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final units = ref.watch(unitFormatterProvider);
    final prefs = ref.watch(queryUnitPrefsProvider);
    final intervals = ref.watch(diveSurfaceIntervalsProvider);
    final computers = ref.watch(allDiveComputersProvider);
    final diveTypeLabel = watchDiveTypeLabelResolver(ref, context.l10n);
    List<CellFilterOption> cellOptions(Dive dive, DiveField field) =>
        diveCellFilterOptions(
          field: field,
          dive: dive,
          units: units,
          prefs: prefs,
          diveTypeLabel: diveTypeLabel,
          surfaceIntervals: intervals.isLoading ? null : intervals.value,
          knownComputerIds: computers.isLoading
              ? null
              : computers.value?.map((c) => c.id).toSet(),
        );
    return QueryChipsFrame(
      root: diveQueryEntity,
      query: filter.query,
      onChanged: (q) => ref.read(tableEditorDiveFilterProvider.notifier).state =
          filter.copyWith(query: q, clearQuery: q == null),
      child: TableEditorSheet<Dive, DiveField>(
        tab: TableEditorTab.dives,
        entity: entity,
        rows: rows,
        configProvider: tableEditorDiveConfigProvider,
        isColumnFiltered: (f) => isDiveColumnFiltered(filter, f),
        headerMenuBuilder: (context, field) => diveHeaderMenuItems(
          context,
          ref,
          field,
          filterProvider: tableEditorDiveFilterProvider,
        ),
        cellMenuBuilder: (context, dive, field) => diveCellMenuItems(
          context,
          ref,
          field,
          cellOptions(dive, field),
          filterProvider: tableEditorDiveFilterProvider,
        ),
        onOpenRecord: onOpenRecord,
      ),
    );
  }
}

/// Which query field a site column filters on; a column with none has no
/// filter menu.
const kSiteColumnKeys = <SiteField, String>{
  SiteField.siteName: 'name',
  SiteField.city: 'city',
  SiteField.notes: 'notes',
  SiteField.rating: 'rating',
  SiteField.maxDepth: 'maxDepth',
  SiteField.difficulty: 'difficulty',
  SiteField.latitude: 'coordinates',
  SiteField.longitude: 'coordinates',
};

const kCenterColumnKeys = <DiveCenterField, String>{
  DiveCenterField.centerName: 'name',
  DiveCenterField.city: 'city',
  DiveCenterField.country: 'country',
  DiveCenterField.stateProvince: 'stateProvince',
  DiveCenterField.rating: 'rating',
  DiveCenterField.notes: 'notes',
  DiveCenterField.latitude: 'coordinates',
  DiveCenterField.longitude: 'coordinates',
};

class SiteEditorTab extends ConsumerStatefulWidget {
  final void Function(String id) onOpenRecord;
  const SiteEditorTab({super.key, required this.onOpenRecord});

  @override
  ConsumerState<SiteEditorTab> createState() => _SiteEditorTabState();
}

class _SiteEditorTabState extends ConsumerState<SiteEditorTab> {
  List<SiteWithCount>? _lastRows;

  @override
  Widget build(BuildContext context) {
    final onOpenRecord = widget.onOpenRecord;
    final entity = ref.watch(tableEditorSiteEntityProvider).value;
    final rows = _lastRows =
        ref.watch(tableEditorSitesProvider).value ?? _lastRows;
    if (entity == null || rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _QueryTab<SiteWithCount, SiteField>(
      tab: TableEditorTab.sites,
      entity: entity,
      rows: rows,
      root: siteQueryEntity,
      keys: kSiteColumnKeys,
      queryProvider: tableEditorSiteQueryProvider,
      configProvider: tableEditorSiteConfigProvider,
      onOpenRecord: onOpenRecord,
    );
  }
}

class CenterEditorTab extends ConsumerStatefulWidget {
  final void Function(String id) onOpenRecord;
  const CenterEditorTab({super.key, required this.onOpenRecord});

  @override
  ConsumerState<CenterEditorTab> createState() => _CenterEditorTabState();
}

class _CenterEditorTabState extends ConsumerState<CenterEditorTab> {
  List<DiveCenterRow>? _lastRows;

  @override
  Widget build(BuildContext context) {
    final onOpenRecord = widget.onOpenRecord;
    final entity = ref.watch(tableEditorCenterEntityProvider);
    final rows = _lastRows =
        ref.watch(tableEditorCentersProvider).value ?? _lastRows;
    if (rows == null) return const Center(child: CircularProgressIndicator());
    return _QueryTab<DiveCenterRow, DiveCenterField>(
      tab: TableEditorTab.centers,
      entity: entity,
      rows: rows,
      root: diveCenterQueryEntity,
      keys: kCenterColumnKeys,
      queryProvider: tableEditorCenterQueryProvider,
      configProvider: tableEditorCenterConfigProvider,
      onOpenRecord: onOpenRecord,
    );
  }
}

/// A tab whose filter is a bare query with the generic column menus.
class _QueryTab<T, F extends EntityField> extends ConsumerWidget {
  final TableEditorTab tab;
  final TableEditorEntity<T, F> entity;
  final List<T> rows;
  final QueryEntity root;
  final Map<F, String> keys;
  final StateProvider<QueryNode?> queryProvider;
  final StateNotifierProvider<
    EntityTableConfigNotifier<F>,
    EntityTableViewConfig<F>
  >
  configProvider;
  final void Function(String id) onOpenRecord;

  const _QueryTab({
    required this.tab,
    required this.entity,
    required this.rows,
    required this.root,
    required this.keys,
    required this.queryProvider,
    required this.configProvider,
    required this.onOpenRecord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(queryProvider);
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    void setQuery(QueryNode? q) => ref.read(queryProvider.notifier).state = q;
    return QueryChipsFrame(
      root: root,
      query: query,
      onChanged: setQuery,
      child: TableEditorSheet<T, F>(
        tab: tab,
        entity: entity,
        rows: rows,
        configProvider: configProvider,
        isColumnFiltered: (f) {
          final key = keys[f];
          return key != null && isColumnFiltered(query, key);
        },
        headerMenuBuilder: (context, field) {
          final key = keys[field];
          if (key == null) return const <EntityTableMenuAction>[];
          return entityColumnHeaderMenuItems(
            l10n: l10n,
            root: root,
            fieldKey: key,
            columnLabel: field.localizedDisplayName(l10n),
            query: query,
            onChanged: setQuery,
          );
        },
        cellMenuBuilder: (context, row, field) {
          final key = keys[field];
          if (key == null) return const <EntityTableMenuAction>[];
          final value = entity.adapter.extractValue(field, row);
          return entityColumnCellMenuItems(
            l10n: l10n,
            root: root,
            fieldKey: key,
            value: value,
            valueLabel: entity.adapter.formatValue(field, value, units),
            query: query,
            onChanged: setQuery,
          );
        },
        onOpenRecord: onOpenRecord,
      ),
    );
  }
}
