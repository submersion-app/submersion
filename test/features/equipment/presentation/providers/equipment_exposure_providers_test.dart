import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Exposure totals are derived on read from the same samples the service
/// clocks and the condition engine use, classified with the diver's
/// current thresholds. Nothing is stored.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockSettingsNotifier settings;

  setUp(() async {
    db = await setUpTestDatabase();
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    required int dateMs,
    int runtime = 3600,
    double? maxDepth,
    double? waterTemp,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: dateMs,
        ).copyWith(
          runtime: Value(runtime),
          maxDepth: Value(maxDepth),
          waterTemp: Value(waterTemp),
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
  final t2 = DateTime.utc(2026, 2, 10).millisecondsSinceEpoch;
  final t3 = DateTime.utc(2026, 3, 10).millisecondsSinceEpoch;

  Future<EquipmentItem> regulatorWithThreeDives() async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await insertDive('cold', dateMs: t1, waterTemp: 5, maxDepth: 12);
    await insertDive('deep', dateMs: t2, waterTemp: 22, maxDepth: 35);
    await insertDive('plain', dateMs: t3, waterTemp: 24, maxDepth: 18);
    for (final d in ['cold', 'deep', 'plain']) {
      await link(d, reg.id);
    }
    return reg;
  }

  test('totals every unit, the dive count and the date range', () async {
    final reg = await regulatorWithThreeDives();
    final totals = await container.read(
      equipmentExposureTotalsProvider(reg.id).future,
    );
    expect(totals.byUnit[ExposureUnit.dives], 3);
    expect(totals.byUnit[ExposureUnit.coldDives], 1);
    expect(totals.byUnit[ExposureUnit.deepCycles], 1);
    expect(totals.byUnit[ExposureUnit.hours], closeTo(3.0, 1e-9));
    expect(totals.byUnit.containsKey(ExposureUnit.days), isFalse);
    expect(totals.diveCount, 3);
    expect(totals.firstDive, DateTime.utc(2026, 1, 10));
    expect(totals.lastDive, DateTime.utc(2026, 3, 10));
  });

  test('an unknown item yields the empty totals', () async {
    final totals = await container.read(
      equipmentExposureTotalsProvider('nope').future,
    );
    expect(totals, EquipmentExposureTotals.empty);
    expect(totals.firstDive, isNull);
  });

  test('a threshold change reclassifies on the next read', () async {
    final reg = await regulatorWithThreeDives();
    final before = await container.read(
      equipmentExposureTotalsProvider(reg.id).future,
    );
    expect(before.byUnit[ExposureUnit.coldDives], 1);
    await settings.setColdWaterThresholdC(4);
    container.invalidate(equipmentExposureTotalsProvider(reg.id));
    final after = await container.read(
      equipmentExposureTotalsProvider(reg.id).future,
    );
    expect(after.byUnit[ExposureUnit.coldDives], isNull);
  });
}
