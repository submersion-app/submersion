import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/own_cylinder_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/cylinders_from_tanks_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _TankGearAction { add, link, unlink }

/// A tank row's cylinder actions on the dive page (issue #4494). A tank with
/// no gear item can become a new cylinder or be linked to one the diver
/// owns; a linked tank can be unlinked, so a wrong link (a rental logged
/// against the diver's own cylinder) is undone without deleting anything.
/// Every action writes at once, so the host shows this only where the
/// Tanks card may write (#4527).
class TankGearMenu extends ConsumerWidget {
  const TankGearMenu({super.key, required this.dive, required this.tank});

  final Dive dive;
  final DiveTank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final linked = tank.equipmentId != null;
    return PopupMenuButton<_TankGearAction>(
      key: Key('tank-gear-menu-${tank.id}'),
      tooltip: l10n.diveLog_tank_gearMenu,
      // Horizontal, so the page's own overflow stays the only vertical one
      // on the dive page.
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        if (!linked) ...[
          PopupMenuItem(
            value: _TankGearAction.add,
            child: Text(l10n.diveLog_tank_addToGear),
          ),
          PopupMenuItem(
            value: _TankGearAction.link,
            child: Text(l10n.diveLog_tank_linkCylinder),
          ),
        ] else
          PopupMenuItem(
            value: _TankGearAction.unlink,
            child: Text(l10n.diveLog_tank_unlinkCylinder),
          ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _TankGearAction action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.diveLog_tank_linkFailed;
    final service = ref.read(cylinderFromTankServiceProvider);
    switch (action) {
      case _TankGearAction.add:
        await showCylindersFromTanksSheet(context, [
          proposalForTank(TankRef(diveId: dive.id, tank: tank)),
        ]);
        return;
      case _TankGearAction.link:
        final item = await showOwnCylinderPicker(
          context,
          hideSpare: false,
          hint: context.l10n.diveLog_tank_linkCylinderHint,
        );
        if (item == null) return;
        try {
          // False when the tank was linked elsewhere while the picker was
          // open: that link stands, and the diver is told this one did not.
          final linked = await service.linkTank(
            diveId: dive.id,
            tankId: tank.id,
            equipmentId: item.id,
          );
          if (!linked) messenger?.showSnackBar(SnackBar(content: Text(failed)));
        } catch (_) {
          messenger?.showSnackBar(SnackBar(content: Text(failed)));
        }
      case _TankGearAction.unlink:
        try {
          // False when the tank was relinked since the menu opened: the
          // newer link stands, and the diver is told this one did not change.
          final unlinked = await service.unlinkTank(
            tankId: tank.id,
            equipmentId: tank.equipmentId!,
          );
          if (!unlinked) {
            messenger?.showSnackBar(SnackBar(content: Text(failed)));
          }
        } catch (_) {
          messenger?.showSnackBar(SnackBar(content: Text(failed)));
        }
    }
  }
}
