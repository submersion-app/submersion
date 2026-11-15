import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

import '../../../../helpers/test_database.dart';

/// Merging two sites that were each adopted from a catalogue record keeps
/// one link. The survivor remembers the other record as one it stands for,
/// so that record is not offered to the diver again.
void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  // The merge page hands over a site built from its form: no link, no
  // answers.
  const merged = DiveSite(id: 'survivor', name: 'Reef (merged)');

  Future<DiveSite> mergeInto({
    required DiveSite survivor,
    required List<DiveSite> others,
  }) async {
    await sites.createSite(survivor);
    for (final other in others) {
      await sites.createSite(other);
    }
    await sites.mergeSites(
      mergedSite: merged,
      siteIds: ['survivor', for (final other in others) other.id],
    );
    return (await sites.getSiteById('survivor'))!;
  }

  test('the survivor stands for the merged site\'s record', () async {
    final site = await mergeInto(
      survivor: const DiveSite(id: 'survivor', name: 'Reef', catalogueId: 'r1'),
      others: const [DiveSite(id: 'other', name: 'Reef 2', catalogueId: 'r2')],
    );

    expect(site.catalogueId, 'r1');
    expect(site.catalogueAnswers.also, {'r2'});
  });

  test('a link the survivor takes over is not also listed', () async {
    final site = await mergeInto(
      survivor: const DiveSite(id: 'survivor', name: 'Reef'),
      others: const [
        DiveSite(id: 'a', name: 'Reef 2', catalogueId: 'r2'),
        DiveSite(id: 'b', name: 'Reef 3', catalogueId: 'r3'),
      ],
    );

    expect(site.catalogueId, 'r2');
    expect(site.catalogueAnswers.also, {'r3'});
  });

  test('records a merged site stood for carry over', () async {
    final site = await mergeInto(
      survivor: const DiveSite(
        id: 'survivor',
        name: 'Reef',
        catalogueId: 'r1',
        catalogueAnswers: SiteCatalogueAnswers(also: {'r5'}),
      ),
      others: const [
        DiveSite(
          id: 'other',
          name: 'Reef 2',
          catalogueId: 'r2',
          catalogueAnswers: SiteCatalogueAnswers(also: {'r6'}),
        ),
      ],
    );

    expect(site.catalogueAnswers.also, {'r2', 'r5', 'r6'});
  });

  test(
    '"not this site" answers are united, less what is now claimed',
    () async {
      final site = await mergeInto(
        survivor: const DiveSite(
          id: 'survivor',
          name: 'Reef',
          catalogueId: 'r1',
          catalogueAnswers: SiteCatalogueAnswers(notSame: {'r2', 'r7'}),
        ),
        others: const [
          DiveSite(
            id: 'other',
            name: 'Reef 2',
            catalogueId: 'r2',
            catalogueAnswers: SiteCatalogueAnswers(notSame: {'r1', 'r8'}),
          ),
        ],
      );

      expect(site.catalogueAnswers.notSame, {'r7', 'r8'});
    },
  );

  test('declined details are kept for the surviving link only', () async {
    final site = await mergeInto(
      survivor: const DiveSite(
        id: 'survivor',
        name: 'Reef',
        catalogueId: 'r1',
        catalogueAnswers: SiteCatalogueAnswers(
          declined: {
            'r1': {'depth'},
          },
        ),
      ),
      others: const [
        DiveSite(
          id: 'other',
          name: 'Reef 2',
          catalogueId: 'r2',
          catalogueAnswers: SiteCatalogueAnswers(
            declined: {
              'r2': {'entry'},
            },
          ),
        ),
      ],
    );

    expect(site.catalogueAnswers.declined, {
      'r1': {'depth'},
    });
  });

  test('sites with no link and no answers merge to none', () async {
    final site = await mergeInto(
      survivor: const DiveSite(id: 'survivor', name: 'Reef'),
      others: const [DiveSite(id: 'other', name: 'Reef 2')],
    );

    expect(site.catalogueId, isNull);
    expect(site.catalogueAnswers, SiteCatalogueAnswers.empty);
  });

  test('undoing a merge restores each site\'s link and answers', () async {
    const survivorAnswers = SiteCatalogueAnswers(notSame: {'r7'});
    const otherAnswers = SiteCatalogueAnswers(
      also: {'r6'},
      declined: {
        'r2': {'entry'},
      },
    );
    await sites.createSite(
      const DiveSite(
        id: 'survivor',
        name: 'Reef',
        catalogueId: 'r1',
        catalogueAnswers: survivorAnswers,
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'other',
        name: 'Reef 2',
        catalogueId: 'r2',
        catalogueAnswers: otherAnswers,
      ),
    );
    final snapshot = await sites.mergeSites(
      mergedSite: merged,
      siteIds: ['survivor', 'other'],
    );

    await sites.undoMerge(snapshot!);

    final survivor = (await sites.getSiteById('survivor'))!;
    final other = (await sites.getSiteById('other'))!;
    expect(survivor.catalogueId, 'r1');
    expect(survivor.catalogueAnswers, survivorAnswers);
    expect(other.catalogueId, 'r2');
    expect(other.catalogueAnswers, otherAnswers);
  });
}
