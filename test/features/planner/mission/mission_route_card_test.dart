import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: const Locale('en'),
  child: const PlanEditorPane(),
);

void main() {
  testWidgets('turning the mission on swaps the segments for the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsNothing);
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Leg 1'), findsOneWidget);
    // The starter is incomplete: the strip names why there is no profile.
    expect(find.textContaining('No profile yet'), findsOneWidget);
  });

  testWidgets('turning it off asks first and keeps the segments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off the DPV mission?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEditorPane)),
    );
    expect(container.read(divePlanNotifierProvider).mission, isNull);
    expect(find.text('Route'), findsNothing);
  });

  testWidgets('adding a leg adds a row', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add leg'));
    await tester.pumpAndSettle();
    expect(find.text('Leg 2'), findsOneWidget);
  });

  testWidgets('the route card fits a 320 pt phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan as DPV mission'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
