import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// The details of [record] that [site] may take: the single home of the
/// rule that built-in data fills only what the diver left empty.
///
/// A field is offered when the record carries it and the site has nothing
/// there. Besides that:
///
/// - **Depth is one field.** It is offered only when the site has neither
///   depth. A site with a maximum and no minimum is not given the record's
///   minimum: the two ranges may not belong together.
/// - **Place fields follow the place.** Position, country, region, town,
///   island and body of water are offered only when the site is at the
///   record's place: it has no position of its own, or lies within
///   [kCataloguePairRadiusMeters] of the record. A linked site the diver
///   has since moved is not given the record's place names.
/// - A position is never offered to a site that has one.
/// - A field the diver turned down for this record is left out.
///
/// Name, notes, rating, access notes, parking, mooring number, exit
/// methods and altitude are not fields at all: nothing here can offer them.
///
/// [siteHasTypes] says whether the site has any site type; types live
/// beside the site, not on it. The result is in the order the fields are
/// shown.
Set<CatalogueGapField> catalogueOfferFor(
  DiveSite site, {
  required bool siteHasTypes,
  required CatalogueSite record,
}) {
  final siteAt = site.location;
  final recordAt = record.location;
  final atRecordsPlace =
      siteAt == null ||
      (recordAt != null &&
          distanceMeters(siteAt, recordAt) <= kCataloguePairRadiusMeters);
  final declined = site.catalogueAnswers.declined[record.id] ?? const {};

  bool offered(CatalogueGapField field) => switch (field) {
    CatalogueGapField.position => siteAt == null && recordAt != null,
    CatalogueGapField.depth =>
      site.minDepth == null &&
          site.maxDepth == null &&
          (record.minDepth != null || record.maxDepth != null),
    CatalogueGapField.country =>
      _isBlank(site.country) && !_isBlank(record.country),
    CatalogueGapField.region =>
      _isBlank(site.region) && !_isBlank(record.region),
    CatalogueGapField.city => _isBlank(site.city) && !_isBlank(record.locality),
    CatalogueGapField.island =>
      _isBlank(site.island) && !_isBlank(record.island),
    CatalogueGapField.bodyOfWater =>
      _isBlank(site.bodyOfWater) && !_isBlank(record.bodyOfWater),
    CatalogueGapField.waterType =>
      site.waterType == null && record.waterType != null,
    CatalogueGapField.siteTypes => !siteHasTypes && record.typeIds.isNotEmpty,
    CatalogueGapField.entry =>
      site.entryMethods.isEmpty && record.entryMethods.isNotEmpty,
    CatalogueGapField.difficulty =>
      site.difficulty == null && record.difficulty != null,
    CatalogueGapField.hazards =>
      _isBlank(site.hazards) && !_isBlank(record.hazards),
    CatalogueGapField.description =>
      _isBlank(site.description) && !_isBlank(record.description),
  };

  return {
    for (final field in CatalogueGapField.values)
      if (!declined.contains(field.name) &&
          (atRecordsPlace || !CatalogueGapField.place.contains(field)) &&
          offered(field))
        field,
  };
}
