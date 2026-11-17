import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';

/// The dive list pane's new dive (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the dive page while it is being created
/// (issue #4527, plan 8).
Widget Function(BuildContext, void Function(String), VoidCallback)
newDivePaneBuilder() =>
    (context, onSaved, onCancel) => DiveDetailPage.newDive(
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );

/// `/dives/new`: the dive page opened unlocked on a new dive (issue #4527,
/// plan 8), with what the route was handed.
Widget newDiveRoutePage({
  DivePrefill? prefill,
  String? tripId,
  String? tripCylinderId,
}) => DiveDetailPage.newDive(
  request: NewDiveRequest(
    prefill: prefill,
    tripId: tripId,
    tripCylinderId: tripCylinderId,
  ),
);

/// The dive list pane's edit mode (`&mode=edit`, the old edit form's
/// address), as the master-detail scaffold's `editBuilder`: the dive page
/// opened unlocked, back to the dive in view mode ([onCancel]) once its
/// sitting ends (issue #4527, plan 11).
Widget unlockedDivePane(
  BuildContext context,
  String id,
  VoidCallback onCancel,
) => DiveDetailPage(
  diveId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  onDeleted: () => context.goInPlace(GoRouterState.of(context).uri.path),
);
