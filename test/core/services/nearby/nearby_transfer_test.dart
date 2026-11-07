import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/nearby/nearby_transfer.dart';
import 'package:submersion/core/utils/off_isolate.dart';

import '../../../helpers/isolate_hops.dart';

/// Transfer file names are built from values the peer sends (issue #3731).
void main() {
  late Directory dir;
  late NearbyTransferFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nearby_transfer');
    files = NearbyTransferFiles(dir, now: DateTime.now);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('an id or peer with a path in it never names a file', () {
    expect(NearbyTransferFiles.isSafeName('3f2a-9c_X'), isTrue);
    for (final bad in ['../x', 'a/b', r'a\b', '', '..', 'x' * 65]) {
      expect(NearbyTransferFiles.isSafeName(bad), isFalse, reason: bad);
      expect(() => files.incoming('peer', bad), throwsArgumentError);
      expect(() => files.incoming(bad, 'id'), throwsArgumentError);
    }
  });

  test(
    'a delta unpacks to the bytes it was given, whatever its size',
    () async {
      for (final size in [16, kOffIsolateMinBytes]) {
        final json = utf8.encode('{"a":"${'x' * size}"}');

        final out = await files.prepareDelta('peer', 'id$size', json);
        final unpacked = await files.gunzip(out.file);

        expect(await unpacked.readAsBytes(), json);
      }
    },
  );

  test('a full copy is sent as exported, never recompressed (#4256)', () async {
    final elsewhere = Directory.systemTemp.createTempSync('nearby_export');
    addTearDown(() => elsewhere.deleteSync(recursive: true));
    final exported = File(p.join(elsewhere.path, 'base.json.gz'))
      ..writeAsBytesSync(gzip.encode(utf8.encode('{"a":1}')));
    final bytes = exported.readAsBytesSync();

    final out = await files.prepareFull('peer', 'id', exported);

    expect(exported.existsSync(), isFalse, reason: 'moved, not copied');
    expect(await out.file.readAsBytes(), bytes);
    expect(out.byteLength, bytes.length);
    expect(p.dirname(out.file.path), dir.path);
    expect((await files.reusableFull('peer'))!.file.path, out.file.path);
  });

  test('a full copy that cannot be moved keeps the export and leaves nothing '
      'behind', () async {
    final exported = File(p.join(dir.path, 'export.json.gz'))
      ..writeAsBytesSync(gzip.encode(utf8.encode('{"a":1}')));
    // A directory in the way: the rename fails, and so does the copy.
    Directory(p.join(dir.path, 'nearby-out-peer-id.gz')).createSync();

    await expectLater(
      files.prepareFull('peer', 'id', exported),
      throwsA(isA<FileSystemException>()),
    );

    expect(exported.existsSync(), isTrue);
    expect(await files.reusableFull('peer'), isNull);
  });

  test('a large delta is compressed on a worker', () async {
    final hops = IsolateHops();
    final worker = NearbyTransferFiles(
      dir,
      now: DateTime.now,
      offIsolateRunner: hops.run,
    );

    await worker.prepareDelta(
      'peer',
      'id',
      utf8.encode('x' * kOffIsolateMinBytes),
    );

    expect(hops.count, 1);
    expect(hops.failures, isEmpty);
  });

  test('a small delta stays on this isolate', () async {
    final hops = IsolateHops();
    final worker = NearbyTransferFiles(
      dir,
      now: DateTime.now,
      offIsolateRunner: hops.run,
    );

    await worker.prepareDelta('peer', 'id', utf8.encode('{}'));

    expect(hops.count, 0);
  });
}
