import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/profile_zoom_mode.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_zoom_mode_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/right_axis_metric_menu.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The chart options' Zoom row (issue #5069): what zooming scales for this
/// chart session, one of the three [ProfileZoomMode]s.
Widget buildZoomModeRow(
  BuildContext context, {
  required ProfileLegendState legendState,
  required ProfileLegend legendNotifier,
}) {
  final l10n = context.l10n;
  return buildMenuRow(
    context,
    key: const ValueKey('chart-options-zoom-mode'),
    label: l10n.diveLog_chartOption_zoom,
    value: profileZoomModeLabel(l10n, legendState.zoomMode),
    onTap: (rowContext) async {
      final picked = await showProfileZoomModeMenu(
        rowContext,
        current: legendState.zoomMode,
      );
      if (picked != null) legendNotifier.setZoomMode(picked);
    },
  );
}

/// Opens the three Zoom choices under [rowContext]'s row, the current one
/// checked, and returns the pick (null when dismissed). Shared by the chart
/// options and Settings, so both offer the same list.
Future<ProfileZoomMode?> showProfileZoomModeMenu(
  BuildContext rowContext, {
  required ProfileZoomMode current,
}) {
  final l10n = rowContext.l10n;
  return showMenu<ProfileZoomMode>(
    context: rowContext,
    position: menuPositionBelow(rowContext),
    items: [
      for (final mode in ProfileZoomMode.values)
        PopupMenuItem<ProfileZoomMode>(
          value: mode,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: mode == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(profileZoomModeLabel(l10n, mode))),
            ],
          ),
        ),
    ],
  );
}

/// Stands in for a config that carries no shown metric: never written.
final ValueListenable<ProfileRightAxisMetric?> _noRightAxisMetric =
    ValueNotifier(null);

/// The chart options' Right axis row (issue #5069): what the axis shows now,
/// "None" when it shows nothing, opening the same menu as tapping the axis.
/// It is how a diver who chose "None" gets the axis back. It follows
/// [ProfileLegendConfig.shownRightAxisMetric], so it stays true while the
/// dialog is open across picks.
Widget buildRightAxisRow(
  BuildContext context, {
  required ProfileLegendConfig config,
  required ProfileLegend legendNotifier,
}) {
  final l10n = context.l10n;
  return ValueListenableBuilder<ProfileRightAxisMetric?>(
    valueListenable: config.shownRightAxisMetric ?? _noRightAxisMetric,
    builder: (context, shown, _) => buildMenuRow(
      context,
      key: const ValueKey('chart-options-right-axis'),
      label: l10n.diveLog_chartOption_rightAxis,
      value: shown == null
          ? l10n.diveLog_profile_rightAxis_none
          : profileMetricName(l10n, shown),
      onTap: (rowContext) => showRightAxisMetricMenu(
        rowContext,
        position: menuPositionBelow(rowContext),
        choices: config.rightAxisChoices,
        current: shown,
        onPick: legendNotifier.setRightAxisMetric,
        onNone: legendNotifier.hideRightAxis,
      ),
    ),
  );
}
