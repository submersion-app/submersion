import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// Shared by the setup wizard page tests: a stand-in for the shared Set up
// this device steps and the pumps that walk the wizard through them.

final _drive = groupAccounts(
  rows: [
    ConnectedAccount(
      id: 'gd',
      kind: AccountKind.googledrive,
      label: 'Google Drive',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: const {'gd': AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

/// Stands in for the shared Set up steps: names the step, its host and the
/// account the flow holds, with a button per way the step can leave.
Widget stubSetUpStep(SetUpStep step, SetUpStepNavigation navigation) =>
    Consumer(
      builder: (context, ref, _) {
        final chosen = ref.watch(setUpFlowProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('stub ${step.name} ${navigation.host.name}'),
            Text('chosen ${chosen?.label}'),
            TextButton(
              onPressed: () {
                if (step == SetUpStep.account) {
                  ref.read(setUpFlowProvider.notifier).choose(_drive);
                }
                navigation.onNext();
              },
              child: const Text('stub next'),
            ),
            TextButton(
              onPressed: navigation.onBack,
              child: const Text('stub back'),
            ),
            TextButton(
              onPressed: navigation.onNotNow,
              child: const Text('stub not now'),
            ),
            if (navigation.onSkip != null)
              TextButton(
                onPressed: navigation.onSkip,
                child: const Text('stub skip'),
              ),
            if (navigation.onNoLibrary != null)
              TextButton(
                onPressed: navigation.onNoLibrary,
                child: const Text('stub no library'),
              ),
          ],
        );
      },
    );

/// OceanBackground animates forever, so pumpAndSettle would time out.
/// Fixed pumps cover the post-frame advance, the 300 ms page transition,
/// and the setState frame that follows the transition future.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps the wizard in [mode] with the shared steps stubbed, plus [extra]
/// overrides.
Future<void> pumpStubbed(
  WidgetTester tester,
  SetupWizardMode mode, {
  List<Override> extra = const [],
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      overrides: [...overrides, ...extra],
      child: SetupWizardPage(mode: mode, setUpStepBody: stubSetUpStep),
    ),
  );
  await pumpWizard(tester);
}

/// Taps a stub step's [label] button and lets the wizard move on.
Future<void> tapStub(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await pumpWizard(tester);
}

/// Names the diver on the Profile step and passes Units, to step 1.
Future<void> throughProfileAndUnitsFromProfile(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'Eric');
  await pumpWizard(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await pumpWizard(tester); // -> units
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await pumpWizard(tester); // -> step 1
}

/// From the welcome fork: a new profile, named, then Units, to step 1.
Future<void> throughProfileAndUnits(WidgetTester tester) async {
  await tester.tap(find.text('Set up a new profile'));
  await pumpWizard(tester);
  await tester.enterText(find.byType(TextFormField), 'Eric');
  await pumpWizard(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await pumpWizard(tester); // -> units
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await pumpWizard(tester); // -> step 1
}
