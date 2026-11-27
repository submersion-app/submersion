import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

/// The Country flags switch on a section's appearance page (issue #5001):
/// one each for sites, dives, buddies and trips, covering that section's
/// rows and its detail page.
class SectionCountryFlagsTile extends ConsumerWidget {
  const SectionCountryFlagsTile({super.key, required this.section});

  final FlagSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final (subtitle, save) = switch (section) {
      FlagSection.sites => (
        l10n.settings_appearance_countryFlags_subtitle_sites,
        notifier.setShowCountryFlags,
      ),
      FlagSection.dives => (
        l10n.settings_appearance_countryFlags_subtitle_dives,
        notifier.setShowDiveCountryFlags,
      ),
      FlagSection.buddies => (
        l10n.settings_appearance_countryFlags_subtitle_buddies,
        notifier.setShowBuddyCountryFlags,
      ),
      FlagSection.trips => (
        l10n.settings_appearance_countryFlags_subtitle_trips,
        notifier.setShowTripCountryFlags,
      ),
    };
    return SwitchListTile(
      key: ValueKey('section-country-flags-${section.name}'),
      secondary: const Icon(Icons.flag_outlined),
      title: Text(l10n.settings_appearance_countryFlags_title),
      subtitle: Text(subtitle),
      value: ref.watch(section.switchProvider),
      onChanged: save,
    );
  }
}
