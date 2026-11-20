import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How readily the app suggests a species (issue #4721): one choice per
/// level the installed pack carries, each with how often its
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
    final chosen = ref.watch(namingLevelNotifierProvider);
    final inForce = levelInForce(manifest, chosen)!.level;
    // The diver chose a level this pack lacks: the list shows the one in
    // force, and a note says so. The default level the pack lacks is no
    // choice of the diver's, so the list shows the one in force without a
    // note (issue #4789). Picked only changes with the level watched above.
    final fallback =
        chosen != inForce &&
        ref.watch(namingLevelNotifierProvider.notifier).picked;

    return RadioGroup<NamingLevel>(
      groupValue: inForce,
      // A tap on the selected tile reports nothing, unless the tile is
      // toggleable, when it reports null. Only the tile in force is, and
      // only while the chosen level is another, so null means the diver
      // chose the level shown over the one the pack lacks. setLevel skips
      // the level already chosen.
      onChanged: (level) => ref
          .read(namingLevelNotifierProvider.notifier)
          .setLevel(level ?? inForce),
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
              toggleable: fallback && level == inForce,
              title: Text(_title(l10n, level)),
              subtitle: Text(
                _hint(l10n, level, precisionOf(manifest.naming, level)),
              ),
            ),
          if (fallback) _FallbackNote(chosen: chosen, inForce: inForce),
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

/// Under the levels when the pack lacks the one the diver chose: which
/// level is in force until an update brings the chosen one, and that
/// choosing it keeps it.
class _FallbackNote extends StatelessWidget {
  const _FallbackNote({required this.chosen, required this.inForce});

  final NamingLevel chosen;
  final NamingLevel inForce;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.settings_speciesId_levelFallback(
                NamingLevelSection._title(l10n, chosen),
                NamingLevelSection._title(l10n, inForce),
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
