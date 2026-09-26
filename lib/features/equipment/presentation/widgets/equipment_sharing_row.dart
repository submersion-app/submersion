import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item page's sharing rows (issue #2046), shown only when two or more
/// profiles exist. The owner sees "Shared with" and taps it to change the
/// shares; a profile the item is shared with sees "Owned by" and the shares
/// read-only.
class EquipmentSharingRow extends ConsumerWidget {
  final EquipmentItem equipment;

  const EquipmentSharingRow({super.key, required this.equipment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasMultipleDiversProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final shares =
        ref.watch(equipmentSharesProvider(equipment.id)).value ?? const [];
    final isOwner =
        equipment.diverId == null || equipment.diverId == activeDiverId;
    String nameOf(String id) => names[id] ?? l10n.equipment_owner_unknown;

    final sharedWith = shares.isEmpty
        ? Text(l10n.equipment_sharing_notShared)
        : Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              for (final s in shares)
                Chip(
                  label: Text(nameOf(s.diverId)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isOwner)
          _row(
            context,
            l10n.equipment_sharing_ownedByLabel,
            Text(nameOf(equipment.diverId!)),
          ),
        InkWell(
          onTap: isOwner
              ? () => _edit(
                  context,
                  ref,
                  activeDiverId,
                  shares.map((s) => s.diverId).toSet(),
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          child: _row(
            context,
            l10n.equipment_sharing_sharedWithLabel,
            sharedWith,
            chevron: isOwner,
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Widget value, {
    bool chevron = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String? activeDiverId,
    Set<String> current,
  ) async {
    if (activeDiverId == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final divers = await ref.read(allDiversProvider.future);
    final others = [
      for (final d in divers)
        if (d.id != activeDiverId) d,
    ];
    if (!context.mounted) return;
    final chosen = await showProfileChecklistDialog(
      context,
      title: l10n.equipment_sharing_dialogTitle,
      body: l10n.equipment_sharing_dialogBody,
      profiles: others,
      initiallySelected: current,
      confirmLabel: l10n.common_action_save,
    );
    if (chosen == null) return;
    try {
      await ref
          .read(equipmentShareRepositoryProvider)
          .setShares(
            equipmentId: equipment.id,
            diverIds: chosen,
            actingDiverId: activeDiverId,
          );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
    }
  }
}
