import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// The setup one key of a transmitter passes to its other keys: what
/// `saveSetup` writes and what the agent's preview of that save reads.
void main() {
  final other = Transmitter(
    id: 'ch-0',
    diveComputerId: 'c1',
    channelIndex: 0,
    label: 'Left',
    volumeL: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    presetName: 'AL80',
    equipmentId: 'gear-old',
    isConfigured: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('takes the setup and keeps the key itself', () {
    final source = Transmitter(
      id: 'sn-1',
      transmitterSerial: '180777',
      label: 'Sidemount left',
      role: TankRole.sidemountLeft,
      volumeL: 12,
      workingPressureBar: 232,
      material: TankMaterial.steel,
      presetName: 'HP100',
      equipmentId: 'gear-new',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final result = other.withSetupOf(source);

    expect(result.role, TankRole.sidemountLeft);
    expect(result.volumeL, 12);
    expect(result.workingPressureBar, 232);
    expect(result.material, TankMaterial.steel);
    expect(result.presetName, 'HP100');
    expect(result.equipmentId, 'gear-new');
    expect(result.isConfigured, isTrue);
    expect(result.id, 'ch-0');
    expect(result.label, 'Left');
    expect(result.channelIndex, 0);
  });

  test("clears what the source's setup leaves empty", () {
    final source = Transmitter(
      id: 'sn-1',
      transmitterSerial: '180777',
      label: 'Sidemount left',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final result = other.withSetupOf(source);

    expect(result.volumeL, isNull);
    expect(result.workingPressureBar, isNull);
    expect(result.material, isNull);
    expect(result.presetName, isNull);
    expect(result.equipmentId, isNull);
  });
}
