import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_lead_block.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'buoyancy_outcome_fixture.dart';

final _history = [
  BuoyancyHistoryEntry(
    diveId: 'h1',
    diveDateTime: DateTime.utc(2026, 5, 1),
    carriedKg: 6,
    idealKg: 5,
  ),
  BuoyancyHistoryEntry(
    diveId: 'h2',
    diveDateTime: DateTime.utc(2026, 5, 2),
    carriedKg: 6,
    idealKg: 5,
    feedback: 'overweighted',
  ),
];

Future<void> _pump(
  WidgetTester tester,
  BuoyancyTwinOutcome outcome, {
  List<BuoyancyHistoryEntry> history = const [],
  double width = 800,
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buoyancyHistoryProvider('d1').overrideWith((ref) async => history),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuoyancyLeadBlock(
              diveId: 'd1',
              outcome: outcome,
              units: UnitFormatter(settings),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the lead carried and the lead the model suggests', (
    tester,
  ) async {
    // 6.0 kg carried, 1.8 kg buoyant at the stop: the model suggests 7.8.
    await _pump(tester, buoyancyOutcome());
    expect(find.text('Lead for next time'), findsOneWidget);
    expect(find.text('You carried'), findsOneWidget);
    expect(find.text('6.0 kg'), findsOneWidget);
    expect(find.text('Model suggests'), findsOneWidget);
    expect(find.text('7.8 kg'), findsOneWidget);
  });

  testWidgets('a buoyant stop reads Underweighted', (tester) async {
    await _pump(tester, buoyancyOutcome(verdictNet: 1.8));
    expect(find.text('Underweighted'), findsOneWidget);
  });

  testWidgets('a heavy stop reads Overweighted', (tester) async {
    await _pump(tester, buoyancyOutcome(verdictNet: -1.2));
    expect(find.text('Overweighted'), findsOneWidget);
  });

  testWidgets('within half a kilo reads Well weighted', (tester) async {
    await _pump(tester, buoyancyOutcome(verdictNet: 0.3));
    expect(find.text('Well weighted'), findsOneWidget);
  });

  testWidgets('with no lead recorded there is no figure and no verdict chip', (
    tester,
  ) async {
    await _pump(tester, buoyancyOutcome(leadKg: 0, droppableLeadKg: 0));
    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.text('0.0 kg'), findsNothing);
    expect(find.text('Underweighted'), findsNothing);
    expect(find.text('Overweighted'), findsNothing);
    expect(find.text('Well weighted'), findsNothing);
    // The suggestion still stands on its own.
    expect(find.text('Model suggests'), findsOneWidget);
  });

  testWidgets('the weighting history sits here without its own title', (
    tester,
  ) async {
    await _pump(tester, buoyancyOutcome(), history: _history);
    expect(find.text('WEIGHTING HISTORY'), findsNothing);
    expect(find.text('Carried'), findsOneWidget);
    expect(find.text('Modeled'), findsOneWidget);
    expect(
      find.text('You typically carry 1.0 kg more than the model suggests'),
      findsOneWidget,
    );
  });

  testWidgets('no history, no legend', (tester) async {
    await _pump(tester, buoyancyOutcome());
    expect(find.text('Carried'), findsNothing);
  });

  testWidgets('an imperial diver reads lb', (tester) async {
    await _pump(
      tester,
      buoyancyOutcome(),
      settings: const AppSettings(weightUnit: WeightUnit.pounds),
    );
    expect(find.text('13.2 lbs'), findsOneWidget);
    expect(find.text('17.2 lbs'), findsOneWidget);
  });

  testWidgets('a narrow card does not overflow', (tester) async {
    await _pump(tester, buoyancyOutcome(), history: _history, width: 300);
    expect(tester.takeException(), isNull);
  });
}
