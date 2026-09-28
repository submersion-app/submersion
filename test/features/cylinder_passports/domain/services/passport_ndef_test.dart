import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  group('URI records', () {
    test('https uses the one-byte prefix code 4', () {
      final record = uriRecord('https://submersion.app/c#f=1');
      expect(record.typeNameFormat, TypeNameFormat.wellKnown);
      expect(record.type, [0x55]);
      expect(record.payload.first, 0x04);
      expect(utf8.decode(record.payload.sublist(1)), 'submersion.app/c#f=1');
    });

    test('round trips through the prefix table', () {
      for (final url in [
        'https://submersion.app/c#f=1&p=$id',
        'http://www.example.com/x',
        'submersion://c?f=1',
        'tel:+15551234',
      ]) {
        expect(uriOf(uriRecord(url)), url);
      }
    });

    test("matches NdefFit's size model", () {
      // NdefFit counts the Type 2 TLV (2 bytes, 4 from 255) and the
      // terminator around the record; the phone reports the message alone.
      final url = PassportPayloadCodec.httpsUrl(full);
      final bytes = uriRecord(url).byteLength;
      expect(NdefFit.uriRecordMessageBytes(url), bytes + (bytes < 255 ? 3 : 5));
    });

    test('any other record carries no URI', () {
      expect(uriOf(androidApplicationRecord()), isNull);
    });

    test('an unknown prefix code or bad UTF-8 carries no URI', () {
      NdefRecord raw(List<int> payload) => NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(const [0x55]),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(payload),
      );
      expect(uriOf(raw(const [0x40, 0x61])), isNull);
      expect(uriOf(raw(const [0x04, 0xff, 0xfe])), isNull);
      expect(uriOf(raw(const [])), isNull);
    });
  });

  test('the Android record names the app', () {
    final record = androidApplicationRecord();
    expect(record.typeNameFormat, TypeNameFormat.external);
    expect(utf8.decode(record.type), 'android.com:pkg');
    expect(utf8.decode(record.payload), passportAndroidPackage);
  });

  group('firstPassportUri', () {
    test('skips the AAR, another app and a fill record', () {
      final tag = PassportPayloadCodec.httpsUrl(full);
      final message = NdefMessage(
        records: [
          androidApplicationRecord(),
          uriRecord('https://example.com/menu'),
          uriRecord('https://submersion.app/f#token'),
          uriRecord(tag),
        ],
      );
      expect(firstPassportUri(message), tag);
    });

    test('a tag with no passport has none', () {
      final message = NdefMessage(
        records: [uriRecord('https://example.com/c#f=1')],
      );
      expect(firstPassportUri(message), isNull);
      expect(firstPassportUri(const NdefMessage(records: [])), isNull);
    });
  });

  group('planPassportMessage', () {
    test('a roomy tag gets everything and the Android record', () {
      final plan = planPassportMessage(full, maxMessageBytes: 496)!;
      expect(plan.payload, full);
      expect(plan.droppedKeys, isEmpty);
      expect(plan.includesAndroidRecord, isTrue);
      expect(
        plan.message.records.first,
        uriRecord(PassportPayloadCodec.httpsUrl(full)),
      );
      expect(plan.message.records.last, androidApplicationRecord());
      expect(plan.message.byteLength, lessThanOrEqualTo(496));
    });

    test(
      'a small tag drops keys in the fixed order and keeps the identity',
      () {
        final plan = planPassportMessage(full, maxMessageBytes: 100)!;
        expect(plan.message.byteLength, lessThanOrEqualTo(100));
        expect(plan.payload.passportId, id);
        expect(plan.payload.writtenOn, full.writtenOn);
        expect(plan.droppedKeys, isNotEmpty);
        expect(
          plan.droppedKeys,
          NdefFit.dropOrder.take(plan.droppedKeys.length).toList(),
        );
      },
    );

    test('the Android record goes only where room remains', () {
      final fitted = planPassportMessage(full, maxMessageBytes: 100)!.payload;
      final tight = uriRecord(PassportPayloadCodec.httpsUrl(fitted)).byteLength;
      final plan = planPassportMessage(fitted, maxMessageBytes: tight)!;
      expect(plan.includesAndroidRecord, isFalse);
      expect(plan.message.records, hasLength(1));
    });

    test('null when even the identity does not fit', () {
      expect(planPassportMessage(full, maxMessageBytes: 40), isNull);
    });

    test('keys the payload never had are not reported as dropped', () {
      final bare = CylinderPassportPayload(
        passportId: id,
        writtenOn: DateTime(2026, 9, 25),
      );
      expect(
        planPassportMessage(bare, maxMessageBytes: 496)!.droppedKeys,
        isEmpty,
      );
    });
  });
}
