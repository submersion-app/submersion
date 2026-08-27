import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  // Issue #554: On macOS, getTemporaryDirectory() maps to the sandbox
  // Library/Caches dir, which macOS may purge and does not guarantee exists.
  // The base-export writer then opened a file for write in the missing dir and
  // crashed with "PathNotFoundException: Cannot open file ... No such file or
  // directory (errno = 2)". iPhone/iPad were unaffected because iOS reliably
  // has that directory. resolveSyncTempDir must return a directory that
  // actually exists, so writers can open temp files in it.
  group('resolveSyncTempDir ensures the temp dir exists (issue #554)', () {
    late Directory parent;
    late Directory missing;

    setUp(() async {
      parent = await Directory.systemTemp.createTemp('sync_temp_dir_test_');
      // A path that path_provider hands back but has NOT created yet -- the
      // macOS Library/Caches situation.
      missing = Directory('${parent.path}/Library/Caches/app.submersion');
      expect(
        missing.existsSync(),
        isFalse,
        reason: 'precondition: the resolved dir does not exist yet',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'getTemporaryDirectory' ? missing.path : null,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (parent.existsSync()) await parent.delete(recursive: true);
    });

    test('returns the resolved path as a directory that exists', () async {
      final dir = await resolveSyncTempDir();
      expect(dir.path, missing.path);
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'macOS Caches dir may be absent; it must be created',
      );
    });

    test(
      'a base temp file can be opened for write in the returned dir',
      () async {
        // The exact operation that threw in production
        // (sync_data_serializer.dart:734, FileMode.write in a missing dir).
        final dir = await resolveSyncTempDir();
        final file = File('${dir.path}/ssv1_base_probe.json');
        final raf = await file.open(mode: FileMode.write);
        await raf.writeString('{}');
        await raf.close();
        expect(file.existsSync(), isTrue);
      },
    );
  });
}
