import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The diver's default equipment view (issue #2628) is stored as null until
/// it differs from the factory set.
void main() {
  test('the default view defaults to the factory set; copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
    expect(
      settings
          .copyWith(equipmentDefaultStatuses: {EquipmentStatus.active})
          .equipmentDefaultStatuses,
      {EquipmentStatus.active},
    );
  });

  group('DiverSettingsRepository default equipment view', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repository.createSettingsForDiver('d1');
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    Future<String?> stored() async =>
        (await db
                .customSelect(
                  'SELECT equipment_default_statuses AS v FROM diver_settings '
                  "WHERE diver_id = 'd1'",
                )
                .getSingle())
            .read<String?>('v');

    test('new settings read the factory set and store nothing', () async {
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
      expect(await stored(), isNull);
    });

    test('a custom set round-trips', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          equipmentDefaultStatuses: {
            EquipmentStatus.active,
            EquipmentStatus.retired,
          },
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, {
        EquipmentStatus.active,
        EquipmentStatus.retired,
      });
      expect(await stored(), '["active","retired"]');
    });

    test('going back to the factory set stores null again', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(equipmentDefaultStatuses: {EquipmentStatus.active}),
      );
      await repository.updateSettingsForDiver('d1', const AppSettings());
      expect(await stored(), isNull);
    });

    test('an unreadable stored value reads as the factory set', () async {
      await db.customStatement(
        "UPDATE diver_settings SET equipment_default_statuses = 'oops' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.equipmentDefaultStatuses, factoryDefaultEquipmentStatuses);
    });
  });
}
