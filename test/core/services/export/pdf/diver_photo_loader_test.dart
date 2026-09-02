import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';

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
}
