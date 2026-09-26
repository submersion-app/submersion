import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Steel 12 L',
    serial: 'AB12345',
    volumeL: 12,
    workingPressureBar: 232,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  test('a short https URL costs header, prefix byte and the rest', () {
    // 'https://submersion.app/c#f=1' is 28 chars; minus 'https://' is 20,
    // plus the prefix byte is 21 of payload; record header 4; TLV 2 + 1.
    expect(NdefFit.uriRecordMessageBytes('https://submersion.app/c#f=1'), 28);
  });

  test('a payload over 255 bytes pays the long record and TLV headers', () {
    final url = 'https://submersion.app/c#${'x' * 260}';
    // 'submersion.app/c#' is 17 chars: payload 1 + 17 + 260 = 278;
    // record header 7; TLV 4 + 1.
    expect(NdefFit.uriRecordMessageBytes(url), 290);
  });

  test('the full payload fits NTAG215 and NTAG216 but not NTAG213', () {
    expect(NdefFit.fit(full, NdefFit.ntag216Bytes), full);
    expect(NdefFit.fit(full, NdefFit.ntag215Bytes), full);
    final small = NdefFit.fit(full, NdefFit.ntag213Bytes);
    expect(small, isNotNull);
    expect(small, isNot(full));
    expect(small!.passportId, id);
    expect(small.writtenOn, full.writtenOn);
    expect(
      NdefFit.uriRecordMessageBytes(PassportPayloadCodec.httpsUrl(small)),
      lessThanOrEqualTo(NdefFit.ntag213Bytes),
    );
  });

  test('drops keys in the fixed order, name first, volume last', () {
    var p = full;
    final seen = <String>[];
    for (final key in NdefFit.dropOrder) {
      final next = NdefFit.drop(p, key);
      expect(next, isNot(p), reason: 'dropping $key changed nothing');
      seen.add(key);
      p = next;
    }
    expect(seen, NdefFit.dropOrder);
    expect(p.name, isNull);
    expect(p.volumeL, isNull);
    expect(p.passportId, id);
  });

  test('fit keeps the earliest surviving suffix of the order', () {
    // Enough room for everything but the name and serial.
    final withoutName = NdefFit.drop(NdefFit.drop(full, 'n'), 'sn');
    final budget = NdefFit.uriRecordMessageBytes(
      PassportPayloadCodec.httpsUrl(withoutName),
    );
    expect(NdefFit.fit(full, budget), withoutName);
  });

  test('returns null when even the identity does not fit', () {
    expect(NdefFit.fit(full, 40), isNull);
  });

  test('a label URL never exceeds 160 characters', () {
    final long = full.copyWith(name: '北' * 40, serial: 'SN-${'9' * 80}');
    expect(PassportPayloadCodec.httpsUrl(long).length, greaterThan(160));
    final label = NdefFit.fitForLabel(long);
    expect(
      PassportPayloadCodec.httpsUrl(label).length,
      lessThanOrEqualTo(NdefFit.labelMaxUrlLength),
    );
    expect(label.passportId, id);
    expect(label.writtenOn, full.writtenOn);
    // Only what had to go went: the spec survives.
    expect(label.volumeL, 12);
  });

  test('a payload that already fits a label is unchanged', () {
    expect(NdefFit.fitForLabel(full), full);
  });
}
