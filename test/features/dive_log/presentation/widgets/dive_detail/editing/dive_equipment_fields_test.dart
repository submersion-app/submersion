import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Equipment card's gear as a field of a sitting (issue #4527, plan 5).
void main() {
  const bcd = EquipmentItem(id: 'bcd', name: 'Wing', type: EquipmentType.bcd);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'First stage',
    type: EquipmentType.regulator,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  final dive = Dive(
    id: 'dive',
    dateTime: DateTime.utc(2026, 3, 9),
    gear: const [
      GearLink(item: bcd, viaSetId: 'warm'),
      GearLink(item: reg, viaSetId: 'warm'),
      GearLink(item: fins),
    ],
  );

  test('the field belongs to the equipment card', () {
    expect(diveGearField.cardId, 'equipment');
  });

  test('the same gear in another order, or with an item renamed, is no '
      'change', () {
    final s = EditSession(dive)
      ..set(diveGearField, const [
        GearLink(item: fins),
        GearLink(
          item: EquipmentItem(
            id: 'reg',
            name: 'Renamed',
            type: EquipmentType.regulator,
          ),
          viaSetId: 'warm',
        ),
        GearLink(item: bcd, viaSetId: 'warm'),
      ]);
    expect(s.isDirty, isFalse);
  });

  test('a link that changes its set is a change', () {
    final s = EditSession(dive)
      ..set(diveGearField, const [
        GearLink(item: bcd),
        GearLink(item: reg, viaSetId: 'warm'),
        GearLink(item: fins),
      ]);
    expect(s.changedCardIds, {'equipment'});
  });

  group('removing', () {
    test('a set with its gear', () {
      final s = EditSession(dive);
      removeSetFromSitting(s, 'warm', keepGear: false);
      expect([for (final g in s.working.gear) g.item.id], ['fins']);
    });

    test('a set, keeping its gear as the dive\'s own', () {
      final s = EditSession(dive);
      removeSetFromSitting(s, 'warm', keepGear: true);
      expect([for (final g in s.working.gear) g.viaSetId], [null, null, null]);
      expect(s.working.gear, hasLength(3));
    });

    test('rows the tree keeps', () {
      final s = EditSession(dive);
      keepGearRows(s, [for (final g in dive.gear.take(2)) g.provenance]);
      expect([for (final g in s.working.gear) g.item.id], ['bcd', 'reg']);
    });

    test('all of it', () {
      final s = EditSession(dive);
      clearGear(s);
      expect(s.working.gear, isEmpty);
    });
  });

  group('adding', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<WidgetRef> refOf(WidgetTester tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox();
            },
          ),
        ),
      );
      return ref;
    }

    testWidgets('new items join, merged by id, as the dive\'s own', (
      tester,
    ) async {
      final ref = await refOf(tester);
      final s = EditSession(dive);
      const mask = EquipmentItem(
        id: 'mask',
        name: 'Mask',
        type: EquipmentType.mask,
      );

      await tester.runAsync(() async {
        await addGearToSitting(ref.read, s, const [
          fins,
          mask,
        ], stillWanted: () => true);
        await s.settled();
      });

      expect(
        [for (final g in s.working.gear) g.item.id],
        ['bcd', 'reg', 'fins', 'mask'],
      );
      expect(s.working.gear.last.viaSetId, isNull);
      expect(s.changedCardIds, {'equipment'});
    });

    testWidgets('adds run one after another', (tester) async {
      final ref = await refOf(tester);
      final s = EditSession(dive.copyWith(gear: const []));
      const mask = EquipmentItem(
        id: 'mask',
        name: 'Mask',
        type: EquipmentType.mask,
      );

      await tester.runAsync(() async {
        final first = addGearToSitting(ref.read, s, const [
          fins,
        ], stillWanted: () => true);
        final second = addGearToSitting(ref.read, s, const [
          mask,
        ], stillWanted: () => true);
        await Future.wait([first, second]);
      });

      expect([for (final g in s.working.gear) g.item.id], ['fins', 'mask']);
    });

    test('a removal made while an add reads its parts is kept', () async {
      final gate = Completer<ComponentsIndex>();
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentComponentsIndexProvider.overrideWith((ref) => gate.future),
        ],
      );
      addTearDown(container.dispose);
      final s = EditSession(dive);
      const mask = EquipmentItem(
        id: 'mask',
        name: 'Mask',
        type: EquipmentType.mask,
      );

      final add = addGearToSitting(container.read, s, const [
        mask,
      ], stillWanted: () => true);
      await Future<void>.delayed(Duration.zero);
      removeSetFromSitting(s, 'warm', keepGear: false);
      gate.complete(ComponentsIndex.empty);
      await add;

      expect([for (final g in s.working.gear) g.item.id], ['fins', 'mask']);
    });

    test('gear that keeps changing while the parts are read is never '
        'written back stale', () async {
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
        ],
      );
      addTearDown(container.dispose);
      final s = EditSession(dive);
      // Each parts read, the diver takes one more row off.
      var reads = 0;
      T read<T>(ProviderListenable<T> provider) {
        final value = container.read(provider);
        if (value is Future<ComponentsIndex>) {
          reads++;
          final gear = s.valueOf(diveGearField);
          if (gear.isNotEmpty) s.set(diveGearField, gear.sublist(1));
        }
        return value;
      }

      await addGearToSitting(read, s, const [
        EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
      ]);

      expect(reads, greaterThan(3));
      expect([for (final g in s.working.gear) g.item.id], ['mask']);
    });

    testWidgets('an add answering after the sitting ended sets nothing', (
      tester,
    ) async {
      final ref = await refOf(tester);
      final s = EditSession(dive);
      final add = addGearToSitting(ref.read, s, const [
        EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
      ], stillWanted: () => true);
      s.dispose();
      await tester.runAsync(() => add);
      expect(s.working.gear, hasLength(3));
    });
  });
}
