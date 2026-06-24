import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/pem.dart';

void main() {
  group('derToPem', () {
    test('wraps DER bytes in BEGIN/END CERTIFICATE armor', () {
      final der = Uint8List.fromList([1, 2, 3, 4, 5]);

      final pem = derToPem(der);

      expect(pem, startsWith('-----BEGIN CERTIFICATE-----\n'));
      expect(pem.trimRight(), endsWith('-----END CERTIFICATE-----'));
    });

    test('base64-encodes the DER payload between the armor lines', () {
      final der = Uint8List.fromList(List<int>.generate(48, (i) => i));

      final pem = derToPem(der);
      final body = pem
          .replaceFirst('-----BEGIN CERTIFICATE-----\n', '')
          .replaceFirst('-----END CERTIFICATE-----\n', '')
          .replaceAll('\n', '');

      expect(base64.decode(body), equals(der));
    });

    test('wraps the base64 body at 64 characters per line', () {
      // 150 DER bytes -> 200 base64 chars -> lines of 64, 64, 64, 8.
      final der = Uint8List.fromList(List<int>.generate(150, (i) => i % 256));

      final pem = derToPem(der);
      final bodyLines = pem
          .split('\n')
          .where(
            (l) =>
                l.isNotEmpty &&
                !l.startsWith('-----BEGIN') &&
                !l.startsWith('-----END'),
          )
          .toList();

      expect(bodyLines.length, 4);
      for (final line in bodyLines.take(3)) {
        expect(line.length, 64);
      }
      expect(bodyLines.last.length, lessThanOrEqualTo(64));
    });
  });
}
