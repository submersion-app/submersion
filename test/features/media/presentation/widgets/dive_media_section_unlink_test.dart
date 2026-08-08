import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _ThrowingDeletionCoordinator implements MediaDeletionCoordinator {
  @override
  Future<void> deleteMultipleMedia(List<String> ids) async {
    throw StateError('store offline');
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

  MediaItem item(String id, {String? diveId}) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test('unlinkMultipleMedia keeps rows while deleteMultipleMedia removes '
      'them', () async {
    await insertDive('d1');
    await repo.createMedia(item('keep-me', diveId: 'd1'));
    await repo.createMedia(item('kill-me', diveId: 'd1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mediaListNotifierProvider('d1').notifier);

    await notifier.unlinkMultipleMedia(['keep-me']);
    final kept = await repo.getMediaById('keep-me');
    expect(kept, isNotNull);
    expect(kept!.diveId, isNull);
    expect(kept.retainInLibrary, isTrue);

    await notifier.deleteMultipleMedia(['kill-me']);
    expect(await repo.getMediaById('kill-me'), isNull);
  });

  testWidgets('selection header offers Unlink and Delete; Unlink keeps the '
      'row', (tester) async {
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

    // Enter selection mode by long-pressing the tile.
    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.link_off), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();
    expect(find.text('Unlink 1 items?'), findsOneWidget);
    await tester.tap(find.text('Unlink'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    final m = await repo.getMediaById('m1');
    expect(m, isNotNull);
    expect(m!.diveId, isNull);
  });

  testWidgets('a failed delete reports a delete error, not an unlink one', (
    tester,
  ) async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaDeletionCoordinatorProvider.overrideWithValue(
              _ThrowingDeletionCoordinator(),
            ),
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

    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 items?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    await tester.pump();

    expect(find.textContaining('Failed to delete:'), findsOneWidget);
    expect(find.textContaining('Failed to unlink:'), findsNothing);
    // The row survives a failed delete.
    expect(await repo.getMediaById('m1'), isNotNull);
  });
}
