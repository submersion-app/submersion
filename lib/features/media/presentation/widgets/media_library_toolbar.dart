import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// The library's control row: filter, sort, select, and view mode.
///
/// Every control is fixed-width, which is the point. The chip row this
/// replaced was an Expanded horizontal scroller that claimed all free width
/// and squeezed the view-mode selector beside it.
///
/// Fixed widths also mean the row has a hard budget, and grid mode already
/// spends nearly all of it: three icon buttons plus the view-mode selector.
/// At 320dp, the narrowest phone the app ships to, those three at default
/// density overflow by 16px, so they are `VisualDensity.compact` (matching
/// the dive media section's header), which reclaims 8dp each and leaves
/// roughly 8dp spare. A FOURTH icon button would overflow by about 32dp;
/// adding one means finding space elsewhere in the row, not just adding it.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);

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
        // their grouping rather than reorder it.
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
        if (canSelect)
          IconButton(
            key: const ValueKey('enter_selection'),
            icon: const Icon(Icons.checklist, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.common_selection_enterTooltip,
            onPressed: selection.enterExplicit,
          ),
        const Spacer(),
        SegmentedButton<MediaLibraryViewMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MediaLibraryViewMode.grid,
              icon: const Icon(Icons.grid_view),
              tooltip: l10n.media_library_viewMode_grid,
            ),
            ButtonSegment(
              value: MediaLibraryViewMode.byDive,
              icon: const Icon(Icons.scuba_diving),
              tooltip: l10n.media_library_viewMode_byDive,
            ),
            ButtonSegment(
              value: MediaLibraryViewMode.timeline,
              icon: const Icon(Icons.calendar_month),
              tooltip: l10n.media_library_viewMode_timeline,
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref
              .read(mediaLibraryViewModeProvider.notifier)
              .setMode(selection.single),
        ),
      ],
    );
  }
}
