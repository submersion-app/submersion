import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/test_database.dart';

/// The cached removals of a library, for the Members and library pages
/// (issue #3481).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('lists the removals the last sync cached for the library', () async {
    final store = SharedLibraryStore();
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'a',
        prefix: 'site-sync',
      ),
    );
    final record = MemberRemoval(
      memberId: 'bo',
      displayName: 'Bo',
      removedAt: DateTime.utc(2026, 10, 18),
      removedBy: 'ann',
    );
    await store.setRemovals('L', [record]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(libraryRemovalsProvider('L'), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(libraryRemovalsProvider('L').future), [record]);
  });
}
