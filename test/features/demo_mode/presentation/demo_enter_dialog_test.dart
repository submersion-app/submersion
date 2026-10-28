import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A controller the test steers by hand.
class _ScriptedController extends DemoEnterController {
  int starts = 0;
  int cancels = 0;
  DemoPackage? lastPackage;

  @override
  DemoEnterUiState build() => const DemoEnterIdle();

  @override
  Future<void> start({
    required bool fromFirstRun,
    required package,
    units,
  }) async {
    starts++;
    lastPackage = package;
    state = const DemoEnterRunning(
      DemoEnterProgress(DemoEnterStage.downloading, done: 50, total: 100),
    );
  }

  @override
  void cancel() => cancels++;

  void progress(DemoEnterProgress progress) =>
      state = DemoEnterRunning(progress);

  void fail() => state = const DemoEnterFailed(DemoDownloadFailure.network);

  void changeSize(DemoPackage package) =>
      state = DemoEnterPackageChanged(package);
}

final _package = DemoPackage(
  schemaVersion: 1,
  url: Uri.parse('https://example.com/demo.zip'),
  sha256: 'a' * 64,
  size: 12 * 1024 * 1024,
  generatedAt: DateTime.utc(2026, 10, 20),
);

final _bigger = DemoPackage(
  schemaVersion: 1,
  url: Uri.parse('https://example.com/bigger.zip'),
  sha256: 'c' * 64,
  size: 14 * 1024 * 1024,
  generatedAt: DateTime.utc(2026, 10, 22),
);

void main() {
  late _ScriptedController controller;

  /// Opens the flow, which first asks; [confirm] answers Download.
  Future<void> open(
    WidgetTester tester, {
    bool confirm = true,
    bool fromFirstRun = false,
  }) async {
    controller = _ScriptedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoEnterControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => askAndEnterDemo(
                context,
                fromFirstRun: fromFirstRun,
                package: _package,
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
    expect(find.textContaining('set aside'), findsOneWidget);
    expect(controller.starts, 0);
    expect(find.byType(DemoEnterDialog), findsNothing);
  });

  testWidgets('on first run the question does not mention a logbook of '
      'their own being set aside', (tester) async {
    await open(tester, confirm: false, fromFirstRun: true);

    expect(find.textContaining('12 MB'), findsOneWidget);
    expect(find.textContaining('set aside'), findsNothing);
  });

  testWidgets('Download starts the package the question named', (tester) async {
    await open(tester);

    expect(controller.lastPackage, _package);
  });

  testWidgets('a package that changed size asks again, and Download takes '
      'the new one', (tester) async {
    await open(tester);
    controller.changeSize(_bigger);
    await tester.pump();

    expect(find.textContaining('has been updated'), findsOneWidget);
    expect(find.textContaining('14 MB'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pump();

    expect(controller.starts, 2);
    expect(controller.lastPackage, _bigger);
  });

  testWidgets('Cancel on a changed size downloads nothing and closes', (
    tester,
  ) async {
    await open(tester);
    controller.changeSize(_bigger);
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.starts, 1);
    expect(find.byType(DemoEnterDialog), findsNothing);
  });

  test('a size in a sentence is isolated left to right', () {
    expect(sizeInSentence(12 * 1024 * 1024), '\u206612 MB\u2069');
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
    expect(bar.value, DemoEnterStage.downloading.end / 2);
  });

  testWidgets('the bar shows real progress at every stage, never a sweep', (
    tester,
  ) async {
    await open(tester);
    double? barValue() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value;

    for (final (progress, label) in const [
      (DemoEnterProgress(DemoEnterStage.downloading), 'Downloading'),
      (
        DemoEnterProgress(DemoEnterStage.preparing, done: 1, total: 2),
        'Preparing',
      ),
      (DemoEnterProgress(DemoEnterStage.opening, done: 3, total: 4), 'Opening'),
    ]) {
      controller.progress(progress);
      await tester.pump();

      expect(find.textContaining(label), findsOneWidget);
      expect(barValue(), progress.fraction);
    }
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
