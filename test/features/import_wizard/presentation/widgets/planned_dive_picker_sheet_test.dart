import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final plans = [
    Dive(
      id: 'p1',
      name: 'Blue Hole',
      dateTime: DateTime(2026, 6, 1, 9),
      isPlanned: true,
    ),
    Dive(
      id: 'p2',
      name: 'Reef',
      dateTime: DateTime(2026, 6, 2, 9),
      isPlanned: true,
    ),
  ];

  Future<String? Function()> open(
    WidgetTester tester, {
    String? selectedId,
    Set<String> unavailableIds = const {},
  }) async {
    String? picked;
    var returned = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showPlannedDivePicker(
                context,
                plannedDives: plans,
                selectedId: selectedId,
                unavailableIds: unavailableIds,
              );
              returned = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => returned ? picked : 'not returned';
  }

  testWidgets('lists planned dives and returns the tapped id', (tester) async {
    final result = await open(tester, selectedId: 'p1');
    expect(find.text('Choose a planned dive'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsOneWidget);
    expect(find.textContaining('Reef'), findsOneWidget);

    await tester.tap(find.byKey(const Key('planned_dive_picker_p2')));
    await tester.pumpAndSettle();
    expect(result(), 'p2');
  });

  testWidgets('Import as a new dive instead returns an empty string', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.tap(
      find.byKey(const Key('planned_dive_picker_import_as_new')),
    );
    await tester.pumpAndSettle();
    expect(result(), '');
  });

  testWidgets('a plan another download already fills is not offered', (
    tester,
  ) async {
    await open(tester, unavailableIds: {'p2'});
    expect(find.textContaining('Blue Hole'), findsOneWidget);
    expect(find.textContaining('Reef'), findsNothing);
  });

  testWidgets('this row keeps its own target in the list', (tester) async {
    await open(tester, selectedId: 'p2', unavailableIds: {'p2'});
    expect(find.textContaining('Reef'), findsOneWidget);
  });
}
