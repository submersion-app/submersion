import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-wide display zoom control.
///
/// No preview widget: zoom is applied at the app root, so this settings page
/// scales as the slider moves and is itself the live preview.
///
/// The title and the slider share one row when the tile is wide enough to
/// hold the localized title unwrapped beside a slider of at least
/// [minOneRowTrackWidth], and stack otherwise. The text is measured at the
/// current text size, so a long translation or large system text keeps the
/// stacked layout until it fits. The width is the tile's own, in logical
/// pixels after zoom, so zooming in on a wide pane can itself bring back the
/// stacked layout.
class DisplayZoomSettingsTile extends ConsumerStatefulWidget {
  const DisplayZoomSettingsTile({super.key});

  /// The shortest slider track the one-row layout accepts; any narrower and
  /// the tile stacks instead.
  static const double minOneRowTrackWidth = 160;

  @override
  ConsumerState<DisplayZoomSettingsTile> createState() =>
      _DisplayZoomSettingsTileState();
}

class _DisplayZoomSettingsTileState
    extends ConsumerState<DisplayZoomSettingsTile> {
  /// Dragging rescales the app live, which changes this tile's logical width,
  /// so a drag near the threshold switches layouts mid-gesture. The key moves
  /// the slider to its new parent instead of rebuilding it, which would
  /// cancel the drag before it saves.
  final _sliderKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final zoom = ref.watch(displayZoomNotifierProvider);
    final notifier = ref.read(displayZoomNotifierProvider.notifier);
    final l10n = context.l10n;
    final percent = (zoom * 100).round();
    final label = l10n.settings_appearance_displaySize_value(percent);

    final reset = zoom == DisplayZoom.defaultValue
        ? null
        : IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.settings_appearance_displaySize_reset,
            onPressed: notifier.reset,
          );
    final slider = _ZoomSlider(
      key: _sliderKey,
      zoom: zoom,
      label: label,
      notifier: notifier,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsWidth = _oneRowControlsWidth(
          context,
          constraints.maxWidth,
        );
        if (controlsWidth != null) {
          return ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(l10n.settings_appearance_displaySize),
            subtitle: Text(label),
            trailing: SizedBox(
              width: controlsWidth,
              child: Row(
                children: [
                  Expanded(child: slider),
                  // Reserve the reset slot even while it is hidden, so the
                  // track does not shrink under the pointer when a drag moves
                  // off 100%.
                  SizedBox(width: kMinInteractiveDimension, child: reset),
                ],
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.format_size),
              title: Text(l10n.settings_appearance_displaySize),
              subtitle: Text(label),
              trailing: reset,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: slider,
            ),
          ],
        );
      },
    );
  }
}

/// The width left for the slider group on one row once the title has the
/// room it needs, or null when that leaves the track shorter than
/// [DisplayZoomSettingsTile.minOneRowTrackWidth].
///
/// Mirrors how [ListTile] splits its width: content padding, the leading slot,
/// a title gap after the leading and another before the trailing. The title
/// slot must fit both the title and the widest percentage subtitle, measured
/// in the current locale and text size. The subtitle is measured at the
/// maximum zoom, not the current one, so the slot does not resize mid-drag.
double? _oneRowControlsWidth(BuildContext context, double tileWidth) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final tileTheme = ListTileTheme.of(context);
  final padding =
      (tileTheme.contentPadding ??
              const EdgeInsetsDirectional.only(start: 16, end: 24))
          .resolve(Directionality.of(context));
  final gap = tileTheme.horizontalTitleGap ?? 16;
  final leading = math.max(
    tileTheme.minLeadingWidth ?? 24,
    IconTheme.of(context).size ?? 24,
  );

  double measure(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  final titleWidth = math.max(
    measure(
      l10n.settings_appearance_displaySize,
      tileTheme.titleTextStyle ?? theme.textTheme.bodyLarge,
    ),
    measure(
      l10n.settings_appearance_displaySize_value(
        (DisplayZoom.max * 100).round(),
      ),
      tileTheme.subtitleTextStyle ?? theme.textTheme.bodyMedium,
    ),
  );
  final controlsWidth =
      tileWidth - padding.horizontal - leading - gap * 2 - titleWidth;

  final labelStyle = theme.textTheme.labelSmall;
  final controlsMinWidth =
      measure(l10n.settings_appearance_displaySize_smaller, labelStyle) +
      measure(l10n.settings_appearance_displaySize_larger, labelStyle) +
      DisplayZoomSettingsTile.minOneRowTrackWidth +
      kMinInteractiveDimension;
  return controlsWidth >= controlsMinWidth ? controlsWidth : null;
}

/// The slider between its Smaller and Larger labels.
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({
    super.key,
    required this.zoom,
    required this.label,
    required this.notifier,
  });

  final double zoom;
  final String label;
  final DisplayZoomNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        Text(l10n.settings_appearance_displaySize_smaller, style: labelStyle),
        Expanded(
          child: Slider(
            value: zoom,
            min: DisplayZoom.min,
            max: DisplayZoom.max,
            divisions: DisplayZoom.divisions,
            label: label,
            // Rescale live on every notch, but only write to storage once the
            // drag ends.
            onChanged: notifier.previewZoom,
            onChangeEnd: notifier.setZoom,
          ),
        ),
        Text(l10n.settings_appearance_displaySize_larger, style: labelStyle),
      ],
    );
  }
}
