import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// OceanBackground animates forever, so pumpAndSettle would time out.
/// Fixed pumps cover the post-frame advance, the 300 ms page transition,
/// and the setState frame that follows the transition future.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('first run shows fork; fresh choice walks to profile and back', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    expect(find.text('Welcome to Submersion'), findsOneWidget);
    expect(find.text('Set up a new logbook'), findsOneWidget);
    expect(find.text('I have existing Submersion data'), findsOneWidget);

    await tester.tap(find.text('Set up a new logbook'));
    await pumpWizard(tester);

    expect(find.text('Create Your Profile'), findsOneWidget);

    // Next disabled with empty name.
    final nextFinder = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNotNull);

    await tester.tap(nextFinder);
    await pumpWizard(tester);
    // Units placeholder page (real step lands in Task 7).
    expect(find.text('Units'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await pumpWizard(tester);
    expect(find.text('Create Your Profile'), findsOneWidget);
  });

  testWidgets('skip setup jumps from profile straight to finish placeholder', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    await tester.ensureVisible(find.text('Skip setup'));
    await tester.pump();
    await tester.tap(find.text('Skip setup'));
    await pumpWizard(tester);
    expect(find.text('Create Your Profile'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester);

    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('settings mode starts at units with no fork', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.settings),
      ),
    );
    await pumpWizard(tester);

    expect(find.text('Welcome to Submersion'), findsNothing);
    expect(find.text('Units'), findsWidgets);
  });
}
