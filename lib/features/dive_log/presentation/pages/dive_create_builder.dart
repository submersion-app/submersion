import 'package:flutter/widgets.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_editing_flag.dart';

/// The dive list pane's new dive (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the dive page while it is being created with
/// [unlockEditing] (issue #4527, plan 8), else the old form, as today.
Widget Function(BuildContext, void Function(String), VoidCallback)
newDivePaneBuilder({bool unlockEditing = kUnlockEditing}) =>
    (context, onSaved, onCancel) => unlockEditing
    ? DiveDetailPage.newDive(
        embedded: true,
        onCreated: onSaved,
        onCreateCancelled: onCancel,
        unlockEditing: true,
      )
    : DiveEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel);

/// `/dives/new`: the dive page opened unlocked on a new dive with
/// [unlockEditing] (issue #4527, plan 8), else the old form, with what the
/// route was handed. Null [unlockEditing] follows the build switch.
Widget newDiveRoutePage({
  DivePrefill? prefill,
  String? tripId,
  String? tripCylinderId,
  bool? unlockEditing,
}) {
  if (!(unlockEditing ?? kUnlockEditing)) {
    return DiveEditPage(
      prefill: prefill,
      tripId: tripId,
      tripCylinderId: tripCylinderId,
    );
  }
  return DiveDetailPage.newDive(
    request: NewDiveRequest(
      prefill: prefill,
      tripId: tripId,
      tripCylinderId: tripCylinderId,
    ),
    unlockEditing: true,
  );
}
