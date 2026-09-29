import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/tag_fill.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
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

  group('encode', () {
    test('emits keys in the fixed order with metric values', () {
      expect(
        PassportPayloadCodec.encode(full),
        'f=1&p=$id&w=2026-09-25&n=Steel+12+L&sn=AB12345&v=12&wp=232'
        '&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1',
      );
    });

    test('omits absent optional keys and keeps one decimal of volume', () {
      final p = CylinderPassportPayload(
        passportId: id,
        writtenOn: DateTime(2026, 9, 25),
        volumeL: 11.1,
      );
      expect(PassportPayloadCodec.encode(p), 'f=1&p=$id&w=2026-09-25&v=11.1');
    });

    test('the https form carries the payload in the fragment', () {
      expect(
        PassportPayloadCodec.httpsUrl(full),
        startsWith('https://submersion.app/c#f=1&p=$id'),
      );
    });

    test('a full payload is at most 160 characters', () {
      // 160 characters is a version 9 QR at error correction M: 53 modules,
      // about half a millimetre each on a 26 mm label.
      expect(
        PassportPayloadCodec.httpsUrl(full).length,
        lessThanOrEqualTo(160),
      );
    });

    test('truncates a long name to 40 characters', () {
      final p = CylinderPassportPayload(passportId: id, name: 'x' * 50);
      final back = PassportPayloadCodec.decode(PassportPayloadCodec.encode(p));
      expect((back as PassportDecoded).payload.name, 'x' * 40);
    });
  });

  group('decode', () {
    test('round trips the full payload from the https form', () {
      final result = PassportPayloadCodec.decode(
        PassportPayloadCodec.httpsUrl(full),
      );
      expect(result, isA<PassportDecoded>());
      final decoded = result as PassportDecoded;
      expect(decoded.payload, full);
      expect(decoded.newerFormat, isFalse);
    });

    test('accepts the custom scheme with the payload in the query', () {
      final result = PassportPayloadCodec.decode(
        'submersion://c?${PassportPayloadCodec.encode(full)}',
      );
      expect((result as PassportDecoded).payload, full);
    });

    test('accepts a bare query string', () {
      final result = PassportPayloadCodec.decode('f=1&p=$id');
      expect((result as PassportDecoded).payload.passportId, id);
    });

    test(
      'decode tolerates whitespace, a trailing slash and upper-case hex',
      () {
        final upper = id.toUpperCase();
        final result = PassportPayloadCodec.decode(
          '  https://submersion.app/c/#f=1&p=$upper \n',
        );
        expect((result as PassportDecoded).payload.passportId, id);
      },
    );

    test('round trips a hostile name', () {
      const name = 'Bill & Ted #2 = Ärger';
      const p = CylinderPassportPayload(passportId: id, name: name);
      final back = PassportPayloadCodec.decode(
        PassportPayloadCodec.httpsUrl(p),
      );
      expect((back as PassportDecoded).payload.name, name);
    });

    test('ignores unknown keys and flags a newer format', () {
      final result = PassportPayloadCodec.decode('f=2&p=$id&zz=9');
      final decoded = result as PassportDecoded;
      expect(decoded.newerFormat, isTrue);
      expect(decoded.payload.passportId, id);
    });

    test('a missing f reads as format 1', () {
      final result = PassportPayloadCodec.decode('p=$id');
      expect((result as PassportDecoded).payload.formatVersion, 1);
    });

    test('malformed percent-encoding is refused, never thrown', () {
      for (final text in [
        'https://submersion.app/c#f=1&p=$id&n=%zz',
        'https://submersion.app/c#f=1&p=$id&n=Tank%2',
        'https://submersion.app/c#f=1&p=$id&n=Bill+Ärger%',
      ]) {
        final result = PassportPayloadCodec.decode(text);
        expect(
          (result as PassportRejected).reason,
          PassportRejectReason.notATag,
          reason: text,
        );
      }
    });

    test('a longer path on the tag host is not a tag', () {
      for (final text in [
        'https://submersion.app/cfoo?f=1&p=$id',
        'https://submersion.app/community#f=1&p=$id',
        'https://submersion.app/c/extra#f=1&p=$id',
        'submersion://cx?f=1&p=$id',
      ]) {
        final result = PassportPayloadCodec.decode(text);
        expect(
          (result as PassportRejected).reason,
          PassportRejectReason.notATag,
          reason: text,
        );
      }
    });

    test('rejects text that is not a tag', () {
      final result = PassportPayloadCodec.decode('https://example.com/x');
      expect((result as PassportRejected).reason, PassportRejectReason.notATag);
    });

    test('rejects a missing or malformed id', () {
      expect(
        (PassportPayloadCodec.decode('f=1&w=2026-01-01') as PassportRejected)
            .reason,
        PassportRejectReason.missingId,
      );
      expect(
        (PassportPayloadCodec.decode('f=1&p=not-a-uuid') as PassportRejected)
            .reason,
        PassportRejectReason.malformedId,
      );
    });

    test(
      'drops out-of-range numbers and bad dates instead of trusting them',
      () {
        final result = PassportPayloadCodec.decode(
          'f=1&p=$id&v=99&wp=20&h=2024-13-40&m=xx&vt=zz',
        );
        final payload = (result as PassportDecoded).payload;
        expect(payload.volumeL, isNull);
        expect(payload.workingPressureBar, isNull);
        expect(payload.lastHydro, isNull);
        expect(payload.material, isNull);
        expect(payload.valve, isNull);
      },
    );

    test('keeps in-range boundaries', () {
      final result = PassportPayloadCodec.decode('f=1&p=$id&v=0.5&wp=400');
      final payload = (result as PassportDecoded).payload;
      expect(payload.volumeL, 0.5);
      expect(payload.workingPressureBar, 400);
    });
  });

  test('a serial is capped like the name', () {
    final p = CylinderPassportPayload(passportId: id, serial: 'X' * 60);
    final back = PassportPayloadCodec.decode(PassportPayloadCodec.encode(p));
    expect(
      (back as PassportDecoded).payload.serial,
      'X' * CylinderPassportPayload.maxSerialLength,
    );
  });

  test('reads the tag whatever the scheme case, http, or a www host', () {
    for (final text in [
      'HTTPS://SUBMERSION.APP/c#f=1&p=$id',
      'http://submersion.app/c#f=1&p=$id',
      'https://www.submersion.app/c#f=1&p=$id',
      'Submersion://c?f=1&p=$id',
    ]) {
      final result = PassportPayloadCodec.decode(text);
      expect((result as PassportDecoded).payload.passportId, id, reason: text);
    }
  });

  test('another host is never a tag', () {
    final result = PassportPayloadCodec.decode(
      'https://submersion.app.evil.example/c#f=1&p=$id',
    );
    expect((result as PassportRejected).reason, PassportRejectReason.notATag);
  });

  group('the newest fill', () {
    final fill = TagFill(
      id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
      filledAt: DateTime.utc(2026, 9, 28, 9, 30),
      o2Percent: 32.1,
      hePercent: 0,
      pressureBar: 232,
      temperatureC: 24.5,
      filledBy: 'Blue Hole',
      analyzer: 'Divesoft',
    );
    final base = CylinderPassportPayload(
      passportId: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
      writtenOn: DateTime(2026, 9, 28),
    );

    test('encodes after the cylinder keys, in order', () {
      expect(
        PassportPayloadCodec.encode(base.copyWith(fill: fill)),
        'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-28'
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09%3A30%3A00Z'
        '&fo=32.1&fh=0&fp=232&fc=24.5&fb=Blue+Hole&fa=Divesoft',
      );
    });

    test('round trips', () {
      final url = PassportPayloadCodec.httpsUrl(base.copyWith(fill: fill));
      final decoded = PassportPayloadCodec.decode(url) as PassportDecoded;
      expect(decoded.payload.fill, fill);
    });

    test('a tag without fill keys has no fill', () {
      final decoded =
          PassportPayloadCodec.decode(PassportPayloadCodec.httpsUrl(base))
              as PassportDecoded;
      expect(decoded.payload.fill, isNull);
    });

    test('a malformed fill is dropped and the tag still opens', () {
      const p = 'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
      for (final bad in [
        '&fi=nope&ft=2026-09-28T09:30:00Z&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=yesterday&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=80&fh=30',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z',
        // Dart reads NaN as a number, and NaN passes every range check.
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=NaN',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=21&fh=NaN',
      ]) {
        final r = PassportPayloadCodec.decode('$p$bad') as PassportDecoded;
        expect(r.payload.fill, isNull, reason: bad);
      }
    });

    test('out-of-range fill details are dropped, the fill kept', () {
      final r =
          PassportPayloadCodec.decode(
                'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab'
                '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
                '&ft=2026-09-28T09:30:00Z&fo=21&fp=900&fc=300',
              )
              as PassportDecoded;
      final f = r.payload.fill!;
      expect((f.o2Percent, f.pressureBar, f.temperatureC), (21.0, null, null));
    });

    test('the reserved signature key is ignored', () {
      final r =
          PassportPayloadCodec.decode(
                'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab'
                '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
                '&ft=2026-09-28T09:30:00Z&fo=21&fs=abc',
              )
              as PassportDecoded;
      expect(r.payload.fill, isNotNull);
    });
  });
}
