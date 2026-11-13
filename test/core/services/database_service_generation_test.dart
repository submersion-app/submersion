import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

/// A cache that follows a connection's table ticks must know when the
/// database it follows is replaced in place (a storage-location move), or
/// it keeps listening to a closed connection (#4461).
void main() {
  tearDown(tearDownTestDatabase);

  test(
    'a new database instance moves the generation and announces it',
    () async {
      final service = DatabaseService.instance;
      final seen = <int>[];
      final sub = service.generationChanges.listen(seen.add);
      addTearDown(sub.cancel);

      await setUpTestDatabase();
      final first = service.generation;
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await pumpEventQueue();

      expect(service.generation, greaterThan(first));
      expect(seen, isNotEmpty);
      expect(seen.last, service.generation);
    },
  );
}
