import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_disclaimer_gate.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<MockSettingsNotifier> pump(
    WidgetTester tester, {
    required bool hasAcceptedPlanningDisclaimer,
  }) async {
    final notifier = MockSettingsNotifier(
      AppSettings(hasAcceptedPlanningDisclaimer: hasAcceptedPlanningDisclaimer),
    );
    final base = await getBaseOverrides(settingsNotifier: notifier);

    await tester.pumpWidget(
      testApp(
        overrides: base.cast(),
        locale: const Locale('en'),
        child: const PlanningDisclaimerGate(child: Text('planning tools')),
      ),
    );
    await tester.pump();
    await tester.pump();

    return notifier;
  }

  testWidgets('shows the disclaimer when the diver has not confirmed it', (
    tester,
  ) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: false);

    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);
    expect(find.text('planning tools'), findsOneWidget);
  });

  testWidgets('stays non-dismissible: tapping outside it does nothing', (
    tester,
  ) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: false);

    // Tap the barrier, well away from the dialog card.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);
  });

  testWidgets('confirming records acceptance and dismisses the dialog', (
    tester,
  ) async {
    final notifier = await pump(tester, hasAcceptedPlanningDisclaimer: false);

    await tester.tap(find.text('I Understand'));
    await tester.pumpAndSettle();

    expect(find.text('Planning Tools Disclaimer'), findsNothing);
    expect(notifier.state.hasAcceptedPlanningDisclaimer, isTrue);
  });

  testWidgets('does not show the disclaimer once already confirmed', (
    tester,
  ) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: true);

    expect(find.text('Planning Tools Disclaimer'), findsNothing);
    expect(find.text('planning tools'), findsOneWidget);
  });

  // The diver switcher opens a dialog/sheet over Planning or Gas
  // Calculators rather than replacing them, so this gate's State survives a
  // switch. It must re-check the newly active diver rather than trusting
  // whatever the previously active diver had confirmed.
  testWidgets('re-checks when the active diver changes, not just at mount', (
    tester,
  ) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: true);
    expect(find.text('Planning Tools Disclaimer'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.text('planning tools')),
    );
    // Simulate the reload a diver switch starts landing with the new
    // diver's (unconfirmed) settings, then the switch itself.
    container.read(settingsProvider.notifier).state = const AppSettings(
      hasAcceptedPlanningDisclaimer: false,
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-2');
    await tester.pump();
    await tester.pump();

    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);
  });

  // The dialog sits on the root navigator, so it outlives the gate when a
  // programmatic navigation (a notification or file deep link) replaces the
  // /planning subtree while it is up. Confirming must still close it: with
  // no barrier tap and no back gesture, a confirm that throws on the
  // disposed gate's ref would leave it on screen for good.
  testWidgets('confirming still closes the dialog after the gate unmounts', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(const AppSettings());
    final base = await getBaseOverrides(settingsNotifier: notifier);
    final showGate = ValueNotifier<bool>(true);
    addTearDown(showGate.dispose);

    await tester.pumpWidget(
      testApp(
        overrides: base.cast(),
        locale: const Locale('en'),
        child: ValueListenableBuilder<bool>(
          valueListenable: showGate,
          builder: (context, show, _) => show
              ? const PlanningDisclaimerGate(child: Text('planning tools'))
              : const Text('elsewhere'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);

    showGate.value = false;
    await tester.pump();
    expect(find.text('elsewhere'), findsOneWidget);
    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);

    await tester.tap(find.text('I Understand'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Planning Tools Disclaimer'), findsNothing);
    expect(notifier.state.hasAcceptedPlanningDisclaimer, isTrue);
  });

  testWidgets('the system back gesture does not dismiss it', (tester) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: false);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);
  });

  // launchReportIssue (settings_page.dart) has its own coverage for the
  // launch/fallback branches; this just checks the button is wired up and
  // tapping it is not a way to dismiss the still-unconfirmed dialog.
  testWidgets('tapping Report an Issue does not dismiss the dialog', (
    tester,
  ) async {
    await pump(tester, hasAcceptedPlanningDisclaimer: false);

    await tester.tap(find.text('Report an Issue'));
    await tester.pumpAndSettle();

    expect(find.text('Planning Tools Disclaimer'), findsOneWidget);
  });
}
