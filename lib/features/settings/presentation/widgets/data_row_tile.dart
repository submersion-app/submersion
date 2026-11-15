import 'package:flutter/material.dart';

import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// One row of Settings > Data (issue #3482): an icon, the feature's name, a
/// one-sentence status with a "Set up" action under it for a feature that is
/// not set up, and a chevron. A feature row is its status (#4561): the health
/// symbol takes the icon's place and [statusAction] (Sign in again) sits
/// beside the sentence, or under it where it would leave the sentence no
/// room. The whole row opens [route] (or runs [onTap]); the button opens
/// [setUpRoute], or [route] when none is given. A row that is not [enabled]
/// is greyed out with its plain icon and says it is unavailable in demo mode
/// (issue #3708). A row with neither [route] nor [onTap] only informs: no
/// chevron and nothing to tap (a browser's database storage, issue #4121).
class DataRowTile extends StatelessWidget {
  const DataRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.onTap,
    this.healthLevel,
    this.statusAction,
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

  /// The feature's status, drawn in the leading slot. Null for a row that
  /// has none (accounts, change log, the Advanced rows).
  final HealthLevel? healthLevel;

  /// An action that belongs to the status sentence (Sign in again).
  final Widget? statusAction;

  final bool offersSetUp;
  final String? setUpRoute;

  /// Logical width, at normal text size, below which [statusAction] goes
  /// under the sentence.
  static const double _minWidthBeside = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final level = healthLevel;
    final target = route;
    if (!enabled) {
      return ListTile(
        enabled: false,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(l10n.demo_row_unavailable),
      );
    }
    final action = statusAction;
    final Widget status = action == null
        ? Text(subtitle)
        : LayoutBuilder(
            builder: (context, constraints) {
              // Beside the sentence while it fits, under it on a narrow
              // phone at large text.
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final beside =
                  constraints.maxWidth / textScale >= _minWidthBeside;
              return beside
                  ? Row(
                      children: [
                        Expanded(child: Text(subtitle)),
                        action,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(subtitle), action],
                    );
            },
          );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: level == null
          ? Icon(icon)
          : HealthSymbol(
              level: level,
              size: 24,
              semanticLabel: healthLevelLabel(l10n, level),
            ),
      title: Text(title),
      // The Set up action sits on its own line under the status, never in
      // trailing, where a translated label would squeeze the title (#2717).
      subtitle: offersSetUp
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                TileSubtitleAction(
                  label: l10n.settings_data_setUp,
                  // Several rows offer Set up; name the one this acts on.
                  semanticsLabel: l10n.settings_data_setUpFeature(title),
                  onPressed: () =>
                      context.pushSettingsPage(setUpRoute ?? route!),
                ),
              ],
            )
          : status,
      trailing: route == null && onTap == null
          ? null
          : const Icon(Icons.chevron_right),
      // In the desktop detail pane when it can show the page (#3467).
      onTap:
          onTap ??
          (target == null ? null : () => context.pushSettingsPage(target)),
    );
  }
}
