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
/// [route]; the button opens [setUpRoute], or [route] when none is given.
class DataRowTile extends StatelessWidget {
  const DataRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.health,
    this.offersSetUp = false,
    this.setUpRoute,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  /// Drawn as a 16 dp mark beside the title unless the feature is not set up.
  final FeatureHealth? health;

  final bool offersSetUp;
  final String? setUpRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final h = health;
    final showMark = h != null && h.level != HealthLevel.notSetUp;
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
                  onPressed: () =>
                      context.pushSettingsPage(setUpRoute ?? route),
                ),
              ],
            )
          : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      // In the desktop detail pane when it can show the page (#3467).
      onTap: () => context.pushSettingsPage(route),
    );
  }
}
