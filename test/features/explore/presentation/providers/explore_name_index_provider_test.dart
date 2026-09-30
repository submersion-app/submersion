import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

/// The legacy `dives.buddy` names are Explore's alone (#2641), so a dive
/// write reloads them and not the shared index every query surface reads.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> container() async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(overrides: overrides.cast());
    addTearDown(c.dispose);
    await c.read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    // Keep both alive across writes, as the dive list and Explore do.
    final shared = c.listen(queryNameIndexProvider, (_, _) {});
    addTearDown(shared.close);
    final explore = c.listen(exploreNameIndexProvider, (_, _) {});
    addTearDown(explore.close);
    return c;
  }

  Iterable<String> legacyLabels(NameIndex index) => index
      .forSubject(QuerySubject.buddies)
      .where((e) => e.target == NameTarget.legacyBuddyName)
      .map((e) => e.label);

  test('holds the shared names followed by the legacy buddy names', () async {
    final c = await container();
    final shared = await c.read(queryNameIndexProvider.future);
    final index = await c.read(exploreNameIndexProvider.future);
    expect(index.entries.take(shared.entries.length), shared.entries);
    expect(legacyLabels(index), ['Bob']);
    expect(legacyLabels(shared), isEmpty);
    // A linked buddy still comes before any legacy text.
    expect(index.forSubject(QuerySubject.buddies).first.primary, isTrue);
  });

  test('a dive write reloads the legacy names, not the shared index', () async {
    final c = await container();
    final shared = await c.read(queryNameIndexProvider.future);
    await c.read(exploreNameIndexProvider.future);

    // Through the typed API, as the app writes: a raw customStatement is
    // not announced to tableUpdates.
    await (db.update(db.dives)..where((d) => d.id.equals('d4'))).write(
      const DivesCompanion(buddy: Value('Dee')),
    );
    // The tick is debounced; give it a moment.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(
      identical(await c.read(queryNameIndexProvider.future), shared),
      isTrue,
    );
    final index = await c.read(exploreNameIndexProvider.future);
    expect(legacyLabels(index), ['Bob', 'Dee']);
  });
}
