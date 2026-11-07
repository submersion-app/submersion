import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/zlib/platform_zlib_pure.dart';
import 'package:submersion/core/services/sync/changeset_log/gzip_temp_sink.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_files.dart';

/// A sink that gzips as it writes, so a streamed base is never staged on disk
/// both plain and compressed (issue #4256).
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gzip_temp_sink');
    SyncTempFiles.directory = () async => dir;
  });

  tearDown(() {
    SyncTempFiles.directory = resolveSyncTempDir;
    dir.deleteSync(recursive: true);
  });

  Future<GzipTempSink> create(String name) async =>
      GzipTempSink(await SyncTempFiles.create(name));

  test('a head patched after the body streamed gunzips in place', () async {
    final sink = await create('base.json.gz');
    await sink.add(utf8.encode('{"checksum":"'));
    final offset = sink.length;
    await sink.add(utf8.encode('0000'));
    await sink.endHead();
    await sink.add(utf8.encode('","data":['));
    for (var i = 0; i < 2000; i++) {
      await sink.add(utf8.encode('${i > 0 ? ',' : ''}{"row":$i}'));
    }
    await sink.add(utf8.encode(']}'));
    await sink.writeAt(offset, utf8.encode('beef'));
    final uncompressed = sink.length;
    final path = await sink.close();

    final text = utf8.decode(gzip.decode(await File(path).readAsBytes()));
    expect(text.length, uncompressed);
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    expect(decoded['checksum'], 'beef');
    expect((decoded['data'] as List).length, 2000);
  });

  test('it streams through gzip.decoder as one document', () async {
    final sink = await create('stream.json.gz');
    await sink.add(utf8.encode('{"a":'));
    await sink.endHead();
    await sink.add(utf8.encode('1}'));
    final path = await sink.close();

    final bytes = await File(
      path,
    ).openRead().transform(gzip.decoder).expand((c) => c).toList();
    expect(utf8.decode(bytes), '{"a":1}');
  });

  test('the file holds compressed bytes only', () async {
    final sink = await create('small.json.gz');
    await sink.add(utf8.encode('{"pad":"'));
    await sink.endHead();
    await sink.add(utf8.encode('${'x' * 100000}"}'));
    final path = await sink.close();

    expect(await File(path).length(), lessThan(2000));
    expect(sink.diskLength, await File(path).length());
  });

  test('random bodies round trip, whatever the head length', () async {
    final random = Random(4256);
    // 70000 spans two stored blocks; 0 is one empty block.
    for (final headLength in [0, 1, 64, 300, 70000]) {
      for (final bodyLength in [0, 1, 50000]) {
        final head = List<int>.generate(headLength, (_) => random.nextInt(256));
        final body = List<int>.generate(bodyLength, (_) => random.nextInt(256));
        final sink = await create('random$headLength-$bodyLength.gz');
        await sink.add(head);
        await sink.endHead();
        await sink.add(body);
        final path = await sink.close();
        final bytes = await File(path).readAsBytes();
        final reason = 'head $headLength, body $bodyLength';

        expect(gzip.decode(bytes), [...head, ...body], reason: reason);
        // A second, independent decoder, strict about the framing.
        expect(pureGunzip(bytes), [...head, ...body], reason: reason);
      }
    }
  });

  test(
    'it is one gzip member, whose trailer covers the whole document',
    () async {
      final sink = await create('member.gz');
      await sink.add(utf8.encode('{"checksum":"0000'));
      await sink.endHead();
      await sink.add(utf8.encode('","data":[${'1,' * 5000}1]}'));
      await sink.writeAt(13, utf8.encode('beef'));
      final path = await sink.close();
      final bytes = await File(path).readAsBytes();
      final document = gzip.decode(bytes);
      final trailer = ByteData.sublistView(bytes, bytes.length - 8);

      expect(bytes.sublist(0, 3), [0x1f, 0x8b, 0x08]);
      expect(trailer.getUint32(0, Endian.little), getCrc32(document));
      expect(trailer.getUint32(4, Endian.little), document.length);
      expect(utf8.decode(document), startsWith('{"checksum":"beef"'));
    },
  );

  test('a sink closed without ending its head keeps it all', () async {
    final sink = await create('head_only.gz');
    await sink.add(utf8.encode('{"only":"head"}'));
    final path = await sink.close();

    expect(
      utf8.decode(gzip.decode(await File(path).readAsBytes())),
      '{"only":"head"}',
    );
  });

  test('writeAt refuses bytes past the head', () async {
    final sink = await create('refuse.gz');
    await sink.add([1, 2, 3]);
    await sink.endHead();
    await sink.add([4, 5, 6]);
    expect(() => sink.writeAt(2, [9, 9]), throwsRangeError);
    expect(() => sink.writeAt(4, [9]), throwsRangeError);
    await sink.close();
  });

  test('a head can only end once', () async {
    final sink = await create('twice.gz');
    await sink.endHead();
    expect(sink.endHead, throwsStateError);
    await sink.close();
  });
}
