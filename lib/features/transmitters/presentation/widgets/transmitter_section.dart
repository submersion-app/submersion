import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_key_widgets.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Transmitter section of a Transmitter item's Equipment page (issue
/// #3676): its keys, the cylinder it feeds and its role, a nudge while no
/// cylinder is set up, and "Apply to existing dives". Role and cylinder are
/// the transmitter's, so they are read from, and saved to, every key.
class TransmitterSection extends ConsumerWidget {
  const TransmitterSection({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(transmittersForEquipmentProvider(equipmentId));
    return keys.when(
      data: (list) => _SectionCard(equipmentId: equipmentId, keys: list),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _SectionCard extends ConsumerWidget {
  const _SectionCard({required this.equipmentId, required this.keys});

  final String equipmentId;
  final List<Transmitter> keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final setup = keys.firstOrNull;
    final addKey = '/equipment/$equipmentId/transmitter';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              EquipmentType.transmitter.localizedName(l10n),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (setup == null) ...[
              Text(
                l10n.transmitters_section_noKey,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push(addKey),
                icon: const Icon(Icons.add),
                label: Text(l10n.transmitters_section_addKey),
              ),
            ] else ...[
              if (!setup.isSetUp) _NoCylinderBanner(),
              for (final key in keys)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors),
                  title: TransmitterKeyLabel(entry: key),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('$addKey/${key.id}'),
                ),
              if (setup.equipmentId case final cylinderId?)
                _CylinderRow(cylinderId: cylinderId),
              Text(
                transmitterSpecLine(l10n, units, setup),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => context.push('$addKey/${setup.id}'),
                    child: Text(l10n.transmitters_section_setUp),
                  ),
                  TextButton(
                    onPressed: () => context.push(addKey),
                    child: Text(l10n.transmitters_section_addKey),
                  ),
                  if (setup.isSetUp)
                    TextButton(
                      onPressed: () => applyTransmitterSetupToExistingDives(
                        context,
                        ref,
                        keys,
                      ),
                      child: Text(l10n.transmitters_action_apply),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoCylinderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.transmitters_noCylinder,
              style: TextStyle(color: colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CylinderRow extends ConsumerWidget {
  const _CylinderRow({required this.cylinderId});

  final String cylinderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` keeps the last item through a reload, so the row stays put
    // while the cylinder is edited or synced.
    final cylinder = ref.watch(equipmentItemProvider(cylinderId)).value;
    if (cylinder == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.propane_tank_outlined),
      title: Text(context.l10n.transmitters_field_gear),
      subtitle: Text(cylinder.name),
      onTap: () => context.push('/equipment/$cylinderId'),
    );
  }
}
