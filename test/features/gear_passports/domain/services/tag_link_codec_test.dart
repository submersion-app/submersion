import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

void main() {
  final cylinder = PassportPayloadCodec.httpsUrl(
    const CylinderPassportPayload(passportId: _id, name: 'Steel 12'),
  );
  final gear = GearTagCodec.httpsUrl(
    const GearTagPayload(passportId: _id, typeCode: 'bcd', name: 'Wing'),
  );

  test('a /c link decodes as a cylinder tag', () {
    final r = TagLinkCodec.decode(cylinder);
    expect(r, isA<CylinderTagLink>());
    expect((r as CylinderTagLink).payload.name, 'Steel 12');
    expect(r.passportId, _id);
  });

  test('a /g link decodes as a gear tag', () {
    final r = TagLinkCodec.decode(gear);
    expect(r, isA<GearTagLink>());
    expect((r as GearTagLink).payload.typeCode, 'bcd');
    expect(r.passportId, _id);
  });

  test('a bare payload is read as a cylinder tag, as before', () {
    expect(TagLinkCodec.decode('f=1&p=$_id'), isA<CylinderTagLink>());
  });

  test('a /g link that fails to decode is rejected, not tried as /c', () {
    expect(
      TagLinkCodec.decode('https://submersion.app/g#f=1&p=$_id'),
      isA<TagLinkRejected>(),
    );
  });

  test('anything else is rejected', () {
    expect(TagLinkCodec.decode('https://example.com'), isA<TagLinkRejected>());
    expect(TagLinkCodec.isTagLink('hello'), isFalse);
  });

  test('isTagLink and passportIdOf accept both kinds', () {
    expect(TagLinkCodec.isTagLink(cylinder), isTrue);
    expect(TagLinkCodec.isTagLink(gear), isTrue);
    expect(TagLinkCodec.passportIdOf(gear), _id);
    expect(TagLinkCodec.passportIdOf('nope'), isNull);
  });
}
