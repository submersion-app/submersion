import 'package:go_router/go_router.dart';

import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

/// A Transmitter item's setup (issue #3676): add a key, or edit one; role
/// and cylinder go onto every key. Routes beneath the item's
/// `:equipmentId`, each an editor with no read page and the app's leave
/// check (issue #4527, phase 4).
///
/// Siblings, not parent and child: a key's address reached with `go`
/// would otherwise build the new-key editor beneath the key's, with a
/// sitting of its own the diver never saw.
List<RouteBase> transmitterEditRoutes() => [
  GoRoute(
    path: 'transmitter',
    name: 'transmitterSetup',
    onExit: confirmLeaveRecordSitting,
    builder: (context, state) =>
        TransmitterEditPage(equipmentId: state.pathParameters['equipmentId']!),
  ),
  GoRoute(
    path: 'transmitter/:transmitterId',
    name: 'transmitterKeyEdit',
    onExit: confirmLeaveRecordSitting,
    builder: (context, state) => TransmitterEditPage(
      equipmentId: state.pathParameters['equipmentId']!,
      transmitterId: state.pathParameters['transmitterId'],
    ),
  ),
];
