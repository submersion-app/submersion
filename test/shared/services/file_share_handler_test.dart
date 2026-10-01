import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/shared/services/file_share_handler.dart';
import 'package:submersion/shared/services/shared_file_unreadable_exception.dart';

void main() {
  group('FileShareHandler', () {
    testWidgets(
      'initialize is no-op on non-mobile platforms',
      variant: const TargetPlatformVariant({TargetPlatform.macOS}),
      (tester) async {
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {},
        );
        handler.initialize();
        handler.dispose();
      },
    );

    testWidgets(
      'dispose without initialize does not throw',
      variant: const TargetPlatformVariant({TargetPlatform.macOS}),
      (tester) async {
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {},
        );
        expect(() => handler.dispose(), returnsNormally);
      },
    );

    test(
      'initialize sets up stream subscription and processes initial media on mobile',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final streamController =
            StreamController<List<SharedMediaFile>>.broadcast();
        final tempDir = await Directory.systemTemp.createTemp('share_init_');
        final tempFile = File('${tempDir.path}/dive.uddf');
        await tempFile.writeAsString('<uddf/>');

        try {
          ReceiveSharingIntent.setMockValues(
            initialMedia: [
              SharedMediaFile(path: tempFile.path, type: SharedMediaType.file),
            ],
            mediaStream: streamController.stream,
          );

          final received = <String>[];
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {
              received.add(name);
            },
          );

          handler.initialize();
          // Let the async chain (getInitialMedia -> handleMediaFiles) resolve.
          await Future<void>.delayed(const Duration(milliseconds: 500));

          expect(received, contains('dive.uddf'));

          handler.dispose();
          await streamController.close();
        } finally {
          debugDefaultTargetPlatformOverride = null;
          await tempDir.delete(recursive: true);
        }
      },
    );

    group('handleMediaFiles', () {
      test('returns early for empty file list', () async {
        var callbackCalled = false;
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            callbackCalled = true;
          },
        );

        await handler.handleMediaFiles([]);

        expect(callbackCalled, isFalse);
      });

      test(
        'reports a shared file it cannot read and imports nothing',
        () async {
          var callbackCalled = false;
          Object? error;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {
              callbackCalled = true;
            },
            onError: (e) => error = e,
          );
          final missing = p.join(
            Directory.systemTemp.path,
            'submersion_share_missing',
            'route.csv',
          );

          await handler.handleMediaFiles([
            SharedMediaFile(path: missing, type: SharedMediaType.file),
          ]);

          // A file left in the sending app's private storage used to vanish
          // without a message or a log line (#2689).
          expect(callbackCalled, isFalse);
          expect(
            error,
            isA<SharedFileUnreadableException>()
                .having((e) => e.unreadablePaths, 'unreadablePaths', [missing])
                .having((e) => e.sharedCount, 'sharedCount', 1)
                .having((e) => e.nothingReadable, 'nothingReadable', isTrue),
          );
        },
      );

      test('ignores a text or link share, which carries no file', () async {
        var received = false;
        Object? error;
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async => received = true,
          onFilesReceived: (paths) async => received = true,
          onError: (e) => error = e,
        );

        // With no file attached, the plugin puts the shared text itself in
        // `path`. It is not a file that failed to read, and the text may be
        // private, so it must not reach the snackbar or the log.
        await handler.handleMediaFiles([
          SharedMediaFile(
            path: 'https://example.com/dive-report',
            type: SharedMediaType.url,
          ),
          SharedMediaFile(path: 'meet at the dock', type: SharedMediaType.text),
        ]);

        expect(received, isFalse);
        expect(error, isNull);
      });

      test('logs a skipped text share by type, never by content', () async {
        final captured = <LogEntry>[];
        final sub = LoggerService.logStream.listen(captured.add);
        addTearDown(sub.cancel);
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {},
        );

        await handler.handleMediaFiles([
          SharedMediaFile(
            path: 'meet at the dock',
            type: SharedMediaType.text,
            mimeType: 'text/plain',
          ),
        ]);
        await pumpEventQueue();

        // A file whose URI the plugin could not resolve also arrives as text,
        // so the skip leaves a trace, without the possibly private text.
        final lines = captured.map((e) => e.message).toList();
        expect(lines.where((m) => m.contains('text/plain')), isNotEmpty);
        expect(lines.where((m) => m.contains('meet at the dock')), isEmpty);
      });

      test('counts only the files of a share that also carries text', () async {
        Object? error;
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {},
          onError: (e) => error = e,
        );
        final missing = p.join(
          Directory.systemTemp.path,
          'submersion_share_missing',
          'route.csv',
        );

        await handler.handleMediaFiles([
          SharedMediaFile(path: 'route export', type: SharedMediaType.text),
          SharedMediaFile(path: missing, type: SharedMediaType.file),
        ]);

        expect(
          error,
          isA<SharedFileUnreadableException>()
              .having((e) => e.unreadablePaths, 'unreadablePaths', [missing])
              .having((e) => e.sharedCount, 'sharedCount', 1)
              .having((e) => e.nothingReadable, 'nothingReadable', isTrue),
        );
      });

      test(
        'does not throw for an unreadable file when onError is null',
        () async {
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {},
          );
          final missing = p.join(
            Directory.systemTemp.path,
            'submersion_share_missing',
            'route.csv',
          );

          await expectLater(
            handler.handleMediaFiles([
              SharedMediaFile(path: missing, type: SharedMediaType.file),
            ]),
            completes,
          );
        },
      );

      test(
        'calls onFileReceived with bytes and filename for valid file',
        () async {
          Uint8List? receivedBytes;
          String? receivedName;

          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {
              receivedBytes = bytes;
              receivedName = name;
            },
          );

          final tempDir = await Directory.systemTemp.createTemp('test_share_');
          final tempFile = File('${tempDir.path}/test_dive.uddf');
          await tempFile.writeAsString('<?xml version="1.0"?><uddf/>');

          try {
            final sharedFile = SharedMediaFile(
              path: tempFile.path,
              type: SharedMediaType.file,
            );

            await handler.handleMediaFiles([sharedFile]);

            expect(receivedBytes, isNotNull);
            expect(receivedName, 'test_dive.uddf');
            expect(receivedBytes, hasLength(greaterThan(0)));
          } finally {
            await tempDir.delete(recursive: true);
          }
        },
      );

      test('uses only first file when multiple are shared', () async {
        final receivedNames = <String>[];

        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            receivedNames.add(name);
          },
        );

        final tempDir = await Directory.systemTemp.createTemp('test_share_');
        final file1 = File('${tempDir.path}/first.uddf');
        final file2 = File('${tempDir.path}/second.uddf');
        await file1.writeAsString('data1');
        await file2.writeAsString('data2');

        try {
          await handler.handleMediaFiles([
            SharedMediaFile(path: file1.path, type: SharedMediaType.file),
            SharedMediaFile(path: file2.path, type: SharedMediaType.file),
          ]);

          expect(receivedNames, hasLength(1));
          expect(receivedNames.first, 'first.uddf');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      group('with a multi-file callback', () {
        late Directory tempDir;

        setUp(() async {
          tempDir = await Directory.systemTemp.createTemp('test_share_');
        });

        tearDown(() async {
          await tempDir.delete(recursive: true);
        });

        Future<String> writeFile(String name) async {
          final path = p.join(tempDir.path, name);
          await File(path).writeAsString('data');
          return path;
        }

        SharedMediaFile shared(String path) =>
            SharedMediaFile(path: path, type: SharedMediaType.file);

        test('hands every shared file over when several are shared', () async {
          final single = <String>[];
          List<String>? multi;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async => single.add(name),
            onFilesReceived: (paths) async => multi = paths,
          );
          final first = await writeFile('100 Reef Single-Gas Dive.fit');
          final second = await writeFile('101 Wall Single-Gas Dive.fit');

          await handler.handleMediaFiles([shared(first), shared(second)]);

          // Several dives exported from Garmin Connect at once used to lose
          // all but the first (#1635).
          expect(multi, [first, second]);
          expect(single, isEmpty);
        });

        test('imports the readable files and reports the ones it cannot '
            'read', () async {
          List<String>? multi;
          Object? error;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {},
            onFilesReceived: (paths) async => multi = paths,
            onError: (e) => error = e,
          );
          final first = await writeFile('a.fit');
          final missing = p.join(tempDir.path, 'missing.fit');
          final third = await writeFile('c.fit');

          await handler.handleMediaFiles([
            shared(first),
            shared(missing),
            shared(third),
          ]);

          expect(multi, [first, third]);
          expect(
            error,
            isA<SharedFileUnreadableException>()
                .having((e) => e.unreadablePaths, 'unreadablePaths', [missing])
                .having((e) => e.sharedCount, 'sharedCount', 3)
                .having((e) => e.nothingReadable, 'nothingReadable', isFalse),
          );
        });

        test('uses the single-file path when only one shared file is '
            'readable, and reports the other', () async {
          final single = <String>[];
          var multiCalled = false;
          Object? error;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async => single.add(name),
            onFilesReceived: (paths) async => multiCalled = true,
            onError: (e) => error = e,
          );
          final missing = p.join(tempDir.path, 'missing.fit');
          final second = await writeFile('b.fit');

          await handler.handleMediaFiles([shared(missing), shared(second)]);

          expect(single, ['b.fit']);
          expect(multiCalled, isFalse);
          expect(
            error,
            isA<SharedFileUnreadableException>()
                .having((e) => e.unreadablePaths, 'unreadablePaths', [missing])
                .having((e) => e.sharedCount, 'sharedCount', 2),
          );
        });

        test('reports every file when none of several can be read', () async {
          var received = false;
          Object? error;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async => received = true,
            onFilesReceived: (paths) async => received = true,
            onError: (e) => error = e,
          );
          final a = p.join(tempDir.path, 'a.csv');
          final b = p.join(tempDir.path, 'b.csv');

          await handler.handleMediaFiles([shared(a), shared(b)]);

          expect(received, isFalse);
          expect(
            error,
            isA<SharedFileUnreadableException>()
                .having((e) => e.unreadablePaths, 'unreadablePaths', [a, b])
                .having((e) => e.nothingReadable, 'nothingReadable', isTrue),
          );
        });

        test('reports a failing multi-file callback through onError', () async {
          Object? error;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async {},
            onFilesReceived: (paths) async => throw Exception('boom'),
            onError: (e) => error = e,
          );

          await handler.handleMediaFiles([
            shared(await writeFile('a.fit')),
            shared(await writeFile('b.fit')),
          ]);

          expect(error, isA<Exception>());
        });
      });

      test(
        'reports an entry that is not a shared file and imports nothing',
        () async {
          Object? error;
          var received = false;
          final handler = FileShareHandler(
            onFileReceived: (bytes, name) async => received = true,
            onFilesReceived: (paths) async => received = true,
            onError: (e) => error = e,
          );

          await handler.handleMediaFiles(['not a SharedMediaFile']);

          expect(error, isA<TypeError>());
          expect(received, isFalse);
        },
      );

      test('calls onError when callback throws', () async {
        Object? receivedError;
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            throw Exception('Callback failed');
          },
          onError: (e) => receivedError = e,
        );

        final tempDir = await Directory.systemTemp.createTemp('test_share_');
        final tempFile = File('${tempDir.path}/test.uddf');
        await tempFile.writeAsString('data');

        try {
          await handler.handleMediaFiles([
            SharedMediaFile(path: tempFile.path, type: SharedMediaType.file),
          ]);

          expect(receivedError, isA<Exception>());
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('does not throw when onError is null and callback fails', () async {
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            throw Exception('Callback failed');
          },
        );

        final tempDir = await Directory.systemTemp.createTemp('test_share_');
        final tempFile = File('${tempDir.path}/test.uddf');
        await tempFile.writeAsString('data');

        try {
          // Should not throw even without an onError handler.
          await handler.handleMediaFiles([
            SharedMediaFile(path: tempFile.path, type: SharedMediaType.file),
          ]);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('reads correct bytes from file', () async {
        Uint8List? receivedBytes;
        const expectedContent = '<?xml version="1.0"?><uddf/>';

        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            receivedBytes = bytes;
          },
        );

        final tempDir = await Directory.systemTemp.createTemp('test_share_');
        final tempFile = File('${tempDir.path}/dive.uddf');
        await tempFile.writeAsString(expectedContent);

        try {
          await handler.handleMediaFiles([
            SharedMediaFile(path: tempFile.path, type: SharedMediaType.file),
          ]);

          expect(String.fromCharCodes(receivedBytes!), expectedContent);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
  });
}
