// Coverage for the Platform-guarded early-return / throw paths in
// `LocalMediaPlatform`. These are the host-platform branches that hit on
// Linux CI (where Platform.isMacOS / Platform.isIOS / Platform.isAndroid
// are all false) — without these tests they show as uncovered.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // These tests only run on hosts that are NOT iOS / macOS / Android (i.e.
  // Linux CI / Windows). On macOS/iOS hosts the methods would actually
  // dispatch to the channel, which is exercised in the host-specific tests.
  final isUnsupportedHost =
      !Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid;

  test('createBookmark throws UnsupportedError on non-iOS/macOS hosts', () {
    if (!isUnsupportedHost) return;
    final p = LocalMediaPlatform();
    expect(
      () => p.createBookmark('/tmp/x.jpg'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('resolveBookmark throws UnsupportedError on non-iOS/macOS hosts', () {
    if (!isUnsupportedHost) return;
    final p = LocalMediaPlatform();
    expect(
      () => p.resolveBookmark(Uint8List.fromList([1])),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('releaseBookmark is a no-op on non-iOS/macOS hosts', () async {
    if (!isUnsupportedHost) return;
    final p = LocalMediaPlatform();
    await expectLater(p.releaseBookmark('ref'), completes);
  });

  test('releaseAllBookmarks is a no-op on non-iOS/macOS hosts', () async {
    if (!isUnsupportedHost) return;
    final p = LocalMediaPlatform();
    await expectLater(p.releaseAllBookmarks(), completes);
  });

  test('takePersistableUri throws UnsupportedError on non-Android hosts', () {
    if (Platform.isAndroid) return;
    final p = LocalMediaPlatform();
    expect(
      () => p.takePersistableUri('content://x/1'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('releasePersistableUri is a no-op on non-Android hosts', () async {
    if (Platform.isAndroid) return;
    final p = LocalMediaPlatform();
    await expectLater(p.releasePersistableUri('content://x/1'), completes);
  });

  test('listPersistedUris returns empty list on non-Android hosts', () async {
    if (Platform.isAndroid) return;
    final p = LocalMediaPlatform();
    expect(await p.listPersistedUris(), isEmpty);
  });
}
