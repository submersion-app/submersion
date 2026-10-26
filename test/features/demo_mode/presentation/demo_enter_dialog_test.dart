import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A controller the test steers by hand.
class _ScriptedController extends DemoEnterController {
  int starts = 0;
  int cancels = 0;

  @override
  DemoEnterUiState build() => const DemoEnterIdle();

  @override
  Future<void> start({required bool fromFirstRun, units}) async {
    starts++;
    state = const DemoEnterRunning(
      DemoEnterProgress(DemoEnterStage.downloading, received: 50, total: 100),
    );
  }

  @override
  void cancel() => cancels++;

  void fail() => state = const DemoEnterFailed(DemoDownloadFailure.network);
}

void main() {
  late _ScriptedController controller;

  Future<void> open(WidgetTester tester) async {
    controller = _ScriptedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoEnterControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDemoEnterDialog(context, fromFirstRun: false),
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('dialog starts entering and shows download progress', (
    tester,
  ) async {
    await open(tester);

    expect(controller.starts, 1);
    expect(find.text('Downloading sample logbook'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
  });

  testWidgets('a failure shows the message and Retry starts again', (
    tester,
  ) async {
    await open(tester);
    controller.fail();
    await tester.pump();

    expect(
      find.text(
        'The sample logbook could not be downloaded. Check your connection '
        'and try again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(controller.starts, 2);
  });

  testWidgets('Cancel stops the download and closes the dialog', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.cancels, 1);
    expect(find.byType(DemoEnterDialog), findsNothing);
  });
}
