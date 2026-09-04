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
/// suits shared one hanger. Eleven shapes that no icon font has are now drawn in
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
    // The drysuit layers (#1537) share the wardrobe family without sharing a
    // glyph: the undersuit is the suit silhouette quilted, the base layer a
    // short-bodied top that cannot be mistaken for a suit at 20px.
    case EquipmentType.undersuit:
      return SubmersionIcons.undersuit;
    case EquipmentType.baselayer:
      return SubmersionIcons.baselayer;
    // A crew-neck shirt: the warm-water top, drawn from the bundled MDI font
    // rather than the wardrobe family, so it does not read as a third layer.
    case EquipmentType.rashGuard:
      return MdiIcons.tshirtCrew;
    case EquipmentType.mask:
      return MdiIcons.divingScubaMask;
    case EquipmentType.fins:
      return MdiIcons.divingFlippers;
    case EquipmentType.snorkel:
      return MdiIcons.divingSnorkel;
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
    // A needle gauge covers the whole analog family the type stands for: SPG,
    // depth gauge, bottom timer, console.
    case EquipmentType.instrument:
      return MdiIcons.gauge;
    case EquipmentType.compass:
      return MdiIcons.compass;
    case EquipmentType.light:
      return Icons.flashlight_on;
    case EquipmentType.camera:
      return Icons.camera_alt;
    case EquipmentType.knife:
      return MdiIcons.knifeMilitary;
    // Crossed screwdriver and wrench: a save-a-dive kit, not one wrench, which
    // is what `other` used to show.
    case EquipmentType.tool:
      return MdiIcons.tools;
    // A diver-down flag rather than a literal sausage buoy: it is the closest
    // dive-domain shape in the bundled font, and it beats a generic pennant.
    case EquipmentType.smb:
      return MdiIcons.divingScubaFlag;
    case EquipmentType.reel:
      return SubmersionIcons.reel;
    case EquipmentType.dpv:
      return SubmersionIcons.dpv;
    // A wrench until #1518, when Tool became a type of its own and the two
    // would have read as the same idea. The catch-all now says catch-all.
    case EquipmentType.other:
      return Icons.category;
  }
}
