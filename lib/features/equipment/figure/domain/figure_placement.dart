import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Default artwork colours per type, ARGB. A diver's own colour attribute
/// (phase 3) replaces these per item.
abstract final class FigureColors {
  static const int black = 0xFF2A2A2E;
  static const int metal = 0xFF9AA3AD;
  static const int aluminium = 0xFFC9CED4;
  static const int steel = 0xFF5B6470;
  static const int darkBlue = 0xFF1F3A5F;
  static const int darkGrey = 0xFF3A3F47;
  static const int midGrey = 0xFF7A8088;
  static const int lightGrey = 0xFFB8BEC6;
  static const int yellow = 0xFFF4C542;
  static const int orange = 0xFFF28C28;
}

/// What the composer already knows about the whole set when it places one
/// item: today only whether the rig is sidemount.
class FigureContext {
  const FigureContext({this.sidemountRig = false});

  final bool sidemountRig;
}

/// Where one type of gear may sit and what to draw there.
class FigurePlacementSpec {
  const FigurePlacementSpec({
    required this.zones,
    this.piecesByZone = const {},
    required this.defaultColor,
    this.occupies = 1,
  });

  /// Candidate zones in preference order. Empty means the tray.
  final List<FigureZone> zones;

  /// Artwork per zone, one piece per view drawn. A zone may be present here
  /// without being a candidate (a tank keeps its back artwork in a sidemount
  /// rig, because a dive tank role can still put it there).
  final Map<FigureZone, List<String>> piecesByZone;

  /// ARGB, used when the item carries no colour attribute.
  final int defaultColor;

  /// Slots consumed in the zone the item lands in. A back-mounted rebreather
  /// fills the whole back tank zone.
  final int occupies;

  bool get isTray => zones.isEmpty;

  List<String> piecesFor(FigureZone zone) => piecesByZone[zone] ?? const [];
}

/// The table from equipment type to body zone and artwork (spec section 4.2).
abstract final class FigurePlacement {
  /// Types that live inside another item; drawn only as their parent.
  static const Set<EquipmentType> childTypes = {
    EquipmentType.o2Cell,
    EquipmentType.battery,
  };

  /// Types with no place on the body. They are numbered in the tray.
  static const Set<EquipmentType> trayTypes = {
    EquipmentType.hose,
    EquipmentType.tankBand,
    EquipmentType.tool,
    EquipmentType.o2Cell,
    EquipmentType.battery,
    EquipmentType.other,
  };

  // Choice keys the catalog declares as literals rather than constants.
  static const String _mount = 'mount';
  static const String _mountConfiguration = 'mount_configuration';
  static const String _pocketMount = 'pocket_mount';

  /// Every attribute combination the table reacts to, for tests that need
  /// to reach every variant.
  static const List<Map<String, String?>> variantAttributeSets = [
    {},
    {EquipmentAttrKeys.bcdStyle: 'back_inflate'},
    {EquipmentAttrKeys.bcdStyle: 'wing'},
    {EquipmentAttrKeys.bcdStyle: 'sidemount'},
    {_mount: 'wrist'},
    {_mount: 'console'},
    {_mount: 'hud'},
    {_mountConfiguration: 'chest'},
    {_mountConfiguration: 'sidemount'},
    {EquipmentAttrKeys.weightStyle: 'integrated'},
    {EquipmentAttrKeys.weightStyle: 'trim'},
    {EquipmentAttrKeys.weightStyle: 'ankle'},
    {_pocketMount: 'thigh'},
    {_pocketMount: 'waist_belt'},
    {EquipmentAttrKeys.tankMaterial: 'steel'},
  ];

  static bool contributesSidemountRig(
    EquipmentType type,
    Map<String, String?> attributes,
  ) =>
      (type == EquipmentType.bcd &&
          attributes[EquipmentAttrKeys.bcdStyle] == 'sidemount') ||
      (type == EquipmentType.rebreather &&
          attributes[_mountConfiguration] == 'sidemount');

