import 'package:flutter/material.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/icons/submersion_icons.dart';

/// The glyph that stands for [type] everywhere it appears: the equipment list,
/// the equipment detail header, the dive-edit gear row, and the equipment
/// picker sheet.
///
/// The switch is exhaustive on purpose. Four copies of this mapping used to
/// live in those four files, two of them ending in a generic fallback, so a
/// new equipment type silently rendered as a backpack in half the app while
/// the compiler stayed quiet. With no default arm, the next type added to
/// [EquipmentType] is a build error here instead.
///
/// Issue #1189 reported that the glyphs "don't really fit the equipment": most
/// types pointed at a metaphor rather than the object, and the two exposure
/// suits shared one hanger. Ten shapes that no icon font has are now drawn in
/// [SubmersionIcons]; five more moved to dive glyphs that were already present
/// in the bundled Material Design Icons font but never exposed.
IconData equipmentTypeIcon(EquipmentType type) {
  switch (type) {
    case EquipmentType.regulator:
      return SubmersionIcons.regulator;
    case EquipmentType.bcd:
      return SubmersionIcons.bcd;
    // The two suits share a silhouette but not a glyph: the drysuit carries
    // the attached hood and boots that distinguish it in the water.
    case EquipmentType.wetsuit:
      return SubmersionIcons.wetsuit;
    case EquipmentType.drysuit:
      return SubmersionIcons.drysuit;
    case EquipmentType.mask:
      return MdiIcons.divingScubaMask;
    case EquipmentType.fins:
      return MdiIcons.divingFlippers;
    case EquipmentType.boots:
      return SubmersionIcons.boots;
    case EquipmentType.gloves:
      return SubmersionIcons.gloves;
    case EquipmentType.hood:
      return SubmersionIcons.hood;
    case EquipmentType.tank:
      return MdiIcons.divingScubaTank;
    case EquipmentType.rebreather:
      return SubmersionIcons.rebreather;
    case EquipmentType.transmitter:
      return Icons.sensors;
    case EquipmentType.weights:
      return MdiIcons.weight;
    case EquipmentType.computer:
      return Icons.watch;
    case EquipmentType.light:
      return Icons.flashlight_on;
    case EquipmentType.camera:
      return Icons.camera_alt;
    case EquipmentType.knife:
      return MdiIcons.knifeMilitary;
    // A diver-down flag rather than a literal sausage buoy: it is the closest
    // dive-domain shape in the bundled font, and it beats a generic pennant.
    case EquipmentType.smb:
      return MdiIcons.divingScubaFlag;
    case EquipmentType.reel:
      return SubmersionIcons.reel;
    case EquipmentType.dpv:
      return SubmersionIcons.dpv;
    case EquipmentType.other:
      return Icons.build;
  }
}
