import 'package:submersion/core/constants/enums.dart';

import '../story/story_plan.dart';
import 'gear_timeline.dart';

/// Lead on one dive.
typedef KitWeight = ({WeightType weightType, double amountKg, String label});

/// What the diver took on one dive: the top-level items (an assembly's parts
/// and fitted children follow their parent), the kit set it is closest to,
/// and the lead.
typedef KitForDive = ({
  List<String> gearKeys,
  String? setKey,
  List<KitWeight> weights,
});

/// The kit for [d], from what the diver owned and used that day.
///
/// The suit follows the water: 3 mm from 26 degrees, 5 mm from 20, 7 mm with
/// hood and gloves from 14, and the drysuit below that once it is owned.
/// Owned cylinders are only used at home; trips rent theirs. Before the
/// first regulator is bought, it is rented too.
KitForDive kitFor(PlannedDive d, GearTimeline t, {required bool photo}) {
  final keys = <String>[];
  bool has(String key) => t.inUseOn(key, d.start);
  void take(String key) {
    if (has(key) && !keys.contains(key)) keys.add(key);
  }

  final ccr = d.diveMode == 'ccr';
  final doubles = !ccr && d.tankCount > 1;
  final technical = ccr || doubles;
  final temp = d.waterTempC;
  final dry = temp < 14 && has('drysuit');
  final local = d.destination.key == 'home' || d.destination.nearHome;

  // Mask, fins, computers.
  final mask = ['mask', 'mask-2'].where(has).firstOrNull ?? 'mask-spare';
  take(mask);
  if (technical && has('fins-jet')) {
    take('fins-jet');
    take('fin-straps');
    take('fin-straps-2');
  } else {
    take('fins');
  }
  take(has('computer-ai') ? 'computer-ai' : 'computer-rec');
  if (technical) take('computer-tech');

  // Exposure.
  // Lead in whole pounds, as a US diver weights.
  final double suitLead;
  if (dry) {
    for (final k in ['drysuit', 'undersuit', 'baselayer', 'socks']) {
      take(k);
    }
    take('dry-gloves');
    take('hood');
    suitLead = _lb(18);
  } else if (temp >= 26) {
    take('wetsuit-3');
    take('rash-guard');
    take('boots');
    take('snorkel');
    suitLead = _lb(4);
  } else if (temp >= 20 && has('wetsuit-5')) {
    take('wetsuit-5');
    take('boots');
    suitLead = _lb(8);
  } else {
    take('wetsuit-7');
    take('hood');
    take('gloves');
    take('boots');
    suitLead = _lb(14);
  }

  // Buoyancy and breathing.
  if (doubles) {
    for (final k in ['backplate', 'harness', 'wing', 'tank-bands']) {
      take(k);
    }
    take('reg-right');
    take('reg-left');
    take('reg-stage-1');
    if (d.tankCount > 2) take('reg-stage-2');
    if (local) {
      take('twin');
      take('stage-1');
      if (d.tankCount > 2) take('stage-2');
    }
  } else if (ccr) {
    for (final k in [
      'backplate',
      'harness',
      'rebreather',
      'reg-stage-bailout',
    ]) {
      take(k);
    }
    if (local) {
      take('ccr-o2');
      take('ccr-dil');
      take('stage-1');
    }
  } else {
    if (has('bcd-jacket')) {
      take('bcd-jacket');
    } else {
      for (final k in ['backplate', 'harness', 'wing-single']) {
        take(k);
      }
    }
    final regulator = temp < 14 && has('reg-cold')
        ? 'reg-cold'
        : ['reg-warm', 'reg-cold'].where(has).firstOrNull;
    if (regulator != null) take(regulator);
    if (local) take('tank-12');
  }

  // Lights, tools, extras.
  if (technical) {
    for (final k in [
      'light-canister',
      'light-backup-1',
      'light-backup-2',
      'reel',
      'wetnotes',
      'pocket',
    ]) {
      take(k);
    }
  } else if (d.night || temp < 14) {
    take('light-primary');
  }
  for (final k in ['smb', 'spool', 'knife']) {
    take(k);
  }
  if ((dry || temp < 20) && !technical) take('weights');
  if (d.scooter) take('dpv');
  if (photo) {
    for (final k in [
      'camera',
      'housing',
      'port',
      'tray',
      'arms',
      'float-arms',
      'strobe-left',
      'strobe-right',
      'video-light',
    ]) {
      take(k);
    }
  }

  final List<KitWeight> weights;
  if (ccr) {
    weights = [
      (weightType: WeightType.trimWeights, amountKg: _lb(8), label: 'Trim'),
    ];
  } else if (doubles) {
    weights = [
      if (dry)
        (weightType: WeightType.trimWeights, amountKg: _lb(4), label: 'Trim'),
    ];
  } else {
    // Steel at home sinks; rental aluminium on trips floats at the end.
    final lead = suitLead + (local ? 0 : _lb(4));
    weights = [
      (
        weightType: WeightType.belt,
        amountKg: dry ? _lb(14) : lead,
        label: 'Belt',
      ),
      if (dry)
        (weightType: WeightType.trimWeights, amountKg: _lb(4), label: 'Trim'),
    ];
  }

  final setKey = ccr
      ? 'ccr'
      : doubles
      ? 'tech'
      : dry
      ? 'lake'
      : 'warm';
  return (gearKeys: keys, setKey: setKey, weights: weights);
}

/// Whether the camera came on [d]: every third trip dive once it is owned.
bool isPhotoDive(PlannedDive d, GearTimeline t) =>
    d.tripId != null && d.number % 3 == 0 && t.inUseOn('camera', d.start);

/// [pounds] of lead, in kilograms.
double _lb(double pounds) => pounds * 0.45359237;
