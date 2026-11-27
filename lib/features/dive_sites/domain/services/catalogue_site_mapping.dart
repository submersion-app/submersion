import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

/// The diver's site a built-in catalogue record becomes when it is adopted.
///
/// Carries every detail the record holds and its id as the link back.
/// Nothing is written into the fields the diver owns: no "imported from"
/// note, and the record's loose descriptive tags (drift, sharks) stay in
/// the catalogue. Rating, access notes, exit methods and altitude are left
/// for the diver (altitude is then filled from the elevation service).
///
/// The id is empty: the repository assigns one.
DiveSite catalogueSiteToDiveSite(CatalogueSite site, {String? diverId}) =>
    DiveSite(
      id: '',
      diverId: diverId,
      name: site.name,
      description: site.description ?? '',
      location: site.location,
      minDepth: site.minDepth,
      maxDepth: site.maxDepth,
      difficulty: site.difficulty,
      waterType: site.waterType,
      country: site.country,
      countryCode: site.countryCode,
      region: site.region,
      city: site.locality,
      island: site.island,
      bodyOfWater: site.bodyOfWater,
      hazards: site.hazards,
      entryMethods: site.entryMethods,
      website: catalogueWebsiteText(site.website),
      catalogueId: site.id,
    );

/// A catalogue record's website as a site stores it (issue #5073): the
/// trimmed text when it is a web address, else null. The value comes from
/// a source anyone can edit, so a phone number or another app's scheme in
/// the tag never becomes the site's website.
String? catalogueWebsiteText(String? raw) {
  final text = raw?.trim() ?? '';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return text;
}

/// The site types an adopted [site] starts with.
SiteClassification catalogueSiteClassification(CatalogueSite site) =>
    SiteClassification(typeIds: site.typeIds);
