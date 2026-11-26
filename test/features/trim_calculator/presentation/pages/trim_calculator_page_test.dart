import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trim_calculator/presentation/pages/trim_calculator_page.dart';
import 'package:submersion/features/trim_calculator/presentation/providers/trim_calculator_providers.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_dive_picker.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_view.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../dive_log/presentation/widgets/buoyancy_outcome_fixture.dart';

/// The Trim Calculator, a Planning tool (issue #5028).
void main() {
  final when = DateTime.utc(2026, 3, 15, 10);
  Dive dive(String id, int number) =>
      Dive(id: id, dateTime: when, diveNumber: number);

  Future<void> pump(
    WidgetTester tester, {
    String? diveId,
    Map<String, Dive?> dives = const {},
    Map<String, BuoyancyTwinOutcome?> outcomes = const {},
    String? latest,
    List<DiveSummary> recent = const [],
    DiverSex? sex,
    bool embedded = false,
  }) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          trimCalculatorLatestDiveIdProvider.overrideWith(
            (ref) async => latest,
          ),
          trimCalculatorRecentDivesProvider.overrideWith((ref) async => recent),
          latestDiverHeightProvider.overrideWith((ref) async => null),
          latestDiverWeightProvider.overrideWith((ref) async => null),
          diverBodyProfileProvider.overrideWith(
            (ref) async => (sex: sex, ageYears: null),
          ),
          for (final e in dives.entries)
            diveProvider(e.key).overrideWith((ref) async => e.value),
          for (final e in outcomes.entries)
            buoyancyTwinProvider(e.key).overrideWith((ref) async => e.value),
        ],
        child: TrimCalculatorPage(diveId: diveId, embedded: embedded),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the dive it is handed', (tester) async {
    await pump(
      tester,
      diveId: 'd1',
      dives: {'d1': dive('d1', 12)},
      outcomes: {'d1': buoyancyOutcome()},
      latest: 'other',
    );
    expect(find.text('#12'), findsOneWidget);
    expect(find.byType(TrimTryoutView), findsOneWidget);
    expect(find.textContaining('safety-stop check'), findsOneWidget);
  });

  testWidgets('with no dive handed, opens on the latest dive', (tester) async {
    await pump(
      tester,
      dives: {'d2': dive('d2', 40)},
      outcomes: {'d2': buoyancyOutcome()},
      latest: 'd2',
    );
    expect(find.text('#40'), findsOneWidget);
    expect(find.byType(TrimTryoutView), findsOneWidget);
  });

  testWidgets('an empty log says to log a dive', (tester) async {
    await pump(tester);
    expect(find.textContaining('Log a dive to check its trim'), findsOneWidget);
    expect(find.byType(TrimTryoutView), findsNothing);
  });

  testWidgets('a dive the model cannot weigh says so and keeps Change dive', (
    tester,
  ) async {
    await pump(
      tester,
      diveId: 'd1',
      dives: {'d1': dive('d1', 12)},
      outcomes: {'d1': null},
    );
    expect(find.textContaining('no tanks or exposure suit'), findsOneWidget);
    expect(find.byType(TrimTryoutView), findsNothing);
    expect(find.byKey(TrimCalculatorPage.changeDiveKey), findsOneWidget);
  });

  testWidgets('a dive no longer in the log offers another', (tester) async {
    await pump(tester, diveId: 'gone', dives: {'gone': null});
    expect(find.textContaining('no longer in your log'), findsOneWidget);
    expect(find.byKey(TrimCalculatorPage.changeDiveKey), findsOneWidget);
  });

  testWidgets('Change dive shows the picked dive', (tester) async {
    await pump(
      tester,
      diveId: 'd1',
      dives: {'d1': dive('d1', 12), 'd2': dive('d2', 40)},
      outcomes: {'d1': buoyancyOutcome(), 'd2': buoyancyOutcome()},
      recent: [
        DiveSummary(
          id: 'd2',
          dateTime: when,
          sortTimestamp: when.millisecondsSinceEpoch,
          diveNumber: 40,
        ),
      ],
    );
    await tester.tap(find.byKey(TrimCalculatorPage.changeDiveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '#40'));
    await tester.pumpAndSettle();
    expect(find.text('#40'), findsOneWidget);
    expect(find.text('#12'), findsNothing);
  });

  testWidgets("the diver's sex reaches the figure's body", (tester) async {
    await pump(
      tester,
      diveId: 'd1',
      dives: {'d1': dive('d1', 12)},
      outcomes: {'d1': buoyancyOutcome()},
      sex: DiverSex.female,
    );
    final figure = tester.widget<TrimFigure>(find.byType(TrimFigure));
    expect(figure.scene.body.sex, DiverSex.female);
  });

  testWidgets('embedded, it wears the Planning pane header', (tester) async {
    await pump(
      tester,
      diveId: 'd1',
      dives: {'d1': dive('d1', 12)},
      outcomes: {'d1': buoyancyOutcome()},
      embedded: true,
    );
    expect(find.byType(PlanningToolPane), findsOneWidget);
    expect(find.text('Trim Calculator'), findsOneWidget);
  });

  group('trimDiveLabel', () {
    const units = UnitFormatter(AppSettings());

    test('names a dive by number and site, dated below', () {
      final label = trimDiveLabel(
        number: 12,
        site: 'Blue Hole',
        when: when,
        units: units,
      );
      expect(label.title, '#12 - Blue Hole');
      expect(label.subtitle, isNotNull);
    });

    test('falls back to the date with neither', () {
      final label = trimDiveLabel(
        number: null,
        site: '',
        when: when,
        units: units,
      );
      expect(label.title, units.formatDate(when));
      expect(label.subtitle, isNull);
    });
  });
}
