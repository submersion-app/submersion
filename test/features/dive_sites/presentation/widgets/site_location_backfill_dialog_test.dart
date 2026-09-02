import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A scripted notifier so the dialog can be driven without a database or
/// network: [candidates] answers the count, [start] walks [script].
class _ScriptedBackfill extends StateNotifier<BackfillState>
    implements SiteLocationBackfillNotifier {
  _ScriptedBackfill({
    required this.candidates,
    required this.script,
    this.stepDelay = const Duration(milliseconds: 10),
  }) : super(const BackfillIdle());

  final int candidates;
  final List<BackfillState> script;
  final Duration stepDelay;
  int startCalls = 0;
  bool cancelled = false;

  @override
  Future<int> countCandidates() async => candidates;

  @override
  Future<void> start() async {
    startCalls++;
    for (final s in script) {
      await Future<void>.delayed(stepDelay);
      state = s;
    }
  }

  @override
  void cancel() => cancelled = true;

  /// Puts the notifier mid-run without going through [start].
  void pretendRunning() => state = const BackfillRunning(done: 1, total: 3);

  @override
  void reset() => state = const BackfillIdle();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host(_ScriptedBackfill notifier) => ProviderScope(
    overrides: [siteLocationBackfillProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showSiteLocationBackfillFlow(context, ref),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );

  testWidgets('says so when there is nothing to fill', (tester) async {
    final notifier = _ScriptedBackfill(candidates: 0, script: const []);
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Every site with coordinates already has its location details.',
      ),
      findsOneWidget,
    );
    expect(notifier.startCalls, 0);
  });

  testWidgets('confirms with the count and estimate, then shows progress and '
      'a summary', (tester) async {
    final notifier = _ScriptedBackfill(
      candidates: 104,
      script: const [
        BackfillRunning(done: 0, total: 104),
        BackfillRunning(done: 12, total: 104),
        BackfillFinished(
          BackfillSummary(total: 104, updated: 90, unchanged: 13, failed: 1),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Fill in missing location details?'), findsOneWidget);
    expect(find.textContaining('104 sites with coordinates'), findsOneWidget);
    expect(find.textContaining('about 4 minutes'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 15));
    expect(find.text('Filling in location details'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('12 of 104'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Filling in location details'), findsNothing);
    expect(find.text('Updated 90, unchanged 13, failed 1'), findsOneWidget);
  });

  testWidgets('a small batch is estimated in the singular', (tester) async {
    // 20 sites at two seconds each rounds up to one minute.
    final notifier = _ScriptedBackfill(candidates: 20, script: const []);
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.textContaining('about 1 minute.'), findsOneWidget);
    expect(find.textContaining('1 minutes'), findsNothing);
  });

  testWidgets('cancel asks the notifier to stop', (tester) async {
    // Slow steps so the progress dialog has finished animating in before
    // the test taps its Cancel button.
    final notifier = _ScriptedBackfill(
      candidates: 3,
      stepDelay: const Duration(milliseconds: 500),
      script: const [
        BackfillRunning(done: 0, total: 3),
        BackfillFinished(
          BackfillSummary(
            total: 3,
            updated: 1,
            unchanged: 0,
            failed: 0,
            cancelled: true,
          ),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('0 of 3'), findsOneWidget);

    // The confirm dialog's Cancel may still be mid-exit; target the progress
    // dialog's own button.
    final progressDialog = find.ancestor(
      of: find.text('Filling in location details'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(of: progressDialog, matching: find.text('Cancel')),
    );
    await tester.pumpAndSettle();

    expect(notifier.cancelled, isTrue);
  });

  testWidgets('an offline run shows the offline message', (tester) async {
    final notifier = _ScriptedBackfill(
      candidates: 3,
      script: const [
        BackfillRunning(done: 0, total: 3),
        BackfillFinished(
          BackfillSummary(
            total: 3,
            updated: 0,
            unchanged: 0,
            failed: 0,
            offline: true,
          ),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Location lookup is unavailable. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reopening the flow mid-run shows progress, not a new run', (
    tester,
  ) async {
    final notifier = _ScriptedBackfill(candidates: 3, script: const []);
    await tester.pumpWidget(host(notifier));
    notifier.pretendRunning();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Filling in location details'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Fill in missing location details?'), findsNothing);
    expect(notifier.startCalls, 0);
  });
}
