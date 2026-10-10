import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3066: the "Choose starting profile" sheet offers every source with
/// samples of its own, and the chosen one reaches the profile editor.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  const now = 1750000000000;
  const diveId = 'dive-1';

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            maxDepth: Value(20.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    // File imports: neither source is linked to a registered computer.
    for (final (id, model, isPrimary, maxDepth) in [
      ('src-a', 'Perdix', true, 20.0),
      ('src-b', 'Teric', false, 30.0),
    ]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value(diveId),
              computerModel: Value(model),
              isPrimary: Value(isPrimary),
              maxDepth: Value(maxDepth),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        sourceId: id,
        isPrimary: isPrimary,
        samples: [
          const ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 60, depth: maxDepth),
          const ProfileSample(timestamp: 120, depth: 0),
        ],
        now: now,
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Pumps the dive edit page with [editor] standing in for the profile
  /// editor route.
  Future<void> pumpEditPage(
    WidgetTester tester, {
    required GoRouterWidgetBuilder editor,
  }) async {
    tester.view.physicalSize = const Size(950, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          tripForDateProvider.overrideWith((ref, date) async => null),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => const Scaffold(
                  body: DiveEditPage(diveId: diveId, embedded: true),
                ),
              ),
              GoRoute(
                path: '/dives/:diveId/edit-profile',
                name: 'editProfile',
                builder: editor,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the chosen source reaches the editor and the form refreshes '
      'after its edit is saved', (tester) async {
    Map<String, String>? editorQuery;
    await pumpEditPage(
      tester,
      editor: (context, state) {
        editorQuery = state.uri.queryParameters;
        // Stands in for the editor: save an edit against the source it was
        // given, then report the save.
        return Scaffold(
          body: TextButton(
            onPressed: () async {
              await repository.saveEditedProfileWithKind(
                diveId: diveId,
                editedPoints: const [
                  DiveProfilePoint(timestamp: 0, depth: 0),
                  DiveProfilePoint(timestamp: 60, depth: 28),
                  DiveProfilePoint(timestamp: 120, depth: 0),
                ],
                editKind: 'profile_editor',
                sourceId: state.uri.queryParameters['sourceId'],
              );
              if (context.mounted) context.pop(true);
            },
            child: const Text('save edit'),
          ),
        );
      },
    );

    await tester.tap(find.text('Dive profile'));
    await tester.pumpAndSettle();

    expect(find.text('Choose starting profile'), findsOneWidget);
    await tester.tap(find.text('Teric'));
    await tester.pumpAndSettle();

    expect(editorQuery?['sourceId'], 'src-b');

    await tester.runAsync(() async {
      await tester.tap(find.text('save edit'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // The form shows the depth the saved edit wrote, so saving the form
    // will not write the pre-edit value back.
    expect(find.text('28.0 m'), findsOneWidget);
    expect(find.text('20.0 m'), findsNothing);
  });

  testWidgets('choosing the primary source names it without promoting', (
    tester,
  ) async {
    Map<String, String>? editorQuery;
    await pumpEditPage(
      tester,
      editor: (context, state) {
        editorQuery = state.uri.queryParameters;
        return const SizedBox.shrink();
      },
    );

    await tester.tap(find.text('Dive profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perdix'));
    await tester.pumpAndSettle();

    // Named even though it is primary: without a source the editor starts
    // from the dive's profile, which interleaves both computers.
    expect(editorQuery?['sourceId'], 'src-a');
  });

  testWidgets('a lone source with samples is named even when not primary', (
    tester,
  ) async {
    // The primary carries metadata only; the other source owns every
    // sample. No sheet is offered, but an edit is still that source's.
    await (db.delete(
      db.diveProfileSeries,
    )..where((t) => t.sourceId.equals('src-a'))).go();

    Map<String, String>? editorQuery;
    await pumpEditPage(
      tester,
      editor: (context, state) {
        editorQuery = state.uri.queryParameters;
        return const SizedBox.shrink();
      },
    );

    await tester.tap(find.text('Dive profile'));
    await tester.pumpAndSettle();

    expect(find.text('Choose starting profile'), findsNothing);
    expect(editorQuery?['sourceId'], 'src-b');
  });
}
