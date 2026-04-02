import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:submersion/shared/services/file_share_handler.dart';

void main() {
  group('FileShareHandler', () {
    test('initialize is no-op on non-mobile platforms', () {
      final handler = FileShareHandler(onFileReceived: (bytes, name) async {});
      // On macOS (test environment), this should return early.
      handler.initialize();
      handler.dispose();
    });

    test('dispose without initialize does not throw', () {
      final handler = FileShareHandler(onFileReceived: (bytes, name) async {});
      expect(() => handler.dispose(), returnsNormally);
    });

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

      test('returns early when file does not exist', () async {
        var callbackCalled = false;
        final handler = FileShareHandler(
          onFileReceived: (bytes, name) async {
            callbackCalled = true;
          },
        );

        final sharedFile = SharedMediaFile(
          path: '/nonexistent/path/file.uddf',
          type: SharedMediaType.file,
        );

        await handler.handleMediaFiles([sharedFile]);

        expect(callbackCalled, isFalse);
      });

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
