import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A null result cancels packing. A result with no bag keeps the gear loose.
Future<({String? bagId})?> pickTripBag(
  BuildContext context,
  List<EquipmentItem> bags, {
  String? currentBagId,
}) => showDialog<({String? bagId})>(
  context: context,
  builder: (dialog) => SimpleDialog(
    title: Text(dialog.l10n.trips_bags_choose),
    children: [
      for (final bag in bags)
        SimpleDialogOption(
          onPressed: () => Navigator.of(dialog).pop((bagId: bag.id)),
          child: Text(
            bag.name,
            style: bag.id == currentBagId
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
        ),
      SimpleDialogOption(
        onPressed: () => Navigator.of(dialog).pop((bagId: null)),
        child: Text(dialog.l10n.trips_bags_none),
      ),
    ],
  ),
);
