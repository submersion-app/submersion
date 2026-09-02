import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The project barrel, not flutter_riverpod directly: Riverpod 3.1 moved
// StateNotifier into flutter_riverpod/legacy.dart and the barrel re-exports
// both halves.
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Fails the unlink so the surface's error branch can be asserted. Delete is
/// captured rather than thrown: this surface must never reach it, and a
/// regression to the old hard-delete wiring would surface as a delete error
/// instead of the expected unlink one.
class _ThrowingMediaListNotifier
    extends StateNotifier<AsyncValue<List<MediaItem>>>
    implements MediaListNotifier {
  _ThrowingMediaListNotifier() : super(const AsyncValue.data(<MediaItem>[]));

  @override
  Future<UnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    throw StateError('unlink failed');
  }

  @override
  Future<void> deleteMultipleMedia(List<String> ids) async {
    throw StateError('delete must not be reached from this surface');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late SharedPreferences prefs;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(String id, {String? diveId, String? siteId}) => MediaItem(
    id: id,
    diveId: diveId,
    siteId: siteId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test('unlinkMultipleMedia removes the row from the library', () async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mediaListNotifierProvider('d1').notifier);

    final outcome = await notifier.unlinkMultipleMedia(['m1']);

    expect(await repo.getMediaById('m1'), isNull);
    expect(outcome.deleted, 1);
    expect(outcome.keptAsSiteMedia, 0);
  });

  test('unlinkMultipleMedia keeps a row a dive site still needs', () async {
    await insertDive('d1');
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Blue Hole',
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
    await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mediaListNotifierProvider('d1').notifier);

    final outcome = await notifier.unlinkMultipleMedia(['m1']);

    final kept = await repo.getMediaById('m1');
    expect(kept, isNotNull);
    expect(kept!.diveId, isNull);
    expect(kept.siteId, 's1');
    // The site link is what keeps the row; nothing latches a retain flag.
    expect(kept.retainInLibrary, isFalse);
    expect(outcome.deleted, 0);
    expect(outcome.keptAsSiteMedia, 1);
  });

  testWidgets('the selection bar offers Unlink and no Delete; Unlink keeps '
      'the row', (tester) async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveMediaSection(diveId: 'd1'),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    // Entry is the keyed Select affordance: long-press was removed as a
    // selection entry across every surface (PR #1021).
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pumpAndSettle();

    // Unlink is the only bulk action here. There is no separate delete
    // because unlink IS the removal: the row, the cloud proxies and the
    // thumbnails all go, and only the original source file is left alone.
    expect(
      find.byKey(const ValueKey('selection_action_unlink')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.byKey(const ValueKey('selection_action_unlink')));
    await tester.pumpAndSettle();
    expect(find.text('Unlink 1 items?'), findsOneWidget);
    await tester.tap(find.text('Unlink'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(await repo.getMediaById('m1'), isNull);
  });

  testWidgets('a failed unlink reports an unlink error and keeps the row', (
    tester,
  ) async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaListNotifierProvider(
              'd1',
            ).overrideWith((ref) => _ThrowingMediaListNotifier()),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveMediaSection(diveId: 'd1'),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('selection_action_unlink')));
    await tester.pumpAndSettle();
    expect(find.text('Unlink 1 items?'), findsOneWidget);
    await tester.tap(find.text('Unlink'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    await tester.pump();

    expect(find.textContaining('Failed to unlink:'), findsOneWidget);
    expect(find.textContaining('Failed to delete:'), findsNothing);
    // The row survives a failed unlink.
    expect(await repo.getMediaById('m1'), isNotNull);
  });
}
