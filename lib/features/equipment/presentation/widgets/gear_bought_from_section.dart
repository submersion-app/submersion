import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/gear_bought_from.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Rows shown before "Show all": a shop can have sold a whole kit.
const _collapsedRows = 5;

/// Statuses that mean the item has left the kit, named on its row.
const _leftKit = {
  EquipmentStatus.retired,
  EquipmentStatus.sold,
  EquipmentStatus.lost,
};

/// How the section sits on its page: a card, as the buddy page's sections
/// do, or under a divider with a 16 px gutter, as the dive centre page's do.
enum GearBoughtFromFrame { card, divided }

/// The diver's gear that a buddy ([buddyId]) or a dive centre ([centerId])
/// sold them (issue #5140), under [title]. Builds nothing when there is
/// none, so most buddies and centres show no trace of it. Read-only: the
/// seller is set on the gear item.
class GearBoughtFromSection extends ConsumerStatefulWidget {
  final String? buddyId;
  final String? centerId;
  final String title;
  final GearBoughtFromFrame frame;

  const GearBoughtFromSection({
    super.key,
    this.buddyId,
    this.centerId,
    required this.title,
    this.frame = GearBoughtFromFrame.card,
  });

  @override
  ConsumerState<GearBoughtFromSection> createState() =>
      _GearBoughtFromSectionState();
}

class _GearBoughtFromSectionState extends ConsumerState<GearBoughtFromSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final items = gearBoughtFrom(
      ref.watch(allEquipmentProvider).value ?? const [],
      buddyId: widget.buddyId,
      centerId: widget.centerId,
    );
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final shown = _expanded ? items : items.take(_collapsedRows).toList();
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: widget.frame == GearBoughtFromFrame.card
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.titleMedium,
        ),
        for (final item in shown) _row(context, item, units),
        if (shown.length < items.length)
          TextButton(
            key: const ValueKey('gear_bought_show_all'),
            onPressed: () => setState(() => _expanded = true),
            child: Text(l10n.equipment_boughtFrom_showAll(items.length)),
          ),
      ],
    );
    return switch (widget.frame) {
      GearBoughtFromFrame.card => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: content),
        ),
      ),
      GearBoughtFromFrame.divided => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: content,
          ),
        ],
      ),
    };
  }

  Widget _row(BuildContext context, EquipmentItem item, UnitFormatter units) {
    final l10n = context.l10n;
    final date = item.purchaseDate;
    final subtitle = [
      if (date != null)
        l10n.equipment_rowLabel_purchased(units.formatDate(date)),
      if (_leftKit.contains(item.status)) item.status.localizedName(l10n),
    ].join(' · ');
    return ListTile(
      key: ValueKey('gear_bought_${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
