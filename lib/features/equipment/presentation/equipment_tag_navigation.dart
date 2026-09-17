import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// Opens the equipment list showing only the items tagged [tagId]
/// (issue #1942), the equipment twin of `openDivesWithTag` and
/// `openSitesWithTag`.
///
/// The filter is replaced rather than merged: a leftover category or
/// attribute condition would hide some of the tag's items. The status axis
/// returns to the default view, which hides retired and sold gear, as the
/// list always does. The filter chip on the list clears the tag again.
void openEquipmentWithTag(BuildContext context, WidgetRef ref, String tagId) {
  ref.read(equipmentFilterProvider.notifier).state = EquipmentFilterState(
    tagIds: {tagId},
  );
  context.go('/equipment');
}
