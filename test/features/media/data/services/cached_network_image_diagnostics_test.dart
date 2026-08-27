import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cnid_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'cacheSize sums all files recursively under the cache directory',
    () async {
      File('${tempDir.path}/a.bin').writeAsBytesSync(List.filled(100, 0));
      final sub = Directory('${tempDir.path}/sub')..createSync();
      File('${sub.path}/b.bin').writeAsBytesSync(List.filled(50, 0));
      File('${sub.path}/c.bin').writeAsBytesSync(List.filled(25, 0));

      final diag = CachedNetworkImageDiagnostics(
        resolveCacheDirectory: () async => tempDir,
        clearCacheCallback: () async {},
      );
      final size = await diag.cacheSize();
      expect(size, 175);
    },
  );

  test('cacheSize returns 0 when the directory does not exist', () async {
    final missing = Directory('${tempDir.path}/missing');
    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => missing,
      clearCacheCallback: () async {},
    );
    final size = await diag.cacheSize();
    expect(size, 0);
  });

  test('clearCache invokes the supplied callback', () async {
    var called = false;
    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => tempDir,
      clearCacheCallback: () async {
        called = true;
      },
    );
    await diag.clearCache();
    expect(called, true);
  });

  test(
    'cacheSize swallows IO errors and returns 0 (best-effort metric)',
    () async {
      final diag = CachedNetworkImageDiagnostics(
        resolveCacheDirectory: () async =>
            throw const FileSystemException('boom'),
        clearCacheCallback: () async {},
      );
      final size = await diag.cacheSize();
      expect(size, 0);
    },
  );
}
