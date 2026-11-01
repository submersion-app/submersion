import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_shortcuts.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Alt+Left, Alt+Right and Alt+N in the planner (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    // Somewhere in the planner, not in a text field.
    await tester.tap(find.byType(PlanSeriesShortcuts), warnIfMissed: false);
    Focus.of(tester.element(find.byType(LayoutBuilder).first)).requestFocus();
    await tester.pump();
  }

  Future<void> alt(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) =>
      containerOf(tester).read(planSeriesNotifierProvider).selectedIndex;

  testWidgets('Alt+N adds a dive and Alt+arrows move between them', (
    tester,
  ) async {
    await pumpPlan(tester);

    await alt(tester, LogicalKeyboardKey.keyN);
    expect(
      containerOf(tester).read(planSeriesNotifierProvider).dives,
      hasLength(2),
    );
    expect(selected(tester), 1);

    await alt(tester, LogicalKeyboardKey.arrowLeft);
    expect(selected(tester), 0);

    await alt(tester, LogicalKeyboardKey.arrowRight);
    expect(selected(tester), 1);
  });

  testWidgets('they stand down while a text field has focus', (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.byKey(const Key('diveNameField')));
    await tester.pump();

    await alt(tester, LogicalKeyboardKey.keyN);

    expect(
      containerOf(tester).read(planSeriesNotifierProvider).dives,
      hasLength(1),
    );
  });

  testWidgets('the planner lists them in the shortcuts help while open', (
    tester,
  ) async {
    await pumpPlan(tester);
    final labels = [
      for (final e in ShortcutCatalog.instance.entries)
        if (e.category == plannerShortcutCategory) e.label,
    ];
    expect(labels, [
      previousPlannedDiveShortcut,
      nextPlannedDiveShortcut,
      addPlannedDiveShortcut,
    ]);

    await tester.pumpWidget(const SizedBox());
    expect(
      ShortcutCatalog.instance.entries.where(
        (e) => e.category == plannerShortcutCategory,
      ),
      isEmpty,
    );
  });
}
