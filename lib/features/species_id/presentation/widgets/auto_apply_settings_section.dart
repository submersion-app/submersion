import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings for tagging confident matches with no tap, and for when those
/// tags log their sightings (issue #4727). Hidden with no model installed.
/// While the installed model can call nothing confident, the switch is
/// shown off and disabled, with a line saying why.
class AutoApplySettingsSection extends ConsumerWidget {
  const AutoApplySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final installed = ref.watch(installedSpeciesPackProvider).value;
    final stored = ref.watch(autoApplyProvider);
    // With no model the setting still acts on names already stored, so a
    // diver who left it on can see it and switch it off.
    if (installed == null && !stored) return const SizedBox.shrink();
    final naming = installed?.manifest.naming;
    final canApply = naming == null || packCanApply(naming);
    final on = canApply && stored;
    final timing = ref.watch(sightingTimingProvider);
    final description = !canApply
        ? l10n.settings_speciesId_autoApplyNever
        : naming != null && packAppliesOnlyWithPlace(naming)
        ? '${l10n.settings_speciesId_autoApplyDescription} '
              '${l10n.settings_speciesId_autoApplyPlaceOnly}'
        : l10n.settings_speciesId_autoApplyDescription;

    void setTiming(SightingTiming? value) {
      if (value != null) {
        ref.read(sightingTimingProvider.notifier).setTiming(value);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: const ValueKey('species_id_auto_apply'),
          title: Text(l10n.settings_speciesId_autoApply),
          subtitle: Text(description),
          isThreeLine: true,
          value: on,
          onChanged: canApply
              ? (value) =>
                    ref.read(autoApplyProvider.notifier).setEnabled(value)
              : null,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Text(
            l10n.settings_speciesId_sightingTiming,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        RadioGroup<SightingTiming>(
          groupValue: timing,
          onChanged: on ? setTiming : (_) {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SightingTiming>(
                key: const ValueKey('species_id_timing_confirm'),
                title: Text(l10n.settings_speciesId_sightingOnConfirm),
                value: SightingTiming.onConfirm,
                enabled: on,
              ),
              RadioListTile<SightingTiming>(
                key: const ValueKey('species_id_timing_straight'),
                title: Text(l10n.settings_speciesId_sightingStraightAway),
                value: SightingTiming.straightAway,
                enabled: on,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
