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
Uint8List _zip64Entry(
  String name,
  List<int> content, {
  int? claimed,
  List<int> extraBefore = const [],
  List<int> endComment = const [],
}) {
  final nameBytes = utf8.encode(name);
  final zip64 = ByteData(20)
    ..setUint16(0, 0x0001, Endian.little)
    ..setUint16(2, 16, Endian.little)
    ..setUint64(4, claimed ?? content.length, Endian.little)
    ..setUint64(12, claimed ?? content.length, Endian.little);
  final header = ByteData(30)
    ..setUint32(0, 0x04034b50, Endian.little)
    ..setUint16(4, 45, Endian.little)
    ..setUint32(14, getCrc32(content), Endian.little)
    ..setUint32(18, 0xFFFFFFFF, Endian.little)
    ..setUint32(22, 0xFFFFFFFF, Endian.little)
    ..setUint16(26, nameBytes.length, Endian.little)
    ..setUint16(28, extraBefore.length + 20, Endian.little);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...nameBytes,
    ...extraBefore,
    ...zip64.buffer.asUint8List(),
    ...content,
    ..._endRecord(comment: endComment),
  ]);
}

/// An end-of-central-directory record, with [comment] after it.
List<int> _endRecord({List<int> comment = const []}) {
  final record = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(20, comment.length, Endian.little);
  return [...record.buffer.asUint8List(), ...comment];
}

