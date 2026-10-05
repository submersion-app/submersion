import 'package:flutter/material.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Height of [MediaViewerToolbar]'s content below the status bar: its 8 px
/// vertical padding either side of a default 48 px [IconButton]. The Perdix
/// overlay reserves this band so the face can never sit on top of the
/// toolbar's buttons; keep the two in step if the padding changes.
const double kMediaViewerToolbarHeight = 64;

/// Width of one toolbar icon button (the default [IconButton] extent).
const double kToolbarButtonExtent = 48;

/// Room kept for the "12 / 345" page indicator before any action icon, at
/// 1x text; scaled with the diver's text size so large text is not clipped.
const double _indicatorMinWidth = 72;

/// One toolbar action, described as data so the toolbar can show it as an
/// icon or move it into the overflow menu without knowing what it does.
@immutable
class MediaViewerAction {
  const MediaViewerAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.priority,
    required this.onPressed,
    this.iconColor,
  });

  /// Stable id; also names the widget key (`viewer_<id>`).
  final String id;
  final IconData icon;

  /// Tooltip on the icon, and the text of its overflow-menu entry.
  final String label;

  /// Lower stays visible longer when the toolbar runs out of room.
  final int priority;

  /// Receives the context of whatever was tapped (the icon, or the overflow
  /// button when picked from the menu) for anchoring popovers and menus.
  final void Function(BuildContext anchorContext) onPressed;

  /// Tint for state (the Perdix toggle when on); null uses the default.
  final Color? iconColor;
}

/// The result of [splitToolbarActions]: both lists in toolbar order.
@immutable
class ToolbarActionSplit {
  const ToolbarActionSplit(this.visible, this.overflow);

  final List<MediaViewerAction> visible;
  final List<MediaViewerAction> overflow;
}

/// Splits [actions] (in toolbar order) into the icons that fit in
/// [availableWidth] and the rest. When everything fits there is no menu;
/// otherwise one slot goes to the overflow button and the remaining slots go
/// to the lowest [MediaViewerAction.priority] values.
ToolbarActionSplit splitToolbarActions(
  List<MediaViewerAction> actions,
  double availableWidth,
) {
  if (actions.length * kToolbarButtonExtent <= availableWidth) {
    return ToolbarActionSplit(List.unmodifiable(actions), const []);
  }
  final slots = ((availableWidth - kToolbarButtonExtent) / kToolbarButtonExtent)
      .floor()
      .clamp(0, actions.length);
  final keep = (List.of(
    actions,
  )..sort((a, b) => a.priority.compareTo(b.priority))).take(slots).toSet();
  return ToolbarActionSplit(
    List.unmodifiable(actions.where(keep.contains)),
    List.unmodifiable(actions.where((a) => !keep.contains(a))),
  );
}

/// The viewer's top bar: close, fullscreen, the page indicator, and the
/// actions, with whatever does not fit in an overflow menu. A [Positioned],
/// so it goes straight into the viewer's [Stack].
class MediaViewerToolbar extends StatelessWidget {
  const MediaViewerToolbar({
    super.key,
    required this.item,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onEnterFullscreen,
    required this.onShare,
    required this.onShowInfo,
    required this.onWriteMetadata,
    required this.onTagSpecies,
    required this.canWriteMetadata,
    required this.showPerdixToggle,
    required this.perdixEnabled,
    required this.onTogglePerdix,
    this.onOpenInLightroom,
    this.onGoToDive,
    this.onReupload,
  });

  final MediaItem item;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onEnterFullscreen;
  final void Function(Rect? anchor) onShare;
  final VoidCallback onShowInfo;
  final VoidCallback onWriteMetadata;
  final VoidCallback onTagSpecies;

  /// Whether the write-dive-data action is offered. Needs enrichment depth to
  /// have anything to write, and a photo to write it to: videos cannot be
  /// edited in place, and replacing one would destroy the original
  /// (issue #1472).
  final bool canWriteMetadata;

  /// Whether the Perdix overlay toggle is shown (media synced to a profile).
  final bool showPerdixToggle;

  /// Whether the Perdix overlay is currently enabled (tints the icon).
  final bool perdixEnabled;
  final VoidCallback onTogglePerdix;

  /// Non-null only for Lightroom-linked items on the connected device.
  final VoidCallback? onOpenInLightroom;

