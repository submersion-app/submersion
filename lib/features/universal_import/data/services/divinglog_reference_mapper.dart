import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_row_values.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Builds the payload entities that come from Diving Log's reference
/// tables, each keyed by the `uddfId` the dive maps reference.
class DivingLogReferenceMapper {
  const DivingLogReferenceMapper._();

  /// The site key for [dive], byte-identical to the one phase 1 built from
  /// the free-text columns.
  ///
  /// Phase 1 is already in main, so its key is the one to match: a
  /// re-import must fold onto the same site rather than creating a second.
  /// The parts are the country, city and place names in that order, joined
  /// with a pipe and lowercased, skipping any that are missing.
  ///
  /// With no text at all, a Place's coordinates key the site instead,
  /// through the shared coordinate name the way Shearwater's key does
  /// (#2210). Keyed on text alone, a dive at a Place the diver never named
  /// never reached [ImportSiteLocation.named] and lost where it happened
  /// (#2232). Nothing phase 1 keyed can collide: it read the text only.
  static String? siteKeyFor(DivingLogLogbook book, DivingLogRawDive dive) {
    final parts = [
      countryNameFor(book, dive),
      cityNameFor(book, dive),
      placeNameFor(book, dive),
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return 'divinglog_site_${parts.join('|').toLowerCase()}';
    }
    final place = dive.placeId == null ? null : book.placesById[dive.placeId];
    final point = ImportSiteLocation.fix(place?.latitude, place?.longitude);
    if (point == null) return null;
    final name = ImportSiteLocation.nameFromCoordinates(
      point.latitude,
      point.longitude,
    );
    return 'divinglog_site_${name.toLowerCase()}';
  }

  /// Each component resolves through its id, falling back to the free text
  /// the dive row still carries.
  ///
  /// An id pointing at a row the file does not have would otherwise drop
  /// that component entirely, which both renames the site and breaks the
  /// fold with phase 1: a dive with a dangling `PlaceID` would key on
  /// country and city alone and land somewhere new.
  static String? placeNameFor(DivingLogLogbook book, DivingLogRawDive dive) =>
      (dive.placeId == null ? null : book.placesById[dive.placeId]?.place) ??
      dive.place;

  static String? cityNameFor(DivingLogLogbook book, DivingLogRawDive dive) =>
      (dive.cityId == null ? null : book.cityNamesById[dive.cityId]) ??
      dive.city;

  /// The dive's own country id first, then the one its `Place` carries,
  /// then the free text.
  ///
  /// A `Place` row names its country, so a dive whose `CountryID` is absent
  /// or dangling still has a relational answer available and should not
  /// drop straight to the text column.
  static String? countryNameFor(DivingLogLogbook book, DivingLogRawDive dive) {
    final direct = dive.countryId == null
        ? null
        : book.countryNamesById[dive.countryId];
    if (direct != null) return direct;
    final placeCountryId = dive.placeId == null
        ? null
        : book.placesById[dive.placeId]?.countryId;
    final viaPlace = placeCountryId == null
        ? null
        : book.countryNamesById[placeCountryId];
    return viaPlace ?? dive.country;
  }

  /// Sites, built from the dives so a `Place` nobody dived is left out and
  /// the key matches what the dive will reference.
  static Map<String, Map<String, dynamic>> sites(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final dive in book.dives) {
      final key = siteKeyFor(book, dive);
      if (key == null) continue;
      final place = dive.placeId == null ? null : book.placesById[dive.placeId];
      final placeName = placeNameFor(book, dive);
      final city = cityNameFor(book, dive);
      final country = countryNameFor(book, dive);
      final name = placeName ?? city ?? country;
      final map = <String, dynamic>{'uddfId': key};
      if (name != null) map['name'] = name;
      if (country != null) map['country'] = country;
      if (city != null) map['region'] = city;
      if (place?.latitude != null) map['latitude'] = place!.latitude;
      if (place?.longitude != null) map['longitude'] = place!.longitude;
      final maxDepth = positiveOrNull(place?.maxDepthMeters);
      if (maxDepth != null) map['maxDepth'] = maxDepth;
      final notes = [
        if (place?.waterName != null) 'Water: ${place!.waterName}',
        if (place?.difficulty != null) 'Difficulty: ${place!.difficulty}',
        if (place?.comments != null) place!.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['description'] = notes;
      // Named from its coordinates when the file gave it none, so a nameless
      // Place still keeps its position (#2232). A site with neither is
      // dropped, which is all it was ever worth.
      final named = ImportSiteLocation.named(map);
      if (named == null) continue;
      // Several dives share a site, and they need not all carry the same
      // detail: one whose PlaceID dangles reaches this key only through the
      // free-text fallback and has no Place row behind it. Taking the first
      // occurrence would then drop the coordinates a later dive's Place row
      // supplies, so later occurrences fill whatever is still missing while
      // anything already set is kept.
      out[key] = {...named, ...?out[key]};
    }
    return out;
  }

