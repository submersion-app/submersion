import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// How the Dive Sites list is grouped (#1080, #3270). Session-only, like the
/// list's sort. The combined values group by the first-named field, then by
/// the second, nested inside it.
enum SiteGroupBy { none, location, water, locationAndWater, library }

/// Key of the group holding sites with no value for the field grouped by. A
/// real key is never empty, because a blank value counts as "none". Shared
/// by every grouping axis (country, body of water): the two never compare
/// against each other, so the same sentinel works for both.
const String noGroupKey = '';

/// The group key of [site]'s country: trimmed and case/accent folded, or
/// [noGroupKey] when the country is null or blank.
String siteCountryKey(DiveSite site) => _groupKey(site.country);

/// The group key of [site]'s body of water: trimmed and case/accent folded,
/// or [noGroupKey] when it is null or blank.
String siteBodyOfWaterKey(DiveSite site) => _groupKey(site.bodyOfWater);

/// The group key of [site]'s shared site library (issue #2567): its id, folded
/// like every other key, or [noGroupKey] for a personal site.
String siteLibraryKey(DiveSite site) => _groupKey(site.sharedLibraryId);

String _groupKey(String? raw) {
  final value = raw?.trim() ?? '';
  return value.isEmpty ? noGroupKey : textSortKey(value);
}

/// The outer-grouping key function matching [groupBy]'s outer axis: country
/// for the two country-based modes, body of water for the water-only mode.
/// Never called for [SiteGroupBy.none], which has no groups.
///
/// A switch rather than a ternary: adding a grouping mode without extending
/// this one is then a compile error, not a silent fall-through to the wrong
/// axis.
String Function(DiveSite) outerKeyOfMode(SiteGroupBy groupBy) =>
    switch (groupBy) {
      SiteGroupBy.water => siteBodyOfWaterKey,
      SiteGroupBy.library => siteLibraryKey,
      SiteGroupBy.none ||
      SiteGroupBy.location ||
      SiteGroupBy.locationAndWater => siteCountryKey,
    };

/// The subgroup-axis key function matching [groupBy]'s inner axis, or null
/// for a mode with no subgrouping. Never called for [SiteGroupBy.none].
String Function(DiveSite)? innerKeyOfMode(SiteGroupBy groupBy) =>
    switch (groupBy) {
      SiteGroupBy.location => (site) => _groupKey(site.region),
      SiteGroupBy.locationAndWater => siteBodyOfWaterKey,
      SiteGroupBy.none || SiteGroupBy.water || SiteGroupBy.library => null,
    };

/// Whether [groupBy]'s inner axis bundles sites with no value into a titled
/// subgroup of its own (see [_groupSites]'s `bundleUnlabeledInner`) rather
/// than leaving them in the outer group's plain [SiteOuterGroup.ungrouped]
/// list. Only [SiteGroupBy.locationAndWater] does, since body of water is
/// commonly blank; region never has, since #1080 (only meaningful for a mode
/// [innerKeyOfMode] gives a key function for).
bool bundlesUnlabeledInner(SiteGroupBy groupBy) =>
    groupBy == SiteGroupBy.locationAndWater;

/// The expansion-state key for the subgroup [subKey] of outer group
/// [outerKey], so the same region or body-of-water name under two different
/// outer groups toggles independently. Shares one expansion set with outer
/// groups (both start closed), distinguished by this prefix rather than a
/// separate set, since a subgroup is in every other respect a header like
/// any other.
String subGroupExpansionKey(String outerKey, String subKey) =>
    '$outerKey\u0000$subKey';

/// The sites of one subgroup (a region or a body of water) inside a
/// [SiteOuterGroup].
class SiteSubGroup<T> {
  const SiteSubGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;

  /// The subgroup's commonest spelling among its sites, or empty for the
  /// ungrouped subgroup, whose label the UI supplies ("No body of water").
  final String label;

  final List<T> items;

  bool get isUngroupedKey => key == noGroupKey;
}

/// The sites sharing one outer-grouping value (a country or a body of
/// water), split into those with no subgroup value and per-subgroup
/// subgroups (#1080, #3270).
class SiteOuterGroup<T> {
  const SiteOuterGroup({
    required this.key,
    required this.label,
    required this.ungrouped,
    required this.subgroups,
  });

  final String key;

  /// The group's commonest spelling, or empty for the ungrouped group, whose
  /// label the UI supplies ("No country", "No body of water").
  final String label;

  /// Sites with no subgroup value, listed before the subgroups. Empty for a
  /// grouping that bundles those sites into an ungrouped subgroup instead
  /// (see [_groupSites]'s `bundleUnlabeledInner`).
  final List<T> ungrouped;

  final List<SiteSubGroup<T>> subgroups;

  bool get isUngroupedKey => key == noGroupKey;

  int get siteCount =>
      ungrouped.length +
      subgroups.fold<int>(0, (sum, subgroup) => sum + subgroup.items.length);

