import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_desktop.dart';

/// Writes a 4x4 JPEG carrying [dateTimeOriginal] in its EXIF IFD.
File _jpegWithExifDate(Directory dir, String name, String dateTimeOriginal) {
  final image = img.Image(width: 4, height: 4);
  image.exif.exifIfd['DateTimeOriginal'] = dateTimeOriginal;
  return File('${dir.path}/$name')..writeAsBytesSync(img.encodeJpg(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getAssetMetadata returns null', () async {
    final metadata = await PhotoPickerServiceDesktop().getAssetMetadata(
      'asset-1',
    );

    expect(metadata, isNull);
  });

  group('assetInfoForFile', () {
    late Directory tempDir;
    late PhotoPickerServiceDesktop service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('desktop_picker_');
      service = PhotoPickerServiceDesktop();
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('carries the absolute path so the import can persist it', () {
      final file = _jpegWithExifDate(tempDir, 'a.jpg', '2025:07:14 17:22:31');

      final asset = service.assetInfoForFile(file);

      // Without this the row lands with blank path columns and display falls
      // to photo_manager, which has no Windows backend.
      expect(asset?.filePath, file.path);
    });

    test('dates the asset from EXIF capture time, not the file mtime', () {
      final file = _jpegWithExifDate(tempDir, 'a.jpg', '2025:07:14 17:22:31');
      // Copying a card to the PC months later leaves an mtime of the copy
      // time; reporting that is why in-window photos read as unmatched.
      file.setLastModifiedSync(DateTime(2025, 11, 2, 9, 15));

      final asset = service.assetInfoForFile(file);

      expect(asset?.createDateTime, DateTime(2025, 7, 14, 17, 22, 31));
    });

    test('reports capture time as local, matching the AssetInfo contract', () {
      final file = _jpegWithExifDate(tempDir, 'a.jpg', '2025:07:14 17:22:31');

      // Consumers (TripMediaScanner, MediaImportService) reinterpret these
      // components as wall-clock-UTC; a UTC-flagged value double-converts.
      expect(service.assetInfoForFile(file)?.createDateTime.isUtc, isFalse);
    });

    test('falls back to the file mtime when no capture time is embedded', () {
      final file = File('${tempDir.path}/nometa.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
      file.setLastModifiedSync(DateTime(2025, 11, 2, 9, 15));

      expect(
        service.assetInfoForFile(file)?.createDateTime,
        DateTime(2025, 11, 2, 9, 15),
      );
    });

    test('records real pixel dimensions for the resolution tiers', () {
      final file = _jpegWithExifDate(tempDir, 'a.jpg', '2025:07:14 17:22:31');

      final asset = service.assetInfoForFile(file);

      // matchByTimestampAndDimensions bails on a 0x0 row, so the hardcoded
      // zeroes silently disabled two of the three resolution tiers.
      expect(asset?.width, 4);
      expect(asset?.height, 4);
    });

    test('returns null for a file that does not exist', () {
      expect(
        service.assetInfoForFile(File('${tempDir.path}/gone.jpg')),
        isNull,
      );
    });

    test('classifies known video extensions as video assets', () {
      final file = File('${tempDir.path}/clip.mp4')..writeAsBytesSync([1, 2]);

      expect(service.assetInfoForFile(file)?.type, AssetType.video);
    });

    test('resolves the picked path back from the generated asset id', () async {
      final file = _jpegWithExifDate(tempDir, 'a.jpg', '2025:07:14 17:22:31');

      final asset = service.assetInfoForFile(file)!;

      expect(await service.getFilePath(asset.id), file.path);
    });
  });
}
