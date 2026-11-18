import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How sure the app must be before it names a fish (issue #4721): one
/// choice per level the installed pack carries, each with how often its
/// names were right when measured. Nothing shows while there is no pack,
/// or the pack carries no levels below its own bars.
class NamingLevelSection extends ConsumerWidget {
  const NamingLevelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(installedSpeciesPackProvider).value?.manifest;
    final offered = manifest == null
        ? const <NamingLevel>[]
        : offeredLevels(manifest.naming);
    if (manifest == null || offered.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final inForce = levelInForce(
      manifest,
      ref.watch(namingLevelProvider),
    )!.level;

    return RadioGroup<NamingLevel>(
      groupValue: inForce,
      onChanged: (level) {
        if (level != null && level != inForce) {
          ref.read(namingLevelProvider.notifier).setLevel(level);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.settings_speciesId_levelTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final level in offered)
            RadioListTile<NamingLevel>(
              key: ValueKey('species_id_level_${level.id}'),
              value: level,
              title: Text(_title(l10n, level)),
              subtitle: Text(
                _hint(l10n, level, precisionOf(manifest.naming, level)),
              ),
            ),
        ],
      ),
    );
  }

  static String _title(AppLocalizations l10n, NamingLevel level) =>
      switch (level) {
        NamingLevel.surer => l10n.settings_speciesId_levelSurer,
        NamingLevel.balanced => l10n.settings_speciesId_levelBalanced,
        NamingLevel.eager => l10n.settings_speciesId_levelEager,
      };

  /// What the level costs: fewer or more names, and how often they were
  /// right. Only Surer can lack a measurement; a carried level always has
  /// one.
  static String _hint(
    AppLocalizations l10n,
    NamingLevel level,
    double? precision,
  ) {
    final percent = precision == null ? null : accuracyPercent(precision);
    return switch (level) {
      NamingLevel.surer =>
        percent == null
            ? l10n.settings_speciesId_levelSurerUnmeasured
            : l10n.settings_speciesId_levelSurerAccuracy(percent),
      NamingLevel.balanced => l10n.settings_speciesId_levelBalancedAccuracy(
        percent ?? 0,
      ),
      NamingLevel.eager => l10n.settings_speciesId_levelEagerAccuracy(
        percent ?? 0,
      ),
    };
  }
}
