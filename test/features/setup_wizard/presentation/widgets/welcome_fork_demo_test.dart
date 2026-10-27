import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

final _package = DemoPackage(
  schemaVersion: 1,
  url: Uri.parse('https://example.com/demo.zip'),
  sha256: 'a' * 64,
  size: 10,
  generatedAt: DateTime.utc(2026, 10, 20),
);

/// The wizard's ocean background animates forever, so fixed pumps.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  testWidgets('WelcomeForkStep shows the demo card only with a callback', (
    tester,
  ) async {
    var tapped = false;
    Widget step({VoidCallback? onTryDemo}) => testApp(
      child: WelcomeForkStep(
        onStartFresh: () {},
        onExistingData: () {},
        onSkipSetup: () {},
        onTryDemo: onTryDemo,
      ),
    );

    await tester.pumpWidget(step());
    expect(find.text('Explore with sample data'), findsNothing);

    await tester.pumpWidget(step(onTryDemo: () => tapped = true));
    await tester.tap(find.text('Explore with sample data'));
    expect(tapped, isTrue);
  });

  Future<void> pumpPage(WidgetTester tester, DemoPackage? available) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(demoPackage: available),
          demoEnterControllerProvider.overrideWith(_IdleController.new),
        ],
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);
  }

  testWidgets('no third card when no sample logbook is available', (
    tester,
  ) async {
    await pumpPage(tester, null);

    expect(find.text('Explore with sample data'), findsNothing);
  });

  testWidgets('third card shows when a sample logbook is available', (
    tester,
  ) async {
    await pumpPage(tester, _package);

    expect(find.text('Explore with sample data'), findsOneWidget);
  });

  testWidgets('tapping it opens the entering dialog', (tester) async {
    await pumpPage(tester, _package);

    await tester.ensureVisible(find.text('Explore with sample data'));
    await tester.tap(find.text('Explore with sample data'));
    await pumpWizard(tester);

    expect(find.byType(DemoEnterDialog), findsOneWidget);
    expect(_IdleController.lastFromFirstRun, isTrue);
  });
}

/// Records the start request without doing anything.
class _IdleController extends DemoEnterController {
  static bool? lastFromFirstRun;

  @override
  Future<void> start({required bool fromFirstRun, units}) async {
    lastFromFirstRun = fromFirstRun;
  }
}