/// Where the central directory starts in [zip].
int _centralDirectory(Uint8List zip) {
  final data = ByteData.sublistView(zip);
  for (var i = 0; i + 4 <= zip.length; i++) {
    if (data.getUint32(i, Endian.little) == 0x02014b50) return i;
  }
  throw StateError('no central directory');
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

  test('a ZIP64 record too short for its sizes is refused', () async {
    final zip = _zip64Entry('m.mlpackage/w.bin', [1, 2, 3, 4, 5]);
    // The record's length now covers only the uncompressed size.
    const at = 30 + 'm.mlpackage/w.bin'.length;
    ByteData.sublistView(zip).setUint16(at + 2, 8, Endian.little);
    await expectLater(unpack(zip), malformed());
  });

  test('a ZIP64 record after another extra field is found', () async {
    // An extended timestamp field first, as zip tools often write.
    final timestamp = ByteData(9)
      ..setUint16(0, 0x5455, Endian.little)
      ..setUint16(2, 5, Endian.little);
    await unpack(
      _zip64Entry('m.mlpackage/w.bin', [
        7,
        8,
        9,
      ], extraBefore: timestamp.buffer.asUint8List()),
    );
    expect(await File(p.join(out, 'm.mlpackage', 'w.bin')).readAsBytes(), [
      7,
      8,
      9,
    ]);
  });

  test('a folder entry is made as a folder', () async {
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()
          ..addFile(ArchiveFile.directory('m.mlpackage/Data/'))
          ..addFile(ArchiveFile.bytes('m.mlpackage/Data/w.bin', [1])),
      ),
    );
    await unpack(zip);
    expect(
      await Directory(p.join(out, 'm.mlpackage', 'Data')).exists(),
      isTrue,
    );
  });

  test('a long central directory still ends in a found end record', () async {
    // More after the entries than the unpacker keeps of it.
    final zip = _zip64Entry('m.mlpackage/w.bin', [
      1,
      2,
    ], endComment: List.filled(0xFFFF, 0x20));
    final entries = zip.length - 22 - 0xFFFF;
    final central = ByteData(4)..setUint32(0, 0x02014b50, Endian.little);
    final long = Uint8List.fromList([
      ...zip.sublist(0, entries),
      ...central.buffer.asUint8List(),
      ...List.filled(200000, 0),
      ...zip.sublist(entries),
    ]);
    await unpack(long, chunk: 8192);
    expect(await File(p.join(out, 'm.mlpackage', 'w.bin')).readAsBytes(), [
      1,
      2,
    ]);
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

  test('a file growing past its recorded size is refused before it is all '
      'written', () async {
    final zeros = Uint8List(4 * 1024 * 1024);
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('m.mlpackage/zeros.bin', zeros)),
      ),
    );
    final data = ByteData.sublistView(zip);
    for (final at in _localHeaders(zip)) {
      data.setUint32(at + 22, 1000, Endian.little);
    }
    await expectLater(unpack(zip, chunk: zip.length), malformed());
    final file = File(p.join(out, 'm.mlpackage', 'zeros.bin'));
    expect(await file.length(), lessThanOrEqualTo(1000));
  });

  test('a zip that ends inside a file is refused', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    await expectLater(unpack(zip.sublist(0, weights + 1000)), malformed());
  });

  test('a zip cut short after its last file is refused', () async {
    final zip = _modelZip();
    await expectLater(
      unpack(zip.sublist(0, _centralDirectory(zip))),
      malformed(),
    );
  });

  test('a zip cut short inside its central directory is refused', () async {
    final zip = _modelZip();
    for (final cut in [_centralDirectory(zip) + 4, zip.length - 1]) {
      await deleteTempDir(Directory(out));
      await expectLater(unpack(zip.sublist(0, cut), chunk: 7), malformed());
    }
  });

  test('an end record carrying a comment is accepted', () async {
    final zip = _zip64Entry('m.mlpackage/w.bin', [1, 2, 3]);
    final commented = Uint8List.fromList([
      ...zip.sublist(0, zip.length - 22),
      ..._endRecord(comment: List.filled(300, 0x50)),
    ]);
    await unpack(commented, chunk: 5);
    expect(await File(p.join(out, 'm.mlpackage', 'w.bin')).readAsBytes(), [
      1,
      2,
      3,
    ]);
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

  test('a deflate stream cut before its end is refused', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    final data = ByteData.sublistView(zip);
    final compressed = data.getUint32(weights + 18, Endian.little);
    final dataStart =
        weights +
        30 +
        data.getUint16(weights + 26, Endian.little) +
        data.getUint16(weights + 28, Endian.little);
    // The entry now claims, and holds, all but its last 16 bytes.
    data.setUint32(weights + 18, compressed - 16, Endian.little);
    final cut = Uint8List.fromList([
      ...zip.sublist(0, dataStart + compressed - 16),
      ...zip.sublist(dataStart + compressed),
    ]);
    await expectLater(unpack(cut), malformed());
  });

  test('a deflate stream cut before its last block is refused even when '
      'the header records what did inflate', () async {
    final zip = _modelZip();
    final weights = _localHeaders(zip).last;
    final data = ByteData.sublistView(zip);
    final compressed = data.getUint32(weights + 18, Endian.little);
    final dataStart =
        weights +
        30 +
        data.getUint16(weights + 26, Endian.little) +
        data.getUint16(weights + 28, Endian.little);
    const cut = 40;
    // What the shortened stream inflates to, as its new recorded size.
    final filter = RawZLibFilter.inflateFilter(raw: true)
      ..process(zip, dataStart, dataStart + compressed - cut);
    var inflated = 0;
    for (List<int>? piece; (piece = filter.processed()) != null;) {
      inflated += piece!.length;
    }
    expect(inflated, lessThan(200000));
    data
      ..setUint32(weights + 18, compressed - cut, Endian.little)
      ..setUint32(weights + 22, inflated, Endian.little);
    final cutZip = Uint8List.fromList([
      ...zip.sublist(0, dataStart + compressed - cut),
      ...zip.sublist(dataStart + compressed),
    ]);
    await expectLater(unpack(cutZip), malformed());
  });

  test('a stored file whose bytes changed is refused', () async {
    final zip = _modelZip(stored: true);
    final weights = _localHeaders(zip).last;
    final data = ByteData.sublistView(zip);
    final dataStart =
        weights +
        30 +
        data.getUint16(weights + 26, Endian.little) +
        data.getUint16(weights + 28, Endian.little);
    zip[dataStart + 1000] ^= 0xFF;
    await expectLater(unpack(zip), malformed());
  });

  test('something that is not a zip is refused', () async {
    await expectLater(
      unpack(Uint8List.fromList(utf8.encode('<html>not found</html>'))),
      malformed(),
    );
  });
}
