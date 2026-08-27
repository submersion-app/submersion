import 'package:drift/drift.dart' show Uint8List;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Exercises the "Re-parse raw data" overflow action. The outcome message is
/// not uniform: a combined dive's profile is deliberately left alone (#1164),
/// so re-parse refreshes only the source provenance and has to say so rather
/// than reporting a plain success for what looks like a no-op.
///
/// [ReparseService] is faked rather than driven for real, so the page's
/// `pigeon.DiveComputerHostApi().parseRawDiveData` tear-off is never invoked
/// and no platform channel is touched.
class _FakeReparseService extends ReparseService {
  _FakeReparseService({required super.db, required this.result});

  final ({List<String> errors, int profilesPreserved}) result;
  final reparsedDiveIds = <String>[];

  @override
  Future<({List<String> errors, int profilesPreserved})> reparseDive(
    String diveId, {
    required Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    )
    parseFn,
  }) async {
    reparsedDiveIds.add(diveId);
    return result;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<_FakeReparseService> pumpDetail(
    WidgetTester tester, {
    required ({List<String> errors, int profilesPreserved}) result,
    bool embedded = false,
  }) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();
    final service = _FakeReparseService(db: db, result: result);

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
          diveHasRawDataProvider(dive.id).overrideWith((ref) async => true),
          reparseServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return service;
  }

  Future<void> tapReparse(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source bar,
    // when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-parse raw data'));
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
