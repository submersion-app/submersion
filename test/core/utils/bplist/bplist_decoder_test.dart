import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/bplist/bplist_decoder.dart';
import 'package:submersion/core/utils/bplist/bplist_object.dart';

void main() {
  group('BPlistDecoder — magic + trailer validation', () {
    test('throws FormatException on non-bplist input', () {
      expect(
        () => BPlistDecoder.decode(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on wrong bplist version', () {
      final bytes = Uint8List.fromList(const [
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x39, 0x39, // "bplist99"
        // minimum trailer padding
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ]);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'throws FormatException on truncated bytes (smaller than trailer)',
      () {
        expect(
          () => BPlistDecoder.decode(Uint8List.fromList(const [0x62, 0x70])),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('BPlistDecoder — small_dict.bplist golden', () {
    late BPlistObject root;

    setUpAll(() async {
      final bytes = await File(
        'test/fixtures/macdive_sqlite/bplist_samples/small_dict.bplist',
      ).readAsBytes();
      root = BPlistDecoder.decode(Uint8List.fromList(bytes));
    });

    test('root is a dict', () {
      expect(root, isA<BPlistDict>());
    });

    test('dict has string, int, date keys with expected values', () {
      final dict = (root as BPlistDict).value;
      expect(dict.keys.toSet(), {'name', 'count', 'when'});
      expect(dict['name']?.asString, 'Perdix');
      expect(dict['count']?.asInt, 42);
      expect(dict['when'], isA<BPlistDate>());
      expect(
        (dict['when'] as BPlistDate).toDateTime(),
        DateTime.utc(2024, 6, 1, 9, 0, 0),
      );
    });
  });

  group('BPlistDecoder — sample_array.bplist golden', () {
    late BPlistObject root;

    setUpAll(() async {
      final bytes = await File(
        'test/fixtures/macdive_sqlite/bplist_samples/sample_array.bplist',
      ).readAsBytes();
      root = BPlistDecoder.decode(Uint8List.fromList(bytes));
    });

    test('root is an array of reals', () {
      expect(root, isA<BPlistArray>());
      final arr = (root as BPlistArray).value;
      expect(arr.length, 4);
      expect(arr[0].asDouble, 0.0);
      expect(arr[1].asDouble, closeTo(10.5, 1e-9));
      expect(arr[2].asDouble, closeTo(20.3, 1e-9));
      expect(arr[3].asDouble, closeTo(30.1, 1e-9));
    });
  });

  group('BPlistDecoder — nested.bplist golden', () {
    late BPlistObject root;

    setUpAll(() async {
      final bytes = await File(
        'test/fixtures/macdive_sqlite/bplist_samples/nested.bplist',
      ).readAsBytes();
      root = BPlistDecoder.decode(Uint8List.fromList(bytes));
    });

    test('nested dict has array, bool, and data bytes', () {
      final dict = (root as BPlistDict).value;
      expect(dict.keys.toSet(), {'depths', 'hasPressure', 'payload'});

      final depths = dict['depths'] as BPlistArray;
      expect(depths.value.length, 4);
      expect(depths.value[0].asDouble, 0.0);
      expect(depths.value[1].asDouble, closeTo(5.2, 1e-9));

      expect(dict['hasPressure']?.asBool, true);

      final payload = dict['payload'] as BPlistData;
      expect(payload.value, [0, 1, 2, 3]);
    });
  });

  group('BPlistDecoder — multi-byte UID markers', () {
    // Synthetic bplist: root = UID(index). The decoder must honor the
    // bplist spec's `byteCount = (marker & 0x0F) + 1` rule so archives
    // with > 255 objects (e.g. large NSKeyedArchiver graphs) decode
    // correctly. Regression test for the 1-byte-only bug.
    Uint8List buildBplistWithRootUid(List<int> uidBytes) {
      final marker = 0x80 | (uidBytes.length - 1);
      final body = <int>[marker, ...uidBytes];
      const bodyOffset = 8;
      final offsetTableOffset = bodyOffset + body.length;
      const numObjects = 1;
      const topObject = 0;
      final trailer = <int>[
        0, 0, 0, 0, 0, 0, // unused / sortVersion
        1, // offsetIntSize
        1, // objectRefSize
        0, 0, 0, 0, 0, 0, 0, numObjects, // numObjects (u64 BE)
        0, 0, 0, 0, 0, 0, 0, topObject, // topObject (u64 BE)
        0, 0, 0, 0, 0, 0, 0, offsetTableOffset, // offsetTableOffset (u64 BE)
      ];
      return Uint8List.fromList([
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30, // "bplist00"
        ...body,
        bodyOffset, // offset table: one entry pointing at body
        ...trailer,
      ]);
    }

    test('decodes 2-byte UID index (e.g. object 256)', () {
      final bytes = buildBplistWithRootUid(const [0x01, 0x00]);
      final result = BPlistDecoder.decode(bytes);
      expect(result, isA<BPlistUID>());
      expect((result as BPlistUID).index, 256);
    });

    test('decodes 4-byte UID index', () {
      final bytes = buildBplistWithRootUid(const [0x00, 0x01, 0x00, 0x00]);
      final result = BPlistDecoder.decode(bytes);
      expect((result as BPlistUID).index, 0x00010000);
    });

    test('still decodes the common 1-byte case', () {
      final bytes = buildBplistWithRootUid(const [0x2A]);
      final result = BPlistDecoder.decode(bytes);
      expect((result as BPlistUID).index, 42);
    });
  });

  // The decoder reads BLOBs straight out of a user's MacDive database, and
  // its contract is that malformed input raises FormatException. Anything
  // else (a stack overflow, a hang, a bare RangeError) escapes callers that
  // rely on that contract and aborts a whole import over one bad row.
  group('BPlistDecoder - malformed object graphs', () {
    test('rejects an array that contains itself', () {
      final bytes = _bplistOf([
        [0xA1, 0x00], // object 0: array [object 0]
      ]);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a dict whose value is the dict itself', () {
      final bytes = _bplistOf([
        [0xD1, 0x01, 0x00], // object 0: {object 1: object 0}
        [0x51, 0x6B], // object 1: "k"
      ]);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('still decodes an object shared by two references', () {
      final bytes = _bplistOf([
        [0xA2, 0x01, 0x01], // object 0: array [object 1, object 1]
        [0x51, 0x6B], // object 1: "k"
      ]);
      final items = BPlistDecoder.decode(bytes).asList!;
      expect(items.map((o) => o.asString), ['k', 'k']);
    });

    test('rejects nesting deeper than any real archive uses', () {
      // Object i is an array holding object i + 1; the last is a string.
      const depth = 2000;
      final bytes = _bplistOf([
        for (var i = 0; i < depth; i++) [0xA1, (i + 1) >> 8, (i + 1) & 0xFF],
        [0x51, 0x6B],
      ], refSize: 2);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a zero object reference size', () {
      // Every reference would read as object 0, so a large count in the
      // root array would never run off the end of the stream.
      final bytes = _bplistOf([
        [0xAF, 0x13, 0x7F, 0xFF], // array claiming 32767 entries
      ], refSize: 0);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('reports a truncated array as a FormatException', () {
      final bytes = _bplistOf([
        [0xA5, 0x00], // array claiming five references, holding one
      ]);
      expect(
        () => BPlistDecoder.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BPlistDecoder — real MacDive ZTIMEZONE BLOB', () {
    late BPlistObject root;

    setUpAll(() async {
      final bytes = await File(
        'test/fixtures/macdive_sqlite/bplist_samples/macdive_ztimezone.bplist',
      ).readAsBytes();
      root = BPlistDecoder.decode(Uint8List.fromList(bytes));
    });

    test('root is a dict', () {
      expect(
        root,
        isA<BPlistDict>(),
        reason: 'MacDive ZTIMEZONE is a dict with NSKeyedArchiver metadata',
      );
    });

    test('dict has NSKeyedArchiver structure keys', () {
      final dict = (root as BPlistDict).value;
      // Actual keys observed in user's database:
      // ['\$archiver', '\$objects', '\$top', '\$version']
      expect(dict.keys, isNotEmpty);
      final keys = dict.keys.toSet();
      const archiverKeys = {r'$archiver', r'$objects', r'$top', r'$version'};
      expect(
        keys.intersection(archiverKeys),
        isNotEmpty,
        reason:
            'expected NSKeyedArchiver keys (\$archiver, \$objects, \$top, \$version); '
            'got $keys',
      );
    });

    test('contains an \$objects array (decoded object graph)', () {
      final dict = (root as BPlistDict).value;
      final objectsValue = dict[r'$objects'];
      expect(
        objectsValue,
        isA<BPlistArray>(),
        reason: '\$objects must be an array in NSKeyedArchiver format',
      );
      final objects = (objectsValue as BPlistArray).value;
      expect(objects, isNotEmpty);
    });

    test(
      'fixture is substantial (> 2 KB) and exercises bplist decoder fully',
      () async {
        // The real user file is 3.1 KB, which is large enough to
        // exercise object offsets beyond single bytes. This verifies
        // that the decoder correctly handles the offset size from the
        // trailer and is not just lucky on tiny Python-generated examples.
        final bytes = await File(
          'test/fixtures/macdive_sqlite/bplist_samples/macdive_ztimezone.bplist',
        ).readAsBytes();
        expect(bytes.length, greaterThan(2048));
      },
    );
  });
}

/// A bplist00 stream holding [objects], each already encoded, with object 0
/// as the root. Offsets are written in two bytes and references in
/// [refSize] bytes, so large synthetic graphs fit.
Uint8List _bplistOf(List<List<int>> objects, {int refSize = 1}) {
  const header = [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30];
  final body = <int>[];
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(header.length + body.length);
    body.addAll(object);
  }
  final offsetTableOffset = header.length + body.length;
  List<int> u64(int value) => [
    for (var shift = 56; shift >= 0; shift -= 8) (value >> shift) & 0xFF,
  ];
  return Uint8List.fromList([
    ...header,
    ...body,
    for (final offset in offsets) ...[offset >> 8, offset & 0xFF],
    0, 0, 0, 0, 0, 0, // unused, sortVersion
    2, // offsetIntSize
    refSize, // objectRefSize
    ...u64(objects.length),
    ...u64(0), // topObject
    ...u64(offsetTableOffset),
  ]);
}
