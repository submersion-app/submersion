import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_origin_republish_sweep.dart';

import '../../helpers/test_database.dart';

class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async => null;
}

class _ThrowingRepository extends MediaRepository {
  @override
  Future<List<String>> getStoreStampedMediaIdsOwnedBy(String deviceId) {
    throw StateError('db unavailable');
  }
}

/// One-time repair for libraries damaged before the origin-device fix.
///
/// The desktop uploaded; the phone flagged the desktop's rows "missing" and
/// that write made sync drop the desktop's cloud stamps on the phone. The
/// desktop still has the stamps, and (usually) the phone's flag. Republishing
/// its own stamped rows hands the stamps back to every peer; re-checking its
/// own flagged rows clears a flag it never earned.
void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late SharedPreferences prefs;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    repo = MediaRepository();
    dir = await Directory.systemTemp.createTemp('origin_republish');
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
    await tearDownTestDatabase();
  });

  MediaOriginRepublishSweep sweep({MediaRepository? repository}) {
    final r = repository ?? repo;
    return MediaOriginRepublishSweep(
      mediaRepository: r,
      verifier: MediaItemVerifier(
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: LocalFileResolver(
            bookmarkStorage: _NullBookmarkStorage(),
            platform: LocalMediaPlatform(),
            exifExtractor: ExifExtractor(),
            localDeviceId: () async => 'me',
          ),
        }),
        repository: r,
      ),
      deviceId: () async => 'me',
      prefs: prefs,
    );
  }

  Future<MediaItem> row(
    String name, {
    required String origin,
    bool present = false,
    bool stamped = false,
    bool flagged = false,
  }) async {
    final path = '${dir.path}/$name';
    if (present) File(path).writeAsBytesSync([1, 2, 3]);
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: path,
        localPath: path,
        originalFilename: name,
        diveId: 'd1',
        originDeviceId: origin,
        contentHash: stamped ? 'hash-$name' : null,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (stamped) {
      await repo.stampRemoteUploaded(created.id, uploadedAt: DateTime(2026, 2));
    }
    if (flagged) await repo.markAsOrphaned(created.id);
    return created;
  }

  Future<Set<String>> pendingMediaIds() async => {
    for (final r in await SyncRepository().getPendingRecords())
      if (r.entityType == 'media') r.recordId,
  };

  test('republishes every stamped row this device imported, and nothing '
      'else', () async {
    final mine = await row('mine.jpg', origin: 'me', stamped: true);
    await row('unstamped.jpg', origin: 'me');
    await row('theirs.jpg', origin: 'other', stamped: true);
    await SyncRepository().clearPendingRecords();

    final outcome = await sweep().run();

    expect(outcome?.republished, 1);
    expect(await pendingMediaIds(), {mine.id});
  });

  test('clears the missing flag on an own row whose file is present', () async {
    final present = await row(
      'present.jpg',
      origin: 'me',
      present: true,
      flagged: true,
    );
    final gone = await row('gone.jpg', origin: 'me', flagged: true);
    // A peer's row this device cannot read: not this device's call to make.
    final theirs = await row('theirs.jpg', origin: 'other', flagged: true);

    final outcome = await sweep().run();

    expect(outcome?.rechecked, 2);
    expect(outcome?.unflagged, 1);
    expect((await repo.getMediaById(present.id))!.isOrphaned, isFalse);
    expect((await repo.getMediaById(gone.id))!.isOrphaned, isTrue);
    expect((await repo.getMediaById(theirs.id))!.isOrphaned, isTrue);
  });

  test('runs once per device', () async {
    await row('mine.jpg', origin: 'me', stamped: true);
    expect(await sweep().run(), isNotNull);
    await SyncRepository().clearPendingRecords();

    expect(await sweep().run(), isNull);

    expect(await pendingMediaIds(), isEmpty);
    expect(prefs.getBool(MediaOriginRepublishSweep.doneFlagKey), isTrue);
  });

  test('a failure leaves the flag unset so the next launch retries', () async {
    final outcome = await sweep(repository: _ThrowingRepository()).run();

    expect(outcome, isNull);
    expect(prefs.getBool(MediaOriginRepublishSweep.doneFlagKey), isNull);
  });
}