  /// Non-null when the viewer is cross-dive and the item has a dive link.
  final VoidCallback? onGoToDive;

  /// Non-null when a media store is connected on this device.
  final void Function(BuildContext anchorContext)? onReupload;

  List<MediaViewerAction> _actions(BuildContext context) {
    final l10n = context.l10n;
    return [
      if (onGoToDive != null)
        MediaViewerAction(
          id: 'go_to_dive',
          icon: Icons.scuba_diving,
          label: l10n.media_viewer_goToDive,
          priority: 0,
          onPressed: (_) => onGoToDive!(),
        ),
      if (canWriteMetadata)
        MediaViewerAction(
          id: 'write_metadata',
          icon: Icons.edit_note,
          label: l10n.media_photoViewer_writeDiveDataTooltip,
          priority: 5,
          onPressed: (_) => onWriteMetadata(),
        ),
      if (showPerdixToggle)
        MediaViewerAction(
          id: 'perdix',
          icon: Icons.watch,
          label: l10n.media_perdixOverlay_toggleTooltip,
          priority: 3,
          iconColor: perdixEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
          onPressed: (_) => onTogglePerdix(),
        ),
      if (onOpenInLightroom != null)
        MediaViewerAction(
          id: 'lightroom',
          icon: Icons.open_in_new,
          label: l10n.media_lightroom_openInLightroom,
          priority: 6,
          onPressed: (_) => onOpenInLightroom!(),
        ),
      MediaViewerAction(
        id: 'species',
        icon: Icons.sell_outlined,
        label: l10n.media_species_actionTooltip,
        priority: 4,
        onPressed: (_) => onTagSpecies(),
      ),
      MediaViewerAction(
        id: 'info',
        icon: Icons.info_outline,
        label: l10n.media_info_title,
        priority: 2,
        onPressed: (_) => onShowInfo(),
      ),
      MediaViewerAction(
        id: 'share',
        icon: Icons.share,
        label: l10n.media_photoViewer_shareTooltip,
        priority: 1,
        // The anchor is the tapped button's context, so the iPad popover
        // points at it (or at the overflow button when shared from the menu).
        onPressed: (anchor) => onShare(shareAnchorFrom(anchor)),
      ),
      if (onReupload != null)
        MediaViewerAction(
          id: 'reupload',
          icon: Icons.tune,
          label: l10n.settings_mediaStorage_quality_section,
          priority: 7,
          onPressed: (anchor) => onReupload!(anchor),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = _actions(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final split = splitToolbarActions(
                  actions,
                  constraints.maxWidth -
                      2 * kToolbarButtonExtent -
                      MediaQuery.textScalerOf(
                        context,
                      ).scale(_indicatorMinWidth),
                );
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: l10n.media_photoViewer_closeTooltip,
                      onPressed: onClose,
                    ),
                    IconButton(
                      key: const ValueKey('viewer_enter_fullscreen'),
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      tooltip: l10n.media_viewer_enterFullscreen,
                      onPressed: onEnterFullscreen,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.media_photoViewer_pageIndicator(
                            currentIndex + 1,
                            totalCount,
                          ),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    for (final action in split.visible)
                      // Builder so the anchor context is the button itself:
                      // findRenderObject from it descends to the IconButton.
                      Builder(
                        key: ValueKey('viewer_${action.id}'),
                        builder: (anchor) => IconButton(
                          icon: Icon(
                            action.icon,
                            color: action.iconColor ?? Colors.white,
                          ),
                          tooltip: action.label,
                          onPressed: () => action.onPressed(anchor),
                        ),
                      ),
                    if (split.overflow.isNotEmpty)
                      Builder(
                        builder: (anchor) => PopupMenuButton<MediaViewerAction>(
                          key: const ValueKey('viewer_overflow'),
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          tooltip: l10n.media_viewer_moreOptions,
                          onSelected: (action) => action.onPressed(anchor),
                          itemBuilder: (_) => [
                            for (final action in split.overflow)
                              PopupMenuItem<MediaViewerAction>(
                                key: ValueKey('viewer_menu_${action.id}'),
                                value: action,
                                child: Row(
                                  children: [
                                    Icon(action.icon, color: action.iconColor),
                                    const SizedBox(width: 12),
                                    Flexible(child: Text(action.label)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
