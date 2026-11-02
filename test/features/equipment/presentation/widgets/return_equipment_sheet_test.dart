import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/return_equipment_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  _FakeMoves(this.history, {this.failing = false});
  final Map<String, List<EquipmentLocationMove>> history;
  final bool failing;
  final recorded = <(String?, DateTime, String)>[];

  @override
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async =>
      history[equipmentId] ?? const [];

  @override
  Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> ids) async =>
      const {};

  @override
  Future<Map<String, String?>> getCurrentLocationIds() async => const {};

  @override
  Future<void> recordMoveGroups(
    List<MoveGroup> groups, {
    String note = '',
  }) async {
    if (failing) throw StateError('no');
    for (final g in groups) {
      recorded.add((g.locationId, g.movedAt, note));
    }
  }
}

class _StatusNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _StatusNotifier({this.failing = false}) : super(const AsyncValue.data([]));
  final bool failing;
  final statuses = <EquipmentStatus>[];

  @override
  Future<void> setStatusForMany(
    List<String> ids,
    EquipmentStatus status,
  ) async {
    if (failing) throw StateError('no');
    statuses.add(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  EquipmentLocation place(
    String id,
    String name, {
    String? buddyId,
    EquipmentLocationKind kind = EquipmentLocationKind.storage,
  }) => EquipmentLocation(
    id: id,
    name: name,
    kind: kind,
    buddyId: buddyId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final places = {
    'anna': place(
      'anna',
      'Anna',
      buddyId: 'b1',
      kind: EquipmentLocationKind.person,
    ),
    'shelf': place('shelf', 'Garage shelf'),
    'locker': place('locker', 'Club locker'),
  };

  EquipmentLocationMove move(String item, String id, String? at, int month) =>
      EquipmentLocationMove(
        id: id,
        equipmentId: item,
        locationId: at,
        movedAt: DateTime(2026, month),
        createdAt: DateTime(2026, month),
      );

  List<EquipmentLocationMove> historyFrom(String item, String? before) => [
    move(item, '$item-2', 'anna', 6),
    move(item, '$item-1', before, 3),
  ];

  const wet = EquipmentItem(
    id: 'wet',
    name: 'Wetsuit',
    type: EquipmentType.wetsuit,
    status: EquipmentStatus.loaned,
  );
  const bcd = EquipmentItem(
    id: 'bcd',
    name: 'BCD',
    type: EquipmentType.bcd,
    status: EquipmentStatus.loaned,
  );

  final confirm = find.byKey(const ValueKey('return_equipment_confirm'));

  Future<({_FakeMoves moves, _StatusNotifier status})> pump(
    WidgetTester tester,
    List<EquipmentItem> items,
    Map<String, List<EquipmentLocationMove>> history, {
    bool failing = false,
    bool statusFails = false,
  }) async {
    final moves = _FakeMoves(history, failing: failing);
    final status = _StatusNotifier(failing: statusFails);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
          allEquipmentLocationsByIdProvider.overrideWith((ref) async => places),
          equipmentListNotifierProvider.overrideWith((ref) => status),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showEquipmentReturnFlow(
              context,
              ref,
              items: items,
              buddyId: 'b1',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (moves: moves, status: status);
  }

  testWidgets('one destination is named', (tester) async {
    await pump(tester, [wet], {'wet': historyFrom('wet', 'shelf')});

    expect(find.text('Return 1 item'), findsOneWidget);
    expect(find.text('Back to Garage shelf'), findsOneWidget);
  });

  testWidgets('no destination reads No location', (tester) async {
    await pump(tester, [wet], {'wet': historyFrom('wet', null)});

    expect(find.text('Back to No location'), findsOneWidget);
  });

  testWidgets('several destinations say each goes back where it was', (
    tester,
  ) async {
    await pump(
      tester,
      [wet, bcd],
      {'wet': historyFrom('wet', 'shelf'), 'bcd': historyFrom('bcd', 'locker')},
    );

    expect(find.text('Return 2 items'), findsOneWidget);
    expect(find.text('Each item goes back where it was'), findsOneWidget);
  });

  testWidgets('confirming returns today, with the note, then offers Active', (
    tester,
  ) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
    );

    await tester.enterText(
      find.byKey(const ValueKey('return_equipment_note')),
      'rinsed',
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final (locationId, movedAt, note) = fakes.moves.recorded.single;
    expect(locationId, 'shelf');
    expect(note, 'rinsed');
    expect(DateTime.now().difference(movedAt).inMinutes, lessThan(1));

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(fakes.status.statuses, [EquipmentStatus.active]);
    expect(find.text('1 item returned'), findsOneWidget);
  });

  testWidgets('a picked day is the day recorded, at noon', (tester) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
    );

    await tester.tap(find.byKey(const ValueKey('return_equipment_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(
      fakes.moves.recorded.single.$2,
      DateTime(now.year, now.month - 1, 15, 12),
    );
  });

  testWidgets('a failed status write says so, and the return still counts', (
    tester,
  ) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
      statusFails: true,
    );

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fakes.moves.recorded, hasLength(1));
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('dismissing writes nothing', (tester) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(fakes.moves.recorded, isEmpty);
    expect(fakes.status.statuses, isEmpty);
  });

  testWidgets('a failed return says so', (tester) async {
    await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
      failing: true,
    );

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
