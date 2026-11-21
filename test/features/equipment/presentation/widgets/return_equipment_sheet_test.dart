import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
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
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async {
    if (failing) throw StateError('no');
    return history[equipmentId] ?? const [];
  }

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
    for (final g in groups) {
      recorded.add((g.locationId, g.movedAt, note));
    }
  }
}

/// The return sheet on a buddy's page in its sitting (issue #3790; held
/// until Save since issue #4527, phase 3): it asks everything now and
/// writes nothing.
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

  /// Opens the sheet; [held] is what the flow handed back once it ends.
  Future<({_FakeMoves moves, List<HeldReturn?> held})> pump(
    WidgetTester tester,
    List<EquipmentItem> items,
    Map<String, List<EquipmentLocationMove>> history, {
    bool failing = false,
  }) async {
    final moves = _FakeMoves(history, failing: failing);
    final held = <HeldReturn?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentLocationMoveRepositoryProvider.overrideWithValue(moves),
          allEquipmentLocationsByIdProvider.overrideWith((ref) async => places),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => held.add(
              await planEquipmentReturn(
                context,
                ref,
                items: items,
                buddyId: 'b1',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (moves: moves, held: held);
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

  testWidgets('confirming holds a return today, with the note, asks about '
      'Active, and writes nothing', (tester) async {
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
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    final plan = fakes.held.single!.plan;
    expect(plan.items.keys, ['wet']);
    expect(plan.note, 'rinsed');
    expect(plan.setActive, isTrue);
    expect(DateTime.now().difference(plan.movedAt).inMinutes, lessThan(1));
    expect(fakes.moves.recorded, isEmpty);
  });

  testWidgets('a picked day is the day held, at noon', (tester) async {
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
    await tester.tap(find.text('Keep status'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(
      fakes.held.single!.plan.movedAt,
      DateTime(now.year, now.month - 1, 15, 12),
    );
  });

  testWidgets('dismissing holds nothing', (tester) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(fakes.held.single, isNull);
    expect(fakes.moves.recorded, isEmpty);
  });

  testWidgets('a failed read says so and holds nothing', (tester) async {
    final fakes = await pump(
      tester,
      [wet],
      {'wet': historyFrom('wet', 'shelf')},
      failing: true,
    );

    expect(tester.takeException(), isNull);
    expect(fakes.held.single, isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
