import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/core/icons/mdi_icons.dart';

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

/// A progress ring round a toolbar icon (issue #4825): filled to [value],
/// or spinning when it is null.
@immutable
class ToolbarRing {
  const ToolbarRing([this.value]);

  final double? value;
}

/// A state colour for a toolbar icon (issue #4926), named for what it means
/// rather than given as a colour, so it is drawn in one that reads on the
/// surface under it: the viewer's dark bar, the pale editing bar, or the
/// overflow menu.
enum ToolbarTone {
  /// Work under way: the theme's primary colour.
  active,

  /// Started but not finished: amber.
  warn,

  /// Done: green.
  ok,
}

/// The colour [tone] is drawn in, [onDarkBar] when on the viewer's own bar,
/// which is dark over any photo in either theme; null for no tone.
Color? toolbarToneColor(
  BuildContext context,
  ToolbarTone? tone, {
  required bool onDarkBar,
}) {
  if (tone == null) return null;
  final palette = onDarkBar ? StatusColors.dark : StatusColors.of(context);
  return switch (tone) {
    ToolbarTone.active => Theme.of(context).colorScheme.primary,
    ToolbarTone.warn => palette.warn.accent,
    ToolbarTone.ok => palette.ok.accent,
  };
}

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
    this.tone,
    this.disabledReason,
    this.ring,
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

  /// A state the icon is tinted for, in colours that suit where it is
  /// drawn; [iconColor], when set, wins.
  final ToolbarTone? tone;

  /// Why the action cannot be used now; non-null draws it disabled, with
  /// this as its tooltip and as a line under it in the overflow menu.
  final String? disabledReason;

  /// Work under way, drawn round the icon when it is on the bar.
  final ToolbarRing? ring;
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

/// The room the editing bar gives its actions in a bar [width] wide:
/// Cancel, Save and the title keep about 240 px, and the actions take what
/// is left, up to half the bar, so a phone still reads the title. Never
/// less than one button, which holds the overflow menu.
double editBarActionsWidth(double width) =>
    math.max(kToolbarButtonExtent, math.min(width - 240, width / 2));

