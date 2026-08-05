import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Appearance settings for the Home tab: which status chips appear in the
/// gauge strip. All chip types are enabled by default.
///
/// When [embedded] is true, omits the Scaffold/AppBar for embedding in the
/// desktop settings detail pane.
class HomeAppearancePage extends ConsumerWidget {
  final bool embedded;

  const HomeAppearancePage({this.embedded = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;

    String chipName(HomeChipType type) => switch (type) {
      HomeChipType.gear => l10n.settings_homeChips_gear,
      HomeChipType.insurance => l10n.settings_homeChips_insurance,
      HomeChipType.noFly => l10n.settings_homeChips_noFly,
      HomeChipType.lastDive => l10n.settings_homeChips_lastDive,
      HomeChipType.certifications => l10n.settings_homeChips_certifications,
      HomeChipType.trip => l10n.settings_homeChips_trip,
      HomeChipType.checklist => l10n.settings_homeChips_checklist,
      HomeChipType.course => l10n.settings_homeChips_course,
      HomeChipType.uploads => l10n.settings_homeChips_uploads,
      HomeChipType.backup => l10n.settings_homeChips_backup,
      HomeChipType.sync => l10n.settings_homeChips_sync,
      HomeChipType.dataQuality => l10n.settings_homeChips_dataQuality,
    };

    final content = ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.settings_homeChips_description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final type in HomeChipType.values)
          SwitchListTile(
            key: Key('homeChipToggle_${type.name}'),
            title: Text(chipName(type)),
            value: !hidden.contains(type.name),
            onChanged: (enabled) =>
                notifier.setHomeChipEnabled(type.name, enabled),
          ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_homeChips_pageTitle)),
      body: content,
    );
  }
}
