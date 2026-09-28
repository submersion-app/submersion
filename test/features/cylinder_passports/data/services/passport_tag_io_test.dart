import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_tag_io.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

import '../../../../helpers/fake_nfc.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final payload = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
  );

  group('writePassportTo', () {
    test('writes the plan and confirms it by reading back', () async {
      final tag = FakeTagHandle();
      final result = await writePassportTo(tag, payload);
      expect(result, isA<TagWritten>());
      final written = result as TagWritten;
      expect(tag.stored, written.plan.message);
      expect(written.capacity, 496);
      expect(written.typeLabel, 'org.nfcforum.ndef.type2');
      expect(
        firstPassportUri(tag.stored!),
        PassportPayloadCodec.httpsUrl(payload),
      );
    });

    test('a tag that cannot hold NDEF is refused', () async {
      expect(await writePassportTo(null, payload), isA<TagNotNdef>());
    });

    test('a locked tag is refused without writing', () async {
      final tag = FakeTagHandle(isWritable: false);
      expect(await writePassportTo(tag, payload), isA<TagReadOnly>());
      expect(tag.writes, 0);
    });

    test(
      'a tag too small for the identity is refused with its capacity',
      () async {
        final tag = FakeTagHandle(maxMessageBytes: 40);
        final result = await writePassportTo(tag, payload);
        expect((result as TagTooSmall).capacity, 40);
        expect(tag.writes, 0);
      },
    );

    test('a tag that reads back differently was not written', () async {
      final tag = FakeTagHandle(
        readBackOverride: NdefMessage(
          records: [uriRecord('https://example.com/')],
        ),
      );
      expect(await writePassportTo(tag, payload), isA<TagReadBackMismatch>());
    });

    test('a tag lost mid-write reports the failure', () async {
      final tag = FakeTagHandle(
        writeError: PlatformException(code: 'io_exception'),
      );
      final result = await writePassportTo(tag, payload);
      expect((result as TagWriteFailed).error, isA<PlatformException>());
    });

    test('a failed read-back reports the failure', () async {
      final tag = FakeTagHandle(
        readError: PlatformException(code: 'io_exception'),
      );
      expect(await writePassportTo(tag, payload), isA<TagWriteFailed>());
    });
  });

  group('readPassportFrom', () {
    final text = PassportPayloadCodec.httpsUrl(payload);

    test('returns the passport link the tag holds', () async {
      final tag = FakeTagHandle(
        stored: NdefMessage(
          records: [androidApplicationRecord(), uriRecord(text)],
        ),
      );
      expect((await readPassportFrom(tag) as TagReadText).text, text);
    });

    test('a tag with no passport, or none at all, has none', () async {
      expect(await readPassportFrom(null), isA<TagHasNoPassport>());
      expect(await readPassportFrom(FakeTagHandle()), isA<TagHasNoPassport>());
      final other = FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://example.com/')]),
      );
      expect(await readPassportFrom(other), isA<TagHasNoPassport>());
    });

    test('uses what the tag held when found, without reading again', () async {
      // iOS fails a second read of an empty tag (a zero-length message);
      // a blank tag is one with no passport, not one that could not be read.
      final blank = FakeTagHandle(readError: PlatformException(code: '403'));
      expect(await readPassportFrom(blank), isA<TagHasNoPassport>());
      final held = FakeTagHandle(
        stored: NdefMessage(records: [uriRecord(text)]),
        readError: PlatformException(code: 'io'),
      );
      expect((await readPassportFrom(held) as TagReadText).text, text);
    });
  });

  test('friendlyTagType names the NFC Forum types', () {
    expect(friendlyTagType('org.nfcforum.ndef.type2'), 'NFC Forum Type 2');
    expect(friendlyTagType('com.nxp.ndef.mifareclassic'), 'MIFARE Classic');
    expect(friendlyTagType('something.else'), 'something.else');
    expect(friendlyTagType(null), isNull);
  });
}
