import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/pdf_thumb_refresh_sweep.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

const _storeId = 'store-1';
const _oldThumb = [1, 1, 1];
const _newThumb = [2, 2, 2];

class _StubThumbnails implements ThumbnailGenerator {
  _StubThumbnails(this.dir);

  final Directory dir;
  final rendered = <String>[];
  bool declines = false;
  Future<void> Function()? duringRender;

  @override
  Future<File?> generateFor(MediaItem item) async {
    rendered.add(item.id);
    await duringRender?.call();
    if (declines) return null;
    return File(p.join(dir.path, 'staged-${item.id}'))
      ..writeAsBytesSync(_newThumb);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #3996: thumbs uploaded before the whole-page fix hold a crop of the
/// page, and a device without the file has nothing else to show. The device
/// that can read the PDF replaces them, once.
void main() {
  final oldStamp = DateTime(2026, 2);
  final sweptAt = DateTime(2026, 11);

  late AppDatabase db;
  late MediaRepository repo;
  late SharedPreferences prefs;
  late Directory dir;
  late InMemoryMediaObjectStore store;
  late _StubThumbnails thumbnails;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    repo = MediaRepository();
    dir = await Directory.systemTemp.createTemp('pdf_thumb_refresh');
    store = InMemoryMediaObjectStore();
    thumbnails = _StubThumbnails(dir);
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

  PdfThumbRefreshSweep sweep({
    Future<bool> Function()? mayUpload,
    Future<bool> Function()? takesOver,
  }) => PdfThumbRefreshSweep(
    mediaRepository: repo,
    thumbnails: thumbnails,
    store: store,
    storeId: _storeId,
    deviceId: () async => 'me',
    mayUpload: mayUpload ?? () async => true,
    takesOver: takesOver ?? () async => true,
    prefs: prefs,
    now: () => sweptAt,
  );

  /// A row with a thumb in the store under [thumbStore].
  Future<MediaItem> stored(
    String name, {
    MediaType type = MediaType.document,
    String origin = 'me',
    String thumbStore = _storeId,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: type,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        diveId: 'd1',
        originDeviceId: origin,
        contentHash: 'hash-$name',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.stampRemoteThumbUploaded(
      created.id,
      uploadedAt: oldStamp,
      storeId: thumbStore,
    );
    store.objects[StoreKeys.thumbKey('hash-$name')] = _oldThumb;
    return created;
  }

  List<int>? thumbOf(String name) =>
      store.objects[StoreKeys.thumbKey('hash-$name')];

  Future<DateTime?> stampOf(MediaItem item) async =>
      (await repo.getMediaById(item.id))?.remoteThumbUploadedAt;

  test('replaces a stored thumb and moves its stamp', () async {
    final map = await stored('map.pdf');

    expect(await sweep().run(), 1);

    expect(thumbOf('map.pdf'), _newThumb);
    expect(await stampOf(map), sweptAt);
    expect(PdfThumbRefreshSweep.isDone(prefs), isTrue);
  });

  test('takes in a PDF from before origin tracking', () async {
    final map = await stored('map.pdf');
    // createMedia names this device, so the old shape is written directly.
    await (db.update(db.media)..where((t) => t.id.equals(map.id))).write(
      const MediaCompanion(originDeviceId: Value(null)),
    );

    expect(await sweep().run(), 1);

    expect(thumbOf('map.pdf'), _newThumb);
  });

  test('leaves everything that is not this device\'s PDF alone', () async {
    final photo = await stored('reef.jpg', type: MediaType.photo);
    final notes = await stored('notes.txt');
    final theirs = await stored('theirs.pdf', origin: 'other');

    expect(await sweep().run(), 0);

    expect(thumbnails.rendered, isEmpty);
    expect(thumbOf('reef.jpg'), _oldThumb);
    expect(await stampOf(photo), oldStamp);
    expect(await stampOf(notes), oldStamp);
    expect(await stampOf(theirs), oldStamp);
  });

  test('leaves a thumb stamped in another store alone', () async {
    await stored('map.pdf', thumbStore: 'store-2');

    expect(await sweep().run(), 0);

    expect(thumbnails.rendered, isEmpty);
    expect(thumbOf('map.pdf'), _oldThumb);
  });

  test('keeps the old thumb when no new one can be rendered', () async {
    final map = await stored('map.pdf');
    thumbnails.declines = true;

    expect(await sweep().run(), 0);

    expect(thumbOf('map.pdf'), _oldThumb);
    expect(await stampOf(map), oldStamp);
    // Nothing a later launch could do better: the file is gone or unreadable.
    expect(PdfThumbRefreshSweep.isDone(prefs), isTrue);
  });

  test('leaves no staged thumb behind', () async {
    await stored('map.pdf');

    await sweep().run();

    expect(dir.listSync(), isEmpty);
  });

  test('does nothing while uploads are held, and tries again', () async {
    final map = await stored('map.pdf');

    expect(await sweep(mayUpload: () async => false).run(), isNull);

    expect(thumbnails.rendered, isEmpty);
    expect(await stampOf(map), oldStamp);
    expect(PdfThumbRefreshSweep.isDone(prefs), isFalse);

    expect(await sweep().run(), 1);
  });

  test('a failed upload leaves the sweep to run again', () async {
    final map = await stored('map.pdf');
    store.failNextWith = Exception('store unreachable');

    expect(await sweep().run(), isNull);

    expect(await stampOf(map), oldStamp);
    expect(dir.listSync(), isEmpty);
    expect(PdfThumbRefreshSweep.isDone(prefs), isFalse);

    expect(await sweep().run(), 1);
    expect(thumbOf('map.pdf'), _newThumb);
  });

  test('runs once', () async {
    await stored('map.pdf');
    await sweep().run();
    thumbnails.rendered.clear();

    expect(await sweep().run(), isNull);

    expect(thumbnails.rendered, isEmpty);
  });

  test('a row another store took over mid-sweep keeps its stamps', () async {
    final map = await stored('map.pdf');
    thumbnails.duringRender = () => repo.stampRemoteThumbUploaded(
      map.id,
      uploadedAt: DateTime(2026, 10),
      storeId: 'store-2',
    );

    await sweep(takesOver: () async => false).run();

    expect(await stampOf(map), DateTime(2026, 10));
  });
}
