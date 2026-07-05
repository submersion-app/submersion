import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_file_picker_platform.dart';
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

DivePlan _plan(String id, String name) => DivePlan(
  id: id,
  name: name,
  gfLow: 50,
  gfHigh: 80,
  createdAt: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
);

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
    child: const SavedPlansSheet(),
  );

  // A router harness so the sheet's `context.go(...)` calls resolve to stub
  // destinations we can assert on.
  Widget routerHarness() => testAppRouter(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    router: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSavedPlansSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/planning/dive-planner/compare',
          builder: (_, _) => const Scaffold(body: Text('compare-page')),
        ),
        GoRoute(
          path: '/planning/dive-planner/:id',
          builder: (_, state) =>
              Scaffold(body: Text('plan:${state.pathParameters['id']}')),
        ),
      ],
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(routerHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists saved plans', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));
    await repository.savePlan(_plan('b', 'Wreck dive'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Reef dive'), findsOneWidget);
    expect(find.text('Wreck dive'), findsOneWidget);
  });

  testWidgets('shows empty state with no plans', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('No saved plans yet'), findsOneWidget);
  });

  testWidgets('delete flow removes a plan after confirmation', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    // Confirmation dialog.
    expect(find.text('Delete plan?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);
  });

  testWidgets('duplicate action copies the plan', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), hasLength(2));
  });

  testWidgets('tapping a plan opens it', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await openSheet(tester);

    await tester.tap(find.text('Reef dive'));
    await tester.pumpAndSettle();
    expect(find.text('plan:a'), findsOneWidget);
  });

  testWidgets('compare mode selects plans and opens the compare page', (
    tester,
  ) async {
    await repository.savePlan(_plan('a', 'Reef dive'));
    await repository.savePlan(_plan('b', 'Wreck dive'));

    await openSheet(tester);

    // Enter compare mode -> checkboxes appear.
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    // Select both, then launch the compare page.
    await tester.tap(find.text('Reef dive'));
    await tester.tap(find.text('Wreck dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Compare (2)'));
    await tester.pumpAndSettle();

    expect(find.text('compare-page'), findsOneWidget);
  });

  testWidgets('import reads a .subplan file and opens the imported plan', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('subplan-import');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/plan.subplan')
      ..writeAsStringSync(planToSubplanJson(_plan('src', 'Imported reef')));
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = FilePickerResult([
        PlatformFile(path: file.path, name: 'plan.subplan', size: 0),
      ]);

    await openSheet(tester);
    // The import does real file + DB I/O; runAsync lets it complete.
    await tester.runAsync(() async {
      await tester.tap(find.text('Import'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Imported with a fresh id, so the route lands on the new plan page.
    expect(find.textContaining('plan:'), findsOneWidget);
    expect(await repository.getAllPlanSummaries(), hasLength(1));
  });

  testWidgets('import surfaces a friendly error for a malformed file', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('subplan-bad');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/bad.subplan')
      ..writeAsStringSync('this is not a plan');
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = FilePickerResult([
        PlatformFile(path: file.path, name: 'bad.subplan', size: 0),
      ]);

    await openSheet(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // The FormatException is caught and surfaced, not thrown out of the sheet.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(await repository.getAllPlanSummaries(), isEmpty);
  });
}
