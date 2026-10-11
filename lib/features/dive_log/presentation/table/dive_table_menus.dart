import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/show_refine_panel.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

/// Header menu items for a dive column (#2984): Add filter and Reset
/// filter on a filterable column, nothing on the rest (the table adds Hide).
List<EntityTableMenuAction> diveHeaderMenuItems(
  BuildContext context,
  WidgetRef ref,
  DiveField field,
) {
  if (!kDiveColumnFilters.containsKey(field)) return const [];
  final l10n = context.l10n;
  final filter = ref.read(diveFilterProvider);
  return [
    EntityTableMenuAction(
      label: l10n.tableMode_menu_addFilter,
      onSelected: () => _addColumnFilter(context, ref, field),
    ),
    EntityTableMenuAction(
      label: l10n.tableMode_menu_resetFilter,
      enabled: isDiveColumnFiltered(filter, field),
      onSelected: () => ref.read(diveFilterProvider.notifier).state =
          resetDiveColumnFilter(ref.read(diveFilterProvider), field),
    ),
  ];
}

/// Cell menu items for a cell in [field]'s column, from its [options]
/// (see `diveCellFilterOptions`); each applies at once.
List<EntityTableMenuAction> diveCellMenuItems(
  BuildContext context,
  WidgetRef ref,
  DiveField field,
  List<CellFilterOption> options,
) {
  final l10n = context.l10n;
  return [
    for (final o in options)
      EntityTableMenuAction(
        label: cellFilterLabel(l10n, o, field),
        onSelected: () => ref.read(diveFilterProvider.notifier).state =
            addDiveTableRule(ref.read(diveFilterProvider), o.rule),
      ),
  ];
}

/// How a cell menu words [option].
String cellFilterLabel(
  AppLocalizations l10n,
  CellFilterOption option,
  DiveField field,
) {
  final v = option.valueLabel;
  final column = field.localizedDisplayName(l10n);
  return switch (option.kind) {
    CellFilterKind.only => l10n.tableMode_cell_only(v),
    CellFilterKind.exclude => l10n.tableMode_cell_exclude(v),
    CellFilterKind.atLeast => l10n.tableMode_cell_atLeast(v),
    CellFilterKind.atMost => l10n.tableMode_cell_atMost(v),
    CellFilterKind.onOrAfter => l10n.tableMode_cell_onOrAfter(v),
    CellFilterKind.onOrBefore => l10n.tableMode_cell_onOrBefore(v),
    CellFilterKind.withValue => l10n.tableMode_cell_with(v),
    CellFilterKind.withoutValue => l10n.tableMode_cell_without(v),
    CellFilterKind.noValue => l10n.tableMode_cell_noValue(column),
    CellFilterKind.anyValue => l10n.tableMode_cell_anyValue(column),
  };
}

/// Add filter: a default rule for the column (a relation asks for its row
/// first, as the builder's Add condition does), then the Refine panel with
/// that rule in its draft, on the Builder tab. Show applies; dismiss drops.
Future<void> _addColumnFilter(
  BuildContext context,
  WidgetRef ref,
  DiveField field,
) async {
  final spec = kDiveColumnFilters[field]!;
  final editor = readQueryEditorContext(context, ref, diveQueryEntity);
  final target = resolvePath(editor.registry, editor.root, spec.path);
  final op = opsFor(target).first;
  final QueryNode rule;
  final relation = target.terminalRelation;
  if (relation != null) {
    final strings = queryBuilderStringsOf(context.l10n);
    final picked = await showQueryRefPicker(
      context,
      editor: editor,
      kind: relation.target,
      title: strings.pickRef.replaceAll(
        '{name}',
        editor.labels.relation(relation),
      ),
      searchHint: strings.pickRefSearch,
    );
    if (picked == null || !context.mounted) return;
    rule = ConditionNode(spec.path, op, picked);
  } else {
    rule = ConditionNode(spec.path, op, defaultValueFor(target, op, editor));
  }
  await showRefinePanel(
    context,
    filterProvider: diveFilterProvider,
    initialDraft: addDiveTableRule(ref.read(diveFilterProvider), rule),
    startOnRulesBuilder: true,
  );
}