  static FigurePlacementSpec forType(
    EquipmentType type, {
    Map<String, String?> attributes = const {},
    FigureContext context = const FigureContext(),
  }) {
    switch (type) {
      case EquipmentType.regulator:
      case EquipmentType.secondStage:
        return const FigurePlacementSpec(
          zones: [FigureZone.mouth, FigureZone.octo],
          piecesByZone: {
            FigureZone.mouth: ['regulator_mouth_front'],
            FigureZone.octo: ['regulator_octo_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.firstStage:
        return const FigurePlacementSpec(
          zones: [FigureZone.tankValve],
          piecesByZone: {
            FigureZone.tankValve: ['firststage_back'],
          },
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.transmitter:
        return const FigurePlacementSpec(
          zones: [FigureZone.tankValve],
          piecesByZone: {
            FigureZone.tankValve: ['transmitter_back'],
          },
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.bcd:
        // Worn on the back (the straps show in front), so every style is
        // labelled on the back view and shares the wing's zone: a rig has a
        // BCD or a wing, and a second one goes to the tray.
        final pieces = switch (attributes[EquipmentAttrKeys.bcdStyle]) {
          'back_inflate' ||
          'wing' => const ['bcd_harness_front', 'bcd_wing_back'],
          'sidemount' => const ['bcd_sidemount_front', 'bcd_sidemount_back'],
          _ => const ['bcd_jacket_front', 'bcd_jacket_back'],
        };
        return FigurePlacementSpec(
          zones: const [FigureZone.wing],
          piecesByZone: {FigureZone.wing: pieces},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.harness:
        return const FigurePlacementSpec(
          zones: [FigureZone.torsoFront],
          piecesByZone: {
            FigureZone.torsoFront: ['bcd_harness_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.backplate:
        return const FigurePlacementSpec(
          zones: [FigureZone.backplate],
          piecesByZone: {
            FigureZone.backplate: ['backplate_back'],
          },
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.wing:
        return const FigurePlacementSpec(
          zones: [FigureZone.wing],
          piecesByZone: {
            FigureZone.wing: ['bcd_wing_back'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.weightPocket:
        if (attributes[EquipmentAttrKeys.weightStyle] == 'trim') {
          return const FigurePlacementSpec(
            zones: [FigureZone.trimLeft, FigureZone.trimRight],
            piecesByZone: {
              FigureZone.trimLeft: ['weights_trim_back'],
              FigureZone.trimRight: ['weights_trim_back'],
            },
            defaultColor: FigureColors.black,
          );
        }
        return const FigurePlacementSpec(
          zones: [FigureZone.hipLeft, FigureZone.hipRight],
          piecesByZone: {
            FigureZone.hipLeft: ['weightpocket_hip_front'],
            FigureZone.hipRight: ['weightpocket_hip_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.gearPocket:
        switch (attributes[_pocketMount]) {
          case 'thigh':
            return const FigurePlacementSpec(
              zones: [FigureZone.thighLeft, FigureZone.thighRight],
              piecesByZone: {
                FigureZone.thighLeft: ['pocket_thigh_front'],
                FigureZone.thighRight: ['pocket_thigh_front'],
              },
              defaultColor: FigureColors.black,
            );
          case 'waist_belt':
            return const FigurePlacementSpec(
              zones: [FigureZone.waist],
              piecesByZone: {
                FigureZone.waist: ['pocket_waist_front'],
              },
              defaultColor: FigureColors.black,
            );
          default:
            return const FigurePlacementSpec(
              zones: [FigureZone.hipLeft, FigureZone.hipRight],
              piecesByZone: {
                FigureZone.hipLeft: ['pocket_hip_front'],
                FigureZone.hipRight: ['pocket_hip_front'],
              },
              defaultColor: FigureColors.black,
            );
        }
      case EquipmentType.wetsuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.suit],
          piecesByZone: {
            FigureZone.suit: ['wetsuit_front', 'wetsuit_back'],
          },
          defaultColor: FigureColors.darkBlue,
        );
      case EquipmentType.drysuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.suit],
          piecesByZone: {
            FigureZone.suit: ['drysuit_front', 'drysuit_back'],
          },
          defaultColor: FigureColors.darkGrey,
        );
      case EquipmentType.undersuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer],
          piecesByZone: {
            FigureZone.underlayer: ['undersuit_front', 'undersuit_back'],
          },
          defaultColor: FigureColors.midGrey,
        );
      case EquipmentType.baselayer:
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer],
          piecesByZone: {
            FigureZone.underlayer: ['baselayer_front', 'baselayer_back'],
          },
          defaultColor: FigureColors.lightGrey,
        );
      case EquipmentType.rashGuard:
        // Underlayer first: the canonical order places a rash guard before
        // the suits, so preferring the suit zone would steal it from a
        // wetsuit in the same set.
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer, FigureZone.suit],
          piecesByZone: {
            FigureZone.suit: ['rashguard_front', 'rashguard_back'],
            FigureZone.underlayer: ['rashguard_front', 'rashguard_back'],
          },
          defaultColor: FigureColors.darkBlue,
        );
      case EquipmentType.hood:
        return const FigurePlacementSpec(
          zones: [FigureZone.head],
          piecesByZone: {
            FigureZone.head: ['hood_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.gloves:
        return const FigurePlacementSpec(
          zones: [FigureZone.hands],
          piecesByZone: {
            FigureZone.hands: ['gloves_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.boots:
        return const FigurePlacementSpec(
          zones: [FigureZone.feet],
          piecesByZone: {
            FigureZone.feet: ['boots_front', 'boots_back'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.fins:
        return const FigurePlacementSpec(
          zones: [FigureZone.fins],
          piecesByZone: {
            FigureZone.fins: ['fins_front', 'fins_back'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.mask:
        return const FigurePlacementSpec(
          zones: [FigureZone.face],
          piecesByZone: {
            FigureZone.face: ['mask_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.snorkel:
        return const FigurePlacementSpec(
          zones: [FigureZone.maskStrap],
          piecesByZone: {
            FigureZone.maskStrap: ['snorkel_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.computer:
        return switch (attributes[_mount]) {
          'console' => const FigurePlacementSpec(
            zones: [FigureZone.console],
            piecesByZone: {
              FigureZone.console: ['computer_console_front'],
            },
            defaultColor: FigureColors.black,
          ),
          'hud' => const FigurePlacementSpec(
            zones: [FigureZone.hud],
            piecesByZone: {
              FigureZone.hud: ['computer_hud_front'],
            },
            defaultColor: FigureColors.black,
          ),
          _ => const FigurePlacementSpec(
            zones: [FigureZone.wristLeft, FigureZone.wristRight],
            piecesByZone: {
              FigureZone.wristLeft: ['computer_wrist_front'],
              FigureZone.wristRight: ['computer_wrist_front'],
            },
            defaultColor: FigureColors.black,
          ),
        };
      case EquipmentType.instrument:
        final wristFirst = attributes[_mount] == 'wrist';
        return FigurePlacementSpec(
          zones: wristFirst
              ? const [
                  FigureZone.wristLeft,
                  FigureZone.wristRight,
                  FigureZone.console,
                ]
              : const [
                  FigureZone.console,
                  FigureZone.wristLeft,
                  FigureZone.wristRight,
                ],
          piecesByZone: const {
            FigureZone.console: ['computer_console_front'],
            FigureZone.wristLeft: ['computer_wrist_front'],
            FigureZone.wristRight: ['computer_wrist_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.compass:
        if (attributes[_mount] == 'console') {
          return const FigurePlacementSpec(
            zones: [FigureZone.console],
            piecesByZone: {
              FigureZone.console: ['computer_console_front'],
            },
            defaultColor: FigureColors.black,
          );
        }
        return const FigurePlacementSpec(
          zones: [FigureZone.wristRight, FigureZone.wristLeft],
          piecesByZone: {
            FigureZone.wristRight: ['compass_wrist_front'],
            FigureZone.wristLeft: ['compass_wrist_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.tank:
        return FigurePlacementSpec(
          zones: context.sidemountRig
              ? const [
                  FigureZone.sidemountLeft,
                  FigureZone.sidemountRight,
                  FigureZone.stageLeft,
                  FigureZone.stageRight,
                ]
              : const [
                  FigureZone.backTank,
                  FigureZone.stageLeft,
                  FigureZone.stageRight,
                ],
          piecesByZone: const {
            FigureZone.backTank: ['tank_single_back'],
            FigureZone.sidemountLeft: ['tank_sidemount_back'],
            FigureZone.sidemountRight: ['tank_sidemount_back'],
            FigureZone.stageLeft: ['tank_stage_front'],
            FigureZone.stageRight: ['tank_stage_front'],
          },
          defaultColor: attributes[EquipmentAttrKeys.tankMaterial] == 'steel'
              ? FigureColors.steel
              : FigureColors.aluminium,
        );
      case EquipmentType.rebreather:
        return switch (attributes[_mountConfiguration]) {
          'chest' => const FigurePlacementSpec(
            zones: [FigureZone.chest],
            piecesByZone: {
              FigureZone.chest: ['rebreather_chest_front'],
            },
            defaultColor: FigureColors.black,
          ),
          'sidemount' => const FigurePlacementSpec(
            zones: [FigureZone.sidemountLeft],
            piecesByZone: {
              FigureZone.sidemountLeft: ['rebreather_sidemount_back'],
            },
            defaultColor: FigureColors.black,
          ),
          _ => const FigurePlacementSpec(
            zones: [FigureZone.backTank],
            piecesByZone: {
              FigureZone.backTank: ['rebreather_back_back'],
            },
            defaultColor: FigureColors.black,
            occupies: 2,
          ),
        };
      case EquipmentType.weights:
        return switch (attributes[EquipmentAttrKeys.weightStyle]) {
          'integrated' => const FigurePlacementSpec(
            zones: [FigureZone.hipLeft, FigureZone.hipRight],
            piecesByZone: {
              FigureZone.hipLeft: ['weights_integrated_front'],
              FigureZone.hipRight: ['weights_integrated_front'],
            },
            defaultColor: FigureColors.black,
          ),
          'trim' => const FigurePlacementSpec(
            zones: [FigureZone.trimLeft, FigureZone.trimRight],
            piecesByZone: {
              FigureZone.trimLeft: ['weights_trim_back'],
              FigureZone.trimRight: ['weights_trim_back'],
            },
            defaultColor: FigureColors.black,
          ),
          'ankle' => const FigurePlacementSpec(
            zones: [FigureZone.ankles],
            piecesByZone: {
              FigureZone.ankles: ['weights_ankle_front'],
            },
            defaultColor: FigureColors.black,
          ),
          _ => const FigurePlacementSpec(
            zones: [FigureZone.waist],
            piecesByZone: {
              FigureZone.waist: ['weights_belt_front'],
            },
            defaultColor: FigureColors.black,
          ),
        };
      case EquipmentType.light:
        return const FigurePlacementSpec(
          zones: [
            FigureZone.handLeft,
            FigureZone.chestClipLeft,
            FigureZone.chestClipRight,
          ],
          piecesByZone: {
            FigureZone.handLeft: ['light_hand_front'],
            FigureZone.chestClipLeft: ['light_clip_front'],
            FigureZone.chestClipRight: ['light_clip_front'],
          },
          defaultColor: FigureColors.yellow,
        );
      case EquipmentType.camera:
        return const FigurePlacementSpec(
          zones: [FigureZone.handRight, FigureZone.handLeft],
          piecesByZone: {
            FigureZone.handRight: ['camera_hand_front'],
            FigureZone.handLeft: ['camera_hand_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.housing:
        return const FigurePlacementSpec(
          zones: [FigureZone.handRight],
          piecesByZone: {
            FigureZone.handRight: ['housing_hand_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.strobe:
        return const FigurePlacementSpec(
          zones: [FigureZone.cameraArm],
          piecesByZone: {
            FigureZone.cameraArm: ['strobe_arm_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.smb:
        return const FigurePlacementSpec(
          zones: [FigureZone.buttDRing, FigureZone.thighLeft],
          piecesByZone: {
            FigureZone.buttDRing: ['smb_butt_back'],
            FigureZone.thighLeft: ['smb_thigh_front'],
          },
          defaultColor: FigureColors.orange,
        );
      case EquipmentType.reel:
        return const FigurePlacementSpec(
          zones: [FigureZone.buttDRing, FigureZone.hipRight],
          piecesByZone: {
            FigureZone.buttDRing: ['reel_butt_back'],
            FigureZone.hipRight: ['reel_hip_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.knife:
        return const FigurePlacementSpec(
          zones: [FigureZone.calfLeft, FigureZone.hipLeft],
          piecesByZone: {
            FigureZone.calfLeft: ['knife_calf_front'],
            FigureZone.hipLeft: ['knife_hip_front'],
          },
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.dpv:
        return const FigurePlacementSpec(
          zones: [FigureZone.dpv],
          piecesByZone: {
            FigureZone.dpv: ['dpv_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.hose:
      case EquipmentType.tankBand:
        return const FigurePlacementSpec(
          zones: [],
          defaultColor: FigureColors.black,
        );
      case EquipmentType.tool:
      case EquipmentType.o2Cell:
      case EquipmentType.battery:
        return const FigurePlacementSpec(
          zones: [],
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.other:
        return const FigurePlacementSpec(
          zones: [],
          defaultColor: FigureColors.midGrey,
        );
    }
  }
}
