import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/features/buddies/data/services/ndef_bytes.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';

import '../../../support/ndef_decode.dart';

void main() {
  test('a one-record URI message encodes to the NFC Forum short record', () {
    final bytes = encodeNdef(NdefMessage(records: [uriRecord('https://ab')]));
    // MB|ME|SR|TNF=1, type length 1, payload length 3, 'U', code 4, 'ab'.
    expect(bytes, [0xD1, 0x01, 0x03, 0x55, 0x04, 0x61, 0x62]);
  });

  test('a payload over 255 bytes uses a long record and round trips', () {
    final message = NdefMessage(records: [uriRecord('https://${'x' * 400}')]);
    final bytes = encodeNdef(message);
    expect(bytes.first & 0x10, 0, reason: 'not a short record');
    expect(bytes.length, message.byteLength);
    expect(uriOf(decodeNdef(bytes).records.single), 'https://${'x' * 400}');
  });

  test('two records set message begin and end on the right ones', () {
    final message = NdefMessage(
      records: [uriRecord('https://a'), uriRecord('https://b')],
    );
    final bytes = encodeNdef(message);
    expect(bytes.first & 0xC0, 0x80);
    final decoded = decodeNdef(bytes);
    expect(decoded.records.map(uriOf), ['https://a', 'https://b']);
  });

  test('truncated bytes throw a FormatException', () {
    expect(
      () => decodeNdef(Uint8List.fromList([0xD1, 0x01, 0x09, 0x55])),
      throwsFormatException,
    );
  });
}
