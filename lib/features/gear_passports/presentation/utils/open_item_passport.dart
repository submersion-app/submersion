import 'package:flutter/widgets.dart';

import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/gear_passports/presentation/pages/gear_passport_page.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

/// Opens [item]'s passport from its page: the cylinder passport for a tank,
/// the gear passport for anything else.
///
/// From the item's page (issue #4527, phase 3) the passport is a
/// satellite of the item: pushed while the page is unlocked, it joins the
/// page's sitting; pushed while it is locked, it has a lock of its own and
/// its Save writes one History entry on the item. Elsewhere it opens its
/// route, as before.
Future<void> openItemPassport(BuildContext context, EquipmentItem item) async {
  final tank = item.type == EquipmentType.tank;
  final scope = context
      .getInheritedWidgetOfExactType<RecordEditScope<EquipmentItem>>();
  if (scope == null) {
    await context.push(
      tank ? '/equipment/${item.id}/passport' : gearPassportLocation(item.id),
    );
    return;
  }
  // On the navigator the passport's route would use, so it keeps the app's
  // navigation around it.
  await pushRecordSatellite<EquipmentItem, void>(
    context,
    rootNavigator: false,
    builder: (joined) => tank
        ? PassportPage(equipmentId: item.id, joined: joined)
        : GearPassportPage(equipmentId: item.id, joined: joined),
  );
}
