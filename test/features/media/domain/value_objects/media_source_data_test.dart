// ignore_for_file: dead_code
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  group('MediaSourceData', () {
    test('FileData carries a File', () {
      final f = File('/tmp/x.jpg');
      final d = FileData(file: f);
      expect(d.file, f);
    });

    test('NetworkData carries url and headers', () {
      final url = Uri.parse('https://example.com/x.jpg');
      final d = NetworkData(url: url, headers: const {'X-Foo': '1'});
      expect(d.url, url);
      expect(d.headers['X-Foo'], '1');
    });

    test('BytesData carries bytes', () {
      final b = Uint8List.fromList([1, 2, 3]);
      final d = BytesData(bytes: b);
      expect(d.bytes, b);
    });

    test('UnavailableData carries kind and optional fields', () {
      const d = UnavailableData(
        kind: UnavailableKind.notFound,
        userMessage: 'file gone',
      );
      expect(d.kind, UnavailableKind.notFound);
      expect(d.userMessage, 'file gone');
      expect(d.originDeviceLabel, isNull);
    });

    test('exhaustive switch over variants compiles', () {
      final data = BytesData(bytes: Uint8List(0));
      final label = switch (data) {
        FileData() => 'file',
        NetworkData() => 'network',
        BytesData() => 'bytes',
        UnavailableData() => 'unavailable',
      };
      expect(label, 'bytes');
    });
  });
}
