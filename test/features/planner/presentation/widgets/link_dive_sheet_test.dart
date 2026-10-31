import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/link_dive_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Dive dive(String id, int number, DateTime when, {bool isPlanned = false}) =>
      Dive(id: id, diveNumber: number, dateTime: when, isPlanned: isPlanned);

  Future<void> pump(
    WidgetTester tester,
    List<Dive> dives, {
    DateTime? planDay,
    String? currentDiveId,
  }) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divesProvider.overrideWith((ref) async => dives),
        ],
        locale: const Locale('en'),
        child: LinkDiveSheet(planDay: planDay, currentDiveId: currentDiveId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<String> shownTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  testWidgets('lists dives newest first', (tester) async {
    await pump(tester, [
      dive('a', 1, DateTime.utc(2026, 1, 1)),
      dive('c', 3, DateTime.utc(2026, 3, 1)),
      dive('b', 2, DateTime.utc(2026, 2, 1)),
    ]);

    expect(shownTitles(tester), ['#3', '#2', '#1']);
  });

  testWidgets('lists the plan\'s day first, then newest', (tester) async {
    await pump(tester, [
      dive('a', 1, DateTime.utc(2026, 1, 1, 9)),
      dive('b', 2, DateTime.utc(2026, 2, 1, 9)),
      dive('c', 3, DateTime.utc(2026, 3, 1, 9)),
    ], planDay: DateTime(2026, 2, 1));

    expect(shownTitles(tester), ['#2', '#3', '#1']);
  });

  testWidgets('leaves out planned dives', (tester) async {
    await pump(tester, [
      dive('a', 1, DateTime.utc(2026, 1, 1)),
      dive('p', 2, DateTime.utc(2026, 2, 1), isPlanned: true),
    ]);

    expect(shownTitles(tester), ['#1']);
  });

  testWidgets('marks the dive already linked', (tester) async {
    await pump(tester, [
      dive('a', 1, DateTime.utc(2026, 1, 1)),
    ], currentDiveId: 'a');

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('says so when there is nothing to link', (tester) async {
    await pump(tester, const []);

    expect(find.text('No logged dives yet'), findsOneWidget);
  });
}
