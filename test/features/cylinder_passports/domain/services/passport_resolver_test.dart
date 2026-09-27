import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tag = 'https://submersion.app/c#f=1&p=$id&w=2026-09-25&v=12';

  PassportResolver resolverWith(Map<String, String> held) =>
      PassportResolver(findEquipmentId: (passportId) async => held[passportId]);

  test('a tag the diver holds resolves to that cylinder', () async {
    final r = await resolverWith({id: 'eq-1'}).resolve(tag);
    expect(r, isA<OwnCylinder>());
    r as OwnCylinder;
    expect(r.equipmentId, 'eq-1');
    expect(r.tag.passportId, id);
    expect(r.tag.volumeL, 12);
    expect(r.newerFormat, isFalse);
  });

  test('a tag nobody holds resolves to a foreign cylinder', () async {
    final r = await resolverWith(const {}).resolve(tag);
    expect(r, isA<ForeignCylinder>());
    expect((r as ForeignCylinder).tag.passportId, id);
  });

  test('text that is not a tag says why', () async {
    final r = await resolverWith(const {}).resolve('https://example.com');
    expect((r as NotACylinderTag).reason, PassportRejectReason.notATag);
  });

  test('a newer format is reported, not refused', () async {
    final r = await resolverWith(
      const {},
    ).resolve('https://submersion.app/c#f=2&p=$id');
    expect((r as ForeignCylinder).newerFormat, isTrue);
  });

  test('the lookup is never called for text that is not a tag', () async {
    var calls = 0;
    final resolver = PassportResolver(
      findEquipmentId: (_) async {
        calls++;
        return null;
      },
    );
    await resolver.resolve('not a tag');
    expect(calls, 0);
  });
}
