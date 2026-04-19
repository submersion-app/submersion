import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppSettingsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = AppSettingsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('AppSettingsRepository.getShareByDefault', () {
    test('returns false when key is absent', () async {
      expect(await repository.getShareByDefault(), isFalse);
    });

    test('round-trips true', () async {
      await repository.setShareByDefault(true);
      expect(await repository.getShareByDefault(), isTrue);
    });

    test('round-trips false after being set to true', () async {
      await repository.setShareByDefault(true);
      await repository.setShareByDefault(false);
      expect(await repository.getShareByDefault(), isFalse);
    });
  });
}
