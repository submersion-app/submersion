import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment categories a navigation route's "Gerät" picker offers: the
/// console/DPV that recorded the route, or the dive computer it might be
/// cross-checked against. Every other category (fins, tanks, ...) has no
/// bearing on a measured route, so it is left out rather than filtered
/// silently by the diver.
const List<EquipmentType> navTrackEquipmentPickerTypes = [
  EquipmentType.dpv,
  EquipmentType.computer,
];

/// A [pickNavTrackEquipment] outcome: a chosen [EquipmentItem], an explicit
/// "no equipment" ([NavTrackEquipmentCleared]), or the sheet dismissed
/// without any choice ([NavTrackEquipmentPickCancelled]) -- three states a
/// bare nullable return cannot tell apart from each other.
sealed class NavTrackEquipmentChoice {
  const NavTrackEquipmentChoice();
}

class NavTrackEquipmentChosen extends NavTrackEquipmentChoice {
  const NavTrackEquipmentChosen(this.item);
  final EquipmentItem item;
}

class NavTrackEquipmentCleared extends NavTrackEquipmentChoice {
  const NavTrackEquipmentCleared();
}

class NavTrackEquipmentPickCancelled extends NavTrackEquipmentChoice {
  const NavTrackEquipmentPickCancelled();
}

/// Opens [NavTrackEquipmentPickerSheet] in its standard draggable sheet and
/// resolves to what the diver did.
///
/// Shared by the import review screen (where a route is first saved) and
/// the track detail page's "Change device" row (for changing it
/// afterward) -- both open the exact same picker the exact same way, so
/// this keeps them from drifting apart if that contract ever changes.
Future<NavTrackEquipmentChoice> pickNavTrackEquipment(
  BuildContext context, {
  required String? selectedEquipmentId,
}) async {
  // showModalBottomSheet resolves to null both when the sheet is dismissed
  // (backdrop tap, close button) and when the sheet pops a bare null for
  // "no equipment chosen" -- the sentinel keeps those apart.
  const noEquipmentChosen = Object();
  final result = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) => NavTrackEquipmentPickerSheet(
        scrollController: scrollController,
        selectedEquipmentId: selectedEquipmentId,
        onEquipmentSelected: (item) =>
            Navigator.of(sheetContext).pop(item ?? noEquipmentChosen),
      ),
    ),
  );
  return switch (result) {
    null => const NavTrackEquipmentPickCancelled(),
    EquipmentItem() => NavTrackEquipmentChosen(result),
    _ => const NavTrackEquipmentCleared(),
  };
}

/// Single-select equipment picker for a route's `equipmentId`, restricted to
/// [navTrackEquipmentPickerTypes] and always offering an explicit "no
/// equipment" (null) row first.
///
/// Deliberately its own small sheet rather than a reuse of
/// `EquipmentPickerSheet` (the dive-edit picker): that one is multi-select,
/// has no "none" row, and carries filter/sort/arrangement chrome a single
/// scooter-or-computer choice does not need.
class NavTrackEquipmentPickerSheet extends ConsumerWidget {
  const NavTrackEquipmentPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedEquipmentId,
    required this.onEquipmentSelected,
  });

  final ScrollController scrollController;
  final String? selectedEquipmentId;
  final void Function(EquipmentItem?) onEquipmentSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final equipmentAsync = ref.watch(activeEquipmentProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.navTrack_review_equipment,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_action_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              final offered = equipmentList
                  .where((e) => navTrackEquipmentPickerTypes.contains(e.type))
                  .toList();
              return ListView.builder(
                controller: scrollController,
                itemCount: offered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      key: const ValueKey('nav-track-equipment-none'),
                      leading: const Icon(Icons.block),
                      title: Text(l10n.navTrack_review_noEquipmentChosen),
                      selected: selectedEquipmentId == null,
                      onTap: () => onEquipmentSelected(null),
                    );
                  }
                  final item = offered[index - 1];
                  return ListTile(
                    key: ValueKey('nav-track-equipment-${item.id}'),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        equipmentTypeIcon(item.type),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(item.type.localizedName(l10n)),
                    selected: item.id == selectedEquipmentId,
                    onTap: () => onEquipmentSelected(item),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                l10n.diveLog_equipmentPicker_errorLoading(error.toString()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
