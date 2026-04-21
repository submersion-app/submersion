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
}
