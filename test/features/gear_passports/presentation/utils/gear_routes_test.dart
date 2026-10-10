import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';

void main() {
  const tag = GearTagPayload(
    passportId: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
    typeCode: 'bcd',
    name: 'Wing & co',
  );

  test('the gear passport lives under the item', () {
    expect(gearPassportLocation('eq-1'), '/equipment/eq-1/gear-passport');
  });

  test('a foreign gear tag rides in the query and round trips', () {
    final location = foreignGearLocation(tag);
    expect(location, startsWith('/equipment/gear-tag?t='));
    expect(
      foreignGearTagFromQuery(Uri.parse(location).queryParameters['t']),
      tag,
    );
  });

  test('anything else in the query or the extra is no tag', () {
    expect(foreignGearTagFromQuery(null), isNull);
    expect(foreignGearTagFromQuery('nope'), isNull);
    expect(scannedGearTagFrom(42), isNull);
    expect(scannedGearTagFrom(tag), tag);
  });
}
