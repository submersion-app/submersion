import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_fold_summary.dart';
import 'package:submersion/features/equipment/presentation/utils/picker_group_folds.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_type_fold_header.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One type's gear in a checkbox list; a null type is gear listed with no
/// heading (type grouping off).
typedef EquipmentTypeGroupRows = (EquipmentType?, List<EquipmentItem>);

/// The groups a checkbox list of gear opens with (issue #3364): see
/// [initialOpenPickerGroups]. Untyped groups have no heading and never fold.
Set<String> initialOpenTypeGroups(
  List<EquipmentTypeGroupRows> groups,
  Set<String> ticked,
) => initialOpenPickerGroups({
  for (final (type, items) in groups)
    if (type != null) typeFoldKey(type): items.map((e) => e.id),
}, ticked);

/// The fold state of a checkbox list of gear (issue #3364): which type
/// groups are open, worked out once and never saved.
mixin FoldableTypeGroupsState<T extends StatefulWidget> on State<T> {
  /// Null until [ensureOpenTypeGroups] works it out; every group shows open
  /// until then.
  Set<String>? openTypeGroups;

  /// The type groups on screen, so a tap before the open set is worked out
  /// starts from every group open, as drawn.
  Set<String> _shownTypeGroups = const {};

  /// Works out the groups to open, once, when [ready] and there is gear.
  /// Call it on every build.
  void ensureOpenTypeGroups(
    List<EquipmentTypeGroupRows> groups,
    Set<String> ticked, {
    bool ready = true,
  }) {
    _shownTypeGroups = {
      for (final (type, _) in groups)
        if (type != null) typeFoldKey(type),
    };
    if (openTypeGroups != null || groups.isEmpty || !ready) return;
    openTypeGroups = initialOpenTypeGroups(groups, ticked);
  }

  /// Folds or opens one group. A tap before the open set is worked out is
  /// the diver's own choice, so the initial rule no longer applies.
  void toggleTypeGroup(String foldKey) => setState(
    () => openTypeGroups = toggleOpenKey(
      openTypeGroups ?? _shownTypeGroups,
      foldKey,
    ),
  );
}

/// The rows of a checkbox list of gear whose type groups fold (issue
/// #3364): each type's heading, then its rows while it is open. A folded
/// heading holding ticked items says "N of M selected", so a tick is never
/// hidden without a trace. A null [open] shows every group open. Used by
/// the add-component sheet and the equipment set editor.
List<Widget> foldableTypeGroupRows(
  BuildContext context, {
  required List<EquipmentTypeGroupRows> groups,
  required Set<String>? open,
  required Set<String> ticked,
  required void Function(String foldKey) onToggle,
  required Widget Function(EquipmentItem item) rowBuilder,
}) {
  final l10n = context.l10n;
  bool isOpen(String key) => open?.contains(key) ?? true;
  return [
    for (final (type, items) in groups)
      if (type == null)
        for (final item in items) rowBuilder(item)
      else ...[
        EquipmentTypeFoldHeader(
          foldKey: typeFoldKey(type),
          type: type,
          count: items.length,
          isExpanded: isOpen(typeFoldKey(type)),
          onTap: () => onToggle(typeFoldKey(type)),
          summary: isOpen(typeFoldKey(type))
              ? null
              : foldedTickSummary(l10n, items.map((e) => e.id), ticked),
        ),
        if (isOpen(typeFoldKey(type)))
          for (final item in items) rowBuilder(item),
      ],
  ];
}
