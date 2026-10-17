import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

const _a = DiveSite(id: 'a', name: 'Österreich - Fernsteinsee');
const _b = DiveSite(id: 'b', name: 'Österreich - Samarangersee');
const _orphan = DiveSite(id: 'z', name: 'Not In The List');

final _withCounts = [
  SiteWithDiveCount(site: _a, diveCount: 4, lastDivedAt: DateTime(2015, 6, 28)),
  const SiteWithDiveCount(site: _b, diveCount: 1),
];

ProviderContainer _container(List<DiveSite> hits) {
  final container = ProviderContainer(
    overrides: [
      sitesWithCountsProvider.overrideWith((ref) async => _withCounts),
      siteSearchProvider.overrideWith((ref, query) async => hits),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Issue #3377: the search page showed every hit with a dive count of 0.
  test('hits carry the list figures, in the search order', () async {
    final container = _container([_b, _a]);

    final results = await container.read(
      siteSearchWithDiveCountProvider('öster').future,
    );

    expect(results.map((e) => e.site.id), ['b', 'a']);
    expect(results.map((e) => e.diveCount), [1, 4]);
    expect(results.last.lastDivedAt, DateTime(2015, 6, 28));
  });

  test('an empty query is the whole list', () async {
    final container = _container(const []);

    final results = await container.read(
      siteSearchWithDiveCountProvider('').future,
    );

    expect(results, _withCounts);
  });

  test('a hit the list does not know reads as never dived', () async {
    final container = _container([_orphan]);

    final results = await container.read(
      siteSearchWithDiveCountProvider('not').future,
    );

    expect(results, [const SiteWithDiveCount(site: _orphan, diveCount: 0)]);
  });
}
