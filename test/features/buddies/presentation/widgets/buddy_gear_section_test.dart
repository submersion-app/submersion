import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_gear_section.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  final returned = <Iterable<String>>[];

  /// Runs while a move is being written, as a real save refreshes the list.
  void Function()? onRecord;

  /// How long the write takes, so a test can let frames pass during it.
  Duration writeTakes = Duration.zero;

  @override
  Future<T> inTransaction<T>(Future<T> Function() body) => body();

  @override
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async =>
      const [];

  @override
  Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> ids) async =>
      const {};

  @override
  Future<List<EquipmentLocationMove>> recordMoves({
    required Iterable<String> equipmentIds,
    required String? locationId,
    required DateTime movedAt,
    String note = '',
  }) async {
    returned.add(equipmentIds);
    onRecord?.call();
    await Future<void>.delayed(writeTakes);
    return const [];
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
            body: SingleChildScrollView(child: BuddyGearSection(buddy: anna)),
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
    await pump(tester, items: [item('a', 'Drysuit')], current: {'a': hers});

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

  testWidgets('Returned takes back that one item', (tester) async {
    final moves = await pump(
      tester,
      items: [item('a', 'Drysuit'), item('b', 'Fins')],
      current: {'a': hers, 'b': hers},
    );

    await tester.tap(find.byKey(const ValueKey('buddy_gear_returned_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return_equipment_confirm')));
    await tester.pumpAndSettle();

    expect(moves.returned.single, ['a']);
  });

  testWidgets('All returned takes back everything', (tester) async {
    final moves = await pump(
      tester,
      items: [item('a', 'Drysuit'), item('b', 'Fins')],
      current: {'a': hers, 'b': hers},
    );

    await tester.tap(allReturned);
    await tester.pumpAndSettle();
    expect(find.text('Return 2 items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return_equipment_confirm')));
    await tester.pumpAndSettle();

    expect(moves.returned.single, ['a', 'b']);
  });

  testWidgets('All returned waits for two rows', (tester) async {
    await pump(tester, items: [item('a', 'Drysuit')], current: {'a': hers});

    expect(find.text('Returned'), findsOneWidget);
    expect(allReturned, findsNothing);
  });

  testWidgets('the header offers Lend gear', (tester) async {
    await pump(tester, items: [item('a', 'Drysuit')], current: {'a': hers});

    expect(find.text('Lend gear'), findsOneWidget);
  });

  testWidgets('the Active prompt still shows once the row has left the list', (
    tester,
  ) async {
    final current = StateProvider<Map<String, EquipmentLocation>>(
      (ref) => {'a': hers},
    );
    final moves = _FakeMoves();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(child: BuddyGearSection(buddy: anna)),
          ),
        ),
      ],
    );
    final loaned = item('a', 'Drysuit', status: EquipmentStatus.loaned);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allEquipmentProvider.overrideWith((ref) async => [loaned]),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => ref.watch(current),
          ),
          allEquipmentLocationsByIdProvider.overrideWith(
            (ref) async => {'hers': hers},
          ),
          equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
          equipmentListNotifierProvider.overrideWith(
            (ref) => _StatusNotifier(),
          ),
          equipmentLocationMovesProvider(
            'a',
          ).overrideWith((ref) async => const <EquipmentLocationMove>[]),
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BuddyGearSection)),
    );
    moves.onRecord = () => container.read(current.notifier).state = const {};
    moves.writeTakes = const Duration(milliseconds: 500);

    await tester.tap(find.byKey(const ValueKey('buddy_gear_returned_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return_equipment_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Drysuit'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Update status?'), findsOneWidget);
  });
}
