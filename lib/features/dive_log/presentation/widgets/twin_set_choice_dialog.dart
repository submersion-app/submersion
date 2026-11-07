import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a dive tank picked from a linked cylinder is (issue #4242).
enum TwinSetChoice { twinSet, single }

/// Asks whether a tank picked from [pickedName], linked with [partnerName],
/// is the twin set ([combinedVolume] between them) or that cylinder alone.
/// [partnerStatus] names a partner away from the pair (sold, in service).
/// Null when the diver backs out, which cancels the pick.
Future<TwinSetChoice?> showTwinSetChoiceDialog(
  BuildContext context, {
  required String pickedName,
  required String partnerName,
  required String combinedVolume,
  String? partnerStatus,
}) {
  final l10n = context.l10n;
  return showDialog<TwinSetChoice>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.twinSet_choiceTitle),
      children: [
        if (partnerStatus != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l10n.twinSet_partnerStatus(partnerName, partnerStatus)),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, TwinSetChoice.twinSet),
          child: Text(
            l10n.twinSet_choicePair(pickedName, partnerName, combinedVolume),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, TwinSetChoice.single),
          child: Text(l10n.twinSet_choiceSingle(pickedName)),
        ),
      ],
    ),
  );
}

/// The pair's volume in liters, or null when either cylinder has none.
double? twinPairVolume(EquipmentItem a, EquipmentItem b) {
  final va = a.volumeL;
  final vb = b.volumeL;
  return va == null || vb == null ? null : va + vb;
}

/// The lower of two working pressures: the pair fills to one pressure, and
/// cannot hold more than its weaker cylinder. Either alone when the other is
/// unknown.
double? twinPairWorkingPressure(EquipmentItem a, EquipmentItem b) {
  final pa = a.workingPressureBar;
  final pb = b.workingPressureBar;
  if (pa == null) return pb;
  if (pb == null) return pa;
  return pa < pb ? pa : pb;
}

/// Asks whether a tank picked from [picked], linked with [partner], is the
/// twin set or [picked] alone, with the pair's volume in the diver's units.
Future<TwinSetChoice?> askTwinSetChoice(
  BuildContext context,
  UnitFormatter units, {
  required EquipmentItem picked,
  required EquipmentItem partner,
}) {
  final status = partner.effectiveStatus;
  return showTwinSetChoiceDialog(
    context,
    pickedName: picked.name,
    partnerName: partner.name,
    combinedVolume: units.formatTankVolume(
      twinPairVolume(picked, partner),
      twinPairWorkingPressure(picked, partner),
    ),
    partnerStatus: isPartnerOutOfUse(status)
        ? status.localizedName(context.l10n)
        : null,
  );
}
