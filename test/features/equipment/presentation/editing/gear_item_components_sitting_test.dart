import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/test_database.dart';

/// Records the dive rewrites a write asks for.
class _RecordingDives extends Fake implements DiveRepository {
  final calls = <(List<GearHistoryRewrite>, bool)>[];

  @override
  Future<List<String>> rewriteAssemblyOnDives(
    String assemblyId,
    List<GearHistoryRewrite> rewrites, {
    required bool alsoLogged,
    bool notify = true,
  }) async {
    calls.add((rewrites, alsoLogged));
    return const [];
  }
}

/// A gear item's components held in its page's sitting (issue #4527,
/// phase 3, plan 7).
void main() {
  final at = DateTime(2026);
  EquipmentComponent row(String id, String part) => EquipmentComponent(
    id: id,
    parentEquipmentId: 'g1',
    componentEquipmentId: part,
    createdAt: at,
    updatedAt: at,
  );

  group('the dives a change rewrites', () {
    test('a part added then removed makes no rewrite', () {
      final r = gearAssemblyRewrites([row('r1', 'p1')], [row('r1', 'p1')], {
        'p2': AssemblyHistoryChoice.alsoPast,
      });

      expect(r.alsoPast, isEmpty);
      expect(r.futureOnly, isEmpty);
    });

    test('a part replaced twice is one swap, old to newest', () {
      final r = gearAssemblyRewrites(
        [row('r1', 'p1')],
        [row('r1', 'p3')],
        const {},
      );

      expect(r.futureOnly, [
        const GearPartReplaced(oldPartId: 'p1', newPartId: 'p3'),
      ]);
    });

    test('a part removed and added back is where it was', () {
      final r = gearAssemblyRewrites([row('r1', 'p1')], [row('r2', 'p1')], {
        'p1': AssemblyHistoryChoice.alsoPast,
      });

      expect(r.alsoPast, isEmpty);
      expect(r.futureOnly, isEmpty);
    });

    test('a part moved onto another row is kept: only the part that left is '
        'removed', () {
      final r = gearAssemblyRewrites(
        [row('r1', 'p1'), row('r2', 'p2')],
        [row('r1', 'p2')],
        const {},
      );

      expect(r.alsoPast, isEmpty);
      expect(r.futureOnly, [const GearPartRemoved('p1')]);
    });

    test('each part goes under its last answer', () {
      final r = gearAssemblyRewrites([row('r1', 'p1')], [row('r2', 'p2')], {
        'p1': AssemblyHistoryChoice.futureOnly,
        'p2': AssemblyHistoryChoice.alsoPast,
      });

      expect(r.alsoPast, [const GearPartAdded('p2')]);
      expect(r.futureOnly, [const GearPartRemoved('p1')]);
    });
  });

  group('held in a sitting', () {
    late EquipmentComponentRepository components;
    late _RecordingDives dives;
    late EditSession<EquipmentItem> session;

    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      components = EquipmentComponentRepository();
      dives = _RecordingDives();
      final items = EquipmentRepository();
      for (final id in ['g1', 'p1', 'p2']) {
        await items.createEquipment(
          EquipmentItem(id: id, name: id, type: EquipmentType.regulator),
        );
      }
      await components.addComponent(parentId: 'g1', componentId: 'p1');
      session = EditSession((await items.getEquipmentById('g1'))!);
      addTearDown(session.dispose);
      T read<T>(ProviderListenable<T> provider) =>
          (identical(provider, equipmentComponentRepositoryProvider)
                  ? components
                  : identical(provider, diveRepositoryProvider)
                  ? dives
                  : throw ArgumentError('$provider'))
              as T;
      holdGearItemComponents(session, read);
      await gearItemComponentsList.currentOrRead(session);
    });
    tearDown(tearDownTestDatabase);

    test('a part added with Also update is written under its id, and the '
        'logged dives are rewritten', () async {
      final parts = gearItemComponentsList.current(session)!;
      rememberPartAnswer(session, 'p2', AssemblyHistoryChoice.alsoPast);
      gearItemComponentsList.set(session, [...parts, row('new', 'p2')]);
      expect(session.changedCardIds, {GearItemCardId.components.name});
      expect(await components.getComponents('g1'), hasLength(1));

      await session.runHeldWrites();

      final stored = await components.getComponents('g1');
      expect(stored.map((c) => c.id), contains('new'));
      expect(dives.calls.map((c) => c.$2), [true, false]);
      expect(dives.calls.first.$1, [const GearPartAdded('p2')]);
      expect(dives.calls.last.$1, isEmpty);
    });

    test('a part added and removed again writes no row and no dive', () async {
      final parts = gearItemComponentsList.current(session)!;
      rememberPartAnswer(session, 'p2', AssemblyHistoryChoice.alsoPast);
      gearItemComponentsList.set(session, [...parts, row('new', 'p2')]);

      gearItemComponentsList.set(session, parts);

      expect(session.hasHeldWrites, isFalse);
      expect(dives.calls, isEmpty);
    });

    test('a part removed and added back is still a part, under its new '
        'row', () async {
      final parts = gearItemComponentsList.current(session)!;
      gearItemComponentsList.set(session, [row('again', 'p1')]);
      expect(parts.single.id, isNot('again'));

      await session.runHeldWrites();

      final stored = await components.getComponents('g1');
      expect(stored.map((c) => (c.id, c.componentEquipmentId)), [
        ('again', 'p1'),
      ]);
    });

    test(
      'a part taken off one row and swapped onto another is saved',
      () async {
        await components.addComponent(parentId: 'g1', componentId: 'p2');
        await gearItemComponentsList.load(session);
        final parts = gearItemComponentsList.current(session)!;
        final first = parts.firstWhere((c) => c.componentEquipmentId == 'p1');
        // p2's row goes, and p1's row takes p2.
        gearItemComponentsList.set(session, [
          first.copyWith(componentEquipmentId: 'p2'),
        ]);

        await session.runHeldWrites();

        final stored = await components.getComponents('g1');
        expect(stored.map((c) => (c.id, c.componentEquipmentId)), [
          (first.id, 'p2'),
        ]);
      },
    );

    test('a part another device added meanwhile keeps the held role and '
        'order on its stored row', () async {
      await components.addComponent(parentId: 'g1', componentId: 'p2');
      await gearItemComponentsList.load(session);
      final stored = gearItemComponentsList.current(session)!;
      final p1 = stored.firstWhere((c) => c.componentEquipmentId == 'p1');
      final p2Elsewhere = stored.firstWhere(
        (c) => c.componentEquipmentId == 'p2',
      );
      // The sitting removes p2, adds it back under a new row with a role,
      // first; meanwhile another device's p2 row is what is stored.
      gearItemComponentsList.set(session, [
        row('held', 'p2').copyWith(role: 'Spare'),
        p1,
      ]);
      await components.removeComponent(p2Elsewhere.id);
      await components.addComponent(parentId: 'g1', componentId: 'p2');

      await session.runHeldWrites();

      final after = await components.getComponents('g1');
      expect(after.map((c) => c.componentEquipmentId), ['p2', 'p1']);
      expect(after.first.role, 'Spare');
    });

    test('a part that would now make a loop refuses the Save', () async {
      final parts = gearItemComponentsList.current(session)!;
      gearItemComponentsList.set(session, [...parts, row('new', 'p2')]);
      // Meanwhile g1 became a part of p2.
      await components.addComponent(parentId: 'p2', componentId: 'g1');

      Object? refused;
      try {
        await session.runHeldWrites();
      } on RecordSittingRefusal catch (e) {
        refused = e;
      }

      expect(
        (refused! as RecordSittingRefusal).message(AppLocalizationsEn()),
        AppLocalizationsEn().equipment_components_cycleError,
      );
    });

    test('a reorder writes the order; a removal alone does not', () async {
      await components.addComponent(parentId: 'g1', componentId: 'p2');
      await gearItemComponentsList.load(session);
      final parts = gearItemComponentsList.current(session)!;
      expect(parts, hasLength(2));

      gearItemComponentsList.set(session, parts.reversed.toList());
      await session.runHeldWrites();

      final stored = await components.getComponents('g1');
      expect(stored.map((c) => c.componentEquipmentId), ['p2', 'p1']);
    });
  });
}
