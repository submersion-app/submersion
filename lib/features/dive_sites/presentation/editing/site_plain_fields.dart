import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The site page's header block: a card, though not a section (issue #4527).
const String siteHeaderCardId = 'header';

String _card(SiteDetailSectionId id) => id.name;

/// The site's name, edited on the header block.
final siteNameField = EditField<DiveSite, String>(
  id: 'name',
  cardId: siteHeaderCardId,
  read: (site) => site.name,
  write: (site, name) => site.copyWith(name: name),
);

/// The site's water, edited on the header block.
final siteWaterTypeField = EditField<DiveSite, WaterType?>(
  id: 'waterType',
  cardId: siteHeaderCardId,
  read: (site) => site.waterType,
  write: (site, water) => water == null
      ? site.copyWith(clearWaterType: true)
      : site.copyWith(waterType: water),
);

/// The site's position, edited on the Location card.
final siteLocationField = EditField<DiveSite, GeoPoint?>(
  id: 'location',
  cardId: _card(SiteDetailSectionId.location),
  read: (site) => site.location,
  write: (site, point) => point == null
      ? site.copyWith(clearLocation: true)
      : site.copyWith(location: point),
);

final siteCountryField = EditField<DiveSite, String?>(
  id: 'country',
  cardId: _card(SiteDetailSectionId.location),
  read: (site) => site.country,
  // Clearing the country clears its code too, as the entity does: a code
  // names its country.
  write: (site, country) => country == null
      ? site.copyWith(clearCountry: true)
      : site.copyWith(country: country),
);

final siteCountryCodeField = EditField<DiveSite, String?>(
  id: 'countryCode',
  cardId: _card(SiteDetailSectionId.location),
  read: (site) => site.countryCode,
  write: (site, code) => code == null
      ? site.copyWith(clearCountryCode: true)
      : site.copyWith(countryCode: code),
);

final siteRegionField = _text(
  'region',
  SiteDetailSectionId.location,
  read: (site) => site.region,
  set: (site, v) => site.copyWith(region: v),
  clear: (site) => site.copyWith(clearRegion: true),
);

final siteCityField = _text(
  'city',
  SiteDetailSectionId.location,
  read: (site) => site.city,
  set: (site, v) => site.copyWith(city: v),
  clear: (site) => site.copyWith(clearCity: true),
);

final siteIslandField = _text(
  'island',
  SiteDetailSectionId.location,
  read: (site) => site.island,
  set: (site, v) => site.copyWith(island: v),
  clear: (site) => site.copyWith(clearIsland: true),
);

final siteBodyOfWaterField = _text(
  'bodyOfWater',
  SiteDetailSectionId.location,
  read: (site) => site.bodyOfWater,
  set: (site, v) => site.copyWith(bodyOfWater: v),
  clear: (site) => site.copyWith(clearBodyOfWater: true),
);

/// The site's altitude, in metres, edited on the Altitude card.
final siteAltitudeField = EditField<DiveSite, double?>(
  id: 'altitude',
  cardId: _card(SiteDetailSectionId.altitude),
  read: (site) => site.altitude,
  write: (site, metres) => metres == null
      ? site.copyWith(clearAltitude: true)
      : site.copyWith(altitude: metres),
);

/// The site's shallowest point, in metres, edited on the Depth card.
final siteMinDepthField = EditField<DiveSite, double?>(
  id: 'minDepth',
  cardId: _card(SiteDetailSectionId.depth),
  read: (site) => site.minDepth,
  write: (site, metres) => metres == null
      ? site.copyWith(clearMinDepth: true)
      : site.copyWith(minDepth: metres),
);

/// The site's deepest point, in metres, edited on the Depth card.
final siteMaxDepthField = EditField<DiveSite, double?>(
  id: 'maxDepth',
  cardId: _card(SiteDetailSectionId.depth),
  read: (site) => site.maxDepth,
  write: (site, metres) => metres == null
      ? site.copyWith(clearMaxDepth: true)
      : site.copyWith(maxDepth: metres),
);

