import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

import '../../../../helpers/test_database.dart';

/// A row with no taken_at sorts in the library by created_at, so every
/// hydration path dates it by created_at too, read as wall-clock like
/// taken_at (issue #4268), rather than by the moment it was read.
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  final created = DateTime.utc(2026, 5, 20, 12);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      'VALUES (?, ?, 0, 0)',
      ['site', 'Reef'],
    );
    await db.customStatement(
      'INSERT INTO media (id, site_id, platform_asset_id, file_path, '
      'file_type, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0)',
      [
        'undated',
        'site',
        'asset-1',
        p.join(Directory.systemTemp.path, 'undated.jpg'),
        'photo',
        created.millisecondsSinceEpoch,
      ],
    );
  });
  tearDown(tearDownTestDatabase);

  test('a full row dates an undated photo by its created_at', () async {
    final items = await repo.getMediaForSite('site');
    expect(items.single.takenAt, created);
  });

  test('a gallery link row dates it the same way', () async {
    final links = await repo.getGalleryLinksForSite('site');
    expect(links.single.takenAt, created);
  });
}
