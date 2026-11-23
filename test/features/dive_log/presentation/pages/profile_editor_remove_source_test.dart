import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/data/services/dive_source_removal_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeRemoval implements DiveSourceRemovalService {
  final removed = <String>[];

  @override
  Future<bool> sharesComputer({
    required String diveId,
    required String sourceId,
  }) async => false;

  @override
  Future<SourceRemoval> remove({
    required String diveId,
    required String sourceId,
  }) async {
    removed.add(sourceId);
    return const SourceRemoval(operationId: 'op-1');
  }
}

/// Issue #4972: a dive imported from two places (divelogs.de and Garmin)
/// carries a profile per source. The editor's Cleanup tab removes the
/// source being edited, and says why Delete Entire Profile is unavailable.
void main() {
  const primaryPoints = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 12.0),
    DiveProfilePoint(timestamp: 120, depth: 0.0),
  ];
  const secondPoints = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 30, depth: 18.0),
    DiveProfilePoint(timestamp: 90, depth: 18.0),
    DiveProfilePoint(timestamp: 120, depth: 0.0),
  ];
  const removeLabel = 'Remove This Source';
  const onlyRevisionHint =
      "This is the dive's only profile revision, so it can't be deleted.";
  const notPrimaryHint =
      "Delete Entire Profile only deletes revisions of the primary "
      "source's profile.";
  const historyFailedHint =
      "Couldn't load the profile revisions, so none can be deleted now.";
  // Names what waits, since the outlier and trim tools keep working.
  const unsavedHint =
      'Save or undo your edits to delete the profile or remove this source.';
  const unsavedDeleteOnlyHint =
      'Save or undo your edits to delete the profile.';

  late Dive dive;
  late _FakeRemoval removal;
  bool? popResult;

  setUp(() {
    removal = _FakeRemoval();
    popResult = null;
    dive = createTestDiveWithBottomTime().copyWith(
      profile: [...primaryPoints, ...secondPoints]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
    );
  });

  DiveDataSource source(String id, {required bool primary, String? dc}) =>
      DiveDataSource(
        id: id,
        diveId: dive.id,
        computerId: dc,
        isPrimary: primary,
        computerModel: dc == null ? null : 'Model $id',
        importedAt: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1),
      );

  ProfileSeriesRevision revision(String id, {required bool active}) =>
      ProfileSeriesRevision(
        seriesId: id,
        diveId: dive.id,
        parentSeriesId: null,
        rootSeriesId: id,
        contentHash: 'hash-$id',
        revisionKind: 'legacy',
        createdAt: 1000,
        isActive: active,
      );

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? sourceId,
    List<DiveDataSource>? sources,
    List<ProfileSeriesRevision>? revisions,
    bool historyFails = false,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveSourceRemovalServiceProvider.overrideWithValue(removal),
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(dive.id).overrideWith(
            (ref) async =>
                sources ??
                [
                  source('src-a', primary: true, dc: 'dc-a'),
                  source('src-b', primary: false, dc: 'dc-b'),
                ],
          ),
          // A removed source is gone from the next read, as in the database.
          sourceProfilesProvider(dive.id).overrideWith(
            (ref) async => {
              'src-a': const SourceProfile(
                sourceId: 'src-a',
                computerId: 'dc-a',
                isEdited: false,
                points: primaryPoints,
              ),
              'src-b': const SourceProfile(
                sourceId: 'src-b',
                computerId: 'dc-b',
                isEdited: false,
                points: secondPoints,
              ),
            }..removeWhere((id, _) => removal.removed.contains(id)),
          ),
          profileSeriesHistoryProvider(dive.id).overrideWith(
            (ref) async => historyFails
                ? throw StateError('database is locked')
                : revisions ?? [revision('series-a', active: true)],
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        popResult = await context.push<bool>('/edit'),
                    child: const Text('open'),
                  ),
                ),
              ),
              GoRoute(
                path: '/edit',
                builder: (context, _) => ProfileEditorPage(
                  diveId: dive.id,
                  initialMode: EditorMode.outlier,
                  sourceId: sourceId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Let the revision history and sources the editor reads settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Smooths the profile, so an edit is pending, and returns to Cleanup.
  Future<void> smoothThenCleanup(WidgetTester tester) async {
    await tester.tap(find.text('Smooth').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply to All'));
    await tester.tap(find.text('Apply to All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanup').first);
    await tester.pumpAndSettle();
  }

  FilledButton buttonLabelled(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        ),
      );

  group('Remove This Source', () {
    testWidgets('removes the source being edited and leaves the editor', (
      tester,
    ) async {
      await pumpEditor(tester, sourceId: 'src-b');

      expect(buttonLabelled(tester, removeLabel).onPressed, isNotNull);
      await tester.ensureVisible(find.text(removeLabel));
      await tester.tap(find.text(removeLabel));
      await tester.pumpAndSettle();

      // The confirmation the Data Sources menu asks, naming the source.
      expect(find.text('Remove this source?'), findsOneWidget);
      expect(find.textContaining('Model src-b'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(removal.removed, ['src-b']);
      expect(find.byType(ProfileEditorPage), findsNothing);
      // The dive page refreshes only when the editor reports a change.
      expect(popResult, isTrue);
      expect(find.text('Source removed'), findsOneWidget);
    });

    testWidgets('keeps its chart while it leaves, not "no profile data"', (
      tester,
    ) async {
      await pumpEditor(tester, sourceId: 'src-b');

      await tester.ensureVisible(find.text(removeLabel));
      await tester.tap(find.text(removeLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      // Step through the exit transition, after the sources re-read.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('No profile data available'), findsNothing);
      }
      await tester.pumpAndSettle();

      expect(removal.removed, ['src-b']);
      expect(find.byType(ProfileEditorPage), findsNothing);
    });

    testWidgets('turning the confirmation down keeps the editor open', (
      tester,
    ) async {
      await pumpEditor(tester, sourceId: 'src-a');

      await tester.ensureVisible(find.text(removeLabel));
      await tester.tap(find.text(removeLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(removal.removed, isEmpty);
      expect(find.byType(ProfileEditorPage), findsOneWidget);
    });

    testWidgets('is not offered on a dive with a single source', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        sources: [source('src-a', primary: true, dc: 'dc-a')],
      );

      expect(find.text(removeLabel), findsNothing);
    });

    testWidgets('is not offered for a source sharing its computer', (
      tester,
    ) async {
      // A combined split pair: the removal refuses, as the menu hides it.
      await pumpEditor(
        tester,
        sourceId: 'src-b',
        sources: [
          source('src-a', primary: true, dc: 'dc-a'),
          source('src-b', primary: false, dc: 'dc-a'),
        ],
      );

      expect(find.text(removeLabel), findsNothing);
    });

    testWidgets('waits for unsaved edits to be saved or undone', (
      tester,
    ) async {
      await pumpEditor(tester, sourceId: 'src-b');
      await smoothThenCleanup(tester);

      expect(buttonLabelled(tester, removeLabel).onPressed, isNull);
      expect(find.text(unsavedHint), findsOneWidget);
    });
  });

  testWidgets('unsaved edits on a single-source dive name only the delete', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      sources: [source('src-a', primary: true, dc: 'dc-a')],
    );
    await smoothThenCleanup(tester);

    expect(find.text(unsavedDeleteOnlyHint), findsOneWidget);
    expect(find.text(unsavedHint), findsNothing);
  });

  group('Delete Entire Profile says why it is unavailable', () {
    testWidgets('on the only revision', (tester) async {
      await pumpEditor(tester, sourceId: 'src-a');

      expect(buttonLabelled(tester, 'Delete Entire Profile').onPressed, isNull);
      expect(find.text(onlyRevisionHint), findsOneWidget);
    });

    testWidgets('on the only revision of a single-source dive', (tester) async {
      await pumpEditor(
        tester,
        sources: [source('src-a', primary: true, dc: 'dc-a')],
      );

      expect(find.text(onlyRevisionHint), findsOneWidget);
    });

    testWidgets('while editing a non-primary source', (tester) async {
      await pumpEditor(
        tester,
        sourceId: 'src-b',
        revisions: [
          revision('series-a', active: true),
          revision('series-a2', active: false),
        ],
      );

      expect(find.text(notPrimaryHint), findsOneWidget);
    });

    testWidgets('when the revisions could not be loaded', (tester) async {
      await pumpEditor(tester, sourceId: 'src-a', historyFails: true);

      expect(buttonLabelled(tester, 'Delete Entire Profile').onPressed, isNull);
      expect(find.text(historyFailedHint), findsOneWidget);
    });

    testWidgets('says nothing when the profile can be deleted', (tester) async {
      await pumpEditor(
        tester,
        sourceId: 'src-a',
        revisions: [
          revision('series-a', active: true),
          revision('series-a2', active: false),
        ],
      );

      expect(
        buttonLabelled(tester, 'Delete Entire Profile').onPressed,
        isNotNull,
      );
      expect(find.text(onlyRevisionHint), findsNothing);
      expect(find.text(notPrimaryHint), findsNothing);
      expect(find.text(unsavedHint), findsNothing);
    });
  });
}
