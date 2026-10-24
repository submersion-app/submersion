import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';

/// The group under the Import header on Settings > Data (issue #2779). Flat,
/// like the rest of that page (issue #3390).
///
/// It holds the preferences for how incoming dive data is interpreted:
/// how closely a dive must sit to a site before site matching proposes it
/// (used wherever dives are matched to sites: after an import, from the GPS
/// logger, from a photo import and from a dive's suggestion card), whether
/// cylinder end pressure is read at the moment of surfacing (applied on dive
/// computer downloads, file imports and reparses), and whether every new
/// import session starts with a tag naming its source and date (issue #998;
/// moved here from Settings > Manage > Tags in issue #3193), and whether a
/// dive computer download defaults to the profile that owns the computer
/// (issue #2050).
///
/// The auto-tag switch is only the starting point for a new session: the
/// import wizard's Import Options sheet overrides it for a single import
/// without touching this default.
class ImportPreferencesGroup extends ConsumerWidget {
  const ImportPreferencesGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensitivity = ref.watch(
      settingsProvider.select((s) => s.siteMatchSensitivity),
    );
    final trimAtSurfacing = ref.watch(
      settingsProvider.select((s) => s.trimTankPressureAtSurfacing),
    );
    final autoTagImports = ref.watch(
      settingsProvider.select((s) => s.autoTagImports),
    );
    final followComputerOwner = ref.watch(
      settingsProvider.select((s) => s.downloadsFollowComputerOwner),
    );

    // Flush with the page's other rows, which drop the default inset.
    return ListTileTheme(
      data: const ListTileThemeData(contentPadding: EdgeInsets.zero),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: LabelWithControl(
              label: Text(context.l10n.settings_siteMatch_title),
              control: DropdownButton<SiteMatchSensitivity>(
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
            subtitle: Text(context.l10n.settings_siteMatch_subtitle),
          ),
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
          SwitchListTile(
            secondary: const Icon(Icons.label_outline),
            title: Text(context.l10n.settings_autoTagImports_title),
            subtitle: Text(context.l10n.settings_autoTagImports_subtitle),
            value: autoTagImports,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setAutoTagImports(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.person_pin_outlined),
            title: Text(context.l10n.settings_downloadsFollowOwner_title),
            subtitle: Text(context.l10n.settings_downloadsFollowOwner_subtitle),
            value: followComputerOwner,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setDownloadsFollowComputerOwner(value),
          ),
        ],
      ),
    );
  }
}
