import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The browser's first run (issue #4121) opens on the connect step, the
/// account chooser, with no welcome fork and no existing-data choice before
/// it, and offers "Continue without a sync store" into the fresh path.
Widget _stubStep(SetUpStep step, SetUpStepNavigation navigation) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('stub ${step.name} ${navigation.host.name}'),
    TextButton(onPressed: navigation.onNext, child: const Text('stub next')),
    TextButton(onPressed: navigation.onBack, child: const Text('stub back')),
    TextButton(
      onPressed: navigation.onNotNow,
      child: const Text('stub not now'),
    ),
    if (navigation.onNoLibrary != null)
      TextButton(
        onPressed: navigation.onNoLibrary,
        child: const Text('stub no library'),
      ),
  ],
);

/// OceanBackground animates forever, so fixed pumps.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    SetupWizardMode mode = SetupWizardMode.firstRun,
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SetupWizardPage(mode: mode, setUpStepBody: _stubStep);
          },
        ),
      ),
    );
    await pumpWizard(tester);
    return container;
  }

  testWidgets('opens on the account step with the connect path chosen', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.existingData);
    expect(draft.source, ExistingDataSource.cloudSync);
    expect(find.text('stub account firstRun'), findsOneWidget);
    expect(find.text('Start fresh'), findsNothing);
    expect(find.text('Bring your data'), findsNothing);
  });

  testWidgets('continue without a sync store leads to the profile step', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    await tester.tap(find.text('stub no library'));
    await pumpWizard(tester);
    expect(
      container.read(setupWizardProvider(SetupWizardMode.firstRun)).path,
      SetupPath.fresh,
    );
    expect(find.text('Create Your Profile'), findsOneWidget);
    expect(find.text('stub account firstRun'), findsNothing);
  });

  testWidgets('the assistant from Settings drops the same steps as a first '
      'run: the draft says browser whatever the mode', (tester) async {
    final container = await pumpPage(tester, mode: SetupWizardMode.settings);
    final steps = computeSteps(
      container.read(setupWizardProvider(SetupWizardMode.settings)),
    );
    expect(steps, isNot(contains(SetupStepId.setUpBackups)));
    expect(steps, isNot(contains(SetupStepId.setUpPhotos)));
    expect(steps, contains(SetupStepId.setUpAccount));
  });

  testWidgets('the first step offers no way back, and the same step later '
      'on the fresh path does', (tester) async {
    TextButton back() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'stub back'));

    await pumpPage(tester);
    expect(find.text('stub account firstRun'), findsOneWidget);
    expect(back().onPressed, isNull);

    await tester.tap(find.text('stub no library'));
    await pumpWizard(tester);
    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // units
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // the connect step
    expect(find.text('stub account firstRun'), findsOneWidget);
    expect(back().onPressed, isNotNull);
  });

  testWidgets('Not now on the connect step reaches Finish: a browser has no '
      'backups step after sync to land on', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('stub no library'));
    await pumpWizard(tester);
    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // units
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // the connect step
    expect(find.text('stub account firstRun'), findsOneWidget);

    await tester.tap(find.text('stub not now'));
    await pumpWizard(tester);
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('stub account firstRun'), findsNothing);
  });
}
