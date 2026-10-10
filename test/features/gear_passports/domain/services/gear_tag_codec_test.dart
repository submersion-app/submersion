import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

GearTagPayload _full() => GearTagPayload(
  passportId: _id,
  typeCode: 'firstStage',
  writtenOn: DateTime(2026, 10, 10),
  name: 'Apeks XTX50 primary',
  brand: 'Apeks',
  model: 'XTX50',
  serial: 'AB12345',
  lastService: DateTime(2026, 3, 2),
);

GearTagPayload _decoded(String text) {
  final r = GearTagCodec.decode(text);
  expect(r, isA<GearTagDecoded>());
  return (r as GearTagDecoded).payload;
}

GearTagRejectReason _rejected(String text) {
  final r = GearTagCodec.decode(text);
  expect(r, isA<GearTagRejected>());
  return (r as GearTagRejected).reason;
}

void main() {
  group('encode', () {
    test('emits keys in fixed order, values encoded', () {
      expect(
        GearTagCodec.encode(_full()),
        'f=1&p=$_id&w=2026-10-10&t=firstStage&n=Apeks+XTX50+primary'
        '&b=Apeks&mo=XTX50&sn=AB12345&ls=2026-03-02',
      );
    });

    test('leaves out absent keys', () {
      expect(
        GearTagCodec.encode(
          const GearTagPayload(passportId: _id, typeCode: 'fins'),
        ),
        'f=1&p=$_id&t=fins',
      );
    });

    test('httpsUrl puts the payload in the fragment of /g', () {
      expect(
        GearTagCodec.httpsUrl(_full()),
        startsWith('https://submersion.app/g#f=1&p='),
      );
    });

    test('caps text by code points', () {
      final long = GearTagPayload(
        passportId: _id,
        typeCode: 'mask',
        name: 'n' * 50,
        brand: 'b' * 30,
        model: 'm' * 30,
        serial: 's' * 30,
      );
      final back = _decoded(GearTagCodec.httpsUrl(long));
      expect(back.name, 'n' * 40);
      expect(back.brand, 'b' * 24);
      expect(back.model, 'm' * 24);
      expect(back.serial, 's' * 24);
    });
  });

  group('decode', () {
    test('round trips every key', () {
      expect(_decoded(GearTagCodec.httpsUrl(_full())), _full());
    });

    test('round trips names with spaces, ampersands, hashes and accents', () {
      final p = _full().copyWith(name: 'Reg & #2 été');
      expect(_decoded(GearTagCodec.httpsUrl(p)).name, p.name);
    });

    test('accepts the custom scheme with a query', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('submersion://g?$q'), _full());
    });

    test('accepts http, www, upper case and a trailing slash', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('HTTP://WWW.Submersion.App/g/#$q'), _full());
    });

    test('accepts the payload in the query of the https form', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('https://submersion.app/g?$q'), _full());
    });

    test(
      'a cylinder link, a longer path, another host or a bare payload is not a gear tag',
      () {
        final q = GearTagCodec.encode(_full());
        expect(
          _rejected('https://submersion.app/c#$q'),
          GearTagRejectReason.notATag,
        );
        expect(
          _rejected('https://submersion.app/g/x#$q'),
          GearTagRejectReason.notATag,
        );
        expect(
          _rejected('https://example.com/g#$q'),
          GearTagRejectReason.notATag,
        );
        expect(_rejected(q), GearTagRejectReason.notATag);
      },
    );

    test('ignores unknown keys and reports a newer format', () {
      final r = GearTagCodec.decode(
        'https://submersion.app/g#f=2&p=$_id&t=bcd&zz=1',
      );
      expect(r, isA<GearTagDecoded>());
      expect((r as GearTagDecoded).newerFormat, isTrue);
      expect(r.payload.typeCode, 'bcd');
    });

    test('rejects a missing or malformed id', () {
      expect(
        _rejected('https://submersion.app/g#f=1&t=bcd'),
        GearTagRejectReason.missingId,
      );
      expect(
        _rejected('https://submersion.app/g#f=1&p=nope&t=bcd'),
        GearTagRejectReason.malformedId,
      );
    });

    test('rejects a missing type and a tank type', () {
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id'),
        GearTagRejectReason.missingType,
      );
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id&t=tank'),
        GearTagRejectReason.notGear,
      );
    });

    test('keeps an unknown type raw and maps it to no EquipmentType', () {
      final p = _decoded('https://submersion.app/g#f=1&p=$_id&t=jetpack');
      expect(p.typeCode, 'jetpack');
      expect(p.type, isNull);
    });

    test('maps a known type', () {
      expect(
        _decoded(GearTagCodec.httpsUrl(_full())).type,
        EquipmentType.firstStage,
      );
    });

    test('drops a bad date, never the tag', () {
      final p = _decoded(
        'https://submersion.app/g#f=1&p=$_id&t=bcd&w=2026-02-30&ls=nope',
      );
      expect(p.writtenOn, isNull);
      expect(p.lastService, isNull);
    });

    test('bad percent-encoding is not a tag', () {
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id&t=bcd&n=%zz'),
        GearTagRejectReason.notATag,
      );
    });

    test('upper-case ids are lower-cased', () {
      final p = _decoded(
        'https://submersion.app/g#f=1&p=${_id.toUpperCase()}&t=bcd',
      );
      expect(p.passportId, _id);
    });
  });
}
