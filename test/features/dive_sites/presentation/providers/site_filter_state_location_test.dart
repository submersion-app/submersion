import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// SiteFilterState.apply()'s country/region matching (issue #1373).
///
/// The filter values now always come from the dropdown's enumerated site
/// values rather than free-typed partial text, so matching must be exact
/// (case-/whitespace-insensitive), not a substring test - otherwise picking
/// one specific entry would also match unrelated but textually overlapping
/// values.
void main() {
  SiteWithDiveCount site(String id, {String? country, String? region}) =>
      SiteWithDiveCount(
        site: DiveSite(id: id, name: id, country: country, region: region),
        diveCount: 0,
      );

  final sites = [
    site('sinai', region: 'Sinai'),
    site('southSinai', region: 'South Sinai'),
    site('congo', country: 'Congo'),
    site('drCongo', country: 'Democratic Republic of Congo'),
  ];

  test('a region filter does not also match a region containing it', () {
    const filter = SiteFilterState(region: 'Sinai');
    final result = filter.apply(sites);

    expect(result.map((s) => s.site.id), ['sinai']);
  });

  test('a country filter does not also match a country containing it', () {
    const filter = SiteFilterState(country: 'Congo');
    final result = filter.apply(sites);

    expect(result.map((s) => s.site.id), ['congo']);
  });

  test('matches case-/whitespace-insensitively', () {
    const filter = SiteFilterState(region: ' sinai ');
    final result = filter.apply(sites);

    expect(result.map((s) => s.site.id), ['sinai']);
  });
}
