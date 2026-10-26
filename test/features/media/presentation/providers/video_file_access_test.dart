import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

class _Storage implements LocalBookmarkStorage {
  _Storage(this.blob);
  final Uint8List? blob;

  @override
  Future<Uint8List?> read(String bookmarkRef) async => blob;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Platform implements LocalMediaPlatform {
  _Platform({this.fails = false});
  final bool fails;
  final List<String> released = [];

  @override
  Future<ResolvedBookmark> resolveBookmark(Uint8List blob) async {
    if (fails) throw StateError('stale bookmark');
    return const ResolvedBookmark(
      bookmarkRef: 'lease-1',
      filePath: '/scoped/dive.mp4',
      stale: false,
    );
  }

  @override
  Future<void> releaseBookmark(String bookmarkRef) async =>
      released.add(bookmarkRef);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #3520: a bookmarked video's frames are read with the bookmark's
/// security-scoped access held only for the read.
void main() {
  VideoFileAccess access(_Platform platform, {Uint8List? blob}) {
    final c = ProviderContainer(
      overrides: [
        localBookmarkStorageProvider.overrideWithValue(
          _Storage(blob ?? Uint8List.fromList([1, 2, 3])),
        ),
        localMediaPlatformProvider.overrideWithValue(platform),
        // Bookmarks are an iOS and macOS matter; the suite runs anywhere.
        videoBookmarksApplyProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    return c.read(videoFileAccessProvider);
  }

  final read = <String>[];
  Future<List<Uint8List?>> reader(String path) async {
    read.add(path);
    return [Uint8List(1)];
  }

  setUp(read.clear);

  test('opens through the bookmark and releases it after the read', () async {
    final platform = _Platform();
    await access(platform)(
      path: '/plain/dive.mp4',
      bookmarkRef: 'bm-1',
      read: reader,
    );
    expect(read, ['/scoped/dive.mp4']);
    expect(platform.released, ['lease-1']);
  });

  test('a read that throws still releases the bookmark', () async {
    final platform = _Platform();
    await expectLater(
      access(platform)(
        path: null,
        bookmarkRef: 'bm-1',
        read: (_) async => throw StateError('decoder'),
      ),
      throwsStateError,
    );
    expect(platform.released, ['lease-1']);
  });

  test('an unreadable bookmark falls back to the plain path', () async {
    final platform = _Platform(fails: true);
    await access(platform)(
      path: '/plain/dive.mp4',
      bookmarkRef: 'bm-1',
      read: reader,
    );
    expect(read, ['/plain/dive.mp4']);
    expect(platform.released, isEmpty);
  });

  test('access returns a non-list result through the bookmark', () async {
    final platform = _Platform();
    final opened = await access(platform)<String>(
      path: null,
      bookmarkRef: 'bm-1',
      read: (path) async => 'opened:$path',
    );
    expect(opened, 'opened:/scoped/dive.mp4');
    expect(platform.released, ['lease-1']);
  });

  test('no bookmark reads the path; neither is nothing to read', () async {
    final platform = _Platform();
    await access(platform)(path: '/plain/dive.mp4', read: reader);
    expect(read, ['/plain/dive.mp4']);
    expect(await access(platform)(read: reader), isNull);
  });
}
