import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width of the section list, and so of the menu: wide enough for the longest
/// section name beside its checkbox, icon and drag handle.
const double _kSectionListWidth = 340;

/// Height of one section row.
const double _kSectionRowHeight = 48;

/// Rows the section list shows before it scrolls.
const int _kVisibleSectionRows = 6;

/// The dive detail page's display-options dropdown.
///
/// Puts the page-shape choices where the page is -- which sections show, in
/// what order, and how much room each one gets -- instead of only under
/// Settings. All of them write to the same per-diver settings the Settings
/// page edits, so a choice made here is the choice made there.
///
/// Sections are listed in the diver's order and reordered by their drag
/// handles right here, which keeps the page's own section rows down to a
/// single tap target each. The last item routes to the settings page for the
/// same list with more room, and its reset to the default order.
class DiveDetailPropertiesMenu extends ConsumerWidget {
  const DiveDetailPropertiesMenu({super.key, required this.isGauge});

  /// Whether the dive is a gauge (bottom-timer) dive.
  ///
  /// Gauge dives never render the gas and decompression sections, so their
  /// toggles are left out rather than shown switched on with nothing behind
  /// them.
  final bool isGauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );
    final offered = [
      for (final section in sections)
        if (!(isGauge && section.id.hiddenInGaugeMode)) section,
    ];
    final offeredIds = [for (final section in offered) section.id];

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(_kSectionListWidth, 640)),
      ),
      menuChildren: [
        _MenuHeading(l10n.diveLog_detail_displayOptions_layout),
        for (final option in DiveDetailLayout.values)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              option == layout
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onPressed: () =>
                ref.read(settingsProvider.notifier).setDiveDetailLayout(option),
            child: Text(option.localizedName(l10n)),
          ),
        const Divider(height: 8),
        _MenuHeading(l10n.diveLog_detail_displayOptions_sections),
        // A fixed box rather than a shrink-wrapped list: the menu panel sizes
        // itself to its children's intrinsic width, which a scrollable cannot
        // report, and a list that scrolls on its own can auto-scroll while a
        // row is dragged past its edge.
        SizedBox(
          width: _kSectionListWidth,
          height:
              math.min(offered.length, _kVisibleSectionRows) *
              _kSectionRowHeight,
          child: ReorderableListView.builder(
            // The menu panel's own scroll view holds the primary controller;
            // a second vertical list must not attach to it too.
            primary: false,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemExtent: _kSectionRowHeight,
            itemCount: offered.length,
            itemBuilder: (context, index) => _SectionRow(
              key: ValueKey(offered[index].id),
              section: offered[index],
              index: index,
              onToggle: () => _toggle(ref, sections, offered[index]),
            ),
            onReorderItem: (oldIndex, newIndex) => ref
                .read(settingsProvider.notifier)
                .setDiveDetailSections(
                  DiveDetailSectionConfig.moveRenderedSection(
                    sections,
                    offeredIds,
                    oldIndex,
                    newIndex,
                  ),
                ),
          ),
        ),
        const Divider(height: 8),
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: const Icon(Icons.checklist),
          onPressed: offered.every((s) => s.visible)
              ? null
              : () => _showAll(ref, sections, offered),
          child: Text(l10n.diveLog_detail_displayOptions_showAll),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.reorder),
          onPressed: () => context.pushNamed('diveDetailSections'),
          child: Text(l10n.diveLog_detail_displayOptions_reorder),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.tune),
        tooltip: l10n.diveLog_detail_displayOptions_tooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  void _toggle(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    DiveDetailSectionConfig section,
  ) {
    final updated = [
      for (final s in sections)
        if (s.id == section.id) s.copyWith(visible: !s.visible) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }

  /// Turns every offered section back on, leaving the diver's order alone.
  ///
  /// Deliberately not `resetDiveDetailSections`, which would also throw away
  /// a custom order the diver never asked to undo. Only the sections the menu
  /// lists are touched: on a gauge dive the gas and deco sections are not
  /// shown here, so switching them on would be a change the diver could
  /// neither see nor expect, surfacing only on their next non-gauge dive.
  void _showAll(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    List<DiveDetailSectionConfig> offered,
  ) {
    final offeredIds = {for (final s in offered) s.id};
    final updated = [
      for (final s in sections)
        if (offeredIds.contains(s.id)) s.copyWith(visible: true) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }
}

/// One section's row: its visibility toggle with a drag handle alongside.
///
/// The handle sits outside the button so grabbing it never competes with the
/// tap that toggles the section; a missed grab must not flip visibility.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
  });

  final DiveDetailSectionConfig section;

  /// This row's index in the enclosing [ReorderableListView].
  final int index;

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              section.visible ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            trailingIcon: Icon(section.id.icon, size: 18),
            onPressed: onToggle,
            child: Text(section.id.localizedDisplayName(context.l10n)),
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A non-interactive group label between runs of menu items.
class _MenuHeading extends StatelessWidget {
  const _MenuHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
