import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

/// Regression tests for the home-page photo ribbon showing photos that no
/// longer exist. Deleting a photo (from the dive detail gallery, the files
/// tab, a dive deletion cascade, or an incoming sync) removes the `media`
/// row, but `recentMediaProvider` is a kept-alive [FutureProvider] that used
/// to have no change-tick subscription: it held its cached slice until
/// pull-to-refresh or an app restart, so the deleted photo stayed on the
/// ribbon as a dead tile.
///
/// The provider now self-invalidates on [MediaRepository.watchMediaChanges],
/// the same repo-tick pattern the recent-dives card uses (issue #217).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
          createdAt: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
          updatedAt: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
        ),
      );

  Future<MediaItem> addPhoto(
    MediaRepository repo, {
    required String diveId,
    required String path,
    required DateTime takenAt,
  }) => repo.createMedia(
    MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      filePath: path,
      diveId: diveId,
      takenAt: takenAt,
      createdAt: takenAt,
      updatedAt: takenAt,
    ),
  );

  /// Polls the provider until [settled] holds, so the media-table tick ->
  /// invalidate -> rebuild round trip has a chance to run.
  ///
  /// The budget is derived from [MediaRepository.changeTickDebounce] rather
  /// than hard-coded, so it stays proportionate if that window is ever
  /// widened. Never settling fails here, naming the round trip that stalled,
  /// instead of surfacing downstream as a bare value mismatch that reads like
  /// a wrong query.
  Future<List<MediaItem>> pollPhotos(
    ProviderContainer container,
    bool Function(List<MediaItem> photos) settled, {
    required String awaiting,
  }) async {
    const interval = Duration(milliseconds: 20);
    final budget = MediaRepository.changeTickDebounce * 20;
    final deadline = DateTime.now().add(budget);

    var photos = await container.read(recentMediaProvider.future);
    while (!settled(photos) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      photos = await container.read(recentMediaProvider.future);
    }

    if (!settled(photos)) {
      fail(
        'Timed out after ${budget.inMilliseconds}ms waiting for $awaiting. '
        'The media-table tick -> invalidateSelfWhen -> rebuild round trip '
        'never settled; recentMediaProvider still holds '
        '${photos.map((p) => p.filePath).toList()}.',
      );
    }
    return photos;
  }

  test('recentMediaProvider drops a photo deleted while off screen', () async {
    await insertDive('d1');
    final repo = MediaRepository();
    final keep = await addPhoto(
      repo,
      diveId: 'd1',
      path: '/tmp/keep.jpg',
      takenAt: DateTime(2026, 3, 1),
    );
    final doomed = await addPhoto(
      repo,
      diveId: 'd1',
      path: '/tmp/doomed.jpg',
      takenAt: DateTime(2026, 3, 2),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Dashboard on screen: an active listener builds the ribbon's provider,
    // exactly like MediaRibbonCard watching recentMediaProvider.
    final onScreen = container.listen(recentMediaProvider, (_, _) {});
    final initial = await container.read(recentMediaProvider.future);
    expect(initial.map((p) => p.id).toList(), [
      doomed.id,
      keep.id,
    ], reason: 'newest first, before the delete');

    // User leaves the dashboard for the dive detail page and deletes a photo.
    onScreen.close();
    await repo.deleteMedia(doomed.id);

    // User returns to the dashboard: the ribbon re-subscribes.
    final backOnScreen = container.listen(recentMediaProvider, (_, _) {});
    addTearDown(backOnScreen.close);

    final photos = await pollPhotos(
      container,
      (p) => !p.any((item) => item.id == doomed.id),
      awaiting: 'the deleted photo to leave the ribbon',
    );

    expect(
      photos.map((p) => p.id).toList(),
      [keep.id],
      reason:
          'A photo deleted while the dashboard was off screen must be gone '
          'from the home-page ribbon on return, not left as a dead tile.',
    );
  });

  test('recentMediaProvider picks up a photo added while off screen', () async {
    await insertDive('d1');
    final repo = MediaRepository();
    final existing = await addPhoto(
      repo,
      diveId: 'd1',
      path: '/tmp/existing.jpg',
      takenAt: DateTime(2026, 3, 1),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final onScreen = container.listen(recentMediaProvider, (_, _) {});
    expect(await container.read(recentMediaProvider.future), hasLength(1));
    onScreen.close();

    // An import or an incoming sync writes a newer photo straight to the DB.
    final imported = await addPhoto(
      repo,
      diveId: 'd1',
      path: '/tmp/imported.jpg',
      takenAt: DateTime(2026, 3, 2),
    );

    final backOnScreen = container.listen(recentMediaProvider, (_, _) {});
    addTearDown(backOnScreen.close);

    final photos = await pollPhotos(
      container,
      (p) => p.any((item) => item.id == imported.id),
      awaiting: 'the newly added photo to appear on the ribbon',
    );

    expect(photos.map((p) => p.id).toList(), [imported.id, existing.id]);
  });
}
