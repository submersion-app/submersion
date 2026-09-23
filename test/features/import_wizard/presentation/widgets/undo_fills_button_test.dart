import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/undo_fills_button.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

PlannedDiveFillOutcome _outcome(String id) => PlannedDiveFillOutcome(
  diveId: id,
  snapshot: DiveMergeSnapshot(
    mergedDiveId: id,
    diveRows: const [],
    tankRows: const [],
    weightRows: const [],
    customFieldRows: const [],
    equipmentRows: const [],
    diveTypeRows: const [],
    tagRows: const [],
    buddyRows: const [],
    sightingRows: const [],
    eventRows: const [],
    gasSwitchRows: const [],
    dataSourceRows: const [],
    tideRows: const [],
    mediaDiveIds: const {},
  ),
  assignedDiveNumber: 1,
);

/// Records undo calls; throws for the ids in [failFor].
class _FakeFillService implements PlannedDiveFillService {
  final undone = <String>[];
  Set<String> failFor = {};

  @override
  Future<void> undo(PlannedDiveFillOutcome outcome) async {
    if (failFor.contains(outcome.diveId)) throw StateError('undo failed');
    undone.add(outcome.diveId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeFillService service) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
        child: UndoFillsButton(
          outcomes: [_outcome('a'), _outcome('b')],
          service: service,
        ),
      ),
    );
    await tester.pump();
  }

  TextButton button(WidgetTester tester) => tester.widget<TextButton>(
    find.byKey(const Key('import_summary_undo_fills')),
  );

  testWidgets('undoes every fill, confirms, and disables itself', (
    tester,
  ) async {
    final service = _FakeFillService();
    await pump(tester, service);

    await tester.tap(find.text('Undo fills'));
    await tester.pumpAndSettle();

    expect(service.undone, ['a', 'b']);
    expect(find.text('Planned dives restored'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('a failure is reported and only the rest is retried', (
    tester,
  ) async {
    final service = _FakeFillService()..failFor = {'b'};
    await pump(tester, service);

    await tester.tap(find.text('Undo fills'));
    await tester.pumpAndSettle();

    expect(service.undone, ['a']);
    expect(
      find.text('Could not restore every planned dive. Try again.'),
      findsOneWidget,
    );
    expect(button(tester).onPressed, isNotNull);

    service.failFor = {};
    await tester.tap(find.text('Undo fills'));
    await tester.pumpAndSettle();

    // 'a' was restored the first time and is not undone twice.
    expect(service.undone, ['a', 'b']);
    expect(button(tester).onPressed, isNull);
  });
}
