import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which of the diver's cylinders a blend is for: a tank from their gear, or
/// its tag scanned. Only an own cylinder can be logged or filled in, so a
/// foreign tag or text that is not a tag says so and resolves null.
Future<EquipmentItem?> showBlenderCylinderPicker(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final tanks = [
    for (final e in await ref.read(activeEquipmentProvider.future))
      if (e.type == EquipmentType.tank) e,
  ];
  if (!context.mounted) return null;
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
    case OwnCylinder(:final equipmentId):
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
