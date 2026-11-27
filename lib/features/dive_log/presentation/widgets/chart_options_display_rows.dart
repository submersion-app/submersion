import 'package:flutter/material.dart';
import 'package:submersion/core/constants/profile_zoom_mode.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_zoom_mode_labels.dart';
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
