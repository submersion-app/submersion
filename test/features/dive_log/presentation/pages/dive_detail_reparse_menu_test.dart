import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/data/services/hand_set_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/unlock_for_operation.dart';

/// Exercises the "Re-parse raw data" overflow action. The outcome message is
/// not uniform: a combined dive's profile is deliberately left alone (#1164),
/// so re-parse refreshes only the source provenance and has to say so rather
/// than reporting a plain success for what looks like a no-op.
///
/// [ReparseService] is faked rather than driven for real, so the page's
/// `pigeon.DiveComputerHostApi().parseRawDiveData` tear-off is never invoked
/// and no platform channel is touched.
class _FakeReparseService extends ReparseService {
  _FakeReparseService({
    required super.db,
    required this.result,
    this.gate,
    this.failure,
    this.handSetChanges = const [],
    this.previewGate,
  });

  final ({List<String> errors, int profilesPreserved}) result;

  /// Holds the preview open until completed.
  final Completer<void>? previewGate;

  /// What the preview reports the re-parse would replace (issue #4909).
  final List<HandSetChange> handSetChanges;

  /// The fields each re-parse was told to replace.
  final replacedFields = <Set<HandSetField>>[];

  /// Holds the re-parse open until completed.
  final Completer<void>? gate;

  /// Thrown instead of a result, as a failed read of the sources is.
  final Object? failure;
  final reparsedDiveIds = <String>[];

  @override
  Future<List<HandSetChange>> previewReparse(
    String diveId, {
    required RawDiveParseFn parseFn,
  }) async {
    await previewGate?.future;
    return handSetChanges;
  }

