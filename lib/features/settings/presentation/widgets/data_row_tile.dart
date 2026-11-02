import 'package:flutter/material.dart';

import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// One row of Settings > Data (issue #3482): an icon, the feature's name
/// with its health mark, a one-sentence status with a "Set up" action under
/// it for a feature that is not set up, and a chevron. The whole row opens
/// [route] (or runs [onTap]); the button opens [setUpRoute], or [route] when
/// none is given. A row that is not [enabled] is greyed out and says it is
/// unavailable in demo mode (issue #3708). A row with neither [route] nor
/// [onTap] only informs: no chevron and nothing to tap (a browser's
/// database storage, issue #4121).
class DataRowTile extends StatelessWidget {
  const DataRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.onTap,
    this.health,
    this.offersSetUp = false,
    this.setUpRoute,
    this.enabled = true,
  }) : assert(
         route != null || onTap != null || !offersSetUp,
         'a Set up action needs a route to open',
       );

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final VoidCallback? onTap;
  final bool enabled;

  /// Drawn as a 16 dp mark beside the title unless the feature is not set up.
  final FeatureHealth? health;

  final bool offersSetUp;
  final String? setUpRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final h = health;
    final target = route;
    final showMark = enabled && h != null && h.level != HealthLevel.notSetUp;
    if (!enabled) {
      return ListTile(
        enabled: false,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(l10n.demo_row_unavailable),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: showMark
          ? Row(
              children: [
                Flexible(child: Text(title)),
                const SizedBox(width: 8),
                HealthSymbol(
                  level: h.level,
                  size: 16,
                  semanticLabel: healthSemanticsLabel(l10n, h),
                ),
              ],
            )
          : Text(title),
      // The Set up action sits on its own line under the status, never in
      // trailing, where a translated label would squeeze the title (#2717).
      subtitle: offersSetUp
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                TileSubtitleAction(
                  label: l10n.settings_data_setUp,
                  // Several rows offer Set up; name the one this acts on.
                  semanticsLabel: l10n.settings_data_setUpFeature(title),
                  onPressed: () =>
                      context.pushSettingsPage(setUpRoute ?? route!),
                ),
              ],
            )
          : Text(subtitle),
      trailing: route == null && onTap == null
          ? null
          : const Icon(Icons.chevron_right),
      // In the desktop detail pane when it can show the page (#3467).
      onTap: onTap ?? (target == null ? null : () => _open(context, target)),
    );
  }

  static void _open(BuildContext context, String route) {
    context.pushSettingsPage(route);
  }
}