/// What the toolbar draws while the photo is unlocked (issue #4527): the
/// shared editing bar, with Cancel, [title] and Save.
@immutable
class MediaViewerEditBar {
  const MediaViewerEditBar({
    required this.title,
    required this.canSave,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
}

/// The viewer's top bar: close, fullscreen, the page indicator, and the
/// actions, with whatever does not fit in an overflow menu. A [Positioned],
/// so it goes straight into the viewer's [Stack].
class MediaViewerToolbar extends ConsumerWidget {
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
    this.onTagPeople,
    this.peopleTaggingActive = false,
    required this.canWriteMetadata,
    required this.showPerdixToggle,
    required this.perdixEnabled,
    required this.onTogglePerdix,
    this.onOpenInLightroom,
    this.onGoToDive,
    this.onReupload,
    this.onAdjustColor,
    this.onUnlock,
    this.writeControls = true,
    this.writeMetadataDisabledReason,
    this.editBar,
    this.onMarineLifeLabels,
    this.marineLifeLabelsOn = true,
    this.marineLifeRing,
    this.marineLifeTone,
    this.marineLifeLabel,
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

  /// Turns people tag mode on or off (issue #1745); null hides the action.
  final VoidCallback? onTagPeople;

  /// Whether people tag mode is on (tints the icon).
  final bool peopleTaggingActive;

  /// Whether the write-dive-data action is offered. Needs enrichment depth to
  /// have anything to write, and a photo in a device library to write it to:
  /// videos cannot be edited in place, and replacing one would destroy the
  /// original (issue #1472), and media outside a library has no original to
  /// edit (issue #3808).
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

  /// Opens the Adjust color panel (issue #3520); null hides the action.
  final VoidCallback? onAdjustColor;

  /// Unlocks the photo for editing (issue #4527); null offers no lock.
  final VoidCallback? onUnlock;

  /// Whether the actions that change the photo (species, people, adjust
  /// colour) are offered: false while the photo is locked.
  final bool writeControls;

  /// Why writing dive data to the photo cannot be used now, which draws it
  /// disabled; null leaves it as [canWriteMetadata] says.
  final String? writeMetadataDisabledReason;

  /// Non-null while the photo is unlocked: the toolbar is drawn as the
  /// shared editing bar, with the actions inside it.
  final MediaViewerEditBar? editBar;

  /// Opens the marine life labels menu (issue #4825), anchored to what was
  /// tapped; null hides the action.
  final void Function(BuildContext anchor)? onMarineLifeLabels;

  /// Whether labels are drawn: a fish when they are, a struck fish when
  /// they are off (issue #4926).
  final bool marineLifeLabelsOn;

  /// How far analysis of the item on screen has got, as the labels icon's
  /// colour (issue #4926); null leaves it plain.
  final ToolbarTone? marineLifeTone;

  /// The item on screen is being analysed: a ring round the labels icon.
  final ToolbarRing? marineLifeRing;

  /// The labels action's tooltip and overflow-menu text, naming how far
  /// analysis has got (issue #4958); null uses the action's plain name.
  final String? marineLifeLabel;

  /// [readOnly] drops every action that changes the media or its links:
  /// a browser views and shares, and nothing more (issue #4121).
  List<MediaViewerAction> _actions(
    BuildContext context, {
    required bool readOnly,
  }) {
    final l10n = context.l10n;
    final writes = writeControls && !readOnly;
    return [
      if (onUnlock != null && !readOnly && editBar == null)
        MediaViewerAction(
          id: 'unlock',
          icon: Icons.lock_outline,
          label: l10n.recordEdit_unlockTooltip,
          // Ahead of everything, so a phone always shows the way in.
          priority: -1,
          onPressed: (_) => onUnlock!(),
        ),
      if (onGoToDive != null)
        MediaViewerAction(
          id: 'go_to_dive',
          icon: Icons.scuba_diving,
          label: l10n.media_viewer_goToDive,
          priority: 0,
          onPressed: (_) => onGoToDive!(),
        ),
      if (canWriteMetadata && !readOnly)
        MediaViewerAction(
          id: 'write_metadata',
          icon: Icons.edit_note,
          label: l10n.media_photoViewer_writeDiveDataTooltip,
          priority: 7,
          disabledReason: writeMetadataDisabledReason,
          onPressed: (_) => onWriteMetadata(),
        ),
      if (showPerdixToggle)
        MediaViewerAction(
          id: 'perdix',
          icon: Icons.watch,
          label: l10n.media_perdixOverlay_toggleTooltip,
          priority: 4,
          iconColor: perdixEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
          onPressed: (_) => onTogglePerdix(),
        ),
      if (onOpenInLightroom != null && !readOnly)
        MediaViewerAction(
          id: 'lightroom',
          icon: Icons.open_in_new,
          label: l10n.media_lightroom_openInLightroom,
          priority: 8,
          onPressed: (_) => onOpenInLightroom!(),
        ),
      if (writes)
        MediaViewerAction(
          id: 'species',
          icon: Icons.sell_outlined,
          label: l10n.media_species_actionTooltip,
          priority: 5,
          onPressed: (_) => onTagSpecies(),
        ),
      if (onTagPeople != null && writes)
        MediaViewerAction(
          id: 'people',
          icon: Icons.person_add_alt_1,
          label: l10n.media_people_actionTooltip,
          // After Adjust color: on a narrow phone it moves to the overflow
          // menu rather than displacing an existing action.
          priority: 7,
          iconColor: peopleTaggingActive
              ? Theme.of(context).colorScheme.primary
              : null,
          onPressed: (_) => onTagPeople!(),
        ),
      // Just before Info, with the rank Info had: on a phone it takes
      // Info's place on the bar (issue #4825).
      if (onMarineLifeLabels != null)
        MediaViewerAction(
          id: 'marine_life_labels',
          icon: marineLifeLabelsOn ? MdiIcons.fish : MdiIcons.fishOff,
          label: marineLifeLabel ?? l10n.media_labels_action,
          priority: 2,
          tone: marineLifeTone,
          ring: marineLifeRing,
          onPressed: (anchor) => onMarineLifeLabels!(anchor),
        ),
      MediaViewerAction(
        id: 'info',
        icon: Icons.info_outline,
        label: l10n.media_info_title,
        priority: 3,
        onPressed: (_) => onShowInfo(),
      ),
      if (onAdjustColor != null && writes)
        MediaViewerAction(
          id: 'adjust_color',
          icon: Icons.palette_outlined,
          label: l10n.media_color_adjustAction,
          // After the existing actions, so a phone keeps showing the ones
          // it showed before this was added (issue #3520).
          priority: 6,
          onPressed: (_) => onAdjustColor!(),
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
      if (onReupload != null && !readOnly)
        MediaViewerAction(
          id: 'reupload',
          icon: Icons.tune,
          label: l10n.settings_mediaStorage_quality_section,
          priority: 9,
          onPressed: (anchor) => onReupload!(anchor),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = _actions(
      context,
      readOnly: !ref.watch(deviceCapabilitiesProvider).mediaAttach,
    );
    final bar = editBar;
    if (bar != null) return _editingBar(context, bar, actions);
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
                    ...toolbarActionButtons(
                      context,
                      split,
                      Colors.white,
                      onDarkBar: true,
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

  /// The shared editing bar in the toolbar's band, so the photo under it
  /// does not move on unlock. Its pale tint brings its own foreground: the
  /// actions take it rather than the dark viewer's white.
  Widget _editingBar(
    BuildContext context,
    MediaViewerEditBar bar,
    List<MediaViewerAction> actions,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.paddingOf(context).top + kMediaViewerToolbarHeight,
      // A semantics container of its own, so the bar's nodes do not mix
      // with the viewer's full-screen tap target under it.
      child: Semantics(
        container: true,
        // The bar's own width: Adjust color docked beside the viewer takes
        // part of the window.
        child: LayoutBuilder(
          builder: (context, constraints) => RecordEditBar(
            title: bar.title,
            canSave: bar.canSave,
            isSaving: bar.isSaving,
            onCancel: bar.onCancel,
            onSave: bar.onSave,
            actions: toolbarActionButtons(
              context,
              splitToolbarActions(
                actions,
                editBarActionsWidth(constraints.maxWidth),
              ),
              null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The icons in [split] that fit, then the overflow menu holding the rest,
/// for the viewer's toolbar and for the editing bars (issue #4527). [color]
/// tints icons with no state colour of their own; null takes the bar's.
/// [onDarkBar] says the icons sit on the viewer's dark bar, so a
/// [MediaViewerAction.tone] takes the colours that read there; the menu
/// is the theme's own surface either way.
List<Widget> toolbarActionButtons(
  BuildContext context,
  ToolbarActionSplit split,
  Color? color, {
  bool onDarkBar = false,
}) => [
  for (final action in split.visible)
    // Builder so the anchor context is the button itself: findRenderObject
    // from it descends to the IconButton.
    Builder(
      key: ValueKey('viewer_${action.id}'),
      builder: (anchor) => IconButton(
        icon: _withRing(
          Icon(
            action.icon,
            color:
                action.iconColor ??
                toolbarToneColor(context, action.tone, onDarkBar: onDarkBar) ??
                color,
            semanticLabel: action.disabledReason == null ? null : action.label,
          ),
          action.ring,
        ),
        tooltip: action.disabledReason ?? action.label,
        onPressed: action.disabledReason == null
            ? () => action.onPressed(anchor)
            : null,
      ),
    ),
  if (split.overflow.isNotEmpty)
    Builder(
      builder: (anchor) => PopupMenuButton<MediaViewerAction>(
        key: const ValueKey('viewer_overflow'),
        icon: Icon(Icons.more_vert, color: color),
        tooltip: context.l10n.media_viewer_moreOptions,
        onSelected: (action) => action.onPressed(anchor),
        itemBuilder: (_) => [
          for (final action in split.overflow)
            PopupMenuItem<MediaViewerAction>(
              key: ValueKey('viewer_menu_${action.id}'),
              value: action,
              enabled: action.disabledReason == null,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    color:
                        action.iconColor ??
                        toolbarToneColor(
                          context,
                          action.tone,
                          onDarkBar: false,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(action.label),
                        if (action.disabledReason case final reason?)
                          Text(
                            reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
];

/// How far [_withRing]'s ring reaches past each side of the icon, into the
/// button's padding.
const double _ringOverhang = 4;

/// [icon] inside [ring], when there is one. The icon alone sizes the
/// button: the ring is painted out into the padding round it, so the
/// button, and the bar it sits in, keep their size while work runs
/// (issue #4870).
Widget _withRing(Widget icon, ToolbarRing? ring) {
  if (ring == null) return icon;
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      // Under the icon, as before; the icon still sizes the stack.
      Positioned(
        left: -_ringOverhang,
        top: -_ringOverhang,
        right: -_ringOverhang,
        bottom: -_ringOverhang,
        child: CircularProgressIndicator(strokeWidth: 2, value: ring.value),
      ),
      icon,
    ],
  );
}
