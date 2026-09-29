import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

void main() {
  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
  );
  final at = DateTime.utc(2026, 9, 28, 9, 30);
  final newest = CylinderFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    passportId: pid,
    equipmentId: id,
    filledAt: at,
    o2Percent: 32,
    createdAt: at,
    updatedAt: at,
  );

  ProviderContainer container({CylinderFill? fill}) {
    final c = ProviderContainer(
      overrides: [
        equipmentItemProvider(id).overrideWith((ref) async => tank),
        passportIdProvider(id).overrideWith((ref) async => pid),
        serviceClockStatusesProvider(id).overrideWith((ref) async => const []),
        serviceRecordsForEquipmentProvider(
          id,
        ).overrideWith((ref) async => const []),
        newestFillProvider(id).overrideWith((ref) async => fill),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an NFC write carries the newest fill', () async {
    final c = container(fill: newest);
    final sub = c.listen(tagPayloadProvider(id), (_, _) {});
    addTearDown(sub.close);
    final payload = await c.read(tagPayloadProvider(id).future);
    expect(payload!.passportId, pid);
    expect(payload.fill?.id, newest.id);
  });

  test('with no fills, the payload has no fill', () async {
    final c = container();
    final sub = c.listen(tagPayloadProvider(id), (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(tagPayloadProvider(id).future))!.fill, isNull);
  });
}
