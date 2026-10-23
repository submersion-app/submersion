import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver picked from a waypoint's menu, opened by right-click with
/// a mouse or by a long-press on touch.
sealed class WaypointMenuAction {
  const WaypointMenuAction();
}

/// Breathe [tank] from this waypoint on.
final class SwitchGasAction extends WaypointMenuAction {
  final DiveTank tank;

  const SwitchGasAction(this.tank);
}

/// Take the waypoint out of the plan, leaving the others where they are.
final class RemoveWaypointAction extends WaypointMenuAction {
  const RemoveWaypointAction();
}

/// Shows the waypoint menu at [globalPosition]: one item per tank, then
/// Remove. Remove is there even with no tank to offer.
Future<WaypointMenuAction?> showWaypointMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<DiveTank> tanks,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<WaypointMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final tank in tanks)
        PopupMenuItem<WaypointMenuAction>(
          value: SwitchGasAction(tank),
          child: Text(
            tank.name == null || tank.name!.isEmpty
                ? tank.gasMix.name
                : '${tank.name} · ${tank.gasMix.name}',
          ),
        ),
      if (tanks.isNotEmpty) const PopupMenuDivider(),
      PopupMenuItem<WaypointMenuAction>(
        key: const Key('planWaypointMenu_remove'),
        value: const RemoveWaypointAction(),
        child: Text(context.l10n.plannerCanvas_chart_removeWaypoint),
      ),
    ],
  );
}
