import 'package:submersion/core/constants/enums.dart';

import '../story/story_plan.dart';
import 'gear_assemblies.dart';
import 'gear_regulators.dart';

/// What a piece of kit is taken on: the kit for each dive picks from these.
/// [warm] is water of 26 degrees or more, [temperate] 14 to 26, [cold]
/// below 14 (a drysuit). [spare] items only stand in for a missing one.
enum KitUse {
  always,
  warm,
  temperate,
  cold,
  tech,
  ccr,
  scooter,
  photo,
  night,
  spare,
}

/// When an item stops being used, and what it is today: sold, lost,
/// retired, lent out, or kept as a spare.
typedef GearDeparture = ({
  StoryMilestone at,
  int offset,
  EquipmentStatus status,
});

/// One piece of the demo diver's kit.
class DemoGear {
  const DemoGear(
    this.key,
    this.name,
    this.type, {
    this.brand,
    this.model,
    this.bought = StoryMilestone.firstDive,
    this.boughtOffset = 0,
    this.leaves,
    this.status = EquipmentStatus.active,
    this.serviceIntervalDays,
    this.travel = false,
    this.size,
    this.attributes = const {},
    this.uses = const {},
    this.replaces,
  });

  final String key;
  final String name;
  final EquipmentType type;
  final String? brand;
  final String? model;

  /// Bought for the dive [boughtOffset] dives after this milestone (a
  /// replacement is bought on the first home day after its predecessor
  /// left).
  final StoryMilestone bought;
  final int boughtOffset;
  final GearDeparture? leaves;

  /// The status today of an item that never leaves.
  final EquipmentStatus status;
  final int? serviceIntervalDays;
  final bool travel;
  final String? size;

  /// Type-specific attributes by `EquipmentAttrKeys` key.
  final Map<String, Object> attributes;
  final Set<KitUse> uses;

  /// The item this one replaced.
  final String? replaces;

  /// Today's status: where it went, or [status].
  EquipmentStatus get currentStatus => leaves?.status ?? status;
}

const _warm = {KitUse.warm};
const _anyWater = {KitUse.warm, KitUse.temperate, KitUse.cold};

