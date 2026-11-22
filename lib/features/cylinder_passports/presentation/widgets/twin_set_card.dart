import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_link_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_twin_set_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A cylinder's twin set (issue #4242): its current partner, with Replace
/// partner and Unlink, or a link button, and the pairings it has been in.
class TwinSetCard extends ConsumerWidget {
  const TwinSetCard({
    super.key,
    required this.equipmentId,
    this.working,
    this.editing,
  });

  final String equipmentId;

  /// The item as the page's sitting has it: whether it hides follows the
  /// sitting's Worn as (issue #4527, phase 3). The stored item when null.
  final EquipmentItem? working;

  /// The open card's sitting: pairing, replacing, unlinking and deleting are
  /// held there until Save. With no sitting given, the card reads only; during
  /// a sitting every view shows its pairings.
  final EditSession<EquipmentItem>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? scope?.session;
    if (session == null) return _build(context, ref, null);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _build(context, ref, session),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cylinder =
        working ?? ref.watch(equipmentItemProvider(equipmentId)).value;
    final storedAsync = ref.watch(pairingsForCylinderProvider(equipmentId));
    final stored = storedAsync.value ?? const <CylinderPairing>[];
    final AsyncValue<Object?> pairingsAsync = session == null
        ? storedAsync
        : ref.watch(allPairingsProvider);
    final pairings = session == null
        ? stored
        : [
            for (final p in pairingsInSitting(
              ref.watch(allPairingsProvider).value ?? const [],
              heldPairingSteps(session),
            ))
              if (p.involves(equipmentId)) p,
          ];
    // Only the open card acts, and its writes are the sitting's. Null
    // offers no action.
    final editing = this.editing;
    final PairingWrites? writer = editing == null
        ? null
        : SittingPairingWrites(
            editing,
            () => ref.read(allPairingsProvider.future),
            ref.read(cylinderPairingRepositoryProvider),
          );
    bool changed(CylinderPairing p) => session != null && !stored.contains(p);
    // Wanted gear is not owned yet, so it is in no twin set.
    if (cylinder == null || cylinder.isWanted) return const SizedBox.shrink();
    // Doubles kept as one item (issue #4641) already are a twin set, so they
    // are not offered a partner; a pairing they were given still shows, so
    // the card stays hidden until the pairings have been read.
    if (cylinder.isWornAsTwinSet &&
        (!pairingsAsync.hasValue || pairings.isEmpty)) {
      return const SizedBox.shrink();
    }
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
                Expanded(
                  child: Text(
                    l10n.twinSet_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                RecordCardPencil(cardTitle: l10n.twinSet_title),
              ],
            ),
            const SizedBox(height: 8),
            if (current == null) ...[
              Text(l10n.twinSet_none),
              if (writer != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => linkTwinSetPartner(
                      context,
                      ref,
                      cylinder,
                      writer: writer,
                    ),
                    icon: const Icon(Icons.link),
                    label: Text(l10n.twinSet_link),
                  ),
                ),
              ],
            ] else
              _CurrentPartner(
                cylinder: cylinder,
                pairing: current,
                writer: writer,
                changed: changed(current),
              ),
            if (history.isNotEmpty) ...[
              const Divider(height: 24),
              Text(l10n.twinSet_history, style: theme.textTheme.titleSmall),
              for (final p in history)
                _HistoryRow(
                  cylinderId: equipmentId,
                  pairing: p,
                  writer: writer,
                  changed: changed(p),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentPartner extends ConsumerWidget {
  const _CurrentPartner({
    required this.cylinder,
    required this.pairing,
    required this.writer,
    required this.changed,
  });

  final EquipmentItem cylinder;
  final CylinderPairing pairing;

  /// The sitting's writes; null offers no action.
  final PairingWrites? writer;
  final bool changed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final partnerId = pairing.partnerOf(cylinder.id);
    final partner = ref.watch(equipmentItemProvider(partnerId)).value;
    final status = partner?.effectiveStatus;
    final writer = this.writer;
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
          title: _withDot(Text(partner?.name ?? ''), changed),
          subtitle: Text(subtitle),
          trailing: writer == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.twinSet_deletePairing,
                  onPressed: () => confirmDeletePairing(
                    context,
                    ref,
                    pairing,
                    writer: writer,
                  ),
                ),
          onTap: () => context.push('/equipment/$partnerId'),
        ),
        if (writer != null)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    unlinkTwinSet(context, ref, pairing, writer: writer),
                child: Text(l10n.twinSet_unlink),
              ),
              FilledButton.tonal(
                onPressed: () => linkTwinSetPartner(
                  context,
                  ref,
                  cylinder,
                  currentPartnerId: partnerId,
                  writer: writer,
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
  const _HistoryRow({
    required this.cylinderId,
    required this.pairing,
    required this.writer,
    required this.changed,
  });

  final String cylinderId;
  final CylinderPairing pairing;

  /// The sitting's writes; null offers no action.
  final PairingWrites? writer;
  final bool changed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final partnerId = pairing.partnerOf(cylinderId);
    final partner = ref.watch(equipmentItemProvider(partnerId)).value;
    final writer = this.writer;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: _withDot(
        Text(
          l10n.twinSet_historyRange(
            partner?.name ?? '',
            units.formatDate(pairing.pairedOn),
            units.formatDate(pairing.unpairedOn),
          ),
        ),
        changed,
      ),
      trailing: writer == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.twinSet_deletePairing,
              onPressed: () =>
                  confirmDeletePairing(context, ref, pairing, writer: writer),
            ),
    );
  }
}

/// [title] with the changed dot when its pairing is the sitting's.
Widget _withDot(Widget title, bool changed) => !changed
    ? title
    : Row(
        children: [
          Flexible(child: title),
          const SizedBox(width: 6),
          const RecordChangedDot(),
        ],
      );

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
