import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  test('reloads when a ref table changes', () async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    // Keep the provider alive across the write.
    final sub = container.listen(queryNameIndexProvider, (_, _) {});
    addTearDown(sub.close);

    final first = await container.read(queryNameIndexProvider.future);
    expect(first.labelOf(QuerySubject.sites, 's9'), isNull);

    // Through the typed API, as the app writes: a raw customStatement is
    // not announced to tableUpdates.
    final now = DateTime(2025, 6, 2).millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's9',
            name: 'New Wall',
            createdAt: now,
            updatedAt: now,
          ),
        );
    // The tick is debounced; give it a moment.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final second = await container.read(queryNameIndexProvider.future);
    expect(second.labelOf(QuerySubject.sites, 's9'), 'New Wall');
  });
}
