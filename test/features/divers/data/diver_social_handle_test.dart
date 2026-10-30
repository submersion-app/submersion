import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

/// A diver's social handle and buddy card share choices (issue #3728).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => DatabaseService.instance.resetForTesting());

  test(
    'socialHandle and buddyCardShare survive create, update, read',
    () async {
      final repo = DiverRepository();
      final created = await repo.createDiver(
        Diver(
          id: 'd1',
          name: 'Jordan',
          socialHandle: '@jordan',
          buddyCardShare: '{"phone":false}',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      var read = await repo.getDiverById(created.id);
      expect(read!.socialHandle, '@jordan');
      expect(read.buddyCardShare, '{"phone":false}');

      await repo.updateDiver(read.copyWith(socialHandle: '@jb'));
      read = await repo.getDiverById(created.id);
      expect(read!.socialHandle, '@jb');
      expect(read.buddyCardShare, '{"phone":false}');
    },
  );
}