/// The kit, bought as the story needs it. Brands and models are real
/// products; they identify nobody.
final demoGear = <DemoGear>[
  // Open Water year.
  const DemoGear(
    'mask',
    'Low-volume mask',
    EquipmentType.mask,
    brand: 'Atomic Aquatics',
    model: 'Venom',
    travel: true,
    uses: {KitUse.always},
    leaves: (at: StoryMilestone.photo, offset: 2, status: EquipmentStatus.lost),
  ),
  const DemoGear(
    'mask-spare',
    'Spare mask',
    EquipmentType.mask,
    brand: 'Cressi',
    model: 'Big Eyes Evolution',
    travel: true,
    status: EquipmentStatus.spare,
    uses: {KitUse.spare},
  ),
  const DemoGear(
    'mask-2',
    'Frameless mask',
    EquipmentType.mask,
    brand: 'Atomic Aquatics',
    model: 'Subframe',
    bought: StoryMilestone.photo,
    boughtOffset: 2,
    replaces: 'mask',
    travel: true,
    uses: {KitUse.always},
  ),
  const DemoGear(
    'snorkel',
    'Folding snorkel',
    EquipmentType.snorkel,
    brand: 'Scubapro',
    model: 'Spectra',
    travel: true,
    uses: _warm,
  ),
  const DemoGear(
    'fins',
    'Travel fins',
    EquipmentType.fins,
    brand: 'Mares',
    model: 'Avanti Quattro+',
    travel: true,
    size: 'L',
    uses: _anyWater,
  ),
  const DemoGear(
    'boots',
    'Neoprene boots',
    EquipmentType.boots,
    brand: 'Mares',
    model: 'Classic NG',
    size: '43',
    uses: {KitUse.warm, KitUse.temperate},
  ),
  const DemoGear(
    'wetsuit-7',
    '7 mm wetsuit',
    EquipmentType.wetsuit,
    brand: 'Waterproof',
    model: 'W4 7mm',
    size: 'L',
    attributes: {'thickness_mm': 7},
    uses: {KitUse.temperate},
  ),
  const DemoGear(
    'hood',
    '5 mm hood',
    EquipmentType.hood,
    brand: 'Waterproof',
    model: 'H1 5/10mm',
    uses: {KitUse.temperate, KitUse.cold},
  ),
  const DemoGear(
    'gloves',
    '5 mm gloves',
    EquipmentType.gloves,
    brand: 'Waterproof',
    model: 'G1 5mm',
    uses: {KitUse.temperate},
  ),
  const DemoGear(
    'bcd-jacket',
    'Jacket BCD',
    EquipmentType.bcd,
    brand: 'Scubapro',
    model: 'Hydros Pro',
    travel: true,
    size: 'L',
    uses: _anyWater,
    leaves: (
      at: StoryMilestone.techStart,
      offset: 10,
      status: EquipmentStatus.sold,
    ),
  ),
  const DemoGear(
    'computer-rec',
    'Wrist computer',
    EquipmentType.computer,
    brand: 'Shearwater',
    model: 'Peregrine',
    travel: true,
    uses: {KitUse.always},
    leaves: (
      at: StoryMilestone.airIntegrated,
      offset: 0,
      status: EquipmentStatus.retired,
    ),
  ),
  const DemoGear(
    'smb',
    'Surface marker buoy',
    EquipmentType.smb,
    brand: 'Halcyon',
    model: 'Diver Alert Marker',
    travel: true,
    uses: {KitUse.always},
  ),
  const DemoGear(
    'spool',
    'Spool',
    EquipmentType.reel,
    brand: 'Halcyon',
    model: 'Spool 30 m',
    travel: true,
    uses: {KitUse.always},
  ),
  const DemoGear(
    'knife',
    'Line cutter',
    EquipmentType.knife,
    brand: 'Trilobite',
    model: 'Line Cutter',
    travel: true,
    uses: {KitUse.always},
  ),
  const DemoGear(
    'weights',
    'Lead weight belt',
    EquipmentType.weights,
    brand: 'Beuchat',
    model: 'Marseillaise belt',
    uses: {KitUse.temperate, KitUse.cold},
  ),
  // First trips and the first summers.
  const DemoGear(
    'wetsuit-3',
    '3 mm wetsuit',
    EquipmentType.wetsuit,
    brand: 'Fourth Element',
    model: 'Proteus II',
    bought: StoryMilestone.firstTrip,
    travel: true,
    size: 'L',
    attributes: {'thickness_mm': 3},
    uses: _warm,
  ),
  const DemoGear(
    'rash-guard',
    'Rash guard',
    EquipmentType.rashGuard,
    brand: 'Fourth Element',
    model: 'Hydroskin',
    bought: StoryMilestone.firstTrip,
    travel: true,
    uses: _warm,
  ),
  const DemoGear(
    'wetsuit-5',
    '5 mm wetsuit',
    EquipmentType.wetsuit,
    brand: 'Waterproof',
    model: 'W4 5mm',
    bought: StoryMilestone.advanced,
    travel: true,
    size: 'L',
    attributes: {'thickness_mm': 5},
    uses: {KitUse.temperate},
  ),
  const DemoGear(
    'tank-12',
    'Steel HP100',
    EquipmentType.tank,
    brand: 'Faber',
    model: 'HP100 3442 psi',
    bought: StoryMilestone.ownRegulator,
    attributes: {
      'volume_l': 12.9,
      'working_pressure_bar': 237.3,
      'tank_material': 'steel',
    },
    uses: {KitUse.temperate, KitUse.cold},
  ),
  const DemoGear(
    'light-primary',
    'Dive light',
    EquipmentType.light,
    brand: 'Halcyon',
    model: 'Flare',
    bought: StoryMilestone.advanced,
    travel: true,
    uses: {KitUse.night, KitUse.cold},
  ),
  const DemoGear(
    'o2-analyser',
    'Oxygen analyser',
    EquipmentType.tool,
    brand: 'Divesoft',
    model: 'Oxygen Analyser',
    bought: StoryMilestone.nitrox,
  ),
  // Drysuit for the cold Jersey water.
  const DemoGear(
    'drysuit',
    'Drysuit',
    EquipmentType.drysuit,
    brand: 'Santi',
    model: 'E.Lite',
    bought: StoryMilestone.drysuit,
    size: 'L',
    status: EquipmentStatus.needsService,
    uses: {KitUse.cold},
  ),
  const DemoGear(
    'undersuit',
    'Undersuit',
    EquipmentType.undersuit,
    brand: 'Santi',
    model: 'BZ400',
    bought: StoryMilestone.drysuit,
    size: 'L',
    uses: {KitUse.cold},
  ),
  const DemoGear(
    'baselayer',
    'Base layer',
    EquipmentType.baselayer,
    brand: 'Fourth Element',
    model: 'Xerotherm',
    bought: StoryMilestone.drysuit,
    uses: {KitUse.cold},
  ),
  const DemoGear(
    'socks',
    'Thermal socks',
    EquipmentType.socks,
    brand: 'Fourth Element',
    model: 'Arctic socks',
    bought: StoryMilestone.drysuit,
    uses: {KitUse.cold},
  ),
  const DemoGear(
    'dry-gloves',
    'Dry glove system',
    EquipmentType.gloves,
    brand: 'SI Tech',
    model: 'Dry glove system',
    bought: StoryMilestone.drysuit,
    uses: {KitUse.cold},
  ),
  const DemoGear(
    'computer-ai',
    'Air-integrated wrist computer',
    EquipmentType.computer,
    brand: 'Shearwater',
    model: 'Teric',
    bought: StoryMilestone.airIntegrated,
    travel: true,
    uses: {KitUse.always},
  ),
  // Camera.
  const DemoGear(
    'camera',
    'Camera',
    EquipmentType.camera,
    brand: 'Sony',
    model: 'Alpha 6400',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'housing',
    'Camera housing',
    EquipmentType.housing,
    brand: 'Nauticam',
    model: 'NA-A6400',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'port',
    'Macro port',
    EquipmentType.port,
    brand: 'Nauticam',
    model: 'N85 macro port 45',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'tray',
    'Tray and handles',
    EquipmentType.trayHandle,
    brand: 'Nauticam',
    model: 'Flexitray',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'arms',
    'Arms and clamps',
    EquipmentType.armClamp,
    brand: 'Nauticam',
    model: 'Strobe arm set',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'float-arms',
    'Float arms',
    EquipmentType.floatArm,
    brand: 'Nauticam',
    model: 'Float arm 70',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'strobe-left',
    'Strobe, left',
    EquipmentType.strobe,
    brand: 'Sea & Sea',
    model: 'YS-D3 Duo',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'strobe-right',
    'Strobe, right',
    EquipmentType.strobe,
    brand: 'Sea & Sea',
    model: 'YS-D3 Duo',
    bought: StoryMilestone.photo,
    travel: true,
    uses: {KitUse.photo},
  ),
  const DemoGear(
    'video-light',
    'Video light',
    EquipmentType.videoLight,
    brand: 'Kraken Sports',
    model: 'Hydra 3500',
    bought: StoryMilestone.photo,
    boughtOffset: 40,
    travel: true,
    uses: {KitUse.photo},
  ),
  ...technicalGear,
  ...regulatorGear,
];

/// Product names for the privacy check's allow list.
Set<String> get demoGearProductNames => {
  for (final g in demoGear) ...[
    if (g.brand != null) g.brand!,
    if (g.model != null) g.model!,
    if (g.brand != null && g.model != null) '${g.brand} ${g.model}',
  ],
};
