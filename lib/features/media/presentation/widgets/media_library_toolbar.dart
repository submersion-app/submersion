import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// Horizontal density that narrows each view-mode segment from 64dp to
/// 48dp, still a full 48 x 48 touch target. SegmentedButton ignores a
/// segment's padding and minimum size here; only density moves the width.
const VisualDensity _kSegmentDensity = VisualDensity(horizontal: -4);

/// Narrowest row width at which the four view-mode segments fit beside the
/// three compact icon buttons with 8dp to spare. Measured at 1x on the
/// default Material 3 theme with a throwaway test: 40dp per compact icon
/// button and 192dp for four segments at [_kSegmentDensity], so
/// 3 x 40 + 192 + 8. MediaLibraryView pads the row by 8dp each side, so
/// phones 336dp and wider keep the segments and only the 320dp class
/// collapses to [_ViewModeMenuButton]. Re-measure if the theme's button
/// metrics change.
const double kMediaToolbarFourSegmentMinWidth = 320;

/// The library's control row: filter, sort, select, and view mode.
///
/// Every control is fixed-width, which is the point. The chip row this
/// replaced was an Expanded horizontal scroller that claimed all free width
/// and squeezed the view-mode selector beside it.
///
/// Fixed widths also mean the row has a hard budget. The fourth view mode
/// (map) pushed the segmented button past what 320dp can hold next to the
/// three compact icon buttons, so the row measures itself: with room, four
/// segments; without, one menu button showing the current mode's icon, the
/// way the dive list picks its view mode.
class MediaLibraryToolbar extends ConsumerWidget {
  const MediaLibraryToolbar({
    super.key,
    required this.selection,
    required this.canSelect,
  });

  /// The library's selection state machine. The Select control is the only
  /// way into multi-select: long-press enters selection nowhere in the app.
  final SelectionController selection;

  /// Whether there is anything to select. An empty library hides the control
  /// rather than offering a mode with no items in it.
  final bool canSelect;

  static IconData iconFor(MediaLibraryViewMode mode) => switch (mode) {
    MediaLibraryViewMode.grid => Icons.grid_view,
    MediaLibraryViewMode.byDive => Icons.scuba_diving,
    MediaLibraryViewMode.timeline => Icons.calendar_month,
    MediaLibraryViewMode.map => Icons.map,
  };

  static String labelFor(MediaLibraryViewMode mode, AppLocalizations l10n) =>
      switch (mode) {
        MediaLibraryViewMode.grid => l10n.media_library_viewMode_grid,
        MediaLibraryViewMode.byDive => l10n.media_library_viewMode_byDive,
        MediaLibraryViewMode.timeline => l10n.media_library_viewMode_timeline,
        MediaLibraryViewMode.map => l10n.media_library_viewMode_map,
      };

  void _setMode(WidgetRef ref, MediaLibraryViewMode next) {
    // Map mode has no multi-select; leaving a selection half-open under a
    // surface that cannot show it would strand the selection bar.
    if (next == MediaLibraryViewMode.map && selection.value.isActive) {
      selection.exit();
    }
    ref.read(mediaLibraryViewModeProvider.notifier).setMode(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactModes =
            constraints.maxWidth < kMediaToolbarFourSegmentMinWidth;
        return Row(
          children: [
            IconButton(
              icon: Badge(
                isLabelVisible: !filter.isEmpty,
                child: const Icon(Icons.filter_list, size: 20),
              ),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.media_library_filter_title,
              onPressed: () => showMediaLibraryFilterSheet(context),
            ),
            // Grid only: the by-dive and timeline groupers consume an
            // already-date-sorted stream, so a name or size sort would break
            // their grouping rather than reorder it, and the map has no order.
            if (mode == MediaLibraryViewMode.grid)
              IconButton(
                icon: const Icon(Icons.sort, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.media_library_sort_title,
                onPressed: () {
                  final sort = ref.read(mediaLibrarySortProvider);
                  showSortBottomSheet<MediaSortField>(
                    context: context,
                    title: l10n.media_library_sort_title,
                    currentField: sort.field,
                    currentDirection: sort.direction,
                    fields: MediaSortField.values,
                    getFieldDisplayName: (field) => field.localizedName(l10n),
                    getFieldIcon: (field) => field.icon,
                    onSortChanged: (field, direction) => ref
                        .read(mediaLibrarySortProvider.notifier)
                        .setSort(field, direction),
                  );
                },
              ),
            // The map cannot show a selection, so it does not offer one.
            if (canSelect && mode != MediaLibraryViewMode.map)
              IconButton(
                key: const ValueKey('enter_selection'),
                icon: const Icon(Icons.checklist, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.common_selection_enterTooltip,
                onPressed: selection.enterExplicit,
              ),
            const Spacer(),
            if (compactModes)
              _ViewModeMenuButton(
                current: mode,
                onChanged: (next) => _setMode(ref, next),
              )
            else
              SegmentedButton<MediaLibraryViewMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: _kSegmentDensity,
                ),
                segments: [
                  for (final m in MediaLibraryViewMode.values)
                    ButtonSegment(
                      value: m,
                      icon: Icon(iconFor(m)),
                      tooltip: labelFor(m, l10n),
                    ),
                ],
                selected: {mode},
                onSelectionChanged: (chosen) => _setMode(ref, chosen.single),
              ),
          ],
        );
      },
    );
  }
}

/// The narrow-width view-mode picker: the current mode's icon, opening a
/// menu of all four. Mirrors `ListViewModeToggle`.
class _ViewModeMenuButton extends StatelessWidget {
  const _ViewModeMenuButton({required this.current, required this.onChanged});

  final MediaLibraryViewMode current;
  final ValueChanged<MediaLibraryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<MediaLibraryViewMode>(
      icon: Icon(MediaLibraryToolbar.iconFor(current), size: 20),
      tooltip: MediaLibraryToolbar.labelFor(current, l10n),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final m in MediaLibraryViewMode.values)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(
                  MediaLibraryToolbar.iconFor(m),
                  size: 20,
                  color: m == current ? primary : null,
                ),
                const SizedBox(width: 12),
                Text(
                  MediaLibraryToolbar.labelFor(m, l10n),
                  style: m == current
                      ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
