import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeLocations extends Fake implements EquipmentLocationRepository {
  _FakeLocations(this.place);
  final EquipmentLocation place;
  var calls = 0;

  @override
  Future<EquipmentLocation> findOrCreateForBuddy({
    required String? diverId,
    required String buddyId,
    required String name,
  }) async {
    calls++;
    return place;
  }
}

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  final recorded = <(Iterable<String>, String?)>[];

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
    recorded.add((equipmentIds, locationId));
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

/// Lending from the buddy page (issue #3790).
void main() {
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
    name: 'Blue 5mm',
    type: EquipmentType.wetsuit,
  );
  const fins = EquipmentItem(
    id: 'fin',
    name: 'Jet fins',
    type: EquipmentType.fins,
  );

  Future<({_FakeLocations locations, _FakeMoves moves, List<HeldLend?> held})>
  pump(WidgetTester tester, {bool failRead = false}) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final locations = _FakeLocations(annasPlace);
    final moves = _FakeMoves();
    final held = <HeldLend?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [wetsuit, fins],
          ),
          currentEquipmentLocationsProvider.overrideWith((ref) async {
            if (failRead) throw StateError('no');
            return {'fin': annasPlace};
          }),
          equipmentLocationsProvider.overrideWith((ref) async => [annasPlace]),
          equipmentLocationRepositoryProvider.overrideWithValue(locations),
          equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
          equipmentListNotifierProvider.overrideWith(
            (ref) => _StatusNotifier(),
          ),
          allDiversProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                held.add(await planLendGear(context, ref, anna)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (locations: locations, moves: moves, held: held);
  }

  testWidgets('leaves out gear already with this buddy', (tester) async {
    await pump(tester);

    expect(find.text('Blue 5mm'), findsOneWidget);
    expect(find.text('Jet fins'), findsNothing);
  });

  testWidgets('a failed read says so instead of doing nothing', (tester) async {
    final fakes = await pump(tester, failRead: true);

    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(fakes.held, [null]);
  });

  testWidgets('cancelling the picker holds nothing', (tester) async {
    final fakes = await pump(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move_equipment_confirm')), findsNothing);
    expect(fakes.locations.calls, 0);
    expect(fakes.held, [null]);
  });

  group('held on a page that edits in place (issue #4527, phase 3)', () {
    testWidgets('a lend opens the Move sheet on the buddy, asks its '
        'questions and writes nothing', (tester) async {
      final fakes = await pump(tester);

      await tester.tap(find.text('Blue 5mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Anna Lindqvist'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('move_equipment_confirm')));
      await tester.pumpAndSettle();
      // Lent to a person: Loaned Out is offered, and taken.
      final l = AppLocalizationsEn();
      await tester.tap(find.text(l.equipment_location_status_yes));
      await tester.pumpAndSettle();

      final lend = fakes.held.single!;
      expect([for (final i in lend.items) i.id], ['wet']);
      expect((lend.pick as BuddyPick).buddy.id, 'anna');
      expect(lend.plan.status, EquipmentStatus.loaned);
      expect(lend.diverId, 'me');
      expect(fakes.locations.calls, 0);
      expect(fakes.moves.recorded, isEmpty);
    });

    testWidgets('backing out of the move sheet holds nothing', (tester) async {
      final fakes = await pump(tester);

      await tester.tap(find.text('Blue 5mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(fakes.held, [null]);
    });
  });
}
