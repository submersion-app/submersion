import 'package:submersion/core/constants/enums.dart';

import '../story/story_plan.dart';
import 'gear_catalog.dart';

/// A regulator (or other assembly) and its parts, each a separate item with
/// the role it plays.
class DemoAssembly {
  const DemoAssembly(this.parentKey, this.parts);

  final String parentKey;
  final List<(String key, String role)> parts;
}

/// A child item fitted inside another (an oxygen cell, a battery), with its
/// slot and when it was fitted.
class DemoInstall {
  const DemoInstall({
    required this.childKey,
    required this.parentKey,
    required this.at,
    this.slot,
  });

  final String childKey;
  final String parentKey;
  final StoryMilestone at;
  final int? slot;
}

const _tech = {KitUse.tech};
const _ccr = {KitUse.ccr};

/// Technical, scooter and rebreather kit, and the wish list.
const technicalGear = <DemoGear>[
  DemoGear(
    'backplate',
    'Stainless backplate',
    EquipmentType.backplate,
    brand: 'Halcyon',
    model: 'Stainless steel backplate',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'harness',
    'Harness',
    EquipmentType.harness,
    brand: 'Halcyon',
    model: 'Hogarthian harness',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'wing',
    'Doubles wing',
    EquipmentType.wing,
    brand: 'Halcyon',
    model: 'Evolve 40',
    bought: StoryMilestone.techStart,
    uses: _tech,
  ),
  DemoGear(
    'wing-single',
    'Single-tank wing',
    EquipmentType.wing,
    brand: 'Halcyon',
    model: 'Eclipse 30',
    bought: StoryMilestone.techStart,
    boughtOffset: 10,
    travel: true,
    uses: {KitUse.warm, KitUse.temperate, KitUse.cold},
  ),
  DemoGear(
    'tank-bands',
    'Tank bands',
    EquipmentType.tankBand,
    brand: 'Halcyon',
    model: 'Stainless tank bands',
    bought: StoryMilestone.techStart,
    uses: _tech,
  ),
  DemoGear(
    'twin',
    'Double HP100s',
    EquipmentType.tank,
    brand: 'Faber',
    model: 'HP100 doubles 3442 psi',
    bought: StoryMilestone.techStart,
    attributes: {
      'volume_l': 25.8,
      'working_pressure_bar': 237.3,
      'tank_material': 'steel',
    },
    uses: _tech,
  ),
  DemoGear(
    'stage-1',
    'AL40 stage',
    EquipmentType.tank,
    brand: 'Luxfer',
    model: 'S40',
    bought: StoryMilestone.techStart,
    attributes: {
      'volume_l': 5.7,
      'working_pressure_bar': 207,
      'tank_material': 'aluminum',
    },
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'stage-2',
    'AL40 oxygen stage',
    EquipmentType.tank,
    brand: 'Luxfer',
    model: 'S40',
    bought: StoryMilestone.trimix,
    attributes: {
      'volume_l': 5.7,
      'working_pressure_bar': 207,
      'tank_material': 'aluminum',
    },
    uses: _tech,
  ),
  DemoGear(
    'fins-jet',
    'Jet fins',
    EquipmentType.fins,
    brand: 'Scubapro',
    model: 'Jet Fin',
    bought: StoryMilestone.techStart,
    size: 'L',
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'fin-straps',
    'Spring fin straps',
    EquipmentType.tool,
    brand: 'Scubapro',
    model: 'Spring straps',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
    leaves: (
      at: StoryMilestone.scooter,
      offset: -10,
      status: EquipmentStatus.retired,
    ),
  ),
  DemoGear(
    'fin-straps-2',
    'Spring fin straps',
    EquipmentType.tool,
    brand: 'Scubapro',
    model: 'Spring straps',
    bought: StoryMilestone.scooter,
    boughtOffset: -10,
    replaces: 'fin-straps',
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'computer-tech',
    'Technical computer',
    EquipmentType.computer,
    brand: 'Shearwater',
    model: 'Perdix 2',
    bought: StoryMilestone.techStart,
    travel: true,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'light-canister',
    'Canister light',
    EquipmentType.light,
    brand: 'Light Monkey',
    model: '21W LED canister',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'light-backup-1',
    'Backup light 1',
    EquipmentType.light,
    brand: 'Halcyon',
    model: 'Flare EOS',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'light-backup-2',
    'Backup light 2',
    EquipmentType.light,
    brand: 'Halcyon',
    model: 'Flare EOS',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'reel',
    'Primary reel',
    EquipmentType.reel,
    brand: 'Halcyon',
    model: 'Defender 45 m',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'wetnotes',
    'Wetnotes',
    EquipmentType.tool,
    brand: 'Halcyon',
    model: 'Wetnotes',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'pocket',
    'Thigh pocket',
    EquipmentType.gearPocket,
    brand: 'Santi',
    model: 'Thigh pocket',
    bought: StoryMilestone.techStart,
    uses: {KitUse.tech, KitUse.ccr},
  ),
  DemoGear(
    'helium-analyser',
    'Helium analyser',
    EquipmentType.tool,
    brand: 'Divesoft',
    model: 'Helium Analyser',
    bought: StoryMilestone.trimix,
  ),
  DemoGear(
    'dpv',
    'Scooter',
    EquipmentType.dpv,
    brand: 'Seacraft',
    model: 'Future',
    bought: StoryMilestone.scooter,
    uses: {KitUse.scooter},
  ),
  DemoGear(
    'dpv-battery',
    'Scooter battery',
    EquipmentType.battery,
    brand: 'Seacraft',
    model: 'Future battery',
    bought: StoryMilestone.scooter,
  ),
  DemoGear(
    'rebreather',
    'Closed-circuit rebreather',
    EquipmentType.rebreather,
    brand: 'JJ-CCR',
    model: 'JJ-CCR',
    bought: StoryMilestone.ccrCourse,
    serviceIntervalDays: 365,
    uses: _ccr,
  ),
  DemoGear(
    'o2-cell-1',
    'Oxygen cell 1',
    EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    bought: StoryMilestone.ccrCourse,
  ),
  DemoGear(
    'o2-cell-2',
    'Oxygen cell 2',
    EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    bought: StoryMilestone.ccrCourse,
    leaves: (
      at: StoryMilestone.cellSwap,
      offset: 0,
      status: EquipmentStatus.retired,
    ),
  ),
  DemoGear(
    'o2-cell-2b',
    'Oxygen cell 2',
    EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    bought: StoryMilestone.cellSwap,
    replaces: 'o2-cell-2',
  ),
  DemoGear(
    'o2-cell-3',
    'Oxygen cell 3',
    EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    bought: StoryMilestone.ccrCourse,
  ),
  DemoGear(
    'ccr-battery',
    'Rebreather battery',
    EquipmentType.battery,
    brand: 'JJ-CCR',
    model: 'Controller battery',
    bought: StoryMilestone.ccrCourse,
  ),
  DemoGear(
    'ccr-o2',
    'Rebreather oxygen cylinder',
    EquipmentType.tank,
    brand: 'Faber',
    model: '3 L 232 bar',
    bought: StoryMilestone.ccrCourse,
    attributes: {
      'volume_l': 3,
      'working_pressure_bar': 232,
      'tank_material': 'steel',
    },
    uses: _ccr,
  ),
  DemoGear(
    'ccr-dil',
    'Rebreather diluent cylinder',
    EquipmentType.tank,
    brand: 'Faber',
    model: '3 L 232 bar',
    bought: StoryMilestone.ccrCourse,
    attributes: {
      'volume_l': 3,
      'working_pressure_bar': 232,
      'tank_material': 'steel',
    },
    uses: _ccr,
  ),
  DemoGear(
    'sidemount-harness',
    'Sidemount harness',
    EquipmentType.harness,
    brand: 'Hollis',
    model: 'Katana 2',
    status: EquipmentStatus.wanted,
  ),
];

