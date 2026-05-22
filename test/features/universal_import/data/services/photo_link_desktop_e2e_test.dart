import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/services/desktop_directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';
import '../../../../helpers/test_database.dart';

/// Insert a bare dive row with the minimum required (non-nullable,
/// no-default) columns: id, diveDateTime, createdAt, updatedAt.
/// All other Dives columns are either nullable or carry a Drift default.
Future<void> _insertBareDive(AppDatabase db, String diveId) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: diveId,
          diveDateTime: DateTime(2024, 6, 1).millisecondsSinceEpoch,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase db;
  late Directory photoDir;
  late MediaRepository mediaRepository;

  setUp(() async {
    // setUpTestDatabase() registers the in-memory DB in DatabaseService.instance
    // so that MediaRepository() (which calls DatabaseService.instance.database)
    // resolves to the same test DB.
    db = await setUpTestDatabase();
    photoDir = Directory.systemTemp.createTempSync('photo_e2e_');
    mediaRepository = MediaRepository();
  });

  tearDown(() async {
    if (photoDir.existsSync()) photoDir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  test('desktop end-to-end: parse -> resolve -> link MediaItems', () async {
    final dbPath =
        '${Directory.systemTemp.path}/e2e_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final dbFile = buildSyntheticMacDiveDb(dbPath);
    addTearDown(() {
      if (dbFile.existsSync()) dbFile.deleteSync();
    });

    final payload = await const MacDiveSqliteParser().parse(
      Uint8List.fromList(await dbFile.readAsBytes()),
    );
    expect(payload.imageRefs, isNotEmpty);

    // Place a stub file for every referenced photo basename in the temp dir.
    for (final ref in payload.imageRefs) {
      File('${photoDir.path}/${ref.filename}').writeAsBytesSync([1, 2, 3]);
    }

    // Build a source-UUID -> dive-id map and insert the dives into the test DB.
    final sourceUuidToDiveId = <String, String>{};
    for (final ref in payload.imageRefs) {
      sourceUuidToDiveId.putIfAbsent(ref.diveSourceUuid, () {
        final id = 'dive-${sourceUuidToDiveId.length + 1}';
        return id;
      });
    }
    for (final id in sourceUuidToDiveId.values.toSet()) {
      await _insertBareDive(db, id);
    }

    // Resolve all image refs against the temp photo directory.
    final resolver = PhotoResolver(
      scanner: DesktopDirectoryScanner(),
      folder: GrantedFolder(path: photoDir.path),
    );
    final resolved = await resolver.resolveAll(payload.imageRefs);
    expect(
      resolved.where((r) => r.scannedFile != null).length,
      payload.imageRefs.length,
    );

    // Link each resolved photo to its dive via LocalMediaLinker.
    // Desktop handles carry localPath only — LocalBookmarkStorage.write
    // is never called, so the flutter_secure_storage keychain is untouched.
    final linker = LocalMediaLinker(
      mediaRepository: mediaRepository,
      bookmarkStorage: LocalBookmarkStorage(),
    );
    var linked = 0;
    for (final r in resolved) {
      if (r.scannedFile == null) continue;
      final diveId = sourceUuidToDiveId[r.ref.diveSourceUuid]!;
      await linker.link(
        diveId: diveId,
        handle: r.scannedFile!.handle,
        basename: r.scannedFile!.basename,
        metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
        fallbackTakenAt: DateTime(2024, 6, 1),
        caption: r.ref.caption,
      );
      linked++;
    }
    expect(linked, payload.imageRefs.length);

    // Verify MediaItem rows were written for the first dive in the map.
    final firstDiveId = sourceUuidToDiveId.values.first;
    final media = await mediaRepository.getMediaForDive(firstDiveId);
    expect(media, isNotEmpty);
    expect(media.first.filePath, startsWith(photoDir.path));
  });
}
