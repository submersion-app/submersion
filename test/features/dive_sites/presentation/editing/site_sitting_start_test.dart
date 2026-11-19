import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_new_sitting.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';

/// Each of the site's held lists is loaded as a sitting starts and names
/// the library field its write changes, in one table, so a list cannot be
/// added to one without the other (issue #4527, phase 2).
void main() {
  test('every held list names a library field, once', () {
    final keys = [for (final list in siteHeldLists) list.key];
    expect(keys.toSet(), hasLength(keys.length));
    for (final list in siteHeldLists) {
      expect(list.libraryFields, isNotEmpty, reason: list.key);
    }
  });

  test('the table holds the site lists', () {
    expect(
      {for (final list in siteHeldLists) list.key},
      {
        siteTypesList.key,
        siteTagsList.key,
        siteSpeciesList.key,
        siteFeaturesList.key,
      },
    );
  });

  // A new site (issue #4527, plan 6) has no rows stored: its lists start
  // empty without a read. No database here, so any read would fail and
  // leave a list unloaded, its card unable to load and a duplicate's copy
  // of it dropped.
  group('a new site', () {
    late ProviderContainer container;
    late EditSession<DiveSite> session;

    setUp(() {
      container = ProviderContainer();
      session = EditSession<DiveSite>(
        const DiveSite(id: 'n1', diverId: 'me', name: ''),
        isNew: true,
      );
      startSiteSitting(session, container.read);
    });

    tearDown(() {
      session.dispose();
      container.dispose();
    });

    test('starts its lists empty without a read', () async {
      await session.settled();

      for (final list in [
        siteTypesList,
        siteTagsList,
        siteSpeciesList,
        siteFeaturesList,
      ]) {
        expect(list.loaded(session), isEmpty, reason: list.key);
        expect(list.failed(session), isFalse, reason: list.key);
      }
    });

    test('takes a duplicate\'s lists whole', () async {
      final at = DateTime.utc(2026, 11, 19);
      final source = (
        site: const DiveSite(id: 's1', diverId: 'me', name: 'Salt Pier'),
        types: const <Never>[],
        tags: [Tag(id: 'g1', name: 'Night', createdAt: at, updatedAt: at)],
        species: const <Never>[],
        features: const [
          SiteFeature(
            id: 'f1',
            siteId: 's1',
            typeName: 'mooring',
            latitude: 1,
            longitude: 2,
          ),
        ],
        sharing: ItemSharing.none,
      );

      await applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy',
        lookUpPlace: (_) async => throw StateError('offline'),
        fetchElevation: (_) async => null,
      );
      await session.settled();

      expect([for (final t in siteTagsList.current(session)!) t.id], ['g1']);
      expect(
        [for (final f in siteFeaturesList.current(session)!) f.id],
        ['f1'],
      );
      expect(session.changedCardIds, containsAll(['tags', 'features']));
    });
  });
}
