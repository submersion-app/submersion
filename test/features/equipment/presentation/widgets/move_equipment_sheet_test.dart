import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeLocations extends Fake implements EquipmentLocationRepository {
  _FakeLocations(this.place);
  final EquipmentLocation place;
  final calls = <(String?, String, String)>[];

  @override
  Future<EquipmentLocation> findOrCreateForBuddy({
    required String? diverId,
    required String buddyId,
    required String name,
  }) async {
    calls.add((diverId, buddyId, name));
    return place;
  }
}

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  _FakeMoves({this.parts = const {}});

  final Map<String, EquipmentStatus> parts;
  final recorded = <String?>[];
  final movedIds = <String>[];

  @override
  Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> ids) async =>
      parts;

  @override
  Future<List<EquipmentLocationMove>> recordMoves({
    required Iterable<String> equipmentIds,
    required String? locationId,
    required DateTime movedAt,
    String note = '',
  }) async {
    recorded.add(locationId);
    movedIds.addAll(equipmentIds);
    return const [];
  }
}

class _StatusNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _StatusNotifier() : super(const AsyncValue.data([]));
  final statuses = <EquipmentStatus>[];

  @override
  Future<void> setStatusForMany(
    List<String> ids,
    EquipmentStatus status,
  ) async => statuses.add(status);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final garage = EquipmentLocation(
    id: 'g',
    name: 'Garage',
    kind: EquipmentLocationKind.storage,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('Move stays disabled until a place is chosen, then returns '
      'the draft', (tester) async {
    MoveDraft? draft;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentLocationsProvider.overrideWith((ref) async => [garage]),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => draft = await showMoveEquipmentSheet(
              context,
              ref,
              itemCount: 2,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Move 2 items'), findsOneWidget);
    expect(find.text('Choose a place'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('move_equipment_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('move_equipment_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('move_equipment_note')),
      'annual',
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect((draft!.pick as PlacePick).location.id, 'g');
    expect(draft!.note, 'annual');
    // Today keeps the time of day, so it lands after any earlier move today.
    expect(DateTime.now().difference(draft!.movedAt).inMinutes, lessThan(1));
  });

  group('lending to a buddy', () {
    final anna = Buddy(
      id: 'anna',
      name: 'Anna Lindqvist',
      notes: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final annasPlace = EquipmentLocation(
      id: 'annas',
      name: 'Anna Lindqvist',
      kind: EquipmentLocationKind.person,
      buddyId: 'anna',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const wetsuit = EquipmentItem(
      id: 'wet',
      name: 'Wetsuit',
      type: EquipmentType.wetsuit,
    );

    Future<
      ({_FakeLocations locations, _FakeMoves moves, _StatusNotifier status})
    >
    pumpFlow(
      WidgetTester tester, {
      Buddy? lendTo,
      Map<String, EquipmentStatus> parts = const {},
    }) async {
      final locations = _FakeLocations(annasPlace);
      final moves = _FakeMoves(parts: parts);
      final status = _StatusNotifier();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            equipmentLocationsProvider.overrideWith((ref) async => [garage]),
            allBuddiesProvider.overrideWith((ref) async => [anna]),
            equipmentLocationRepositoryProvider.overrideWithValue(locations),
            equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
            equipmentListNotifierProvider.overrideWith((ref) => status),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          ],
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showMoveEquipmentFlow(
                context,
                ref,
                items: const [wetsuit],
                lendTo: lendTo,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (locations: locations, moves: moves, status: status);
    }

    final confirm = find.byKey(const ValueKey('move_equipment_confirm'));

    testWidgets('a buddy shows by name and enables Move', (tester) async {
      await pumpFlow(tester, lendTo: anna);

      expect(find.text('Anna Lindqvist'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('confirming resolves the place and offers Loaned Out', (
      tester,
    ) async {
      final fakes = await pumpFlow(tester, lendTo: anna);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(fakes.locations.calls, [('me', 'anna', 'Anna Lindqvist')]);
      expect(fakes.moves.recorded, ['annas']);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(fakes.status.statuses, [EquipmentStatus.loaned]);
    });

    testWidgets('answering No leaves the status alone', (tester) async {
      final fakes = await pumpFlow(tester, lendTo: anna);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep status'));
      await tester.pumpAndSettle();

      expect(fakes.moves.recorded, ['annas']);
      expect(fakes.status.statuses, isEmpty);
    });

    testWidgets('cancelling creates no place', (tester) async {
      final fakes = await pumpFlow(tester, lendTo: anna);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(fakes.locations.calls, isEmpty);
      expect(fakes.moves.recorded, isEmpty);
    });

    testWidgets('a lend asks whether the parts go too', (tester) async {
      final fakes = await pumpFlow(
        tester,
        lendTo: anna,
        parts: const {'hood': EquipmentStatus.active},
      );

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Move parts too?'), findsOneWidget);
      await tester.tap(find.text('Move parts'));
      await tester.pumpAndSettle();

      expect(fakes.moves.movedIds, ['wet', 'hood']);
    });

    testWidgets('the picker path lends through the same steps', (tester) async {
      final fakes = await pumpFlow(tester);

      await tester.tap(find.byKey(const ValueKey('move_equipment_to')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lend to a buddy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna Lindqvist'));
      await tester.pumpAndSettle();
      expect(fakes.locations.calls, isEmpty);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(fakes.locations.calls, hasLength(1));
      expect(fakes.moves.recorded, ['annas']);
    });
  });
}
