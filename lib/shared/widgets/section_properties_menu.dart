import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width of the section list, and so of the menu: wide enough for the longest
/// section name beside its checkbox, icon and drag handle.
const double _kSectionListWidth = 340;

/// Height of one section row.
const double _kSectionRowHeight = 48;

/// Rows the section list shows before it scrolls.
const int _kVisibleSectionRows = 6;

/// One section as a [SectionPropertiesMenu] lists it.
class SectionMenuEntry {
  const SectionMenuEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.visible,
  });

  /// Identifies the row across rebuilds and reorders (a section id enum).
  final Object id;

  /// The section's localized name.
  final String label;

  /// The section's icon, shown trailing the name.
  final IconData icon;

  /// Whether the section is switched on.
  final bool visible;
}

/// A detail page's display-options panel: its layout, which sections show,
/// and in what order.
///
/// Shared by Dive Details and Site Details, where it opens from the page's
/// overflow menu: the page wraps its overflow button in this widget as
/// [child], lists [displayOptionsMenuItem] among the overflow items, and
/// opens [controller] when that item is chosen. The panel then drops down
/// under the overflow button the diver just used.
///
/// It holds no settings of its own: each page's wrapper decides which
/// sections to offer and where each choice is written, so the two pages store
/// their configurations separately while presenting them identically.
///
/// Sections are reordered by their drag handles right here, which keeps a
/// page's own section rows down to a single tap target each. The last item
/// opens the page's settings screen for the same list with more room, and
/// its reset to the default order.
class SectionPropertiesMenu extends StatelessWidget {
  const SectionPropertiesMenu({
    super.key,
    required this.layout,
    required this.onLayoutChanged,
    required this.entries,
    required this.onToggle,
    required this.onReorder,
    required this.onShowAll,
    required this.onOpenSettings,
    required this.controller,
    required this.child,
  });

  /// The page's current layout, shown as the checked radio item.
  final DiveDetailLayout layout;

  final ValueChanged<DiveDetailLayout> onLayoutChanged;

  /// The sections offered, in the diver's order.
  final List<SectionMenuEntry> entries;

  /// Called with the index in [entries] of the section tapped.
  final ValueChanged<int> onToggle;

  /// Called with indices into [entries], as
  /// [ReorderableListView.onReorderItem] reports them.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Turns every offered section on. The item is disabled while every entry
  /// is already visible.
  final VoidCallback onShowAll;

  /// Opens the page's section settings screen.
  final VoidCallback onOpenSettings;

  /// Opens and closes the panel; owned by the page so its overflow menu can
  /// open the panel.
  final MenuController controller;

  /// The widget the panel drops down from: the page's overflow button.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MenuAnchor(
      controller: controller,
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
            onPressed: () => onLayoutChanged(option),
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
              math.min(entries.length, _kVisibleSectionRows) *
              _kSectionRowHeight,
          child: ReorderableListView.builder(
            // The menu panel's own scroll view holds the primary controller;
            // a second vertical list must not attach to it too.
            primary: false,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemExtent: _kSectionRowHeight,
            itemCount: entries.length,
            itemBuilder: (context, index) => _SectionRow(
              key: ValueKey<Object>(entries[index].id),
              entry: entries[index],
              index: index,
              onToggle: () => onToggle(index),
            ),
            onReorderItem: onReorder,
          ),
        ),
        const Divider(height: 8),
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: const Icon(Icons.checklist),
          onPressed: entries.every((e) => e.visible) ? null : onShowAll,
          child: Text(l10n.diveLog_detail_displayOptions_showAll),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.reorder),
          onPressed: onOpenSettings,
          child: Text(l10n.diveLog_detail_displayOptions_reorder),
        ),
      ],
      child: child,
    );
  }
}

/// The overflow-menu row that opens a [SectionPropertiesMenu].
PopupMenuItem<T> displayOptionsMenuItem<T>(BuildContext context, T value) {
  return PopupMenuItem<T>(
    value: value,
    child: ListTile(
      leading: const Icon(Icons.dashboard_customize_outlined),
      title: Text(context.l10n.diveLog_detail_displayOptions_tooltip),
      contentPadding: EdgeInsets.zero,
    ),
  );
}

/// One section's row: its visibility toggle with a drag handle alongside.
///
/// The handle sits outside the button so grabbing it never competes with the
/// tap that toggles the section; a missed grab must not flip visibility.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.entry,
    required this.index,
    required this.onToggle,
  });

  final SectionMenuEntry entry;

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
              entry.visible ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            trailingIcon: Icon(entry.icon, size: 18),
            onPressed: onToggle,
            child: Text(entry.label),
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
