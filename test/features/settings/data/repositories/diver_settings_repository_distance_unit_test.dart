import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
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
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('new settings default to kilometres', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.kilometers);
  });

  test('createSettingsForDiver stores the given distance unit', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(distanceUnit: DistanceUnit.miles),
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.miles);
  });

  for (final unit in DistanceUnit.values) {
    test('round-trips ${unit.name}', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(distanceUnit: unit),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.distanceUnit, unit);
    });
  }

  test('an unrecognized stored value degrades to kilometres', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(distanceUnit: DistanceUnit.miles),
    );
    await db.customStatement(
      "UPDATE diver_settings SET distance_unit = 'leagues' "
      "WHERE diver_id = 'd1'",
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.distanceUnit, DistanceUnit.kilometers);
  });
}
