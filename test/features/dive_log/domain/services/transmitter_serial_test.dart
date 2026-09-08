import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

void main() {
  group('normalizeTransmitterSerial', () {
    test('keeps a real serial, trimmed', () {
      expect(normalizeTransmitterSerial(' 180777 '), '180777');
    });

    test('treats null, blank and whitespace as absent', () {
      expect(normalizeTransmitterSerial(null), isNull);
      expect(normalizeTransmitterSerial(''), isNull);
      expect(normalizeTransmitterSerial('   '), isNull);
    });

    test('treats the zero sentinel as absent, however it is padded', () {
      // libdivecomputer reports 0 for "no transmitter"; a file or peer that
      // stringifies that must not turn it into an identity two unrelated
      // tanks could share.
      expect(normalizeTransmitterSerial('0'), isNull);
      expect(normalizeTransmitterSerial('000'), isNull);
      expect(normalizeTransmitterSerial(' 0 '), isNull);
    });
  });
}
