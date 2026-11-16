import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// A site picked in a sitting brings its location set, and the next site
/// takes it back (issue #4527, plan 5).
void main() {
  final t0 = DateTime.utc(2026, 3, 9);
  const wing = EquipmentItem(
    id: 'wing',
    name: 'Wing',
    type: EquipmentType.wing,
  );
  const drysuit = EquipmentItem(
    id: 'dry',
    name: 'Drysuit',
    type: EquipmentType.drysuit,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  // An altitude of their own, so picking them looks nothing up.
  const reef = DiveSite(
    id: 'reef',
    name: 'Reef',
    location: GeoPoint(27.0, 34.0),
    altitude: 0,
  );
  const lake = DiveSite(
    id: 'lake',
    name: 'Lake',
    location: GeoPoint(47.0, 8.0),
  );
  const nowhere = DiveSite(id: 'nowhere', name: 'Nowhere');
  EquipmentSet setOf(String id, List<EquipmentItem> items) => EquipmentSet(
    id: id,
    name: id,
    equipmentIds: [for (final i in items) i.id],
    items: items,
    createdAt: t0,
    updatedAt: t0,
  );
  EquipmentSetGeofence fence(String setId, GeoPoint at) => EquipmentSetGeofence(
    id: 'g-$setId',
    setId: setId,
    latitude: at.latitude,
    longitude: at.longitude,
    radiusMeters: 5000,
    createdAt: t0,
    updatedAt: t0,
  );
  final warm = setOf('warm', const [wing]);
  final cold = setOf('cold', const [drysuit]);
  const warmWeights = SetBundle(
    setId: 'warm',
    gearIds: ['wing'],
    weights: [
      (weightType: WeightType.integrated, amountKg: 2.0, notes: '', label: ''),
    ],
  );
  final bare = Dive(id: 'dive', dateTime: t0);

  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        equipmentSetSelectionInputsProvider.overrideWith(
          (ref) async => EquipmentSetSelectionInputs(
            sets: [warm, cold],
            geofences: [
              fence('warm', reef.location!),
              fence('cold', lake.location!),
            ],
          ),
        ),
        setBundleProvider('warm').overrideWith((ref) async => warmWeights),
        setBundleProvider('cold').overrideWith(
          (ref) async => const SetBundle(setId: 'cold', gearIds: ['dry']),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<void> pick(EditSession<Dive> s, DiveSite? site) async {
    s.set(diveSiteField, site);
    reevaluateGearForSite(s, read: container.read);
    await s.settled();
  }

  test('a dive with no gear gets the best set, with its weights', () async {
    final s = EditSession(bare);
    await pick(s, reef);
    expect(
      [for (final g in s.working.gear) (g.item.id, g.viaSetId)],
      [('wing', 'warm')],
    );
    expect(s.working.weights.single.amountKg, 2);
    expect(s.changedCardIds, containsAll(['equipment', 'weights']));
  });

  test(
    'site A applied a set, then site B: A\'s gear and weights go back',
    () async {
      final s = EditSession(bare);
      await pick(s, reef);
      await pick(s, lake);
      expect([for (final g in s.working.gear) g.item.id], ['dry']);
      expect(s.working.weights, isEmpty);
    },
  );

  test(
    'site A applied a set, then a site with none: the dive is as it was',
    () async {
      final s = EditSession(bare);
      await pick(s, reef);
      await pick(s, nowhere);
      expect(s.working.gear, isEmpty);
      expect(s.working.weights, isEmpty);
      expect(s.changedCardIds, isNot(contains('equipment')));
    },
  );

  test(
    'gear the diver changed after A\'s set is kept when B is picked',
    () async {
      final s = EditSession(bare);
      await pick(s, reef);
      s.set(diveGearField, [...s.working.gear, const GearLink(item: fins)]);
      await pick(s, lake);
      expect([
        for (final g in s.working.gear) g.item.id,
      ], containsAll(['wing', 'fins']));
      expect(geofenceSuggestion(s)?.id, 'cold');
    },
  );

  test('gear and weights changed after A\'s set and changed back are the '
      'diver\'s: B leaves them, and its weights change nothing', () async {
    final s = EditSession(bare);
    await pick(s, reef);
    final setGear = s.valueOf(diveGearField);
    final setWeights = s.valueOf(diveWeightsField);
    s
      ..set(diveGearField, [...setGear, const GearLink(item: fins)])
      ..set(diveGearField, setGear)
      ..set(diveWeightsField, const <DiveWeight>[])
      ..set(diveWeightsField, setWeights);

    await pick(s, lake);

    expect([for (final g in s.working.gear) g.item.id], ['wing']);
    expect(s.working.weights.single.amountKg, 2);
  });

  test('weighting feedback given after A\'s set does not keep its weights '
      'when B is picked', () async {
    final s = EditSession(bare);
    await pick(s, reef);
    s.set(diveWeightingFeedbackField, WeightingFeedback.correct);

    await pick(s, lake);

    expect(s.working.weights, isEmpty);
  });

  test('a dive with gear gets a suggestion, not a set', () async {
    final s = EditSession(bare.copyWith(gear: const [GearLink(item: fins)]));
    await pick(s, reef);
    expect([for (final g in s.working.gear) g.item.id], ['fins']);
    expect(geofenceSuggestion(s)?.id, 'warm');
  });

  test('a set whose gear is all on the dive is not suggested', () async {
    final s = EditSession(bare.copyWith(gear: const [GearLink(item: wing)]));
    await pick(s, reef);
    expect(geofenceSuggestion(s), isNull);
  });

  test('a dismissed set is not suggested again', () async {
    final s = EditSession(bare.copyWith(gear: const [GearLink(item: fins)]));
    await pick(s, reef);
    dismissGeofenceSuggestion(s);
    expect(geofenceSuggestion(s), isNull);
    await pick(s, lake);
    await pick(s, reef);
    expect(geofenceSuggestion(s), isNull);
  });

  test('the suggestion goes when another site is picked', () async {
    final s = EditSession(bare.copyWith(gear: const [GearLink(item: fins)]));
    await pick(s, reef);
    await pick(s, nowhere);
    expect(geofenceSuggestion(s), isNull);
  });

  test('A\'s inputs answering after B: nothing applied for A', () async {
    final gate = Completer<EquipmentSetSelectionInputs>();
    final slow = ProviderContainer(
      parent: container,
      overrides: [
        equipmentSetSelectionInputsProvider.overrideWith((ref) => gate.future),
      ],
    );
    addTearDown(slow.dispose);
    final s = EditSession(bare);
    s.set(diveSiteField, reef);
    reevaluateGearForSite(s, read: slow.read);
    s.set(diveSiteField, lake);
    gate.complete(
      EquipmentSetSelectionInputs(
        sets: [warm],
        geofences: [fence('warm', reef.location!)],
      ),
    );
    await s.settled();
    expect(s.working.gear, isEmpty);
  });

  test('A\'s set still going on when B is picked: what it put on goes back '
      'and B\'s set comes', () async {
    final gate = Completer<SetBundle>();
    final slow = ProviderContainer(
      parent: container,
      overrides: [setBundleProvider('warm').overrideWith((ref) => gate.future)],
    );
    addTearDown(slow.dispose);
    final s = EditSession(bare)..set(diveSiteField, reef);
    reevaluateGearForSite(s, read: slow.read);
    // A's gear is on; its weights wait for the bundle.
    for (var i = 0; i < 200 && s.working.gear.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect([for (final g in s.working.gear) g.item.id], ['wing']);

    s.set(diveSiteField, lake);
    reevaluateGearForSite(s, read: slow.read);
    gate.complete(warmWeights);
    await s.settled();

    expect([for (final g in s.working.gear) g.item.id], ['dry']);
    expect(s.working.weights, isEmpty);
  });

  test('A, B and A again: the set is put on once', () async {
    final gate = Completer<EquipmentSetSelectionInputs>();
    final slow = ProviderContainer(
      parent: container,
      overrides: [
        equipmentSetSelectionInputsProvider.overrideWith((ref) => gate.future),
      ],
    );
    addTearDown(slow.dispose);
    final s = EditSession(bare)..set(diveSiteField, reef);
    reevaluateGearForSite(s, read: slow.read);
    s.set(diveSiteField, lake);
    reevaluateGearForSite(s, read: container.read);
    s.set(diveSiteField, reef);
    reevaluateGearForSite(s, read: container.read);
    gate.complete(
      EquipmentSetSelectionInputs(
        sets: [warm],
        geofences: [fence('warm', reef.location!)],
      ),
    );
    await s.settled();

    expect([for (final g in s.working.gear) g.item.id], ['wing']);
    expect([for (final w in s.working.weights) w.amountKg], [2]);
  });

  testWidgets('a site picked through the site assigner brings its set', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final s = EditSession(bare);

    await tester.runAsync(() async {
      readDiveSiteAssigner(context)(s, reef);
      await s.settled();
    });

    expect([for (final g in s.working.gear) g.item.id], ['wing']);
  });
}
