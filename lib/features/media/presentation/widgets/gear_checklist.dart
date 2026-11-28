import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A searchable checklist of the diver's gear (issue #5046): the items in
/// [firstIds] under On this dive, then the rest by type. Shared by the
/// photo's gear sheet and the Library's bulk Link to gear.
///
/// Renders as slivers' worth of children for the caller's [ListView], so a
/// sheet keeps one scroll controller.
class GearChecklist extends ConsumerStatefulWidget {
  const GearChecklist({
    super.key,
    required this.chosen,
    required this.onToggle,
    this.firstIds = const {},
    this.title,
    this.scrollController,
  });

  /// The ids checked.
  final Set<String> chosen;

  /// Called with an item's id when its row is tapped; null reads only.
  final ValueChanged<String>? onToggle;

  /// Items listed first, under On this dive.
  final Set<String> firstIds;

  final String? title;
  final ScrollController? scrollController;

  @override
  ConsumerState<GearChecklist> createState() => _GearChecklistState();
}

class _GearChecklistState extends ConsumerState<GearChecklist> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all =
        ref.watch(allEquipmentProvider).value ?? const <EquipmentItem>[];
    final query = _query.trim().toLowerCase();
    bool matches(EquipmentItem g) =>
        query.isEmpty ||
        [
          g.name,
          g.brand,
          g.model,
        ].any((s) => s != null && s.toLowerCase().contains(query));
    final shown = [
      for (final g in all)
        if (matches(g)) g,
    ];
    final first = sortedByText([
      for (final g in shown)
        if (widget.firstIds.contains(g.id)) g,
    ], (g) => g.name);
    final byType = <EquipmentType, List<EquipmentItem>>{};
    for (final g in shown) {
      if (widget.firstIds.contains(g.id)) continue;
      byType.putIfAbsent(g.type, () => []).add(g);
    }

    Widget row(EquipmentItem g) => CheckboxListTile(
      key: ValueKey('gear_checklist_row_${g.id}'),
      value: widget.chosen.contains(g.id),
      onChanged: widget.onToggle == null ? null : (_) => widget.onToggle!(g.id),
      secondary: Icon(equipmentItemIcon(g)),
      title: Text(g.name, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle(g),
      controlAffinity: ListTileControlAffinity.trailing,
    );

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (widget.title case final title?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.media_gearSheet_search,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.media_gearSheet_empty),
          ),
        if (first.isNotEmpty) ...[
          header(l10n.media_gearSheet_onThisDive),
          for (final g in first) row(g),
        ],
        if (byType.isNotEmpty) ...[
          header(l10n.media_gearSheet_yourGear),
          for (final type in byType.keys.sortedByLocalizedName(l10n)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                type.localizedName(l10n),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final g in sortedByText(byType[type]!, (g) => g.name)) row(g),
          ],
        ],
      ],
    );
  }

  Widget? _subtitle(EquipmentItem g) {
    final parts = [
      g.brand,
      g.model,
    ].whereType<String>().where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? null : Text(parts.join(' '));
  }
}

/// Opens a checklist of the diver's gear and returns the ids picked, or
/// null when the diver backs out. For the bulk sheet's Add.
Future<Set<String>?> showGearChooser(BuildContext context) =>
    showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) =>
              _GearChooser(scrollController: controller),
        ),
      ),
    );

class _GearChooser extends StatefulWidget {
  const _GearChooser({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_GearChooser> createState() => _GearChooserState();
}

class _GearChooserState extends State<_GearChooser> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: GearChecklist(
            title: l10n.media_gearSheet_yourGear,
            chosen: _picked,
            scrollController: widget.scrollController,
            onToggle: (id) => setState(
              () => _picked.contains(id) ? _picked.remove(id) : _picked.add(id),
            ),
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('gear_chooser_add'),
                  onPressed: _picked.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(Set.of(_picked)),
                  child: Text(l10n.common_action_add),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
