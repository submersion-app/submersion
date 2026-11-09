import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';

Uint8List _bytes(int from, int count) =>
    Uint8List.fromList(List<int>.generate(count, (i) => from + i));

void main() {
  group('rangeOfAnswer', () {
    test('a 206 of exactly the range passes through', () {
      final body = _bytes(10, 10);
      expect(rangeOfAnswer(206, body, start: 10, endInclusive: 19), same(body));
    });

    test('a 206 longer than the range is cut to it', () {
      // A server that answers past the asked end: the relay must not pass
      // on more than it asked for, or the worker's Content-Length is wrong.
      expect(
        rangeOfAnswer(206, _bytes(10, 50), start: 10, endInclusive: 19),
        _bytes(10, 10),
      );
    });

    test('a 206 shorter than the range (the object ends) is kept', () {
      expect(
        rangeOfAnswer(206, _bytes(95, 5), start: 95, endInclusive: 120),
        _bytes(95, 5),
      );
    });

    test('a 200 is the whole object and is cut to the range', () {
      expect(
        rangeOfAnswer(200, _bytes(0, 100), start: 95, endInclusive: 120),
        _bytes(95, 5),
      );
    });

    test('a 200 that ends before the range starts gives nothing', () {
      expect(
        rangeOfAnswer(200, _bytes(0, 10), start: 20, endInclusive: 29),
        isEmpty,
      );
    });
  });
}
