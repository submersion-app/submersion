import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A scripted notifier so the dialog can be driven without a database or
/// network: [candidates] sites are handed back to the flow, [start] walks
/// [script].
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

  SiteLocationLookupMode? startedWith;
  List<DiveSite>? startedTargets;

  @override
  Future<List<DiveSite>> findCandidates(SiteLocationLookupMode mode) async {
    return [
      for (var i = 0; i < candidates; i++) DiveSite(id: '$i', name: 'Site $i'),
    ];
  }

  @override
  Future<void> start(
    SiteLocationLookupMode mode, {
    List<DiveSite>? targets,
  }) async {
    startCalls++;
    startedWith = mode;
    startedTargets = targets;
    for (final s in script) {
      await Future<void>.delayed(stepDelay);
      state = s;
    }
  }

  @override
  void cancel() => cancelled = true;

  /// Puts the notifier mid-run without going through [start].
  void pretendRunning() => state = const BackfillRunning(
    mode: SiteLocationLookupMode.fillMissing,
    done: 1,
    total: 3,
  );

  @override
  void reset() => state = const BackfillIdle();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings without a database round-trip. The place name language names the
/// target language in the refresh copy.
class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(String code) : super(AppSettings(placeNameLanguage: code));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host(
    _ScriptedBackfill notifier, {
    SiteLocationLookupMode mode = SiteLocationLookupMode.fillMissing,
    String placeNameLanguage = 'en',
  }) => ProviderScope(
    overrides: [
      siteLocationBackfillProvider.overrideWith((_) => notifier),
      settingsProvider.overrideWith((_) => _FixedSettings(placeNameLanguage)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                showSiteLocationBackfillFlow(context, ref, mode: mode),
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
        BackfillRunning(
          mode: SiteLocationLookupMode.fillMissing,
          done: 0,
          total: 104,
        ),
        BackfillRunning(
          mode: SiteLocationLookupMode.fillMissing,
          done: 12,
          total: 104,
        ),
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
        BackfillRunning(
          mode: SiteLocationLookupMode.fillMissing,
          done: 0,
          total: 3,
        ),
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
        BackfillRunning(
          mode: SiteLocationLookupMode.fillMissing,
          done: 0,
          total: 3,
        ),
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

  testWidgets('the refresh flow names the language and the mode it runs', (
    tester,
  ) async {
    final notifier = _ScriptedBackfill(
      candidates: 30,
      script: const [
        BackfillRunning(
          mode: SiteLocationLookupMode.refreshAll,
          done: 0,
          total: 30,
        ),
        BackfillFinished(
          BackfillSummary(total: 30, updated: 30, unchanged: 0, failed: 0),
        ),
      ],
    );
    await tester.pumpWidget(
      host(
        notifier,
        mode: SiteLocationLookupMode.refreshAll,
        placeNameLanguage: 'de',
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh place names?'), findsOneWidget);
    expect(
      find.textContaining('differ from the place name language (Deutsch)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 15));
    expect(find.text('Refreshing place names'), findsOneWidget);
    expect(notifier.startedWith, SiteLocationLookupMode.refreshAll);
    expect(
      notifier.startedTargets,
      isNotNull,
      reason: 'the run reuses the sites the confirmation was counted from',
    );
    expect(notifier.startedTargets, hasLength(notifier.candidates));
    await tester.pumpAndSettle();
  });

  testWidgets('a refresh with no coordinates anywhere says so', (tester) async {
    final notifier = _ScriptedBackfill(candidates: 0, script: const []);
    await tester.pumpWidget(
      host(notifier, mode: SiteLocationLookupMode.refreshAll),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('No site has coordinates to look up.'), findsOneWidget);
    expect(notifier.startCalls, 0);
  });
}