  @override
  Future<({List<String> errors, int profilesPreserved})> reparseDive(
    String diveId, {
    required RawDiveParseFn parseFn,
    Iterable<HandSetChange> replaceHandSet = const [],
  }) async {
    reparsedDiveIds.add(diveId);
    replacedFields.add({for (final c in replaceHandSet) c.field});
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late GoRouter router;
  late int diveReads;

  setUp(
    () =>
        db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions)),
  );
  tearDown(() => db.close());

  Future<_FakeReparseService> pumpDetail(
    WidgetTester tester, {
    required ({List<String> errors, int profilesPreserved}) result,
    bool embedded = false,
    Locale locale = const Locale('en'),
    Completer<void>? gate,
    Object? failure,
    List<HandSetChange> handSetChanges = const [],
    Completer<void>? previewGate,
  }) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();
    final service = _FakeReparseService(
      db: db,
      result: result,
      gate: gate,
      failure: failure,
      handSetChanges: handSetChanges,
      previewGate: previewGate,
    );
    diveReads = 0;

    router = GoRouter(
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
        GoRoute(
          path: '/elsewhere',
          builder: (context, state) => const Scaffold(),
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
          diveProvider(dive.id).overrideWith((ref) async {
            diveReads++;
            return dive;
          }),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          // Gates the menu item; without it the action never renders.
          diveHasRawDataProvider(dive.id).overrideWith((ref) async => true),
          reparseServiceProvider.overrideWithValue(service),
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
    return service;
  }

  Future<void> tapReparse(
    WidgetTester tester, {
    String label = 'Re-parse raw data',
  }) async {
    await unlockForOperation(tester);
    // The header overflow menu is the last more_vert on the page (a source bar,
    // when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a preserved profile is reported instead of a plain success', (
    tester,
  ) async {
    final service = await pumpDetail(
      tester,
      result: (errors: <String>[], profilesPreserved: 2),
    );

    await tapReparse(tester);

    expect(service.reparsedDiveIds, ['test-dive-1']);
    expect(
      find.text(
        'Source details refreshed. This dive was combined from other dives, '
        'so its profile was left unchanged.',
      ),
      findsOneWidget,
    );
  });

  // Values the diver set by hand (issue #4909): the computer read 22 degrees
  // where the diver corrected it to 26.
  group('values set by hand', () {
    const waterTemp = HandSetChange(
      field: HandSetField.waterTemp,
      storedValue: 26.0,
      parsedValue: 22.0,
    );

    testWidgets('are listed before the re-parse, in the diver\'s units', (
      tester,
    ) async {
      final service = await pumpDetail(
        tester,
        result: (errors: <String>[], profilesPreserved: 0),
        handSetChanges: [waterTemp],
      );

      await tapReparse(tester);

      expect(find.text('Re-parse this dive?'), findsOneWidget);
      expect(find.text('Water Temperature'), findsOneWidget);
      expect(find.textContaining('Yours: 26'), findsOneWidget);
      expect(find.textContaining('Computer: 22'), findsOneWidget);
      expect(service.reparsedDiveIds, isEmpty);
    });

    testWidgets('leaving during the preview re-parses, keeping them', (
      tester,
    ) async {
      final previewGate = Completer<void>();
      final service = await pumpDetail(
        tester,
        result: (errors: <String>[], profilesPreserved: 0),
        handSetChanges: [waterTemp],
        previewGate: previewGate,
      );

      await tapReparse(tester);
      router.go('/elsewhere');
      await tester.pumpAndSettle();
      previewGate.complete();
      await tester.pump();
      await tester.pump();

      expect(service.replacedFields, [<HandSetField>{}]);
      expect(find.text('Re-parse this dive?'), findsNothing);
    });

    testWidgets('cancelling re-parses nothing', (tester) async {
      final service = await pumpDetail(
        tester,
        result: (errors: <String>[], profilesPreserved: 0),
        handSetChanges: [waterTemp],
      );

      await tapReparse(tester);
      // The unlocked page's own bar has a Cancel too.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.reparsedDiveIds, isEmpty);
      expect(find.text('Dive re-parsed successfully'), findsNothing);
    });

    testWidgets('keeps them unless the diver chooses Replace', (tester) async {
      final service = await pumpDetail(
        tester,
        result: (errors: <String>[], profilesPreserved: 0),
        handSetChanges: [waterTemp],
      );

      await tapReparse(tester);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
      await tester.pumpAndSettle();

      expect(service.replacedFields, [
        {HandSetField.waterTemp},
      ]);
      expect(find.text('Dive re-parsed successfully'), findsOneWidget);
    });
  });

  testWidgets('an ordinary dive reports a plain success', (tester) async {
    await pumpDetail(
      tester,
      result: (errors: <String>[], profilesPreserved: 0),
    );

    await tapReparse(tester);

    expect(find.text('Dive re-parsed successfully'), findsOneWidget);
  });

  testWidgets('the first error is surfaced when a source fails to parse', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      result: (errors: <String>['native bridge error'], profilesPreserved: 0),
    );

    await tapReparse(tester);

    expect(find.text('Re-parse failed: native bridge error'), findsOneWidget);
  });

  testWidgets('a source missing its computer details says so in the '
      'diver\'s language', (tester) async {
    await pumpDetail(
      tester,
      result: (errors: <String>[missingDescriptorsError], profilesPreserved: 0),
      locale: const Locale('de'),
    );

    await tapReparse(tester, label: 'Rohdaten neu auswerten');

    expect(
      find.text('Neu-Auswertung fehlgeschlagen: Tauchcomputer-Angaben fehlen'),
      findsOneWidget,
    );
  });

  testWidgets('leaving while it runs still refreshes the dive', (tester) async {
    // A re-parse takes a while and nothing holds the diver on the page. The
    // list reads this dive too, so the refresh must not depend on the page
    // that started it, and using a dead ref here would throw a StateError.
    final gate = Completer<void>();
    await pumpDetail(
      tester,
      result: (errors: <String>[], profilesPreserved: 0),
      gate: gate,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
    final subscription = container.listen(
      diveProvider('test-dive-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await tapReparse(tester);
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(find.byType(DiveDetailPage), findsNothing);
    final readsBefore = diveReads;

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(diveReads, readsBefore + 1);
    expect(find.text('Dive re-parsed successfully'), findsOneWidget);
  });

  testWidgets('a failure before any source is parsed is reported', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      result: (errors: <String>[], profilesPreserved: 0),
      failure: StateError('the read failed'),
    );

    await tapReparse(tester);

    expect(
      find.text('Re-parse failed: Bad state: the read failed'),
      findsOneWidget,
    );
  });

  testWidgets('the embedded app bar runs the same action', (tester) async {
    final service = await pumpDetail(
      tester,
      result: (errors: <String>[], profilesPreserved: 1),
      embedded: true,
    );

    await tapReparse(tester);

    expect(service.reparsedDiveIds, ['test-dive-1']);
    expect(
      find.text(
        'Source details refreshed. This dive was combined from other dives, '
        'so its profile was left unchanged.',
      ),
      findsOneWidget,
    );
  });
}
