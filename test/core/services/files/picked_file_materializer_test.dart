// file_picker 12 hands back handles whose `path` is null unless the Uri
// scheme is `file`, so an Android SAF pick has no local path. Every ingest
// path in this app is path-based; this is the seam that keeps those picks
// working instead of being silently dropped.

import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/files/picked_file_materializer.dart';

import '../../../helpers/mock_file_picker_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picked_materializer_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? tmp.path : null,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> writeSource(String name, String contents) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsString(contents);
    return f;
  }

  test('returns an empty list without touching the temp directory', () async {
    expect(await materializePickedFiles(const []), isEmpty);
    expect(
      Directory('${tmp.path}/picked').existsSync(),
      isFalse,
      reason: 'nothing to copy means no scratch directory should be created',
    );
  });

  test('passes a local-path pick straight through', () async {
    final source = await writeSource('local.uddf', '<uddf/>');

    final result = await materializePickedFiles([
      FakePlatformFile(source.path),
    ]);

    expect(result.single.path, source.path);
    expect(result.single.name, 'local.uddf');
    expect(
      result.single.uri.isScheme('file'),
      isTrue,
      reason: 'the original handle travels alongside the path',
    );
  });

  test('copies a content-URI pick to disk with its bytes intact', () async {
    final bytes = Uint8List.fromList('dive data'.codeUnits);

    final result = await materializePickedFiles([
      FakePlatformFile.contentUri(
        Uri.parse('content://com.android.providers/document/42'),
        name: 'from_saf.uddf',
        bytes: bytes,
      ),
    ]);

    final materialized = File(result.single.path);
    expect(materialized.existsSync(), isTrue);
    expect(await materialized.readAsBytes(), bytes);
    expect(result.single.name, 'from_saf.uddf');
    expect(
      result.single.uri.scheme,
      'content',
      reason:
          'the SAF Uri must survive: it is the persistable-permission '
          'identifier the document import needs (#1002)',
    );
  });

  test('keeps same-named content picks apart', () async {
    // Two SAF picks from different folders can share a display name; the
    // second must not overwrite the first.
    final result = await materializePickedFiles([
      FakePlatformFile.contentUri(
        Uri.parse('content://x/1'),
        name: 'log.csv',
        bytes: Uint8List.fromList('first'.codeUnits),
      ),
      FakePlatformFile.contentUri(
        Uri.parse('content://x/2'),
        name: 'log.csv',
        bytes: Uint8List.fromList('second'.codeUnits),
      ),
    ]);

    expect(result, hasLength(2));
    expect(result[0].path, isNot(result[1].path));
    expect(await File(result[0].path).readAsString(), 'first');
    expect(await File(result[1].path).readAsString(), 'second');
  });

  test('preserves order across a mixed selection', () async {
    final local = await writeSource('a.uddf', 'a');

    final result = await materializePickedFiles([
      FakePlatformFile(local.path),
      FakePlatformFile.contentUri(
        Uri.parse('content://x/9'),
        name: 'b.uddf',
        bytes: Uint8List.fromList('b'.codeUnits),
      ),
    ]);

    expect(result.map((f) => f.name), ['a.uddf', 'b.uddf']);
  });

  test('throws a named exception when a handle cannot be read', () async {
    expect(
      () => materializePickedFiles([_UnreadableFile()]),
      throwsA(
        isA<PickedFileMaterializationException>()
            .having((e) => e.fileName, 'fileName', 'broken.uddf')
            .having((e) => e.toString(), 'toString', contains('broken.uddf')),
      ),
      reason: 'callers surface a real error rather than an empty selection',
    );
  });
}

/// A handle whose stream fails, the shape of a revoked SAF permission.
final class _UnreadableFile extends PlatformFile {
  @override
  String get name => 'broken.uddf';

  @override
  Uri get uri => Uri.parse('content://revoked/1');

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  Future<int> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async =>
      throw const FileSystemException('permission revoked');

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.error(const FileSystemException('permission revoked'));
}
