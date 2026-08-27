import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DivePlanRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
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

  DivePlanNotifier notifierOf(WidgetTester tester) =>
      containerOf(tester).read(divePlanNotifierProvider.notifier);

  // The save IconButton renders Icons.save while the plan is dirty and
  // Icons.save_outlined (disabled) once it is clean, so a tap must always
  // target Icons.save.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
  }

  Future<void> seedAndSave(WidgetTester tester) async {
    notifierOf(tester).addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    await tapSave(tester);
  }

  testWidgets('first save opens the name dialog with a generated default', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    expect(find.text('Name your plan'), findsOneWidget);
    // No site is set on a bare plan, so the name is depth plus date.
    expect(find.textContaining('30.0m - '), findsOneWidget);
  });

  testWidgets('cancelling the first save persists nothing', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);
    // Read the state through the container: StateNotifier.state is @protected,
    // and reading it directly is an analyzer error that CI treats as fatal.
    expect(containerOf(tester).read(divePlanNotifierProvider).isDirty, isTrue);
  });

  testWidgets('confirming the first save persists under the entered name', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries = await repository.getAllPlanSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Zenobia');
  });

  testWidgets('the stored summary reflects edits made during the naming flow', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    // Deepen the plan while the naming flow is still in flight. The dialog
    // blocks the diver, but the site lookup that precedes it does not, so the
    // summary must describe the plan as it is when save() actually runs.
    notifierOf(tester).addSimplePlan(maxDepth: 45, bottomTimeMinutes: 10);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final summaries = await repository.getAllPlanSummaries();
    expect(summaries.single.maxDepth, 45);
  });

  testWidgets('a site change during the lookup drops the stale site name', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          // Switch the plan to a different site while the lookup for the
          // original one is still in flight. No modal is up during that await,
          // so this is something the diver can really do.
          siteProvider.overrideWith((ref, id) async {
            await Future<void>.delayed(Duration.zero);
            ref.read(divePlanNotifierProvider.notifier).updateSite('elsewhere');
            return const DiveSite(id: 'blue-hole', name: 'Blue Hole');
          }),
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    notifierOf(tester).addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    notifierOf(tester).updateSite('blue-hole');
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Name your plan'), findsOneWidget);
    // The fetched name describes a site the plan no longer uses, so it must
    // not be paired with the plan's current depth and date.
    expect(find.textContaining('Blue Hole'), findsNothing);
    expect(find.textContaining('30.0m - '), findsOneWidget);
  });

  testWidgets('a second tap during the site lookup does not stack dialogs', (
    tester,
  ) async {
    // Hold the site lookup open so both taps land inside the async gap. The
    // save button stays enabled there because isDirty is still true and no
    // modal is up yet.
    final gate = Completer<void>();
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          siteProvider.overrideWith((ref, id) async {
            await gate.future;
            return const DiveSite(id: 'blue-hole', name: 'Blue Hole');
          }),
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    notifierOf(tester).addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    notifierOf(tester).updateSite('blue-hole');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Name your plan'), findsOneWidget);
  });

  testWidgets('a second save does not re-open the dialog', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // A successful save clears isDirty, which disables the save button. Dirty
    // the plan again so there is something to re-save.
    notifierOf(tester).updateMode(PlanMode.ccr);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Name your plan'), findsNothing);
    final summaries = await repository.getAllPlanSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Zenobia');
  });
}
