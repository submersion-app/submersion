import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

MediaItem _localFile({String? localPath, String? filePath}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: localPath,
  filePath: filePath,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  test('sourceType getter returns localFile', () {
    expect(LocalFileResolver().sourceType, MediaSourceType.localFile);
  });

  test('canResolveOnThisDevice always true', () {
    expect(LocalFileResolver().canResolveOnThisDevice(_localFile()), isTrue);
  });

  test(
    'resolve returns FileData when localPath points at an existing file',
    () async {
      final tmp = Directory.systemTemp.createTempSync('local_file_resolver');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, 'photo.jpg'));
      await file.writeAsBytes([1, 2, 3]);

      final data = await LocalFileResolver().resolve(
        _localFile(localPath: file.path),
      );

      expect(data, isA<FileData>());
      expect((data as FileData).file.path, file.path);
    },
  );

  test('resolve falls back to filePath when localPath is null', () async {
    // Pre-v72 rows that the migration backfilled set local_path = file_path,
    // but defensively the resolver should also work for a row that only has
    // filePath populated.
    final tmp = Directory.systemTemp.createTempSync('local_file_resolver');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File(p.join(tmp.path, 'photo.jpg'));
    await file.writeAsBytes([1, 2, 3]);

    final data = await LocalFileResolver().resolve(
      _localFile(filePath: file.path),
    );

    expect(data, isA<FileData>());
  });

  test('resolve returns Unavailable.notFound when path is missing', () async {
    final data = await LocalFileResolver().resolve(
      _localFile(localPath: '/no/such/file.jpg'),
    );
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test(
    'resolve returns Unavailable.notFound when both paths are null',
    () async {
      final data = await LocalFileResolver().resolve(_localFile());
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test(
    'resolve returns Unavailable.notFound when localPath is empty',
    () async {
      final data = await LocalFileResolver().resolve(_localFile(localPath: ''));
      expect(data, isA<UnavailableData>());
    },
  );

  test('resolveThumbnail delegates to resolve', () async {
    final tmp = Directory.systemTemp.createTempSync('local_file_resolver');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File(p.join(tmp.path, 'photo.jpg'));
    await file.writeAsBytes([1, 2, 3]);

    final data = await LocalFileResolver().resolveThumbnail(
      _localFile(localPath: file.path),
      target: const Size(64, 64),
    );

    expect(data, isA<FileData>());
  });

  test('verify returns available when file exists', () async {
    final tmp = Directory.systemTemp.createTempSync('local_file_resolver');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File(p.join(tmp.path, 'photo.jpg'));
    await file.writeAsBytes([1, 2, 3]);

    final v = await LocalFileResolver().verify(
      _localFile(localPath: file.path),
    );
    expect(v, VerifyResult.available);
  });

  test('verify returns notFound when file is missing', () async {
    final v = await LocalFileResolver().verify(
      _localFile(localPath: '/no/such/file.jpg'),
    );
    expect(v, VerifyResult.notFound);
  });

  test('extractMetadata returns null', () async {
    expect(await LocalFileResolver().extractMetadata(_localFile()), isNull);
  });
}
