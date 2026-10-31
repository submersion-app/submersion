import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_service_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_with_figure.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Equipment card.
class DiveEquipmentSection extends ConsumerWidget {
  const DiveEquipmentSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get collapsed state from provider
    final isExpanded = ref.watch(equipmentSectionExpandedProvider);
    final showFigure = ref.watch(
      settingsProvider.select((s) => s.showDiveFigure),
    );

    // Collapsed subtitle showing the top-level row count as the tree view
    // places it: an assembly's parts sit inside its row, and an orphaned
    // row is promoted, so the count matches what expands below (#1487).
    final collapsedSubtitle = context.l10n.diveLog_detail_equipmentCount(
      GearTree.topLevelCount(dive.gearProvenance),
    );

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_equipment,
      icon: Icons.backpack,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      // The header is one large InkWell that toggles the card, so this button
      // consumes its own tap: without it, arranging would also collapse the
      // section the diver was looking at.
      trailing: IconButton(
        icon: const Icon(Icons.sort, size: 20),
        tooltip: context.l10n.equipment_list_sortTooltip,
        onPressed: () => showEquipmentArrangeSheet(context),
      ),
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setEquipmentExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // The tree, and the diver figure above it unless the diver has
        // turned it off (issue #2326). It marks gear another profile owns
        // against this dive's diver, as the tree alone did (issue #2046).
        child: DiveGearWithFigure(
          dive: dive,
          showFigure: showFigure,
          showServiceStatus: diveGearShowsLiveServiceStatus(
            dive,
            DateTime.now(),
          ),
          onTap: (item) => context.push('/equipment/${item.id}'),
          // The check-in chip for each row (condition phase 3a).
          rowTrailing: (item) =>
              ObservationStatusChip(equipment: item, dive: dive),
        ),
      ),
    );
  }
}
