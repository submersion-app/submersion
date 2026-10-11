import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_resolver.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
const _cylinder = 'https://submersion.app/c#f=1&p=$_id&n=Steel';
const _gear = 'https://submersion.app/g#f=1&p=$_id&t=bcd&n=Wing';

TagResolver _resolver(PassportHolder? holder) =>
    TagResolver(findHolder: (_) async => holder);

void main() {
  test('own gear resolves with its current type and the gear link', () async {
    final r = await _resolver((
      equipmentId: 'eq',
      type: EquipmentType.bcd,
    )).resolve(_gear);
    expect(r, isA<OwnTaggedItem>());
    r as OwnTaggedItem;
    expect(r.equipmentId, 'eq');
    expect(r.type, EquipmentType.bcd);
    expect(r.link, isA<GearTagLink>());
  });

  test('a cylinder tag on an item now a regulator resolves as own', () async {
    final r = await _resolver((
      equipmentId: 'eq',
      type: EquipmentType.regulator,
    )).resolve(_cylinder);
    expect((r as OwnTaggedItem).type, EquipmentType.regulator);
    expect(r.link, isA<CylinderTagLink>());
  });

  test('misses are foreign, by tag kind', () async {
    expect(await _resolver(null).resolve(_cylinder), isA<ForeignCylinderTag>());
    final g = await _resolver(null).resolve(_gear);
    expect(g, isA<ForeignGearTag>());
    expect((g as ForeignGearTag).tag.name, 'Wing');
  });

  test('text that is no tag is unreadable, and nothing is looked up', () async {
    var looked = false;
    final r = await TagResolver(
      findHolder: (_) async {
        looked = true;
        return null;
      },
    ).resolve('hello');
    expect(r, isA<UnreadableTag>());
    expect(looked, isFalse);
  });

  test('the newer-format flag rides along on a foreign gear tag', () async {
    final r = await _resolver(
      null,
    ).resolve('https://submersion.app/g#f=2&p=$_id&t=bcd');
    expect((r as ForeignGearTag).newerFormat, isTrue);
  });
}
