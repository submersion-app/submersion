import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_saved.dart';
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

  /// Opens the key editor at [path]. Once it has saved, says so, and after
  /// a first setup, a downloaded key confirmed or a takeover offers to fill
  /// the dives already logged (spec section 5): the card's own Apply, with
  /// its counts and confirmation (issue #4527, phase 4). The message goes
  /// out even when this card was rebuilt meanwhile; the offer needs the card
  /// that opened the editor, so it goes with it.
  Future<void> _openKeyEditor(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final saved = await context.push<Object?>(path);
    if (saved is! TransmitterKeySaved) return;
    final offerApply = saved.offerApply && context.mounted;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transmitters_saved),
        persist: false,
        action: !offerApply
            ? null
            : SnackBarAction(
                label: l10n.transmitters_action_apply,
                onPressed: () => _applyAfterSave(context, ref),
              ),
      ),
    );
  }

  /// The snackbar's Apply: every key of the item as it is now (the setup
  /// went onto each), through the card's Apply. Nothing once the item page
  /// has gone, as its card's Apply has gone with it.
  Future<void> _applyAfterSave(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final List<Transmitter> current;
    try {
      // Read again, not the card's copy: the save may not have reached it.
      current = await ref.refresh(
        transmittersForEquipmentProvider(equipmentId).future,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    await _runApply(context, ref, current);
  }

  /// The card's Apply, from its button or from the snackbar after a save:
  /// refused with "Save or cancel your changes first" while the item page
  /// holds unsaved changes or is busy; through the item page's operation
  /// gate while it is unlocked, as a whole-record operation (phase 3); at
  /// once on a locked page or one with no editing. The counts and the
  /// confirmation are applyTransmitterSetupToExistingDives'.
  Future<void> _runApply(
    BuildContext context,
    WidgetRef ref,
    List<Transmitter> keys,
  ) async {
    final controller = RecordEditScope.maybeOf<EquipmentItem>(context);
    Future<bool> apply() =>
        applyTransmitterSetupToExistingDives(context, ref, keys);
    final block = recordOperationBlockOf(controller);
    switch (block) {
      case RecordOperationBlock.unsaved:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(recordOperationReason(context.l10n, block)!)),
        );
      case RecordOperationBlock.none:
        await recordOperationRunnerOf(
          controller!,
          record: 'equipment $equipmentId',
        )(apply);
      case RecordOperationBlock.locked || null:
        await apply();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
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
                onPressed: () => _openKeyEditor(context, ref, addKey),
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
                  onTap: () =>
                      _openKeyEditor(context, ref, '$addKey/${key.id}'),
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
                    onPressed: () =>
                        _openKeyEditor(context, ref, '$addKey/${setup.id}'),
                    child: Text(l10n.transmitters_section_setUp),
                  ),
                  TextButton(
                    onPressed: () => _openKeyEditor(context, ref, addKey),
                    child: Text(l10n.transmitters_section_addKey),
                  ),
                  // On the item's page (issue #4527, phase 3), Apply
                  // rewrites dives: a whole-record operation.
                  if (setup.isSetUp)
                    Builder(
                      builder: (context) {
                        final controller =
                            RecordEditScope.maybeOf<EquipmentItem>(context);
                        return RecordOperationButton(
                          reason: recordOperationReason(
                            l10n,
                            recordOperationBlockOf(controller),
                          ),
                          onPressed: () => _runApply(context, ref, keys),
                          builder: (onPressed) => TextButton(
                            key: const ValueKey('transmitter_apply'),
                            onPressed: onPressed,
                            child: Text(l10n.transmitters_action_apply),
                          ),
                        );
                      },
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
