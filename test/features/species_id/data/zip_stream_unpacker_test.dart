import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/pack/zip_stream_unpacker.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import '../../../helpers/temp_dir.dart';

/// Weights that compress: runs of zeros between noisy stretches.
Uint8List _weights(int length) => Uint8List.fromList(
  List.generate(length, (i) => (i ~/ 512).isEven ? 0 : (i * 31) % 251),
);

/// A model package as the pack builder zips one: its folder at the top.
Uint8List _modelZip({bool stored = false}) {
  final weights = _weights(200000);
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes(
        'detector.mlpackage/Manifest.json',
        utf8.encode('{"model": 1}'),
      ),
    )
    ..addFile(
      stored
          ? ArchiveFile.noCompress(
              'detector.mlpackage/Data/weights.bin',
              weights.length,
              weights,
            )
          : ArchiveFile.bytes('detector.mlpackage/Data/weights.bin', weights),
    );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// Offsets of every local file header in [zip].
List<int> _localHeaders(Uint8List zip) {
  final data = ByteData.sublistView(zip);
  return [
    for (var i = 0; i + 4 <= zip.length; i++)
      if (data.getUint32(i, Endian.little) == 0x04034b50) i,
  ];
}

/// One stored entry whose sizes sit in a ZIP64 extra field, as Python's
/// zipfile writes them for a file over 2 GB.
Uint8List _zip64Entry(String name, List<int> content, {int? claimed}) {
  final nameBytes = utf8.encode(name);
  final extra = ByteData(20)
    ..setUint16(0, 0x0001, Endian.little)
    ..setUint16(2, 16, Endian.little)
    ..setUint64(4, claimed ?? content.length, Endian.little)
    ..setUint64(12, claimed ?? content.length, Endian.little);
  final header = ByteData(30)
    ..setUint32(0, 0x04034b50, Endian.little)
    ..setUint16(4, 45, Endian.little)
    ..setUint32(18, 0xFFFFFFFF, Endian.little)
    ..setUint32(22, 0xFFFFFFFF, Endian.little)
    ..setUint16(26, nameBytes.length, Endian.little)
    ..setUint16(28, 20, Endian.little);
  final central = ByteData(4)..setUint32(0, 0x02014b50, Endian.little);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...nameBytes,
    ...extra.buffer.asUint8List(),
    ...content,
    ...central.buffer.asUint8List(),
  ]);
}

void main() {
  late Directory dir;
  late String out;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zip_stream_unpacker');
    out = p.join(dir.path, 'detector');
  });
  tearDown(() => deleteTempDir(dir));

  /// Feeds [zip] to a new unpacker in [chunk]-byte pieces, then closes it.
  Future<void> unpack(Uint8List zip, {int chunk = 4096}) async {
    final unpacker = ZipStreamUnpacker(out);
    try {
      for (var i = 0; i < zip.length; i += chunk) {
        await unpacker.add(
          zip.sublist(i, i + chunk > zip.length ? zip.length : i + chunk),
        );
      }
      await unpacker.close();
    } on Object {
      await unpacker.abort();
      rethrow;
    }
  }

  Matcher malformed() => throwsA(
    isA<PackManifestException>().having(
      (e) => e.reason,
      'reason',
      PackManifestFailure.malformed,
    ),
  );

  File weightsFile() =>
      File(p.join(out, 'detector.mlpackage', 'Data', 'weights.bin'));

  test('a deflated model unpacks to the bytes that were zipped', () async {
    await unpack(_modelZip());
    expect(await weightsFile().readAsBytes(), _weights(200000));
    expect(
      await File(
        p.join(out, 'detector.mlpackage', 'Manifest.json'),
      ).readAsString(),
      '{"model": 1}',
    );
  });

  test('a stored model unpacks to the bytes that were zipped', () async {
    await unpack(_modelZip(stored: true));
    expect(await weightsFile().readAsBytes(), _weights(200000));
  });

  test('headers split across any chunk boundary still unpack', () async {
    for (final chunk in [1, 7, 30, 31, 100]) {
      await deleteTempDir(Directory(out));
      await unpack(_modelZip(), chunk: chunk);
      expect(await weightsFile().readAsBytes(), _weights(200000));
    }
  });

  test('a large chunk of highly compressed data unpacks in full', () async {
    final zeros = Uint8List(8 * 1024 * 1024);
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('m.mlpackage/zeros.bin', zeros)),
      ),
    );
    await unpack(zip, chunk: zip.length);
    expect(
      await File(p.join(out, 'm.mlpackage', 'zeros.bin')).length(),
      zeros.length,
    );
  });

  test('sizes in a ZIP64 extra field are read', () async {
    await unpack(_zip64Entry('m.mlpackage/w.bin', [1, 2, 3, 4, 5]), chunk: 3);
    expect(await File(p.join(out, 'm.mlpackage', 'w.bin')).readAsBytes(), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('ZIP64 sizes past 4 GB keep their high half', () async {
    // Read as 5 bytes if the high half were dropped, and then accepted.
    final zip = _zip64Entry('m.mlpackage/w.bin', [
      1,
      2,
      3,
      4,
      5,
    ], claimed: 0x100000005);
    await expectLater(unpack(zip), malformed());
  });

  test('an entry that would land outside the folder is refused', () async {
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('../escaped.bin', Uint8List(4))),
      ),
    );
    await expectLater(unpack(zip), malformed());
    expect(await File(p.join(dir.path, 'escaped.bin')).exists(), isFalse);
  });

  test('a file that does not unpack to its recorded size is refused', () async {
    final zip = _modelZip(stored: true);
    final data = ByteData.sublistView(zip);
    final weights = _localHeaders(zip).last;
    data.setUint32(weights + 22, 200001, Endian.little);
    await expectLater(unpack(zip), malformed());
  });

  test('a zip that ends inside a file is refused', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    await expectLater(unpack(zip.sublist(0, weights + 1000)), malformed());
  });

  test('a zip that ends inside a header is refused', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    await expectLater(unpack(zip.sublist(0, weights + 10)), malformed());
  });

  test('sizes that follow the data, not the header, are refused', () async {
    final zip = _modelZip();
    final data = ByteData.sublistView(zip);
    final first = _localHeaders(zip).first;
    data.setUint16(first + 6, data.getUint16(first + 6, Endian.little) | 8);
    await expectLater(unpack(zip), malformed());
  });

  test(
    'a compression method other than stored or deflate is refused',
    () async {
      final zip = _modelZip();
      ByteData.sublistView(
        zip,
      ).setUint16(_localHeaders(zip).first + 8, 12, Endian.little);
      await expectLater(unpack(zip), malformed());
    },
  );

  test('deflated data that does not inflate is refused', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    final dataStart =
        weights +
        30 +
        ByteData.sublistView(zip).getUint16(weights + 26, Endian.little) +
        ByteData.sublistView(zip).getUint16(weights + 28, Endian.little);
    zip.fillRange(dataStart, dataStart + 64, 0xFF);
    await expectLater(unpack(zip), malformed());
  });

  test('something that is not a zip is refused', () async {
    await expectLater(
      unpack(Uint8List.fromList(utf8.encode('<html>not found</html>'))),
      malformed(),
    );
  });
}
