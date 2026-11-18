import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_service_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_with_figure.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

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

    final edit = RecordEditScope.of<Dive>(context);
    // A check-in writes at once, a whole-record operation (issue #4527):
    // listed but disabled until the page is unlocked with nothing to save,
    // and only for gear the dive is stored with, not for gear that is only
    // in the sitting and may never be saved.
    final storedGearIds = {
      for (final link in (edit.session?.stored ?? dive).gear) link.item.id,
    };
    bool checkInReadOnly(String equipmentId) =>
        !storedGearIds.contains(equipmentId);
    final operationReason = recordOperationReason(
      context.l10n,
      recordOperationBlockOf(edit),
    );
    final runAsOperation = recordOperationRunnerOf(edit);
    final card = CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_equipment,
      icon: Icons.backpack,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      // The header is one large InkWell that toggles the card, so this button
      // consumes its own tap: without it, arranging would also collapse the
      // section the diver was looking at.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort writes the diver's own arrangement, a display setting, so
          // it works while the dive is locked.
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.equipment_list_sortTooltip,
            onPressed: () => showEquipmentArrangeSheet(context),
          ),
          RecordCardPencil(
            cardTitle: context.l10n.diveLog_detail_section_equipment,
          ),
        ],
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
          rowTrailing: (item) => ObservationStatusChip(
            equipment: item,
            dive: dive,
            readOnly: checkInReadOnly(item.id),
            operationReason: checkInReadOnly(item.id) ? null : operationReason,
            runAsOperation: runAsOperation,
          ),
        ),
      ),
    );
    // During a sitting, the set the dive's location suggests shows above the
    // card once every editor has closed: arriving after a lookup, it must
    // not push an open editor down the page (issue #4527).
    final session = edit.session;
    if (session == null || edit.openCardIds.isNotEmpty) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DiveGeofenceSuggestion(
          session: session,
          onUse: (set, items) => useSetInSitting(
            session,
            set,
            items,
            // The banner goes as the use starts; the use goes on.
            read: ProviderScope.containerOf(context, listen: false).read,
            questions: SetUseQuestions.dialogs(
              context,
              ref.read(unitFormatterProvider),
            ),
            auto: false,
          ),
        ),
        card,
      ],
    );
  }
}
