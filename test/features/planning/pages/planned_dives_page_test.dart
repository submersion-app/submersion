import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/pages/planned_dives_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        divePlanSummariesProvider.overrideWith(
          (ref) async => [
            DivePlanSummary(
              id: 'p1',
              name: 'Reef 30m',
              updatedAt: DateTime(2026, 7, 4),
              maxDepth: 30.0,
              mode: PlanMode.oc,
            ),
          ],
        ),
      ],
      locale: const Locale('en'),
      child: const PlannedDivesPage(),
    ),
  );

  testWidgets(
    'titles the app bar like the desktop pane it stands in for, and shows '
    'the same saved-plans content',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Saved plans'), findsOneWidget);
      expect(find.text('OC'), findsOneWidget);
      expect(find.text('Reef 30m'), findsOneWidget);
    },
  );

  testWidgets('the sort button opens a sort sheet offering date, depth '
      'and name', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Max Depth'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });
}
