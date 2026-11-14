import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The stored value of an item's `figure_position` attribute per zone
/// (issue #4493). Kept apart from the enum's names so renaming a zone never
/// rewrites what a diver saved. The catalog's choice keys match these.
const Map<FigureZone, String> figurePositionKeys = {
  FigureZone.mouth: 'mouth',
  FigureZone.octo: 'octo',
  FigureZone.chestClipLeft: 'chest_left',
  FigureZone.chestClipRight: 'chest_right',
  FigureZone.console: 'console',
  FigureZone.wristLeft: 'wrist_left',
  FigureZone.wristRight: 'wrist_right',
  FigureZone.handLeft: 'hand_left',
  FigureZone.handRight: 'hand_right',
  FigureZone.hipLeft: 'hip_left',
  FigureZone.hipRight: 'hip_right',
  FigureZone.thighLeft: 'thigh_left',
  FigureZone.thighRight: 'thigh_right',
  FigureZone.calfLeft: 'calf_left',
  FigureZone.backTank: 'back',
  FigureZone.trimLeft: 'trim_left',
  FigureZone.trimRight: 'trim_right',
  FigureZone.buttDRing: 'butt_d_ring',
  FigureZone.sidemountLeft: 'sidemount_left',
  FigureZone.sidemountRight: 'sidemount_right',
  FigureZone.stageLeft: 'stage_left',
  FigureZone.stageRight: 'stage_right',
};

/// The zone a stored `figure_position` names, or null for none or a value
/// this version does not know.
FigureZone? figurePositionZone(String? key) =>
    key == null ? null : _zoneByKey[key];

final Map<String, FigureZone> _zoneByKey = {
  for (final e in figurePositionKeys.entries) e.value: e.key,
};

/// The zones a cylinder's `worn_as` choice sends it to, the named side
/// first so a full side still lands the tank on the other one.
List<FigureZone> wornAsZones(String? wornAs) => switch (wornAs) {
  'back' => const [FigureZone.backTank],
  'sidemount_left' => const [
    FigureZone.sidemountLeft,
    FigureZone.sidemountRight,
  ],
  'sidemount_right' => const [
    FigureZone.sidemountRight,
    FigureZone.sidemountLeft,
  ],
  'stage' => const [FigureZone.stageLeft, FigureZone.stageRight],
  _ => const [],
};

/// The spots the diver can move an item of [type] to: every zone it has
/// artwork for, in either kind of rig, keeping one zone per distinct
/// drawing. Artwork is authored in place and a zone only adds a mirror
/// flip, so two zones with the same pieces and the same flip look alike
/// (a vest over or under the suit), and offering both would change
/// nothing. Empty when there is no real choice.
List<FigureZone> pickableFigureZones(
  EquipmentType type,
  Map<String, String?> attributes,
) {
  final specs = [
    FigurePlacement.forType(type, attributes: attributes),
    FigurePlacement.forType(
      type,
      attributes: attributes,
      context: const FigureContext(sidemountRig: true),
    ),
  ];
  final seen = <String>{};
  final zones = <FigureZone>[];
  for (final spec in specs) {
    for (final zone in [...spec.zones, ...spec.piecesByZone.keys]) {
      final pieces = spec.piecesFor(zone);
      if (pieces.isEmpty) continue;
      if (seen.add('${pieces.join('+')}|${zone.mirrored}')) zones.add(zone);
    }
  }
  return zones.length < 2 ? const [] : zones;
}
