import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'buoyancy_outcome_fixture.dart';

Future<void> _pump(WidgetTester tester, BuoyancyTwinOutcome? outcome) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        buoyancyTwinProvider('d1').overrideWith((ref) async => outcome),
      ],
      child: const MaterialApp(
        // Pinned so the asserted strings and decimal separators do not depend
        // on the host locale (repo convention).
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuoyancySection(
              diveId: 'd1',
              units: UnitFormatter(AppSettings()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the verdict and expands the breakdown', (tester) async {
    await _pump(tester, buoyancyOutcome());
    // Verdict amount is rendered (1.8 kg buoyant).
    expect(find.textContaining('1.8'), findsWidgets);

    // Expand the breakdown and find the lead row.
    final expansion = find.byType(ExpansionTile);
    expect(expansion, findsOneWidget);
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(find.textContaining('-6.0'), findsWidgets);
  });

  testWidgets('warns when droppable lead is below the minimum ditchable', (
    tester,
  ) async {
    await _pump(
      tester,
      buoyancyOutcome(minDitchableKg: 6.0, droppableLeadKg: 2.0),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('hints that no lead was recorded when lead is zero', (
    tester,
  ) async {
    // Lead lives either in the dive's Weights section or as a dry weight on
    // weights-type gear; zero means neither, and the net reads far too
    // buoyant (issue #1103).
    await _pump(tester, buoyancyOutcome(leadKg: 0.0, droppableLeadKg: 0.0));
    expect(find.textContaining('No lead recorded'), findsOneWidget);
  });

  testWidgets('no lead hint is absent once lead is known', (tester) async {
    await _pump(tester, buoyancyOutcome());
    expect(find.textContaining('No lead recorded'), findsNothing);
  });

  testWidgets('a narrow card fits its header row', (tester) async {
    // Half of a 700px paired row. The title, the Adjust button and the info
    // icon could not shrink, so the header overflowed; the title now gives
    // way instead.
    await tester.binding.setSurfaceSize(const Size(300, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, buoyancyOutcome());

    expect(tester.takeException(), isNull);
    expect(find.text('BUOYANCY'), findsOneWidget);
  });

  testWidgets('renders nothing when the outcome is null', (tester) async {
    await _pump(tester, null);
    expect(find.byType(Card), findsNothing);
  });
}
