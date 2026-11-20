import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sharing_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The item page's sharing rows (issue #2046), shown only when two or more
/// profiles exist. The owner sees "Shared with" and taps it to change the
/// shares; a profile the item is shared with sees "Owned by" and the shares
/// read-only.
///
/// It offers no edit outside the open Details card (issue #4527, phase 3);
/// in the page's sitting ([editing]) the owner's choice is held until Save,
/// and a closed card shows what a sitting holds ([shown]).
class EquipmentSharingRow extends ConsumerWidget {
  final EquipmentItem equipment;

  /// The sitting the shares are chosen in: the Details card's editor.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose shares a closed card shows.
  final EditSession<EquipmentItem>? shown;

  const EquipmentSharingRow({
    super.key,
    required this.equipment,
    this.editing,
    this.shown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref, null);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _build(context, ref, sitting),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? sitting,
  ) {
    // An ownerless item has no owner to manage its shares.
    if (!ref.watch(hasMultipleDiversProvider) || equipment.diverId == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    // Until the active diver is known, say nothing about ownership rather
    // than flash the wrong answer.
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    if (!activeDiver.hasValue) return const SizedBox.shrink();
    final activeDiverId = activeDiver.value;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    // Likewise until the shares are read: an unread list is not "Not shared",
    // and editing from it would start the checklist empty and save that,
    // removing every existing share.
    final sharesAsync = ref.watch(equipmentSharesProvider(equipment.id));
    if (!sharesAsync.hasValue) return const SizedBox.shrink();
    // The sitting's choice once it has read the shares, else as stored.
    final held = sitting == null ? null : gearItemSharing.inSitting(sitting);
    final shareIds =
        held ?? {for (final s in sharesAsync.requireValue) s.diverId};
    final isOwner = canShareEquipment(equipment, activeDiverId);
    // In the open card, only once the sitting has read the shares: a
    // choice made before then, or after the read failed, could not be held.
    final editing = this.editing;
    final canEdit =
        isOwner && editing != null && gearItemSharing.loaded(editing) != null;
    String nameOf(String id) => names[id] ?? l10n.equipment_owner_unknown;

    final sharedWith = shareIds.isEmpty
        ? Text(l10n.equipment_sharing_notShared)
        : Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.start,
            children: [
              for (final id in shareIds)
                Chip(
                  label: Text(nameOf(id)),
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
          onTap: canEdit
              ? () => _edit(context, ref, activeDiverId, shareIds)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: _row(
            context,
            l10n.equipment_sharing_sharedWithLabel,
            sharedWith,
            chevron: canEdit,
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
    return DetailRow(
      label: label,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: value),
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
    final session = editing;
    if (activeDiverId == null || session == null) return;
    final l10n = context.l10n;
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
    // Held until Save.
    if (chosen == null || session.isDisposed) return;
    gearItemSharing.set(session, chosen, actingDiverId: activeDiverId);
  }
}
