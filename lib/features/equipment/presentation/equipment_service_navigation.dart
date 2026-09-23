import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// Opens the equipment list showing only the gear whose service clocks sit at
/// [severity], the service twin of `openEquipmentWithTag`.
///
/// The filter is replaced rather than merged: a leftover category, attribute
/// condition or tag would hide some of the items the caller just counted, and
/// that count is the promise the list has to keep. The filter chip on the
/// list clears the severity again.
void openEquipmentWithServiceDue(
  BuildContext context,
  WidgetRef ref,
  ServiceDueFilter severity,
) {
  ref.read(equipmentFilterProvider.notifier).state = EquipmentFilterState(
    serviceDue: severity,
  );
  context.push('/equipment');
}
