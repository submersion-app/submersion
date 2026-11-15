import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_offer.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

/// The catalogue records read for a set of sites, by site id.
class PairingCandidates {
  const PairingCandidates({
    this.linkedRecords = const {},
    this.near = const {},
    this.named = const {},
  });

  /// A linked site's record. Absent when the catalogue no longer holds it.
  final Map<String, CatalogueSite> linkedRecords;

  /// For an unlinked site with a position: the records around it. Any
  /// beyond the pairing distance are ignored.
  final Map<String, List<CatalogueSite>> near;

  /// For an unlinked site without a position: the records of its name.
  final Map<String, List<CatalogueSite>> named;
}

/// A record within reach of a site, with how far apart they are.
typedef _Reach = ({CatalogueSite record, double meters});

/// Pairs each of [sites] with at most one catalogue record.
///
/// [claimed] holds the records no site may be offered: every record one of
/// the diver's sites is linked to or stands for. [sitesWithTypes] names
/// the sites that have a site type.
///
/// A record goes to one site. Sure claims are settled first, then nearby
/// ones, then named ones; among sites after one record the nearer wins.
/// The result lists linked and sure pairs, then nearby, then named, each
/// by site name.
List<CataloguePair> pairSitesWithCatalogue({
  required List<DiveSite> sites,
  required Set<String> sitesWithTypes,
  required Set<String> claimed,
  required PairingCandidates candidates,
}) {
  final taken = <String>{};
  final pairs = <CataloguePair>[];

  CataloguePair pairOf(
    DiveSite site,
    CatalogueSite record,
    CataloguePairKind kind, {
    double? meters,
  }) => CataloguePair(
    site: site,
    record: record,
    kind: kind,
    fields: catalogueOfferFor(
      site,
      siteHasTypes: sitesWithTypes.contains(site.id),
      record: record,
    ),
    distanceMeters: meters,
  );

  bool open(DiveSite site, CatalogueSite record) =>
      !claimed.contains(record.id) &&
      !site.catalogueAnswers.notSame.contains(record.id);

  // Linked sites: the record is given, and only a non-empty offer lists it.
  for (final site in sites.where((site) => site.catalogueId != null)) {
    final record = candidates.linkedRecords[site.id];
    if (record == null) continue;
    final siteAt = site.location;
    final recordAt = record.location;
    final pair = pairOf(
      site,
      record,
      CataloguePairKind.linked,
      meters: siteAt != null && recordAt != null
          ? distanceMeters(siteAt, recordAt)
          : null,
    );
    if (pair.fields.isNotEmpty) pairs.add(pair);
  }

  // Unlinked sites with a position: what lies within reach of each, a dive
  // site record before a wreck or reef record, then the nearer.
  final located = <DiveSite, ({List<_Reach> sameName, List<_Reach> any})>{};
  // Sites whose own record, same name and within reach, another of the
  // diver's sites already has: the diver holds this place twice.
  final ownRecordClaimed = <DiveSite>{};
  for (final site in sites) {
    final siteAt = site.location;
    if (site.catalogueId != null || siteAt == null) continue;
    final nearRecords = candidates.near[site.id] ?? const <CatalogueSite>[];
    if (nearRecords.any(
      (record) =>
          claimed.contains(record.id) &&
          record.location != null &&
          distanceMeters(siteAt, record.location!) <=
              kCataloguePairRadiusMeters &&
          catalogueNamesEqual(site.name, record.name),
    )) {
      ownRecordClaimed.add(site);
    }
    final reach =
        <_Reach>[
            for (final record in nearRecords)
              if (record.location != null && open(site, record))
                (
                  record: record,
                  meters: distanceMeters(siteAt, record.location!),
                ),
          ].where((r) => r.meters <= kCataloguePairRadiusMeters).toList()
          ..sort(_diveSiteThenNearer);
    located[site] = (
      sameName: [
        for (final r in reach)
          if (catalogueNamesEqual(site.name, r.record.name)) r,
      ],
      any: reach,
    );
  }

  /// Gives each site in [claims] its first record nobody has taken, the
  /// site nearest its own best record going first.
  void settle(Map<DiveSite, List<_Reach>> claims, CataloguePairKind kind) {
    final order = claims.keys.where((site) => claims[site]!.isNotEmpty).toList()
      ..sort((a, b) {
        final byDistance = claims[a]!.first.meters.compareTo(
          claims[b]!.first.meters,
        );
        return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
      });
    for (final site in order) {
      for (final reach in claims[site]!) {
        if (!taken.add(reach.record.id)) continue;
        pairs.add(pairOf(site, reach.record, kind, meters: reach.meters));
        break;
      }
    }
  }

  settle({
    for (final entry in located.entries) entry.key: entry.value.sameName,
  }, CataloguePairKind.sure);
  // A site that has an equal-named record within reach is that record's
  // or nobody's: when a nearer site took it, or another of the diver's
  // sites already has it, the site is not handed a neighbour under
  // another name instead.
  settle({
    for (final entry in located.entries)
      if (entry.value.sameName.isEmpty && !ownRecordClaimed.contains(entry.key))
        entry.key: entry.value.any,
  }, CataloguePairKind.nearby);

  // Unlinked sites without a position: exactly one record of the name, in
  // the site's country when it names one. A namesake another site already
  // has, or one a located site has just taken, still counts as a record of
  // the name: with it the name does not pick out one place, and the site
  // is not handed whichever namesake is left. Only a record the site said
  // it is not is set aside first. By site id, so a record two such sites
  // are after goes to the same one every time.
  final bare =
      sites
          .where((site) => site.catalogueId == null && site.location == null)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  for (final site in bare) {
    final country = site.countryCode ?? countryCodeFor(site.country);
    final namesakes = [
      for (final record in candidates.named[site.id] ?? const <CatalogueSite>[])
        if (record.location != null &&
            !site.catalogueAnswers.notSame.contains(record.id) &&
            (country == null || record.countryCode == country) &&
            catalogueNamesEqual(site.name, record.name))
          record,
    ];
    if (namesakes.length != 1) continue;
    final record = namesakes.single;
    if (claimed.contains(record.id) || !taken.add(record.id)) continue;
    pairs.add(pairOf(site, record, CataloguePairKind.named));
  }

  int group(CataloguePair pair) => switch (pair.kind) {
    CataloguePairKind.linked || CataloguePairKind.sure => 0,
    CataloguePairKind.nearby => 1,
    CataloguePairKind.named => 2,
  };
  return pairs..sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final byName = compareTextForSort(a.site.name, b.site.name);
    return byName != 0 ? byName : a.site.id.compareTo(b.site.id);
  });
}

int _diveSiteThenNearer(_Reach a, _Reach b) {
  final aRegister = a.record.kind == CatalogueKind.register ? 1 : 0;
  final bRegister = b.record.kind == CatalogueKind.register ? 1 : 0;
  if (aRegister != bRegister) return aRegister - bRegister;
  final byDistance = a.meters.compareTo(b.meters);
  return byDistance != 0 ? byDistance : a.record.id.compareTo(b.record.id);
}
