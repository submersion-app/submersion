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

  /// Opens the flow, which first asks; [confirm] answers Download.
  Future<void> open(WidgetTester tester, {bool confirm = true}) async {
    controller = _ScriptedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoEnterControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDemoEnterDialog(
                context,
                fromFirstRun: false,
                downloadBytes: 12 * 1024 * 1024,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    if (!confirm) return;
    await tester.tap(find.text('Download'));
    await tester.pump();
    // Lets the question finish closing, so only the progress dialog's
    // buttons remain.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('asks before downloading, naming the download size', (
    tester,
  ) async {
    await open(tester, confirm: false);

    expect(find.text('Explore with sample data?'), findsOneWidget);
    expect(find.textContaining('12 MB'), findsOneWidget);
    expect(controller.starts, 0);
    expect(find.byType(DemoEnterDialog), findsNothing);
  });

  testWidgets('Cancel on the question downloads nothing', (tester) async {
    await open(tester, confirm: false);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.starts, 0);
    expect(find.text('Explore with sample data?'), findsNothing);
    expect(find.byType(DemoEnterDialog), findsNothing);
  });

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
