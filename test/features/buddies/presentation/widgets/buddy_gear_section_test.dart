import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_gear_sitting.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_gear_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  final returned = <Iterable<String>>[];

  /// Runs while a move is being written, as a real save refreshes the list.
  void Function()? onRecord;

  /// How long the write takes, so a test can let frames pass during it.
  Duration writeTakes = Duration.zero;

  @override
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async =>
      const [];

  @override
  Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> ids) async =>
      const {};

  @override
  Future<void> recordMoveGroups(
    List<MoveGroup> groups, {
    String note = '',
  }) async {
    returned.addAll(groups.map((g) => g.equipmentIds));
    onRecord?.call();
    await Future<void>.delayed(writeTakes);
  }
}

class _StatusNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _StatusNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> setStatusForMany(
    List<String> ids,
    EquipmentStatus status,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The gear section on a buddy's page (issue #3790).
void main() {
  final anna = Buddy(
    id: 'anna',
    name: 'Anna Lindqvist',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentLocation place(
    String id,
    String name, {
    String? buddyId = 'anna',
    bool archived = false,
  }) => EquipmentLocation(
    id: id,
    name: name,
    kind: EquipmentLocationKind.person,
    buddyId: buddyId,
    isArchived: archived,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentItem item(
    String id,
    String name, {
    EquipmentStatus status = EquipmentStatus.active,
    EquipmentType type = EquipmentType.wetsuit,
  }) => EquipmentItem(id: id, name: name, type: type, status: status);

  final hers = place('hers', 'Anna at home');

  Future<_FakeMoves> pump(
    WidgetTester tester, {
    required List<EquipmentItem> items,
    required Map<String, EquipmentLocation> current,
    List<EquipmentLocation>? places,
    EditSession<Buddy>? editing,
  }) async {
    final moves = _FakeMoves();
    final byId = {
      for (final p in places ?? [hers]) p.id: p,
    };
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: BuddyGearSection(buddy: anna, editing: editing),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              Scaffold(body: Text('ITEM ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allEquipmentProvider.overrideWith((ref) async => items),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => current,
          ),
          allEquipmentLocationsByIdProvider.overrideWith((ref) async => byId),
          equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
          equipmentListNotifierProvider.overrideWith(
            (ref) => _StatusNotifier(),
          ),
          activeEquipmentProvider.overrideWith((ref) async => items),
          allDiversProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          for (final i in items)
            equipmentLocationMovesProvider(i.id).overrideWith(
              (ref) async => [
                EquipmentLocationMove(
                  id: 'm${i.id}',
                  equipmentId: i.id,
                  locationId: current[i.id]?.id,
                  movedAt: DateTime(2026, 10, 12),
                  createdAt: DateTime(2026, 10, 12),
                ),
              ],
            ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return moves;
  }

  final title = find.text('Gear with Anna Lindqvist');
  final allReturned = find.text('All returned');

  testWidgets('builds nothing when the buddy holds no gear', (tester) async {
    await pump(
      tester,
      items: [item('a', 'Wetsuit')],
      current: {'a': place('his', 'Sam', buddyId: 'sam')},
    );

    expect(title, findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('lists linked gear by name with its type and date', (
    tester,
  ) async {
    await pump(
      tester,
      items: [item('z', 'Zip fins'), item('a', 'Apeks wetsuit')],
      current: {'z': hers, 'a': hers},
    );

    expect(title, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Apeks wetsuit')).dy,
      lessThan(tester.getTopLeft(find.text('Zip fins')).dy),
    );
    expect(find.textContaining('Wetsuit'), findsWidgets);
    expect(find.textContaining('Since'), findsNWidgets(2));
    expect(find.textContaining('2026'), findsNWidgets(2));
  });

  testWidgets('only Loaned Out items say so, so family gear reads plainly', (
    tester,
  ) async {
    await pump(
      tester,
      items: [
        item('l', 'Lent', status: EquipmentStatus.loaned),
        item('f', 'Family'),
      ],
      current: {'l': hers, 'f': hers},
    );

    expect(find.textContaining('Loaned Out'), findsOneWidget);
    final family = find.ancestor(
      of: find.text('Family'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: family, matching: find.textContaining('Loaned')),
      findsNothing,
    );
  });

  testWidgets('places are named when gear sits at more than one', (
    tester,
  ) async {
    final other = place('other', 'Anna at the club');
    await pump(
      tester,
      items: [item('a', 'Wetsuit'), item('b', 'Fins')],
      current: {'a': hers, 'b': other},
      places: [hers, other],
    );

    expect(find.textContaining('Anna at home'), findsOneWidget);
    expect(find.textContaining('Anna at the club'), findsOneWidget);
  });

  testWidgets('one place goes unnamed', (tester) async {
    await pump(tester, items: [item('a', 'Wetsuit')], current: {'a': hers});

    expect(find.textContaining('Anna at home'), findsNothing);
  });

  testWidgets('a second linked place holding nothing does not name the '
      'place', (tester) async {
    final empty = place('empty', 'Old place', archived: true);
    await pump(
      tester,
      items: [item('a', 'Wetsuit')],
      current: {'a': hers},
      places: [hers, empty],
    );

    expect(find.textContaining('Anna at home'), findsNothing);
  });

  testWidgets('Returned names its item for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    final session = EditSession(anna);
    addTearDown(session.dispose);
    await pump(
      tester,
      items: [item('a', 'Drysuit')],
      current: {'a': hers},
      editing: session,
    );

    expect(find.bySemanticsLabel('Returned: Drysuit'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('an archived place counts: the gear is still with them', (
    tester,
  ) async {
    final old = place('old', 'Old place', archived: true);
    await pump(
      tester,
      items: [item('a', 'Wetsuit')],
      current: {'a': old},
      places: [old],
    );

    expect(find.text('Wetsuit'), findsOneWidget);
  });

  testWidgets('a row opens the item', (tester) async {
    await pump(tester, items: [item('a', 'Drysuit')], current: {'a': hers});

    await tester.tap(find.text('Drysuit'));
    await tester.pumpAndSettle();

    expect(find.text('ITEM a'), findsOneWidget);
  });

  testWidgets('in a sitting, All returned holds everything and moves '
      'nothing', (tester) async {
    final session = EditSession(anna);
    addTearDown(session.dispose);
    final moves = await pump(
      tester,
      items: [item('a', 'Drysuit'), item('b', 'Fins')],
      current: {'a': hers, 'b': hers},
      editing: session,
    );

    await tester.tap(allReturned);
    await tester.pumpAndSettle();
    expect(find.text('Return 2 items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return_equipment_confirm')));
    await tester.pumpAndSettle();

    expect(moves.returned, isEmpty);
    expect(heldBuddyGearMoves(session).single.returned!.plan.items.keys, [
      'a',
      'b',
    ]);
  });

  testWidgets('All returned waits for two rows', (tester) async {
    final session = EditSession(anna);
    addTearDown(session.dispose);
    await pump(
      tester,
      items: [item('a', 'Drysuit')],
      current: {'a': hers},
      editing: session,
    );

    expect(find.text('Returned'), findsOneWidget);
    expect(allReturned, findsNothing);
  });

  testWidgets('the open card\'s Lend gear opens the gear picker', (
    tester,
  ) async {
    final session = EditSession(anna);
    addTearDown(session.dispose);
    await pump(
      tester,
      items: [item('a', 'Drysuit')],
      current: {'a': hers},
      editing: session,
    );

    await tester.tap(find.text('Lend gear'));
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentPickerSheet), findsOneWidget);
  });

  group('on a page that edits in place (issue #4527, phase 3)', () {
    testWidgets('locked, no action is offered', (tester) async {
      await pump(
        tester,
        items: [item('a', 'Drysuit'), item('b', 'Fins')],
        current: {'a': hers, 'b': hers},
      );

      expect(title, findsOneWidget);
      expect(find.byKey(const ValueKey('buddy_gear_lend')), findsNothing);
      expect(allReturned, findsNothing);
      expect(find.byKey(const ValueKey('buddy_gear_returned_a')), findsNothing);
    });

    testWidgets('Cancel on one lent item keeps the others', (tester) async {
      final session = EditSession(anna);
      addTearDown(session.dispose);
      final drysuit = item('a', 'Drysuit');
      final fins = item('b', 'Fins');
      holdBuddyLend(
        session,
        HeldLend(
          items: [drysuit, fins],
          pick: BuddyPick(anna),
          plan: EquipmentMovePlan(
            items: const {
              'a': EquipmentStatus.active,
              'b': EquipmentStatus.active,
            },
            movedAt: DateTime(2026, 10, 1),
          ),
          diverId: 'me',
        ),
      );
      await pump(
        tester,
        items: [drysuit, fins],
        current: const {},
        editing: session,
      );
      expect(find.text('Drysuit'), findsOneWidget);
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('buddy_gear_returned_b')));
      await tester.pumpAndSettle();

      expect(find.text('Drysuit'), findsOneWidget);
      expect(find.text('Fins'), findsNothing);
      expect(heldBuddyGearMoves(session).single.lend!.items, [drysuit]);
    });

    testWidgets('a lent part offers no Cancel of its own', (tester) async {
      final session = EditSession(anna);
      addTearDown(session.dispose);
      final reg = item('a', 'Regulator');
      final hose = item('h', 'Hose');
      holdBuddyLend(
        session,
        HeldLend(
          items: [reg],
          pick: BuddyPick(anna),
          plan: EquipmentMovePlan(
            items: const {'a': EquipmentStatus.active},
            movedAt: DateTime(2026, 10, 1),
            withParts: true,
            partIds: const {'h'},
          ),
          diverId: 'me',
        ),
      );
      final shelf = place('shelf', 'Shelf', buddyId: null);
      await pump(
        tester,
        items: [reg, hose],
        // Gear is listed only once it is somewhere.
        current: {'a': shelf, 'h': shelf},
        places: [hers, shelf],
        editing: session,
      );

      expect(find.text('Hose'), findsOneWidget);
      expect(find.byKey(const ValueKey('buddy_gear_returned_h')), findsNothing);
      expect(
        find.byKey(const ValueKey('buddy_gear_returned_a')),
        findsOneWidget,
      );
    });

    testWidgets('in a sitting, Returned is held and moves nothing', (
      tester,
    ) async {
      final session = EditSession(anna);
      addTearDown(session.dispose);
      final moves = await pump(
        tester,
        items: [item('a', 'Drysuit'), item('b', 'Fins')],
        current: {'a': hers, 'b': hers},
        editing: session,
      );

      await tester.tap(find.byKey(const ValueKey('buddy_gear_returned_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('return_equipment_confirm')));
      await tester.pumpAndSettle();

      expect(moves.returned, isEmpty);
      expect(heldBuddyGearMoves(session), hasLength(1));
      expect(session.changedCardIds, {'gear'});
      expect(find.text('Drysuit'), findsNothing);
      expect(find.text('Fins'), findsOneWidget);
    });
  });
}
