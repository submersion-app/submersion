import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/site_dive_media_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('SiteDiveMediaRepository error handling', () {
    late SiteDiveMediaRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = SiteDiveMediaRepository();
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('countMediaFromDivesAtSite rethrows a database failure', () async {
      await expectLater(
        repository.countMediaFromDivesAtSite('s1'),
        throwsA(anything),
      );
    });

    test('getMediaFromDivesAtSite rethrows a database failure', () async {
      await expectLater(
        repository.getMediaFromDivesAtSite('s1'),
        throwsA(anything),
      );
    });
  });
}
