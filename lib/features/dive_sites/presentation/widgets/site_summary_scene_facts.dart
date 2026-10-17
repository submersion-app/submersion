import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

/// The facts the Dive sites chart scene shows, derived from the site list
/// exactly as `SiteSummaryWidget` derives them, so the scene and the details
/// view never disagree.
class SiteSceneFacts {
  const SiteSceneFacts._({
    required this.siteCount,
    required this.countryCount,
    required this.withGps,
    required this.notDived,
    required this.mostDived,
    required this.bestRated,
    required this.lastDived,
  });

  factory SiteSceneFacts.from(List<SiteWithDiveCount> sites) {
    // Trimmed before testing and keying, as the details view does:
    // imported rows carry whitespace-only countries and trailing spaces.
    final countries = {
      for (final s in sites)
        if ((s.site.country?.trim() ?? '').isNotEmpty) s.site.country!.trim(),
    };

    // The details view's own sort expressions, so each pick is the first
    // row of the matching list there.
    final rated =
        sites.where((s) => s.site.rating != null && s.site.rating! > 0).toList()
          ..sort((a, b) => (b.site.rating ?? 0).compareTo(a.site.rating ?? 0));
    final dived = sites.toList()
      ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
    final recent = sites.where((s) => s.lastDivedAt != null).toList()
      ..sort((a, b) => b.lastDivedAt!.compareTo(a.lastDivedAt!));

    return SiteSceneFacts._(
      siteCount: sites.length,
      countryCount: countries.length,
      withGps: sites.where((s) => s.site.hasCoordinates).length,
      notDived: sites.where((s) => s.diveCount == 0).length,
      mostDived: dived.where((s) => s.diveCount > 0).firstOrNull,
      bestRated: rated.firstOrNull,
      lastDived: recent.firstOrNull,
    );
  }

  final int siteCount;
  final int countryCount;
  final int withGps;
  final int notDived;
  final SiteWithDiveCount? mostDived;
  final SiteWithDiveCount? bestRated;
  final SiteWithDiveCount? lastDived;

  /// The sites the chart marks: most dived, best rated and last dived, each
  /// once, in that order.
  List<SiteWithDiveCount> get marked {
    final seen = <String>{};
    return [
      for (final s in [mostDived, bestRated, lastDived])
        if (s != null && seen.add(s.site.id)) s,
    ];
  }
}
