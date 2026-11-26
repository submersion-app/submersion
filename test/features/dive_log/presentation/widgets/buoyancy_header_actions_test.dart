import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_header_actions.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/mock_providers.dart';
import 'buoyancy_outcome_fixture.dart';

/// The What if? button and info icon the Weights and buoyancy card puts in
/// its title row (issue #5005).
Future<void> _pump(
  WidgetTester tester, {
  required bool compact,
  BuoyancyTwinOutcome? outcome,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        // Pinned so the asserted strings do not depend on the host locale.
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: BuoyancyHeaderActions(
              outcome: outcome ?? buoyancyOutcome(),
              units: const UnitFormatter(AppSettings()),
              compact: compact,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers a what-if, not an edit (#4585)', (tester) async {
    await _pump(tester, compact: false);

    expect(find.text('Adjust'), findsNothing);
    await tester.tap(find.text('What if?'));
    await tester.pumpAndSettle();
    expect(find.text('What if you changed your weighting?'), findsOneWidget);
  });

  testWidgets('compact shows only the icon, with the label as tooltip', (
    tester,
  ) async {
    await _pump(tester, compact: true, locale: const Locale('de'));

    expect(find.text('Was wäre, wenn?'), findsNothing);
    await tester.tap(find.byTooltip('Was wäre, wenn?'));
    await tester.pumpAndSettle();
    expect(find.text('Was wäre, wenn du dein Blei änderst?'), findsOneWidget);
  });

  testWidgets('fullWidth covers the label and the info slot', (tester) async {
    await _pump(tester, compact: false);
    final context = tester.element(find.byType(BuoyancyHeaderActions));
    final rendered = tester.getSize(find.byType(BuoyancyHeaderActions)).width;

    // Never below what the full actions actually take, so a caller that
    // reserves this much never overflows.
    expect(
      BuoyancyHeaderActions.fullWidth(context),
      greaterThanOrEqualTo(rendered),
    );
  });

  testWidgets('the info sheet names the What if? button', (tester) async {
    await _pump(tester, compact: false);
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('“What if?” opens a sheet'), findsOneWidget);
    expect(find.textContaining('Adjust opens'), findsNothing);
  });

  testWidgets('uses an info icon instead of the hover tooltip', (tester) async {
    await _pump(tester, compact: false);

    expect(find.byType(InfoButton), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message ==
                'Modeled net buoyancy through the dive from your profile, gas use, and gear.',
      ),
      findsNothing,
    );
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Peak lift needed'), findsWidgets);
    expect(find.textContaining('Buoyancy swing'), findsNothing);
    expect(find.textContaining('Drysuit gas added'), findsNothing);
  });

  testWidgets('a drysuit outcome mentions drysuit gas in the info sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      compact: false,
      outcome: buoyancyOutcome(
        suitKind: TwinSuitKind.drysuit,
        drysuitGasLiters: 12,
      ),
    );
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Drysuit gas added'), findsWidgets);
  });
}
