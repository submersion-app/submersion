import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/backup_bookmark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.submersion/backup_bookmark');
  final calls = <MethodCall>[];

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(() {
    calls.clear();
    BackupBookmarkService.debugSupportedOverride = true;
  });

  tearDown(() {
    BackupBookmarkService.debugSupportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('resolveBookmark returns a lease with ref, path, and isStale', () async {
    mock((call) async {
      if (call.method == 'resolveBookmark') {
        return {'ref': 'r1', 'path': '/x/Backups', 'isStale': true};
      }
      return null;
    });

    final lease = await BackupBookmarkService.resolveBookmark(Uint8List(4));

    expect(lease, isNotNull);
    expect(lease!.ref, 'r1');
    expect(lease.path, '/x/Backups');
    expect(lease.isStale, isTrue);
    expect(calls.single.method, 'resolveBookmark');
  });

  test('release invokes releaseBookmark with the ref', () async {
    mock((_) async => null);

    await BackupBookmarkService.release('r9');

    expect(calls.single.method, 'releaseBookmark');
    expect((calls.single.arguments as Map)['ref'], 'r9');
  });

  test('releaseAll invokes releaseAllBookmarks', () async {
    mock((_) async => null);

    await BackupBookmarkService.releaseAll();

    expect(calls.single.method, 'releaseAllBookmarks');
  });

  test('verifyWriteAccess returns the channel bool', () async {
    mock((call) async => call.method == 'verifyWriteAccess' ? true : null);

    expect(await BackupBookmarkService.verifyWriteAccess('/x'), isTrue);
  });

  test('createBookmark returns the bookmark bytes', () async {
    mock(
      (call) async => call.method == 'createBookmark'
          ? Uint8List.fromList([1, 2, 3])
          : null,
    );

    final bytes = await BackupBookmarkService.createBookmark('/x/Backups');

    expect(bytes, [1, 2, 3]);
    expect((calls.single.arguments as Map)['path'], '/x/Backups');
  });

  test('pickFolder returns path and bookmark', () async {
    mock(
      (call) async => call.method == 'pickFolderWithSecurityScope'
          ? {
              'path': '/x/Backups',
              'bookmarkData': Uint8List.fromList([9]),
            }
          : null,
    );

    final pick = await BackupBookmarkService.pickFolder();

    expect(pick, isNotNull);
    expect(pick!.path, '/x/Backups');
    expect(pick.bookmark, [9]);
  });

  test('makes no channel call and returns null when unsupported', () async {
    BackupBookmarkService.debugSupportedOverride = false;
    mock((_) async => null);

    expect(await BackupBookmarkService.resolveBookmark(Uint8List(1)), isNull);
    expect(await BackupBookmarkService.createBookmark('/x'), isNull);
    expect(await BackupBookmarkService.verifyWriteAccess('/x'), isFalse);
    expect(calls, isEmpty);
  });

  test('degrades to null/false when no native handler is registered', () async {
    // No mock() handler in this test -> the channel has no handler, so
    // invokeMethod throws MissingPluginException, which must be swallowed.
    expect(await BackupBookmarkService.createBookmark('/x'), isNull);
    expect(await BackupBookmarkService.resolveBookmark(Uint8List(1)), isNull);
    expect(await BackupBookmarkService.verifyWriteAccess('/x'), isFalse);
  });
}