  /// Every site in display order: ungrouped first, then each subgroup.
  Iterable<T> get allItems sync* {
    yield* ungrouped;
    for (final subgroup in subgroups) {
      yield* subgroup.items;
    }
  }
}

/// Accumulates one outer or subgroup bucket while grouping; never escapes
/// [_groupSites].
class _Bucket<T> {
  final spellings = <String>[];
  final items = <T>[];
  final subBuckets = <String, _Bucket<T>>{};
}

/// Groups [items] by [outerRawOf], then by [innerRawOf] when given, for a
/// site list or picker.
///
/// Outer groups order alphabetically (accent and case folded) with the
/// ungrouped group last; subgroups order the same way after the outer
/// group's ungrouped sites (or, with [bundleUnlabeledInner], after its last
/// named subgroup, since the ungrouped subgroup then sorts like any other
/// ungrouped entry). Items keep their input order inside every group, so the
/// caller's sort carries through.
///
/// [bundleUnlabeledInner] decides what an item with no inner-axis value
/// joins: the outer group's plain [SiteOuterGroup.ungrouped] list (false,
/// the long-standing region behaviour, #1080), or a titled "ungrouped"
/// subgroup of its own (true, body-of-water's behaviour, #3270) -- body of
/// water is often missing per-site, so leaving those sites unbundled would
/// read as a wall of untitled rows before the first named subgroup.
List<SiteOuterGroup<T>> _groupSites<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
  String Function(DiveSite) outerRawOf,
  String Function(DiveSite)? innerRawOf, {
  bool bundleUnlabeledInner = false,
}) {
  final outers = <String, _Bucket<T>>{};
  for (final item in items) {
    final site = siteOf(item);
    final outerRaw = outerRawOf(site).trim();
    final outerKey = _groupKey(outerRaw);
    final outer = outers.putIfAbsent(outerKey, _Bucket<T>.new);
    if (outerKey != noGroupKey) {
      outer.spellings.add(outerRaw);
    }

    final innerRaw = innerRawOf == null ? '' : innerRawOf(site).trim();
    if (innerRaw.isEmpty) {
      if (innerRawOf != null && bundleUnlabeledInner) {
        outer.subBuckets
            .putIfAbsent(noGroupKey, _Bucket<T>.new)
            .items
            .add(item);
      } else {
        outer.items.add(item);
      }
      continue;
    }
    final innerBucket = outer.subBuckets.putIfAbsent(
      textSortKey(innerRaw),
      _Bucket<T>.new,
    );
    innerBucket.spellings.add(innerRaw);
    innerBucket.items.add(item);
  }

  final collator = TextCollator();
  final groups = [
    for (final entry in outers.entries)
      SiteOuterGroup<T>(
        key: entry.key,
        label: entry.key == noGroupKey ? '' : _commonest(entry.value.spellings),
        ungrouped: List.unmodifiable(entry.value.items),
        subgroups: List.unmodifiable(
          [
            for (final sub in entry.value.subBuckets.entries)
              SiteSubGroup<T>(
                key: sub.key,
                label: sub.key == noGroupKey
                    ? ''
                    : _commonest(sub.value.spellings),
                items: List.unmodifiable(sub.value.items),
              ),
          ]..sort(
            (a, b) => _compareUngroupedLast(
              a.isUngroupedKey,
              a.label,
              b.isUngroupedKey,
              b.label,
              collator,
            ),
          ),
        ),
      ),
  ];
  groups.sort(
    (a, b) => _compareUngroupedLast(
      a.isUngroupedKey,
      a.label,
      b.isUngroupedKey,
      b.label,
      collator,
    ),
  );
  return List.unmodifiable(groups);
}

/// Orders the ungrouped group or subgroup last, everything else by label --
/// shared by the outer-group and subgroup sorts in [_groupSites].
int _compareUngroupedLast(
  bool aUngrouped,
  String aLabel,
  bool bUngrouped,
  String bLabel,
  TextCollator collator,
) {
  if (aUngrouped != bUngrouped) return aUngrouped ? 1 : -1;
  return collator.compare(aLabel, bLabel);
}

/// Groups [items] by country, then region (#1080).
List<SiteOuterGroup<T>> groupSitesByLocation<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) => _groupSites(
  items,
  siteOf,
  (site) => site.country ?? '',
  (site) => site.region ?? '',
);

/// Groups [items] by shared site library, with no further subgrouping (issue
/// #2567). The group label is the library id; the list maps it to the
/// library's name, which the domain does not know.
List<SiteOuterGroup<T>> groupSitesByLibrary<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) => _groupSites(items, siteOf, (site) => site.sharedLibraryId ?? '', null);

/// Groups [items] by body of water, with no further subgrouping (#3270).
List<SiteOuterGroup<T>> groupSitesByWater<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) => _groupSites(items, siteOf, (site) => site.bodyOfWater ?? '', null);

