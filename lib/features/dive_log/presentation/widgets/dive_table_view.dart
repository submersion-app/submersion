import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_table_menus.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

/// The dive list's table (#2984): the shared [EntityTableView] fed by
/// [DiveFieldAdapter] and the dive table's stored config, so scrollbars,
/// resizing and column menus are the same code every list runs.
class DiveTableView extends ConsumerWidget {
  final List<Dive> dives;
  final void Function(String diveId) onDiveTap;
  final void Function(String diveId)? onDiveTapDown;
  final void Function(String diveId)? onDiveDoubleTap;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final String? highlightedId;

  /// Resolves a dive-type slug to its on-screen label for the Dive Type
  /// column and its sort.
  ///
  /// Required rather than optional, like `DiveListItem.diveTypeLabelResolver`:
  /// without one, [DiveField.extractFromDive] falls back to the slug
  /// capitalization, so a custom type shows its id instead of the diver's
  /// name and a built-in type stays English. Build it once, above the table,
  /// via [watchDiveTypeLabelResolver].
  final DiveTypeLabelResolver diveTypeLabelResolver;

  const DiveTableView({
    super.key,
    required this.dives,
    required this.onDiveTap,
    required this.diveTypeLabelResolver,
    this.onDiveTapDown,
    this.onDiveDoubleTap,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.highlightedId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final notifier = ref.read(tableViewConfigProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final intervalsAsync = ref.watch(diveSurfaceIntervalsProvider);
    final intervals = intervalsAsync.value ?? const <String, Duration?>{};
    final computers = ref.watch(allDiveComputersProvider);
    final prefs = ref.watch(queryUnitPrefsProvider);
    final filter = ref.watch(diveFilterProvider);
    final units = UnitFormatter(settings);
    // Cell menus read only settled data: a value still loading could offer
    // a rule that drops the dive it was offered on.
    final menuIntervals = intervalsAsync.isLoading
        ? null
        : intervalsAsync.value;
    final computerIds = computers.isLoading
        ? null
        : computers.value?.map((c) => c.id).toSet();
    List<CellFilterOption> cellOptions(Dive dive, DiveField field) =>
        diveCellFilterOptions(
          field: field,
          dive: dive,
          units: units,
          prefs: prefs,
          diveTypeLabel: diveTypeLabelResolver,
          surfaceIntervals: menuIntervals,
          knownComputerIds: computerIds,
        );
    return EntityTableView<Dive, DiveField>(
      entities: dives,
      idExtractor: (d) => d.id,
      adapter: DiveFieldAdapter(
        gasModel: settings.gasModel,
        diveTypeLabel: diveTypeLabelResolver,
        surfaceIntervals: intervals,
      ),
      config: config.toEntityConfig(),
      units: units,
      onSortFieldChanged: notifier.setSortField,
      onResizeColumn: notifier.resizeColumn,
      onHideColumn: notifier.hideColumn,
      onEntityTap: onDiveTap,
      onEntityTapDown: onDiveTapDown,
      onEntityDoubleTap: onDiveDoubleTap,
      selectedIds: selectedIds,
      isSelectionMode: isSelectionMode,
      highlightedId: highlightedId,
      headerMenuBuilder: (context, field) =>
          diveHeaderMenuItems(context, ref, field),
      cellMenuBuilder: (context, dive, field) =>
          diveCellMenuItems(context, ref, field, cellOptions(dive, field)),
      isColumnFiltered: (field) => isDiveColumnFiltered(filter, field),
      // Only a cell with items gets the gesture, so a hold elsewhere stays
      // the row's.
      hasCellMenu: (dive, field) => cellOptions(dive, field).isNotEmpty,
    );
  }
}
