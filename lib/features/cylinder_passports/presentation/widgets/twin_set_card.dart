import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_link_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A cylinder's twin set (issue #4242): its current partner, with Replace
/// partner and Unlink, or a link button, and the pairings it has been in.
class TwinSetCard extends ConsumerWidget {
  const TwinSetCard({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cylinder = ref.watch(equipmentItemProvider(equipmentId)).value;
    final pairings =
        ref.watch(pairingsForCylinderProvider(equipmentId)).value ??
        const <CylinderPairing>[];
    // Wanted gear is not owned yet, so it is in no twin set.
    if (cylinder == null || cylinder.isWanted) return const SizedBox.shrink();
    final current = currentPairing(pairings, equipmentId);
    final history = [
      for (final p in pairings)
        if (!p.isOpen) p,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  SubmersionIcons.tankTwinSet,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.twinSet_title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (current == null) ...[
              Text(l10n.twinSet_none),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => linkTwinSetPartner(context, ref, cylinder),
                  icon: const Icon(Icons.link),
                  label: Text(l10n.twinSet_link),
                ),
              ),
            ] else
              _CurrentPartner(cylinder: cylinder, pairing: current),
            if (history.isNotEmpty) ...[
              const Divider(height: 24),
              Text(l10n.twinSet_history, style: theme.textTheme.titleSmall),
              for (final p in history)
                _HistoryRow(cylinderId: equipmentId, pairing: p),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentPartner extends ConsumerWidget {
  const _CurrentPartner({required this.cylinder, required this.pairing});

  final EquipmentItem cylinder;
  final CylinderPairing pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final partnerId = pairing.partnerOf(cylinder.id);
    final partner = ref.watch(equipmentItemProvider(partnerId)).value;
    final status = partner?.effectiveStatus;
    final subtitle = [
      l10n.twinSet_since(units.formatDate(pairing.pairedOn)),
      if (status != null && isPartnerOutOfUse(status))
        status.localizedName(l10n),
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(partner?.name ?? ''),
          subtitle: Text(subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.twinSet_deletePairing,
            onPressed: () => confirmDeletePairing(context, ref, pairing),
          ),
          onTap: () => context.push('/equipment/$partnerId'),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => unlinkTwinSet(context, ref, pairing),
              child: Text(l10n.twinSet_unlink),
            ),
            FilledButton.tonal(
              onPressed: () => linkTwinSetPartner(
                context,
                ref,
                cylinder,
                currentPartnerId: partnerId,
              ),
              child: Text(l10n.twinSet_replace),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.cylinderId, required this.pairing});

  final String cylinderId;
  final CylinderPairing pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final partnerId = pairing.partnerOf(cylinderId);
    final partner = ref.watch(equipmentItemProvider(partnerId)).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        l10n.twinSet_historyRange(
          partner?.name ?? '',
          units.formatDate(pairing.pairedOn),
          units.formatDate(pairing.unpairedOn),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.twinSet_deletePairing,
        onPressed: () => confirmDeletePairing(context, ref, pairing),
      ),
    );
  }
}

/// "Twin set with `partner`" under a passport's header (issue #4242), so a
/// tag scan lands somewhere that shows the pair. Tapping it opens the
/// partner. Nothing while the cylinder has no current pairing.
class TwinSetPartnerLine extends ConsumerWidget {
  const TwinSetPartnerLine({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPairingProvider(equipmentId)).value;
    if (current == null) return const SizedBox.shrink();
    final partnerId = current.partnerOf(equipmentId);
    final partner = ref.watch(equipmentItemProvider(partnerId)).value;
    if (partner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(SubmersionIcons.tankTwinSet),
        title: Text(context.l10n.twinSet_with(partner.name)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/equipment/$partnerId'),
      ),
    );
  }
}
