import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_navigator.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/widgets/planned_dive_icon.dart';
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

/// The repetitive series UI on the plan canvas (issue #3565): the navigator,
/// the Surface interval card, Fill, and Save held back for a series.
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

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(WidgetTester tester, Size size) async {
    await setSize(tester, size);
    await tester.pumpWidget(harness());
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  Future<void> addDive(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add a dive'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  }

  PopupMenuItem<String> menuItem(WidgetTester tester, String label) =>
      tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );

  Finder tooltipOn(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Tooltip));

  Finder navigatorText(String text) => find.descendant(
    of: find.byType(PlanSeriesNavigator),
    matching: find.text(text),
  );

  Finder siField() => find.byKey(const Key('surfaceIntervalField'));
  Finder nameField() => find.byKey(const Key('diveNameField'));

  Finder plannedIcons() => find.descendant(
    of: find.byType(PlanSeriesNavigator),
    matching: find.byType(PlannedDiveIcon),
  );

  for (final (name, size) in [
    ('desktop', const Size(1400, 900)),
    ('phone', const Size(420, 900)),
  ]) {
    group('on $name', () {
      testWidgets('a new plan shows Dive A and the add button', (tester) async {
        await pumpPlan(tester, size);
        expect(navigatorText('A'), findsOneWidget);
        expect(find.byTooltip('Dive A'), findsOneWidget);
        expect(plannedIcons(), findsOneWidget);
        expect(find.byTooltip('Add a dive'), findsOneWidget);
        expect(find.byTooltip('Previous dive'), findsNothing);
        expect(find.byTooltip('Next dive'), findsNothing);
      });

      testWidgets('+ adds Dive B after a 1:00 surface interval', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        await addDive(tester);

        expect(navigatorText('B'), findsOneWidget);
        expect(find.byTooltip('Dive B'), findsOneWidget);
        expect(plannedIcons(), findsNWidgets(2));
        expect(navigatorText('1:00'), findsOneWidget);
        expect(find.byTooltip('Surface interval 1:00'), findsOneWidget);
        final series = containerOf(tester).read(planSeriesNotifierProvider);
        expect(series.selectedIndex, 1);
      });

      testWidgets('the interval is greyed out on Dive A, live after it', (
        tester,
      ) async {
        bool siEnabled() => tester.widget<TextField>(siField()).enabled!;
        IconButton stepper(String tooltip) => tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        );

        await pumpPlan(tester, size);
        expect(find.text('Dive details'), findsOneWidget);
        expect(siEnabled(), isFalse);
        expect(stepper('15 minutes more').onPressed, isNull);
        expect(stepper('15 minutes less').onPressed, isNull);

        await addDive(tester);
        expect(siEnabled(), isTrue);
        expect(stepper('15 minutes more').onPressed, isNotNull);

        await tester.tap(find.byTooltip('Dive A'));
        await tester.pumpAndSettle();
        expect(siEnabled(), isFalse);
      });

      testWidgets('moving between dives leaves the panels where they are', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        await addDive(tester);
        final onB = tester.getTopLeft(find.byType(PlanTankList));

        await tester.tap(find.byTooltip('Dive A'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(PlanTankList)), onB);
      });

      testWidgets('Dive details holds only the name and interval', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        expect(
          find.descendant(
            of: find.byType(PlanDiveDetailsCard),
            matching: find.byType(PlanEnvironmentSection),
          ),
          findsNothing,
        );
      });

      testWidgets('a named dive shows its name instead of its letter', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        expect(navigatorText('A'), findsOneWidget);
        await tester.enterText(nameField(), 'Morning dive');
        await tester.pumpAndSettle();

        expect(navigatorText('Morning dive'), findsOneWidget);
        expect(navigatorText('A'), findsNothing);
        expect(find.byTooltip('Dive A: Morning dive'), findsOneWidget);
        expect(
          containerOf(tester).read(planSeriesNotifierProvider).selected.name,
          'Morning dive',
        );
      });

      testWidgets('Save is held back while the plan is a series', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        IconButton save() => tester.widget<IconButton>(
          find.ancestor(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Icon &&
                  (w.icon == Icons.save || w.icon == Icons.save_outlined),
            ),
            matching: find.byType(IconButton),
          ),
        );
        expect(save().onPressed, isNotNull);

        await addDive(tester);
        // An edited dive, so only the series holds Save back.
        containerOf(
          tester,
        ).read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);
        await tester.pumpAndSettle();
        expect(
          containerOf(tester).read(divePlanNotifierProvider).isDirty,
          isTrue,
        );
        expect(save().onPressed, isNull);
        expect(save().tooltip, "A series of dives can't be saved yet");
      });

      testWidgets('Convert to Dive says why a series holds it back', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        await openMenu(tester);
        expect(menuItem(tester, 'Convert to Dive').enabled, isTrue);
        expect(tooltipOn('Convert to Dive'), findsNothing);
        await closeMenu(tester);

        await addDive(tester);
        await openMenu(tester);
        expect(menuItem(tester, 'Convert to Dive').enabled, isFalse);
        expect(
          tester.widget<Tooltip>(tooltipOn('Convert to Dive')).message,
          "A series of dives can't be converted to logged dives yet",
        );
      });

      testWidgets('Follow a dive is offered on the first dive only', (
        tester,
      ) async {
        await pumpPlan(tester, size);
        await addDive(tester);
        await openMenu(tester);
        expect(menuItem(tester, 'Follow a dive').enabled, isFalse);
        expect(
          tester.widget<Tooltip>(tooltipOn('Follow a dive')).message,
          'Only the first dive of a series can follow a logged dive',
        );
        await closeMenu(tester);

        await tester.tap(find.byTooltip('Dive A'));
        await tester.pumpAndSettle();
        await openMenu(tester);
        expect(menuItem(tester, 'Follow a dive').enabled, isTrue);
        expect(tooltipOn('Follow a dive'), findsNothing);
      });
    });
  }

  testWidgets('the DPV mission toggle says why a series holds it back', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 900));
    SwitchListTile toggle() => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Plan as DPV mission'),
    );
    expect(toggle().onChanged, isNotNull);
    expect(tooltipOn('Plan as DPV mission'), findsNothing);

    await addDive(tester);
    expect(toggle().onChanged, isNull);
    expect(
      tester.widget<Tooltip>(tooltipOn('Plan as DPV mission')).message,
      "A series of dives can't be planned as a DPV mission",
    );

    await tester.tap(find.byTooltip('Dive A'));
    await tester.pumpAndSettle();
    expect(toggle().onChanged, isNull);
  });

  testWidgets('typing a surface interval sets it on the dive', (tester) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);

    await tester.enterText(
      find.byKey(const Key('surfaceIntervalField')),
      '2:30',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final c = containerOf(tester);
    expect(
      c.read(divePlanNotifierProvider).surfaceInterval,
      const Duration(hours: 2, minutes: 30),
    );
    expect(navigatorText('2:30'), findsOneWidget);
  });

  testWidgets('an invalid surface interval is flagged, not applied', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);

    await tester.enterText(
      find.byKey(const Key('surfaceIntervalField')),
      '1:75',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Enter a time as h:mm'), findsOneWidget);
    expect(
      containerOf(tester).read(divePlanNotifierProvider).surfaceInterval,
      const Duration(hours: 1),
    );
  });

  testWidgets('the steppers move the surface interval 15 minutes', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);

    await tester.tap(find.byTooltip('15 minutes more'));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(divePlanNotifierProvider).surfaceInterval,
      const Duration(hours: 1, minutes: 15),
    );
    expect(find.byType(PlanDiveDetailsCard), findsOneWidget);
  });

  testWidgets('Fill all tanks refills the carried tanks', (tester) async {
    await pumpPlan(tester, const Size(1400, 900));
    final c = containerOf(tester);
    final full = c.read(divePlanNotifierProvider).tanks.first.startPressure;
    expect(find.text('Fill all tanks'), findsNothing);

    await addDive(tester);
    expect(
      c.read(divePlanNotifierProvider).tanks.first.startPressure,
      lessThan(full!),
    );
    expect(find.text('Fill all tanks'), findsOneWidget);

    await tester.tap(find.text('Fill all tanks'));
    await tester.pumpAndSettle();
    expect(c.read(divePlanNotifierProvider).tanks.first.startPressure, full);
    expect(find.text('Fill all tanks'), findsNothing);
  });

  testWidgets('a single tank fills from its own Fill button', (tester) async {
    await pumpPlan(tester, const Size(1400, 900));
    final c = containerOf(tester);
    final full = c.read(divePlanNotifierProvider).tanks.first.startPressure;
    await addDive(tester);

    final tank = c.read(divePlanNotifierProvider).tanks.first;
    await tester.tap(find.byTooltip('Fill ${tank.name ?? tank.gasMix.name}'));
    await tester.pumpAndSettle();
    expect(c.read(divePlanNotifierProvider).tanks.first.startPressure, full);
  });

  testWidgets('the selected dive is removed after confirming', (tester) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);

    await tester.tap(find.byTooltip('Remove Dive B'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Dive B'), findsNothing);
    expect(
      containerOf(tester).read(planSeriesNotifierProvider).isSeries,
      isFalse,
    );
  });

  testWidgets('the name field follows the selected dive', (tester) async {
    await pumpPlan(tester, const Size(1400, 900));
    await tester.enterText(nameField(), 'Wreck');
    await addDive(tester);

    TextField field() => tester.widget<TextField>(nameField());
    expect(field().controller!.text, isEmpty);
    expect(field().decoration!.hintText, 'B');

    await tester.tap(find.byTooltip('Dive A: Wreck'));
    await tester.pumpAndSettle();
    expect(field().controller!.text, 'Wreck');
  });

  testWidgets("a dive's dot takes the colour of its worst warning", (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);
    final c = containerOf(tester);
    final results = c.read(planSeriesResultsProvider);
    PlanIssueSeverity worst(int i) => results[i].outcome.issues
        .map((issue) => issue.severity)
        .reduce((a, b) => a.index >= b.index ? a : b);
    // The fixture: A raises warnings only; B, on A's leftover gas, runs
    // its tank empty, which is critical.
    expect(worst(0), isNot(PlanIssueSeverity.critical));
    expect(worst(1), PlanIssueSeverity.critical);

    Badge badge(String tooltip) => tester.widget<Badge>(
      find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(Badge)),
    );
    final scheme = Theme.of(
      tester.element(find.byType(PlanSeriesNavigator)),
    ).colorScheme;
    expect(badge('Dive A').isLabelVisible, isTrue);
    expect(badge('Dive A').backgroundColor, Colors.orange);
    expect(badge('Dive B').backgroundColor, scheme.error);
  });

  group('the surface interval field', () {
    Future<ProviderContainer> threeDives(WidgetTester tester) async {
      await pumpPlan(tester, const Size(1400, 900));
      await addDive(tester);
      await addDive(tester);
      return containerOf(tester);
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(siField()).controller!.text;

    testWidgets('a touch on another dive commits to the dive it was typed on', (
      tester,
    ) async {
      final c = await threeDives(tester);
      await tester.tap(siField());
      await tester.pump();
      await tester.enterText(siField(), '3:00');
      await tester.pump();

      await tester.tap(find.byTooltip('Dive B'));
      await tester.pumpAndSettle();

      final s = c.read(planSeriesNotifierProvider);
      expect(s.selectedIndex, 1);
      expect(s.dives[1].state.surfaceInterval, const Duration(hours: 1));
      expect(s.dives[2].state.surfaceInterval, const Duration(hours: 3));
      expect(fieldText(tester), '1:00');
    });

    testWidgets(
      'invalid text does not follow to a dive with the same interval',
      (tester) async {
        await threeDives(tester);
        await tester.enterText(siField(), '1:75');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Enter a time as h:mm'), findsOneWidget);

        await tester.tap(find.byTooltip('Dive B'));
        await tester.pumpAndSettle();

        expect(find.text('Enter a time as h:mm'), findsNothing);
        expect(fieldText(tester), '1:00');
      },
    );

    testWidgets('a stepper steps from what was typed', (tester) async {
      final c = await threeDives(tester);
      await tester.tap(siField());
      await tester.pump();
      await tester.enterText(siField(), '3:00');
      await tester.pump();

      await tester.tap(find.byTooltip('15 minutes more'));
      await tester.pumpAndSettle();

      expect(
        c.read(divePlanNotifierProvider).surfaceInterval,
        const Duration(hours: 3, minutes: 15),
      );
    });

    testWidgets('leaving it untouched keeps the seconds it does not show', (
      tester,
    ) async {
      final c = await threeDives(tester);
      const interval = Duration(hours: 1, minutes: 5, seconds: 30);
      c.read(divePlanNotifierProvider.notifier).setSurfaceInterval(interval);
      await tester.pumpAndSettle();
      expect(fieldText(tester), '1:05');

      await tester.tap(siField());
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(c.read(divePlanNotifierProvider).surfaceInterval, interval);
    });
  });

  group('the name field', () {
    testWidgets('drops a name the plan no longer has', (tester) async {
      await pumpPlan(tester, const Size(1400, 900));
      await tester.enterText(nameField(), 'Wreck');
      await tester.pumpAndSettle();

      final c = containerOf(tester);
      c
          .read(divePlanNotifierProvider.notifier)
          .loadPlan(c.read(divePlanNotifierProvider).copyWith());
      await tester.pumpAndSettle();

      expect(c.read(planSeriesNotifierProvider).selected.name, isNull);
      expect(tester.widget<TextField>(nameField()).controller!.text, isEmpty);
    });

    testWidgets('leaves the space at the end of a name being typed', (
      tester,
    ) async {
      await pumpPlan(tester, const Size(1400, 900));
      await tester.enterText(nameField(), 'Wreck ');
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(planSeriesNotifierProvider).selected.name,
        'Wreck',
      );
      expect(tester.widget<TextField>(nameField()).controller!.text, 'Wreck ');
    });
  });

  testWidgets('saving a carried tank untouched leaves it carried', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 900));
    await addDive(tester);
    final c = containerOf(tester);
    final carried = c.read(divePlanNotifierProvider).tanks.first;
    // The dialog shows whole bar, so this is the value it would round.
    expect(
      carried.startPressure,
      isNot(carried.startPressure!.roundToDouble()),
    );

    await tester.tap(find.widgetWithText(InputChip, 'Primary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(c.read(planSeriesNotifierProvider).selected.pinnedTankIds, isEmpty);
    expect(
      c.read(divePlanNotifierProvider).tanks.first.startPressure,
      carried.startPressure,
    );
  });
}
