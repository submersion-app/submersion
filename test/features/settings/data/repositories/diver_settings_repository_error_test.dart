import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiverSettingsRepository error handling', () {
    late DiverSettingsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiverSettingsRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      // getSettingsForDiver - rethrows
      await expectLater(
        repository.getSettingsForDiver('d1'),
        throwsA(anything),
      );

      // createSettingsForDiver - rethrows
      await expectLater(
        repository.createSettingsForDiver('d1'),
        throwsA(anything),
      );

      // updateSettingsForDiver - rethrows
      await expectLater(
        repository.updateSettingsForDiver('d1', const AppSettings()),
        throwsA(anything),
      );

      // deleteSettingsForDiver - rethrows
      await expectLater(
        repository.deleteSettingsForDiver('d1'),
        throwsA(anything),
      );
    });
  });
}
