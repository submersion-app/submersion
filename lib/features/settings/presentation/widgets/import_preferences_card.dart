import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The card under the Import header on Settings > Data (issue #2779).
///
/// It holds the preferences for how incoming dive data is interpreted:
/// how closely a dive must sit to a site before site matching proposes it
/// (used wherever dives are matched to sites: after an import, from the GPS
/// logger, from a photo import and from a dive's suggestion card), and
/// whether cylinder end pressure is read at the moment of surfacing (applied
/// on dive computer downloads, file imports and reparses).
class ImportPreferencesCard extends ConsumerWidget {
  const ImportPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensitivity = ref.watch(
      settingsProvider.select((s) => s.siteMatchSensitivity),
    );
    final trimAtSurfacing = ref.watch(
      settingsProvider.select((s) => s.trimTankPressureAtSurfacing),
    );

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(context.l10n.settings_siteMatch_title),
            subtitle: Text(context.l10n.settings_siteMatch_subtitle),
            trailing: DropdownButton<SiteMatchSensitivity>(
              value: sensitivity,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setSiteMatchSensitivity(value);
                }
              },
              items: [
                DropdownMenuItem(
                  value: SiteMatchSensitivity.strict,
                  child: Text(context.l10n.settings_siteMatch_strict),
                ),
                DropdownMenuItem(
                  value: SiteMatchSensitivity.balanced,
                  child: Text(context.l10n.settings_siteMatch_balanced),
                ),
                DropdownMenuItem(
                  value: SiteMatchSensitivity.relaxed,
                  child: Text(context.l10n.settings_siteMatch_relaxed),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.compress),
            title: Text(context.l10n.settings_tankPressureAtSurfacing_title),
            subtitle: Text(
              context.l10n.settings_tankPressureAtSurfacing_subtitle,
            ),
            value: trimAtSurfacing,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setTrimTankPressureAtSurfacing(value),
          ),
        ],
      ),
    );
  }
}
