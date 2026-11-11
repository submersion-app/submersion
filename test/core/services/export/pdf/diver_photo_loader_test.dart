import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// The portrait is decorative: a logbook export must still produce a PDF when
/// the file behind `Diver.photoPath` has moved, so every failure resolves to
/// null rather than an exception.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('diver_photo'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('reads the bytes of an existing portrait', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final file = File('${tempDir.path}/portrait.jpg')..writeAsBytesSync(bytes);

    expect(await loadDiverPhotoFromDisk(file.path), bytes);
  });

  test('returns null for a diver with no portrait', () async {
    expect(await loadDiverPhotoFromDisk(null), isNull);
  });

  test('returns null for an empty path', () async {
    expect(await loadDiverPhotoFromDisk(''), isNull);
  });

  test('returns null when the file has been moved away', () async {
    expect(await loadDiverPhotoFromDisk('${tempDir.path}/gone.jpg'), isNull);
  });

  test(
    'returns null rather than throwing when the path is a directory',
    () async {
      expect(await loadDiverPhotoFromDisk(tempDir.path), isNull);
    },
  );

  group('diverPortrait (#4458)', () {
    final now = DateTime(2026, 1, 1);
    final paths = <String?>[];
    Future<Uint8List?> fromPath(String? path) async {
      paths.add(path);
      return path == null ? null : Uint8List.fromList([9]);
    }

    setUp(paths.clear);

    test('prefers the profile photo bytes over the legacy path', () async {
      final bytes = Uint8List.fromList([1, 2]);
      final diver = Diver(
        id: 'd',
        name: 'D',
        photo: bytes,
        photoPath: '/legacy.jpg',
        createdAt: now,
        updatedAt: now,
      );

      expect(await diverPortrait(diver, fromPath), same(bytes));
      expect(paths, isEmpty, reason: 'the file is not read at all');
    });

    test('falls back to the legacy path without bytes', () async {
      final diver = Diver(
        id: 'd',
        name: 'D',
        photoPath: '/legacy.jpg',
        createdAt: now,
        updatedAt: now,
      );

      expect(await diverPortrait(diver, fromPath), [9]);
      expect(paths, ['/legacy.jpg']);
    });

    test('is null with no diver', () async {
      expect(await diverPortrait(null, fromPath), isNull);
    });
  });
}
