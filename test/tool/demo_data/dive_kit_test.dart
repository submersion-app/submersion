import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

import '../../../tool/demo_data/src/seeders/dive_kit.dart';
import '../../../tool/demo_data/src/seeders/gear_assemblies.dart';
import '../../../tool/demo_data/src/seeders/gear_catalog.dart';
import '../../../tool/demo_data/src/seeders/gear_timeline.dart';
import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';

void main() {
  late StoryPlan plan;
  late GearTimeline timeline;
  final byKey = {for (final g in demoGear) g.key: g};

  setUpAll(() {
    plan = StoryPlanner(
      Random(42),
      Catalog.load('assets/data'),
    ).plan(anchor: DateTime(2026, 10, 1));
    timeline = GearTimeline(plan, demoGear);
  });

  bool insideTrip(DateTime when) => plan.trips.any(
    (t) =>
        !when.isBefore(DateTime(t.start.year, t.start.month, t.start.day)) &&
        when.isBefore(DateTime(t.end.year, t.end.month, t.end.day + 1)),
  );

  KitForDive kit(PlannedDive d) => kitFor(d, timeline, photo: d.number.isEven);

  test('no dive uses gear before it was bought or after it left', () {
    for (final d in plan.dives) {
      for (final key in kit(d).gearKeys) {
        expect(
          timeline.inUseOn(key, d.start),
          isTrue,
          reason: 'dive ${d.number}: $key',
        );
      }
    }
  });

  test(
    'every item on a dive is a top-level item, never a part or a fitted child',
    () {
      final parts = {
        for (final a in demoAssemblies)
          for (final (k, _) in a.parts) k,
        for (final i in demoInstalls) i.childKey,
      };
      for (final d in plan.dives) {
        expect(
          kit(d).gearKeys.where(parts.contains),
          isEmpty,
          reason: 'dive ${d.number}',
        );
      }
    },
  );

  test('every dive has a mask, fins, a computer and an exposure suit', () {
    for (final d in plan.dives) {
      final types = {for (final k in kit(d).gearKeys) byKey[k]!.type};
      expect(types, contains(EquipmentType.mask), reason: 'dive ${d.number}');
      expect(types, contains(EquipmentType.fins), reason: 'dive ${d.number}');
      expect(
        types,
        contains(EquipmentType.computer),
        reason: 'dive ${d.number}',
      );
      expect(
        types.contains(EquipmentType.wetsuit) ||
            types.contains(EquipmentType.drysuit),
        isTrue,
        reason: 'dive ${d.number}',
      );
    }
  });

  test('a drysuit only below 14 degrees, and always there once owned', () {
    for (final d in plan.dives) {
      final keys = kit(d).gearKeys;
      if (d.waterTempC >= 14) {
        expect(keys, isNot(contains('drysuit')), reason: 'dive ${d.number}');
      } else if (timeline.inUseOn('drysuit', d.start)) {
        expect(keys, contains('drysuit'), reason: 'dive ${d.number}');
      }
    }
  });

  test('early trips before the own regulator carry no regulator', () {
    final own = plan.milestones[StoryMilestone.ownRegulator]!;
    final early = plan.dives.where((d) => d.number < own);
    expect(early, isNotEmpty);
    for (final d in early) {
      final types = [for (final k in kit(d).gearKeys) byKey[k]!.type];
      expect(
        types,
        isNot(contains(EquipmentType.regulator)),
        reason: 'dive ${d.number}',
      );
    }
  });

  test(
    'scooter dives carry the scooter, rebreather dives the rebreather and bailout',
    () {
      for (final d in plan.dives) {
        final keys = kit(d).gearKeys;
        expect(keys.contains('dpv'), d.scooter, reason: 'dive ${d.number}');
        if (d.diveMode == 'ccr') {
          expect(keys, containsAll(['rebreather', 'reg-stage-bailout']));
        }
      }
    },
  );

  test('doubles dives carry both posts and a stage regulator per stage', () {
    for (final d in plan.dives.where(
      (d) => d.diveMode == 'oc' && d.tankCount > 1,
    )) {
      final keys = kit(d).gearKeys;
      expect(
        keys,
        containsAll(['reg-right', 'reg-left']),
        reason: 'dive ${d.number}',
      );
      // Trips rent their cylinders; the diver's own twins stay home.
      if (d.destination.key == 'home') expect(keys, contains('twin'));
      expect(keys, contains('reg-stage-1'), reason: 'dive ${d.number}');
      if (d.tankCount > 2) expect(keys, contains('reg-stage-2'));
    }
  });

  test('the weights follow the suit', () {
    for (final d in plan.dives) {
      final k = kit(d);
      final lead = k.weights.fold(0.0, (a, w) => a + w.amountKg);
      if (k.gearKeys.contains('drysuit') &&
          d.tankCount == 1 &&
          d.diveMode == 'oc') {
        expect(lead, greaterThanOrEqualTo(6), reason: 'dive ${d.number}');
      }
      if (k.gearKeys.contains('wetsuit-3')) {
        expect(lead, lessThanOrEqualTo(4), reason: 'dive ${d.number}');
      }
    }
  });

  test('no purchase, service record or fill falls inside a trip', () {
    for (final g in demoGear) {
      final at = timeline.boughtOn(g.key);
      if (at == null) continue;
      expect(insideTrip(at), isFalse, reason: '${g.key} bought $at');
    }
  });

  test('a replacement arrives no earlier than what it replaced leaves', () {
    for (final g in demoGear.where((g) => g.replaces != null)) {
      expect(
        timeline.boughtOn(g.key)!.isBefore(timeline.leftOn(g.replaces!)!),
        isFalse,
        reason: g.key,
      );
    }
  });

  test('a wished-for item is never owned', () {
    expect(timeline.boughtOn('sidemount-harness'), isNull);
    expect(timeline.inUseOn('sidemount-harness', plan.anchor), isFalse);
  });
}