List<(String, String)> _stageParts(String n) => [
  ('fs-stage-$n', 'first stage'),
  ('ss-stage-$n', 'second stage'),
  ('hose-stage-$n', 'hose'),
  ('hose-stage-$n-hp', 'gauge hose'),
  ('spg-stage-$n', 'pressure gauge'),
];

/// The regulators and what each is built from.
final demoAssemblies = <DemoAssembly>[
  const DemoAssembly('reg-warm', [
    ('fs-warm', 'first stage'),
    ('ss-warm-primary', 'primary'),
    ('ss-warm-octo', 'octopus'),
    ('hose-warm-lp', 'primary hose'),
    ('hose-warm-octo', 'octopus hose'),
    ('hose-warm-lpi', 'inflator hose'),
    ('hose-warm-hp', 'gauge hose'),
    ('spg-warm', 'pressure gauge'),
    ('compass-warm', 'compass'),
  ]),
  const DemoAssembly('reg-cold', [
    ('fs-cold', 'first stage'),
    ('ss-cold-primary', 'primary'),
    ('ss-cold-octo', 'octopus'),
    ('hose-cold-lp', 'primary hose'),
    ('hose-cold-octo', 'octopus hose'),
    ('hose-cold-lpi', 'inflator hose'),
    ('hose-cold-lpi-2', 'inflator hose'),
    ('hose-cold-dry', 'drysuit hose'),
    ('hose-cold-hp', 'gauge hose'),
    ('spg-cold', 'pressure gauge'),
    ('transmitter-cold', 'transmitter'),
  ]),
  const DemoAssembly('reg-right', [
    ('fs-right', 'first stage'),
    ('ss-right', 'long hose primary'),
    ('hose-right-long', 'long hose'),
    ('hose-right-lpi', 'wing inflator hose'),
    ('transmitter-right', 'transmitter'),
  ]),
  const DemoAssembly('reg-left', [
    ('fs-left', 'first stage'),
    ('ss-left', 'necklace'),
    ('hose-left-necklace', 'necklace hose'),
    ('hose-left-dry', 'drysuit hose'),
    ('hose-left-hp', 'gauge hose'),
    ('spg-left', 'pressure gauge'),
  ]),
  DemoAssembly('reg-stage-1', _stageParts('1')),
  DemoAssembly('reg-stage-2', _stageParts('2')),
  DemoAssembly('reg-stage-bailout', _stageParts('bailout')),
];

/// What is fitted inside the rebreather and the scooter.
const demoInstalls = <DemoInstall>[
  DemoInstall(
    childKey: 'o2-cell-1',
    parentKey: 'rebreather',
    at: StoryMilestone.ccrCourse,
    slot: 1,
  ),
  DemoInstall(
    childKey: 'o2-cell-2',
    parentKey: 'rebreather',
    at: StoryMilestone.ccrCourse,
    slot: 2,
  ),
  DemoInstall(
    childKey: 'o2-cell-3',
    parentKey: 'rebreather',
    at: StoryMilestone.ccrCourse,
    slot: 3,
  ),
  DemoInstall(
    childKey: 'o2-cell-2b',
    parentKey: 'rebreather',
    at: StoryMilestone.cellSwap,
    slot: 2,
  ),
  DemoInstall(
    childKey: 'ccr-battery',
    parentKey: 'rebreather',
    at: StoryMilestone.ccrCourse,
  ),
  DemoInstall(
    childKey: 'dpv-battery',
    parentKey: 'dpv',
    at: StoryMilestone.scooter,
  ),
];
