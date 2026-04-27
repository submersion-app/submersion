import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exif_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns metadata with mtime fallback when file has no EXIF', () async {
    final f = File('${tempDir.path}/no_exif.bin')
      ..writeAsBytesSync([0, 1, 2, 3]);
    final extractor = ExifExtractor();
    final meta = await extractor.extract(f);
    expect(meta, isNotNull);
    expect(meta!.takenAt, isNotNull); // file mtime fallback
    expect(
      meta.takenAt!.difference(DateTime.now()).abs(),
      lessThan(const Duration(minutes: 5)),
    );
    expect(meta.mimeType, isNotEmpty);
  });

  test('returns null on missing file', () async {
    final extractor = ExifExtractor();
    final meta = await extractor.extract(File('${tempDir.path}/missing'));
    expect(meta, isNull);
  });

  test('mimeType reflects file extension', () async {
    final extractor = ExifExtractor();
    final jpg = File('${tempDir.path}/x.jpg')..writeAsBytesSync([0]);
    final png = File('${tempDir.path}/x.png')..writeAsBytesSync([0]);
    final mp4 = File('${tempDir.path}/x.mp4')..writeAsBytesSync([0]);
    final mov = File('${tempDir.path}/x.mov')..writeAsBytesSync([0]);
    expect((await extractor.extract(jpg))!.mimeType, 'image/jpeg');
    expect((await extractor.extract(png))!.mimeType, 'image/png');
    expect((await extractor.extract(mp4))!.mimeType, 'video/mp4');
    expect((await extractor.extract(mov))!.mimeType, 'video/quicktime');
  });
}
