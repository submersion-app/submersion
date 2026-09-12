import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Exercises the "Resync from original file" overflow action (issue #478).
/// [DiveResyncOrchestrator] is faked rather than driven for real, so no
/// database or filesystem access happens.
class _FakeDiveResyncOrchestrator extends DiveResyncOrchestrator {
  _FakeDiveResyncOrchestrator({required super.db, required this.outcome});

  final DiveResyncOutcome outcome;
  final resyncedDiveIds = <String>[];

  @override
  Future<DiveResyncOutcome> resync(String diveId) async {
    resyncedDiveIds.add(diveId);
    return outcome;
  }
}

/// A stored file can be corrupted or truncated on disk since import; the
/// orchestrator's enumerated skip paths never throw, but its parser call can.
/// This fake reproduces that so the page's error handling is exercised
/// without a real corrupted file.
class _ThrowingDiveResyncOrchestrator extends DiveResyncOrchestrator {
  _ThrowingDiveResyncOrchestrator({required super.db});

  @override
  Future<DiveResyncOutcome> resync(String diveId) {
    throw const FormatException('truncated UDDF payload');
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Shared pump used by both [pumpDetail] and the thrown-error test, which
  /// needs an orchestrator that cannot report an outcome via [outcome].
  Future<void> pumpWithOrchestrator(
    WidgetTester tester,
    DiveResyncOrchestrator orchestrator, {
    required bool hasImportedFile,
    required bool embedded,
    Locale locale = const Locale('en'),
  }) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          // The embedded variant renders no Scaffold of its own -- it lives
          // inside the master-detail host's. Without one, showSnackBar has
          // nothing to present to.
          builder: (context, state) => embedded
              ? Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true))
              : DiveDetailPage(diveId: dive.id),
        ),
      ],
    );

    // The detail page intentionally overflows its fixed test viewport; that is
    // not what this test asserts, so swallow only overflow errors.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          // Gates the menu item; without it the action never renders.
          diveHasImportedFileProvider(
            dive.id,
          ).overrideWith((ref) async => hasImportedFile),
          diveResyncOrchestratorProvider.overrideWithValue(orchestrator),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<_FakeDiveResyncOrchestrator> pumpDetail(
    WidgetTester tester, {
    bool hasImportedFile = true,
    DiveResyncOutcome outcome = const DiveResyncOutcome.success(),
    bool embedded = false,
    Locale locale = const Locale('en'),
  }) async {
    final orchestrator = _FakeDiveResyncOrchestrator(db: db, outcome: outcome);
    await pumpWithOrchestrator(
      tester,
      orchestrator,
      hasImportedFile: hasImportedFile,
      embedded: embedded,
      locale: locale,
    );
    return orchestrator;
  }

  Future<void> tapResync(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source
    // bar, when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sync).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows Resync from original file only when a file is stored', (
    tester,
  ) async {
    await pumpDetail(tester, hasImportedFile: true);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Resync from original file'), findsOneWidget);
  });

  testWidgets('hides Resync from original file when no file is stored', (
    tester,
  ) async {
    await pumpDetail(tester, hasImportedFile: false);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Resync from original file'), findsNothing);
  });

  testWidgets('tapping Resync calls the orchestrator and shows success', (
    tester,
  ) async {
    final orchestrator = await pumpDetail(
      tester,
      outcome: const DiveResyncOutcome.success(),
    );

    await tapResync(tester);

    expect(orchestrator.resyncedDiveIds, ['test-dive-1']);
    expect(find.text('Dive updated from the original file'), findsOneWidget);
  });

  testWidgets('a resync that preserved the profile says so', (tester) async {
    // On a combined or multi-source dive the writer refreshes the header and
    // deliberately leaves the profile alone; reporting a plain success would
    // tell the diver their profile was rewritten. Reuses the string the
    // re-parse path already shows for the same situation (#1164).
    await pumpDetail(
      tester,
      outcome: const DiveResyncOutcome.success(profilePreserved: true),
    );

    await tapResync(tester);

    expect(
      find.text(
        'Source details refreshed. This dive was combined from other dives, '
        'so its profile was left unchanged.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Resync surfaces the orchestrator failure reason', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      outcome: const DiveResyncOutcome.failure(
        DiveResyncFailure.noMatchingDive,
      ),
    );

    await tapResync(tester);

    expect(
      find.text(
        'Could not resync: the original file no longer contains a matching '
        'dive',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the failure reason is localized, not English inside German', (
    tester,
  ) async {
    // The reason used to be an English string built in the service layer and
    // interpolated into the translated sentence, so 10 of 11 locales showed a
    // half-translated message.
    await pumpDetail(
      tester,
      outcome: const DiveResyncOutcome.failure(
        DiveResyncFailure.storedFileMissing,
      ),
      locale: const Locale('de'),
    );

    await tapResync(tester);

    expect(
      find.text(
        'Resynchronisierung fehlgeschlagen: Die Originaldatei ist auf diesem '
        'Gerät nicht mehr vorhanden',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a thrown error is surfaced as a message, not a silent no-op', (
    tester,
  ) async {
    await pumpWithOrchestrator(
      tester,
      _ThrowingDiveResyncOrchestrator(db: db),
      hasImportedFile: true,
      embedded: false,
    );

    await tapResync(tester);

    expect(
      find.text(
        'Could not resync: an unexpected error occurred while reading the '
        'original file',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the embedded app bar runs the same action', (tester) async {
    final orchestrator = await pumpDetail(
      tester,
      outcome: const DiveResyncOutcome.success(),
      embedded: true,
    );

    await tapResync(tester);

    expect(orchestrator.resyncedDiveIds, ['test-dive-1']);
    expect(find.text('Dive updated from the original file'), findsOneWidget);
  });
}