  /// Buddies, keyed by their display name so the id maps resolve.
  static Map<String, Map<String, dynamic>> buddies(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final buddy in book.buddiesById.values) {
      final name = buddy.fullName;
      if (name == null) continue;
      final map = <String, dynamic>{'name': name, 'uddfId': name};
      if (buddy.email != null) map['email'] = buddy.email;
      final phone = buddy.phone ?? buddy.mobile;
      if (phone != null) map['phone'] = phone;
      if (buddy.comments != null) map['notes'] = buddy.comments;
      out[name] = map;
    }
    return out;
  }

  /// Display names shared by more than one `Buddy` row.
  ///
  /// Buddies are keyed by display name, deliberately, so that a free-text
  /// buddy or divemaster naming the same person folds onto the table row
  /// instead of arriving twice. The cost is that two distinct people with
  /// one name become a single record. That trade stands, but the merge is
  /// reported here rather than made in silence.
  static List<String> buddyNameCollisions(DivingLogLogbook book) {
    final counts = <String, int>{};
    for (final buddy in book.buddiesById.values) {
      final name = buddy.fullName;
      if (name == null) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return [
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    ];
  }

  static Map<String, Map<String, dynamic>> trips(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final trip in book.tripsById.values) {
      final name = trip.name;
      if (name == null) continue;
      final key = 'divinglog_trip_${trip.id}';
      final map = <String, dynamic>{'name': name, 'uddfId': key};
      if (trip.startDate != null) map['startDate'] = trip.startDate;
      if (trip.endDate != null) map['endDate'] = trip.endDate;
      if (trip.comments != null) map['notes'] = trip.comments;
      out[key] = map;
    }
    return out;
  }

  static Map<String, Map<String, dynamic>> diveCenters(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final shop in book.shopsById.values) {
      final name = shop.name;
      if (name == null) continue;
      final key = 'divinglog_shop_${shop.id}';
      final map = <String, dynamic>{'name': name, 'uddfId': key};
      if (shop.street != null) map['street'] = shop.street;
      if (shop.city != null) map['city'] = shop.city;
      if (shop.state != null) map['stateProvince'] = shop.state;
      if (shop.zip != null) map['postalCode'] = shop.zip;
      if (shop.country != null) map['country'] = shop.country;
      if (shop.phone != null) map['phone'] = shop.phone;
      if (shop.email != null) map['email'] = shop.email;
      if (shop.url != null) map['website'] = shop.url;
      final notes = [
        if (shop.shopType != null) 'Type: ${shop.shopType}',
        if (shop.comments != null) shop.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['notes'] = notes;
      out[key] = map;
    }
    return out;
  }

  /// Dive types, keyed by the slug the importer matches on.
  ///
  /// MacDive already establishes the convention: the entity's `id` and
  /// `uddfId` are both `DiveTypeEntity.generateSlug(name)`, and a dive
  /// references them through `diveTypeIds` holding the same slugs. A name
  /// used as the key would reach nothing.
  static Map<String, Map<String, dynamic>> diveTypes(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final entry in book.diveTypesById.entries) {
      // Same predicate the ref and the count use, so an entity cannot be
      // emitted for something a dive can never reference, nor withheld for
      // something the count calls resolved.
      final slug = _diveTypeSlug(book, entry.key);
      if (slug == null || out.containsKey(slug)) continue;
      out[slug] = <String, dynamic>{
        'id': slug,
        'name': entry.value.name!.trim(),
        'uddfId': slug,
        'isBuiltIn': false,
        if (entry.value.sortOrder != null) 'sortOrder': entry.value.sortOrder,
      };
    }
    return out;
  }

  /// The slug dive type [id] resolves to, or null when it reaches nothing
  /// importable.
  ///
  /// One predicate for the entity, the ref and the count. Two of those
  /// agreeing and a third testing something close but different is how a
  /// reference goes missing without anything reporting it: a name can be
  /// non-blank and still slugify to nothing, since `generateSlug` strips
  /// every character outside `[a-z0-9 -]`.
  static String? _diveTypeSlug(DivingLogLogbook book, int id) {
    final name = book.diveTypesById[id]?.name?.trim();
    if (name == null || name.isEmpty) return null;
    final slug = DiveTypeEntity.generateSlug(name);
    return slug.isEmpty ? null : slug;
  }

  /// The `diveTypeIds` for [dive]: slugs, matching [diveTypes].
  static List<String> diveTypeIdsFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) {
    final out = <String>[];
    for (final id in dive.diveTypeIds) {
      final slug = _diveTypeSlug(book, id);
      if (slug != null && !out.contains(slug)) out.add(slug);
    }
    return out;
  }

  /// How many of [dive]'s dive type ids reach no usable name.
  ///
  /// Counted per id, not by comparing list lengths: [diveTypeIdsFor]
  /// collapses two ids that share a name into one slug, so a length
  /// comparison would call a perfectly resolved duplicate a missing record.
  static int unresolvedDiveTypeCount(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) => dive.diveTypeIds.where((id) => _diveTypeSlug(book, id) == null).length;

  /// How many of [dive]'s buddy ids reach no named row.
  static int unresolvedBuddyCount(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) => dive.buddyIds
      .where((id) => book.buddiesById[id]?.fullName == null)
      .length;

  static Map<String, Map<String, dynamic>> certifications(
    DivingLogLogbook book,
  ) {
    final out = <String, Map<String, dynamic>>{};
    for (final cert in book.certifications) {
      final name = cert.name;
      if (name == null) continue;
      final key = 'divinglog_cert_${cert.id}';
      final map = <String, dynamic>{'name': name, 'uddfId': key, 'level': name};
      if (cert.organisation != null) map['agency'] = cert.organisation;
      if (cert.certDate != null) map['issueDate'] = cert.certDate;
      if (cert.number != null) map['cardNumber'] = cert.number;
      if (cert.instructor != null) map['instructorName'] = cert.instructor;
      out[key] = map;
    }
    return out;
  }
}
