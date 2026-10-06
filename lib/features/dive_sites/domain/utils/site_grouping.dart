import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Key of the group holding sites with no country. A real country key is
/// never empty, because a blank country counts as no country.
const String noCountryGroupKey = '';

/// The group key of [site]'s country: trimmed and case/accent folded, or
/// [noCountryGroupKey] when the country is null or blank.
String siteCountryKey(DiveSite site) {
  final country = site.country?.trim() ?? '';
  return country.isEmpty ? noCountryGroupKey : textSortKey(country);
}

/// The sites of one region inside a [SiteCountryGroup].
class SiteRegionGroup<T> {
  const SiteRegionGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;

  /// The region's commonest spelling among its sites.
  final String label;

  final List<T> items;
}

/// The sites of one country, split into those with no region and per-region
/// subgroups (#1080).
class SiteCountryGroup<T> {
  const SiteCountryGroup({
    required this.key,
    required this.label,
    required this.unregioned,
    required this.regions,
  });

  final String key;

  /// The country's commonest spelling, or empty for the no-country group,
  /// whose label the UI supplies ("No country").
  final String label;

  /// Sites with no region, listed before the region subgroups.
  final List<T> unregioned;

  final List<SiteRegionGroup<T>> regions;

  bool get isNoCountry => key == noCountryGroupKey;

  int get siteCount =>
      unregioned.length +
      regions.fold<int>(0, (sum, region) => sum + region.items.length);

  /// Every site in display order: unregioned first, then each region.
  Iterable<T> get allItems sync* {
    yield* unregioned;
    for (final region in regions) {
      yield* region.items;
    }
  }
}

/// Accumulates one country or region while grouping; never escapes
/// [groupSitesByLocation].
class _Bucket<T> {
  final spellings = <String>[];
  final items = <T>[];
  final regions = <String, _Bucket<T>>{};
}

/// Groups [items] by country, then region, for a site list or picker.
///
/// Countries order alphabetically (accent and case folded) with the
/// no-country group last; regions order the same way after the country's
/// unregioned sites. Items keep their input order inside each group, so the
/// caller's sort carries through.
List<SiteCountryGroup<T>> groupSitesByLocation<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) {
  final countries = <String, _Bucket<T>>{};
  for (final item in items) {
    final site = siteOf(item);
    final countryKey = siteCountryKey(site);
    final country = countries.putIfAbsent(countryKey, _Bucket<T>.new);
    if (countryKey != noCountryGroupKey) {
      country.spellings.add(site.country!.trim());
    }
    final region = site.region?.trim() ?? '';
    if (region.isEmpty) {
      country.items.add(item);
      continue;
    }
    final regionBucket = country.regions.putIfAbsent(
      textSortKey(region),
      _Bucket<T>.new,
    );
    regionBucket.spellings.add(region);
    regionBucket.items.add(item);
  }

  final collator = TextCollator();
  final groups = [
    for (final entry in countries.entries)
      SiteCountryGroup<T>(
        key: entry.key,
        label: entry.key == noCountryGroupKey
            ? ''
            : _commonest(entry.value.spellings),
        unregioned: List.unmodifiable(entry.value.items),
        regions: List.unmodifiable(
          [
            for (final region in entry.value.regions.entries)
              SiteRegionGroup<T>(
                key: region.key,
                label: _commonest(region.value.spellings),
                items: List.unmodifiable(region.value.items),
              ),
          ]..sort((a, b) => collator.compare(a.label, b.label)),
        ),
      ),
  ];
  groups.sort((a, b) {
    if (a.isNoCountry != b.isNoCountry) return a.isNoCountry ? 1 : -1;
    return collator.compare(a.label, b.label);
  });
  return List.unmodifiable(groups);
}

/// The most frequent spelling; a tie keeps the one seen first.
String _commonest(List<String> spellings) {
  final counts = <String, int>{};
  for (final spelling in spellings) {
    counts[spelling] = (counts[spelling] ?? 0) + 1;
  }
  var best = spellings.first;
  var bestCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

/// One row of a grouped site list.
sealed class SiteListRow<T> {
  const SiteListRow();
}

final class CountryHeaderRow<T> extends SiteListRow<T> {
  const CountryHeaderRow({required this.group, required this.isExpanded});

  final SiteCountryGroup<T> group;
  final bool isExpanded;
}

final class RegionHeaderRow<T> extends SiteListRow<T> {
  const RegionHeaderRow(this.label);

  final String label;
}

final class SiteRow<T> extends SiteListRow<T> {
  const SiteRow(this.item);

  final T item;
}

/// Flattens [groups] into rows for one lazy list. A country whose key is not
/// in [expanded] contributes only its header.
List<SiteListRow<T>> flattenSiteGroups<T>(
  List<SiteCountryGroup<T>> groups, {
  required Set<String> expanded,
}) => [
  for (final group in groups) ...[
    CountryHeaderRow<T>(group: group, isExpanded: expanded.contains(group.key)),
    if (expanded.contains(group.key)) ...[
      for (final item in group.unregioned) SiteRow<T>(item),
      for (final region in group.regions) ...[
        RegionHeaderRow<T>(region.label),
        for (final item in region.items) SiteRow<T>(item),
      ],
    ],
  ],
];

/// The countries a grouped list opens with: the [selected] site's country,
/// and the only group when there is just one.
Set<String> initialExpandedCountries<T>(
  List<SiteCountryGroup<T>> groups, {
  DiveSite? selected,
}) => {
  if (groups.length == 1) groups.single.key,
  if (selected != null) siteCountryKey(selected),
};

/// A copy of [keys] with [key] removed if present, else added: one country
/// header tap.
Set<String> toggleCountryKey(Set<String> keys, String key) =>
    keys.contains(key) ? (keys.toSet()..remove(key)) : {...keys, key};

/// Every group key, for "a search or filter is active, open everything".
Set<String> allCountryKeys<T>(List<SiteCountryGroup<T>> groups) => {
  for (final group in groups) group.key,
};
