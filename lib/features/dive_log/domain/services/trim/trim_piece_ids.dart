/// The trim figure's side-view drawings for a gear-figure drawing (issue
/// #5028).
///
/// Gear is placed by the gear figure's composer, which also picks each
/// item's drawing from its type and attributes (BCD style, computer mount,
/// pocket mount and so on). The side view follows that choice: a front or
/// back piece id names its side pieces here, so both figures draw the same
/// variant. Suits and layers that cross a joint have one piece per moving
/// part.
List<String> trimPieceIdsForGearPieces(
  List<String> figurePieceIds, {
  bool shorty = false,
}) {
  final out = <String>[];
  for (final id in figurePieceIds) {
    final base = id.replaceFirst(RegExp(r'_(front|back)$'), '');
    final side = base == 'wetsuit' && shorty
        ? _shortyWetsuit
        : _sidePieces[base] ?? const <String>[];
    for (final s in side) {
      if (!out.contains(s)) out.add(s);
    }
  }
  return out;
}

const _shortyWetsuit = ['wetsuit_shorty_side_torso', 'wetsuit_shorty_side_arm'];

const Map<String, List<String>> _sidePieces = {
  'backplate': ['backplate_side'],
  'baselayer': [
    'baselayer_side_torso',
    'baselayer_side_arm',
    'baselayer_side_shin',
  ],
  'bcd_harness': ['harness_side'],
  'bcd_jacket': ['bcd_jacket_side'],
  'bcd_sidemount': ['bcd_sidemount_side'],
  'bcd_wing': ['bcd_wing_side'],
  'boots': ['boots_side'],
  'camera_hand': ['camera_side'],
  'compass_wrist': ['compass_wrist_side'],
  'computer_console': ['computer_console_side'],
  'computer_hud': ['computer_hud_side'],
  'computer_wrist': ['computer_wrist_side'],
  'dpv': ['dpv_side'],
  'drysuit': [
    'drysuit_side_torso',
    'drysuit_side_arm',
    'drysuit_side_shin',
    'drysuit_side_foot',
  ],
  'fins': ['fins_side'],
  'firststage': ['firststage_side'],
  'gloves': ['gloves_side'],
  'hood': ['hood_side'],
  'housing_hand': ['housing_side'],
  'knife_calf': ['knife_calf_side'],
  'knife_hip': ['knife_hip_side'],
  'light_clip': ['light_clip_side'],
  'light_hand': ['light_hand_side'],
  'mask': ['mask_side'],
  'pocket_hip': ['pocket_hip_side'],
  'pocket_thigh': ['pocket_thigh_side'],
  'pocket_waist': ['pocket_waist_side'],
  'rashguard': ['rashguard_side_torso', 'rashguard_side_arm'],
  'rebreather_back': ['rebreather_back_side'],
  'rebreather_chest': ['rebreather_chest_side'],
  'rebreather_sidemount': ['rebreather_sidemount_side'],
  'reel_butt': ['reel_butt_side'],
  'reel_hip': ['reel_hip_side'],
  'regulator_mouth': ['regulator_mouth_side'],
  'regulator_octo': ['regulator_octo_side'],
  'smb_butt': ['smb_butt_side'],
  'smb_thigh': ['smb_thigh_side'],
  'snorkel': ['snorkel_side'],
  'socks': ['socks_side'],
  'strobe_arm': ['strobe_side'],
  'tank_doubles': ['tank_doubles_side'],
  'tank_sidemount': ['tank_sidemount_side'],
  'tank_single': ['tank_single_side'],
  'tank_stage': ['tank_stage_side'],
  'transmitter': ['transmitter_side'],
  'undersuit': [
    'undersuit_side_torso',
    'undersuit_side_arm',
    'undersuit_side_shin',
  ],
  'vest': ['vest_side'],
  'weightpocket_hip': ['weightpocket_side'],
  'weights_ankle': ['weights_ankle_side'],
  'weights_belt': ['weights_belt_side'],
  'weights_integrated': ['weights_hip_side'],
  'weights_trim': ['weights_trim_side'],
  'wetsuit': ['wetsuit_side_torso', 'wetsuit_side_arm', 'wetsuit_side_shin'],
};