final siteDifficultyField = EditField<DiveSite, SiteDifficulty?>(
  id: 'difficulty',
  cardId: _card(SiteDetailSectionId.difficulty),
  read: (site) => site.difficulty,
  write: (site, level) => level == null
      ? site.copyWith(clearDifficulty: true)
      : site.copyWith(difficulty: level),
);

final siteRatingField = EditField<DiveSite, double?>(
  id: 'rating',
  cardId: _card(SiteDetailSectionId.rating),
  read: (site) => site.rating,
  write: (site, stars) => stars == null
      ? site.copyWith(clearRating: true)
      : site.copyWith(rating: stars),
);

final siteHazardsField = _text(
  'hazards',
  SiteDetailSectionId.hazards,
  read: (site) => site.hazards,
  set: (site, v) => site.copyWith(hazards: v),
  clear: (site) => site.copyWith(clearHazards: true),
);

final siteParkingInfoField = _text(
  'parkingInfo',
  SiteDetailSectionId.access,
  read: (site) => site.parkingInfo,
  set: (site, v) => site.copyWith(parkingInfo: v),
  clear: (site) => site.copyWith(clearParkingInfo: true),
);

final siteAccessNotesField = _text(
  'accessNotes',
  SiteDetailSectionId.access,
  read: (site) => site.accessNotes,
  set: (site, v) => site.copyWith(accessNotes: v),
  clear: (site) => site.copyWith(clearAccessNotes: true),
);

final siteMooringNumberField = _text(
  'mooringNumber',
  SiteDetailSectionId.access,
  read: (site) => site.mooringNumber,
  set: (site, v) => site.copyWith(mooringNumber: v),
  clear: (site) => site.copyWith(clearMooringNumber: true),
);

/// How divers get in at the site; the order carries no meaning.
final siteEntryMethodsField = EditField<DiveSite, List<EntryMethod>>(
  id: 'entryMethods',
  cardId: _card(SiteDetailSectionId.access),
  read: (site) => site.entryMethods,
  write: (site, methods) => site.copyWith(entryMethods: methods),
  equals: _sameMethods,
);

/// How divers get out at the site; the order carries no meaning.
final siteExitMethodsField = EditField<DiveSite, List<EntryMethod>>(
  id: 'exitMethods',
  cardId: _card(SiteDetailSectionId.access),
  read: (site) => site.exitMethods,
  write: (site, methods) => site.copyWith(exitMethods: methods),
  equals: _sameMethods,
);

bool _sameMethods(List<EntryMethod> a, List<EntryMethod> b) =>
    setEquals(a.toSet(), b.toSet());

/// Every field a site's sitting edits, in card order: what the field
/// census checks against the table's columns.
final List<EditField<DiveSite, Object?>> siteSittingFields = [
  siteNameField,
  siteWaterTypeField,
  siteDescriptionField,
  siteMinDepthField,
  siteMaxDepthField,
  siteDifficultyField,
  siteRatingField,
  siteHazardsField,
  siteParkingInfoField,
  siteAccessNotesField,
  siteMooringNumberField,
  siteEntryMethodsField,
  siteExitMethodsField,
  siteLocationField,
  siteCountryField,
  siteCountryCodeField,
  siteRegionField,
  siteCityField,
  siteIslandField,
  siteBodyOfWaterField,
  siteNotesField,
  siteAltitudeField,
];

/// A free-text value of [card]; null is no value.
EditField<DiveSite, String?> _text(
  String id,
  SiteDetailSectionId card, {
  required String? Function(DiveSite site) read,
  required DiveSite Function(DiveSite site, String value) set,
  required DiveSite Function(DiveSite site) clear,
}) => EditField<DiveSite, String?>(
  id: id,
  cardId: card.name,
  read: read,
  write: (site, value) => value == null ? clear(site) : set(site, value),
);
