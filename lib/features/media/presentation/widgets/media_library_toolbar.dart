import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// Horizontal density that narrows each view-mode segment from 64dp to
/// 48dp, still a full 48 x 48 touch target. SegmentedButton ignores a
/// segment's padding and minimum size here; only density moves the width.
const VisualDensity _kSegmentDensity = VisualDensity(horizontal: -4);

/// Width of one compact icon button: filter, sort, select and, on rows too
/// narrow for the slider, thumbnail size.
const double _kCompactIconButtonWidth = 40;

/// Width of the four view-mode segments at [_kSegmentDensity].
const double _kFourSegmentWidth = 192;

/// Narrowest row width at which the four view-mode segments fit beside the
/// four compact icon buttons. Measured at 1x on the default Material 3
/// theme with a throwaway test: 40dp per compact icon button and 192dp for
/// four segments at [_kSegmentDensity], so 4 x 40 + 192 with nothing to
/// spare (issue #3398). MediaLibraryView pads the row by 8dp each side, so
/// phones 368dp and wider (a 375dp iPhone hands the row 359dp) keep the
/// segments, and narrower ones collapse to [_ViewModeMenuButton].
/// Re-measure if the theme's button metrics change.
const double kMediaToolbarFourSegmentMinWidth =
    4 * _kCompactIconButtonWidth + _kFourSegmentWidth;

/// Width of the inline thumbnail size slider: seven stops about 16dp apart
/// once the slider's own 24dp of padding at each end is taken off.
const double _kThumbnailSliderWidth = 140;

/// Width of the slider in the thumbnail size menu: wider than the inline
/// one, so the stops are easier to hit with a thumb.
const double _kThumbnailMenuSliderWidth = 240;

/// Narrowest row that holds the inline thumbnail size slider (issue #3297):
/// three icon buttons, the four segments, the slider, and 8dp to spare.
/// Below it the slider moves behind [_ThumbnailSizeButton] (issue #3398).
const double kMediaToolbarThumbnailSliderMinWidth =
    3 * _kCompactIconButtonWidth +
    _kFourSegmentWidth +
    _kThumbnailSliderWidth +
    8;

/// The library's control row: filter, sort, select, thumbnail size, and
/// view mode.
///
/// Every control is fixed-width, which is the point. The chip row this
/// replaced was an Expanded horizontal scroller that claimed all free width
/// and squeezed the view-mode selector beside it.
///
/// Fixed widths also mean the row has a hard budget. Four segments beside
/// four compact icon buttons need [kMediaToolbarFourSegmentMinWidth], so
/// the row measures itself: with room, four segments; without, one menu
/// button showing the current mode's icon, the way the dive list picks its
/// view mode. The threshold ignores which buttons the current mode shows,
/// so switching modes never reshapes the view-mode control.
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
        // The map has no thumbnail grid to size.
        final sizable = mode != MediaLibraryViewMode.map;
        final inlineSlider =
            constraints.maxWidth >= kMediaToolbarThumbnailSliderMinWidth;
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
            if (sizable && inlineSlider)
              const _ThumbnailSizeSlider(width: _kThumbnailSliderWidth),
            if (sizable && !inlineSlider) const _ThumbnailSizeButton(),
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

/// Seven stops from the smallest thumbnails to two across (issue #3297).
class _ThumbnailSizeSlider extends ConsumerWidget {
  const _ThumbnailSizeSlider({required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final step = ref.watch(mediaThumbnailScaleProvider.select((s) => s.step));
    return Tooltip(
      message: l10n.media_library_thumbnailSize,
      // The Semantics label below already names the slider; announcing the
      // tooltip too would read it twice.
      excludeFromSemantics: true,
      child: SizedBox(
        width: width,
        child: Semantics(
          label: l10n.media_library_thumbnailSize,
          child: Slider(
            key: const ValueKey('thumbnail_size_slider'),
            value: step.toDouble(),
            max: kMediaThumbnailSteps - 1,
            divisions: kMediaThumbnailSteps - 1,
            onChanged: (value) => ref
                .read(mediaThumbnailScaleProvider.notifier)
                .setStep(value.round()),
          ),
        ),
      ),
    );
  }
}

/// The narrow-width thumbnail size control (issue #3398): a compact icon
/// button opening a menu that holds the slider, for rows with no room for
/// the slider itself.
class _ThumbnailSizeButton extends StatelessWidget {
  const _ThumbnailSizeButton();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: _ThumbnailSizeSlider(width: _kThumbnailMenuSliderWidth),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('thumbnail_size_button'),
        icon: const Icon(Icons.photo_size_select_large, size: 20),
        visualDensity: VisualDensity.compact,
        tooltip: l10n.media_library_thumbnailSize,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
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
