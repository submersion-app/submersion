import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

/// The iCloud half of the bookmark channel (issue #2177).
///
/// These pin the method names and arguments the Swift handlers on iOS and
/// macOS answer to. No CI shard runs that Swift, so this is the only place a
/// renamed method or argument would be caught before a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.submersion/security_scoped_bookmark');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  /// What the fake native side answers. Throwing is allowed: a
  /// [PlatformException] reaches Dart as one, and a [MissingPluginException]
  /// reads as a native build that lacks the method.
  late FutureOr<Object?> Function(MethodCall call) reply;

  setUp(() {
    calls = <MethodCall>[];
    reply = (_) => null;
    SecurityScopedBookmarkService.debugSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SecurityScopedBookmarkService.debugSupportedOverride = null;
    });
  });

  group('iCloudDownloadStatus', () {
    test('asks the native side about exactly the path it was given', () async {
      reply = (_) => 'notDownloaded';

      final status = await SecurityScopedBookmarkService.iCloudDownloadStatus(
        '/folder/submersion.db',
      );

      expect(status, ICloudItemStatus.notDownloaded);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'iCloudDownloadStatus');
      expect(calls.single.arguments, {'path': '/folder/submersion.db'});
    });

    test('maps every answer the native side gives', () async {
      const expected = {
        'notUbiquitous': ICloudItemStatus.notInICloud,
        'downloaded': ICloudItemStatus.downloaded,
        'notDownloaded': ICloudItemStatus.notDownloaded,
      };
      for (final entry in expected.entries) {
        reply = (_) => entry.key;
        expect(
          await SecurityScopedBookmarkService.iCloudDownloadStatus('/x.db'),
          entry.value,
          reason: 'native answer "${entry.key}"',
        );
      }
    });

    test('no answer, or one it does not know, reads as unknown', () async {
      for (final answer in <Object?>[null, 'somethingNew']) {
        reply = (_) => answer;
        expect(
          await SecurityScopedBookmarkService.iCloudDownloadStatus('/x.db'),
          isNull,
          reason: 'native answer $answer',
        );
      }
    });

    test(
      'a native error reads as unknown, never as "not downloaded"',
      () async {
        reply = (_) => throw PlatformException(code: 'boom');
        expect(
          await SecurityScopedBookmarkService.iCloudDownloadStatus('/x.db'),
          isNull,
        );
      },
    );

    test('a native build without the method reads as unknown', () async {
      reply = (_) => throw MissingPluginException();
      expect(
        await SecurityScopedBookmarkService.iCloudDownloadStatus('/x.db'),
        isNull,
      );
    });

    test('off Apple platforms the native side is never asked', () async {
      SecurityScopedBookmarkService.debugSupportedOverride = false;
      expect(
        await SecurityScopedBookmarkService.iCloudDownloadStatus('/x.db'),
        isNull,
      );
      expect(calls, isEmpty);
    });
  });

  group('downloadICloudItem', () {
    test('passes the path and the timeout in whole seconds', () async {
      reply = (_) => true;

      final downloaded = await SecurityScopedBookmarkService.downloadICloudItem(
        '/folder/submersion.db',
        timeout: const Duration(seconds: 60),
      );

      expect(downloaded, isTrue);
      expect(calls.single.method, 'downloadICloudItem');
      expect(calls.single.arguments, {
        'path': '/folder/submersion.db',
        'timeoutSeconds': 60,
      });
    });

    test('anything but a plain yes reads as not downloaded', () async {
      final replies = <FutureOr<Object?> Function(MethodCall)>[
        (_) => false,
        (_) => null,
        (_) => throw PlatformException(code: 'offline'),
        (_) => throw MissingPluginException(),
      ];
      for (final (index, candidate) in replies.indexed) {
        reply = candidate;
        expect(
          await SecurityScopedBookmarkService.downloadICloudItem(
            '/x.db',
            timeout: const Duration(seconds: 1),
          ),
          isFalse,
          reason: 'reply #$index',
        );
      }
    });

    test('off Apple platforms it reports no download without asking', () async {
      SecurityScopedBookmarkService.debugSupportedOverride = false;
      expect(
        await SecurityScopedBookmarkService.downloadICloudItem(
          '/x.db',
          timeout: const Duration(seconds: 1),
        ),
        isFalse,
      );
      expect(calls, isEmpty);
    });

    test('a native side that never answers is given up on, so startup cannot '
        'wait forever on the download splash', () {
      fakeAsync((async) {
        reply = (_) => Completer<Object?>().future;
        bool? downloaded;
        SecurityScopedBookmarkService.downloadICloudItem(
          '/x.db',
          timeout: const Duration(seconds: 1),
        ).then((value) => downloaded = value);

        async.flushMicrotasks();
        expect(downloaded, isNull, reason: 'still inside the native timeout');

        async.elapse(const Duration(minutes: 1));
        expect(downloaded, isFalse);
      });
    });
  });
}
