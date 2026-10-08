import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/import_tag_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('pickBlenderCylinderSpecs');

/// Which of the diver's cylinders a blend is for: a tank from their gear, or
/// its tag scanned. Only an own cylinder can be logged or filled in, so a
/// foreign tag or text that is not a tag says so and resolves null.
///
/// [allowScan] hides the "Scan tag" choice: a scan imports the tag's newest
/// fill into the cylinder's history as a side effect (spec section 11), which
/// fits picking the start cylinder or logging a fill, but not a spot that
/// only wants the water volume or working pressure for a cost line.
///
/// Without the scan and with no tanks in the gear there is nothing to pick,
/// so the sheet is not opened at all: [onNoTanks] is called instead and the
/// picker resolves null.
Future<EquipmentItem?> showBlenderCylinderPicker(
  BuildContext context,
  WidgetRef ref, {
  bool allowScan = true,
  VoidCallback? onNoTanks,
}) async {
  final l10n = context.l10n;
  final tanks = [
    for (final e in await ref.read(activeEquipmentProvider.future))
      if (e.type == EquipmentType.tank) e,
  ];
  if (!context.mounted) return null;
  if (tanks.isEmpty && !allowScan) {
    onNoTanks?.call();
    return null;
  }
  final choice = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            l10n.gasCalculators_blender_chooseCylinder,
            style: Theme.of(sheetContext).textTheme.titleMedium,
          ),
        ),
        for (final tank in tanks)
          ListTile(
            leading: const Icon(Icons.propane_tank_outlined),
            title: Text(tank.name),
            onTap: () => Navigator.pop(sheetContext, tank),
          ),
        if (allowScan)
          ListTile(
            key: const Key('blender-scan-tag'),
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(l10n.gasCalculators_blender_scanTag),
            onTap: () => Navigator.pop(sheetContext, _scan),
          ),
      ],
    ),
  );
  if (choice is EquipmentItem) return choice;
  if (choice != _scan || !context.mounted) return null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return null;
  switch (await resolveScannedTag(ref, text)) {
    case OwnCylinder(:final equipmentId, :final tag):
      // Every tag the app opens is checked for a fill (spec section 11), so
      // a newer fill from the diver's other phone sets the start mix.
      await importTagFill(ref, tag: tag, equipmentId: equipmentId);
      return ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(equipmentId);
    case ForeignCylinder():
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.gasCalculators_blender_notYourCylinder)),
      );
      return null;
    case NotACylinderTag():
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
      );
      return null;
  }
}

/// The picker's Scan tag choice, told apart from a tank.
const _scan = #scan;

/// A tank [pickBlenderCylinderSpecs] resolved, with its water volume
/// guaranteed present -- the one field every call site needs, carried in the
/// type instead of a convention callers have to trust.
typedef BlenderCylinderSpecs = ({EquipmentItem tank, double volumeL});

/// Picks one of the diver's own tanks for its water volume and working
/// pressure (issue #2926), without the tag scan: a spot that only wants a
/// number for a cost line or a billed gas, not a fill to log. Handles the
/// picker's failure, an empty gear list (pointing the diver at the
/// free-text field instead) and the "no volume recorded" case itself, with
/// the same wording at every call site, and resolves null when nothing
/// usable was picked.
///
/// [onMessage] receives that feedback instead of a snackbar. A caller that is
/// itself a modal sheet needs it: the page's [ScaffoldMessenger] would draw
/// the snackbar underneath the sheet, out of sight.
Future<BlenderCylinderSpecs?> pickBlenderCylinderSpecs(
  BuildContext context,
  WidgetRef ref, {
  void Function(String message)? onMessage,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  void report(String message) {
    if (onMessage != null) {
      onMessage(message);
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  EquipmentItem? tank;
  try {
    tank = await showBlenderCylinderPicker(
      context,
      ref,
      allowScan: false,
      onNoTanks: () => report(l10n.gasCalculators_blender_noCylinders),
    );
  } catch (e, stackTrace) {
    _log.error(
      'Failed to choose a cylinder for its specs',
      error: e,
      stackTrace: stackTrace,
    );
    report(l10n.gasCalculators_blender_cylinderFailed);
    return null;
  }
  if (tank == null || !context.mounted) return null;
  final volumeL = tank.volumeL;
  if (volumeL == null) {
    report(l10n.gasCalculators_blender_cylinderNoVolume(tank.name));
    return null;
  }
  return (tank: tank, volumeL: volumeL);
}
