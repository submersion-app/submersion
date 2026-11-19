import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// What an open gear item card shows in place of its actions while its
/// held [list] is not yet read in [session] (issue #4527, phase 3, plan 6):
/// a progress bar, or a way to read it again when the read failed. Null
/// once the rows are read, when the card may act: an action taken before
/// then would have no list to go into, and would be lost.
Widget? gearItemListPending<E>(
  SittingList<EquipmentItem, E> list,
  EditSession<EquipmentItem> session,
) {
  if (list.current(session) != null) return null;
  if (list.failed(session)) {
    return SittingLoadFailed(onRetry: () => list.load(session));
  }
  return const LinearProgressIndicator();
}