/// Groups [items] by country, then body of water (#3270). Sites with no
/// body of water join a titled "No body of water" subgroup of their own
/// rather than sitting unbundled above it, since that field is commonly
/// blank.
List<SiteOuterGroup<T>> groupSitesByLocationAndWater<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) => _groupSites(
  items,
  siteOf,
  (site) => site.country ?? '',
  (site) => site.bodyOfWater ?? '',
  bundleUnlabeledInner: true,
);

/// The grouping [groupBy] asks for, or an empty list for [SiteGroupBy.none].
List<SiteOuterGroup<T>> groupSitesFor<T>(
  SiteGroupBy groupBy,
  List<T> items,
  DiveSite Function(T) siteOf,
) => switch (groupBy) {
  SiteGroupBy.none => const [],
  SiteGroupBy.location => groupSitesByLocation(items, siteOf),
  SiteGroupBy.water => groupSitesByWater(items, siteOf),
  SiteGroupBy.locationAndWater => groupSitesByLocationAndWater(items, siteOf),
  SiteGroupBy.library => groupSitesByLibrary(items, siteOf),
};

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

final class OuterHeaderRow<T> extends SiteListRow<T> {
  const OuterHeaderRow({required this.group, required this.isExpanded});

  final SiteOuterGroup<T> group;
  final bool isExpanded;
}

final class SubHeaderRow<T> extends SiteListRow<T> {
  const SubHeaderRow({
    required this.outerKey,
    required this.subgroup,
    required this.isExpanded,
  });

  /// The key of the outer group this subgroup nests inside, needed to build
  /// its [subGroupExpansionKey].
  final String outerKey;

  final SiteSubGroup<T> subgroup;

  final bool isExpanded;

  /// This subgroup's key in the shared expansion set.
  String get expansionKey => subGroupExpansionKey(outerKey, subgroup.key);
}

final class SiteRow<T> extends SiteListRow<T> {
  const SiteRow(this.item);

  final T item;
}

/// Flattens [groups] into rows for one lazy list. An outer group whose key
/// is not in [expanded] contributes only its header; a subgroup whose
/// [subGroupExpansionKey] is not in [expanded] likewise contributes only its
/// own header, once its outer group is open. Both start closed.
List<SiteListRow<T>> flattenSiteGroups<T>(
  List<SiteOuterGroup<T>> groups, {
  required Set<String> expanded,
}) => [
  for (final group in groups) ...[
    OuterHeaderRow<T>(group: group, isExpanded: expanded.contains(group.key)),
    if (expanded.contains(group.key)) ...[
      for (final item in group.ungrouped) SiteRow<T>(item),
      for (final subgroup in group.subgroups) ...[
        SubHeaderRow<T>(
          outerKey: group.key,
          subgroup: subgroup,
          isExpanded: expanded.contains(
            subGroupExpansionKey(group.key, subgroup.key),
          ),
        ),
        if (expanded.contains(subGroupExpansionKey(group.key, subgroup.key)))
          for (final item in subgroup.items) SiteRow<T>(item),
      ],
    ],
  ],
];

/// The groups a grouped list opens with: the [selected] site's outer group
/// (keyed by [outerKeyOf]) and, when [innerKeyOf] is given, its subgroup too
/// -- otherwise the selected site would sit behind two collapsed headers
/// instead of one. Also the only outer group when there is just one.
///
/// A blank inner value is skipped unless [bundlesInner] says the mode
/// bundles it into a titled subgroup of its own (#3270) rather than leaving
/// it in the outer group's plain ungrouped list -- only then does a blank
/// value still have a subgroup header to open.
Set<String> initialExpandedGroups<T>(
  List<SiteOuterGroup<T>> groups, {
  required String Function(DiveSite) outerKeyOf,
  DiveSite? selected,
  String Function(DiveSite)? innerKeyOf,
  bool bundlesInner = false,
}) {
  final outerKey = selected == null ? null : outerKeyOf(selected);
  final innerKey = selected == null || innerKeyOf == null
      ? null
      : innerKeyOf(selected);
  return {
    if (groups.length == 1) groups.single.key,
    ?outerKey,
    if (outerKey != null &&
        innerKey != null &&
        (innerKey != noGroupKey || bundlesInner))
      subGroupExpansionKey(outerKey, innerKey),
  };
}

/// A copy of [keys] with [key] removed if present, else added: one group
/// header tap.
Set<String> toggleGroupKey(Set<String> keys, String key) =>
    keys.contains(key) ? (keys.toSet()..remove(key)) : {...keys, key};

/// Every outer group key, for "a search or filter is active, open
/// everything".
Set<String> allGroupKeys<T>(List<SiteOuterGroup<T>> groups) => {
  for (final group in groups) group.key,
};

/// Every subgroup's expansion key, scoped to its outer group, for "a search
/// or filter is active, open everything" and for the site picker, which
/// never lets a region collapse at all.
Set<String> allSubGroupKeys<T>(List<SiteOuterGroup<T>> groups) => {
  for (final group in groups)
    for (final subgroup in group.subgroups)
      subGroupExpansionKey(group.key, subgroup.key),
};
