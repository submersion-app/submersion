import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Counts platform lookups so the memoization can be asserted rather than
/// asserted-in-a-comment, and can be made to fail on demand.
class _CountingPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CountingPathProvider(this.supportPath);

  final String supportPath;
  int calls = 0;
  bool shouldThrow = false;

  @override
  Future<String?> getApplicationSupportPath() async {
    calls++;
    if (shouldThrow) throw const FileSystemException('support dir unavailable');
    return supportPath;
  }
}

void main() {
  late Directory support;
  late _CountingPathProvider platform;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('media_cache_root_test');
    platform = _CountingPathProvider(support.path);
    PathProviderPlatform.instance = platform;
    resetMediaCacheRootForTesting();
  });

  tearDown(() async {
    resetMediaCacheRootForTesting();
    if (support.existsSync()) await support.delete(recursive: true);
  });

  test('resolves the media cache root under the support directory', () async {
    final root = await mediaCacheRoot();

    expect(root.path, p.join(support.path, 'Submersion', 'media_cache'));
  });

  test('resolves the platform lookup once across many callers', () async {
    // Five call sites share this: the media store runtime, the eviction pass,
    // and the three media cache rows on the storage usage page. Each one used
    // to pay its own platform channel round trip for the same immutable path.
    await mediaCacheRoot();
    await mediaCacheRoot();
    await Future.wait([mediaCacheRoot(), mediaCacheRoot(), mediaCacheRoot()]);

    expect(platform.calls, 1);
  });

  test('a failed lookup is not cached, so the next caller retries', () async {
    // The failure mode this guards: caching a rejected future would turn one
    // bad moment at boot into a permanent failure for the whole process.
    platform.shouldThrow = true;
    await expectLater(mediaCacheRoot(), throwsA(isA<FileSystemException>()));

    platform.shouldThrow = false;
    final root = await mediaCacheRoot();

    expect(root.path, p.join(support.path, 'Submersion', 'media_cache'));
    expect(platform.calls, 2, reason: 'the retry must reach the platform');
  });

  test('the testing reset clears the memo', () async {
    await mediaCacheRoot();
    expect(platform.calls, 1);

    resetMediaCacheRootForTesting();
    await mediaCacheRoot();

    expect(platform.calls, 2);
  });
}
