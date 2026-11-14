import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// How far a built-in catalogue record is trusted.
///
/// A [verified] record comes from a register whose positions can be traced.
/// A [researched] one was gathered by research and has not been checked
/// against such a source.
enum CatalogueTrust { verified, researched }

/// What kind of list a catalogue record came from.
///
/// A [site] comes from a source that lists places people dive. A [register]
/// record comes from a list of things on the seabed: a wreck register or a
/// reef deployment list. There are many times more of those, so the picker
/// keeps them in a section of their own and GPS matching prefers a dive
/// site to one of them.
enum CatalogueKind { site, register }

/// One site of the built-in catalogue (`assets/data/site_catalogue.json`).
///
/// Not one of the diver's sites: adopting it creates a [DiveSite] whose
/// `catalogueId` is this record's [id].
class CatalogueSite extends Equatable {
  /// Stable across catalogue versions (`osm_node_663869401`).
  final String id;
  final String name;

  /// Null for a record found by search only.
  final GeoPoint? location;

  /// ISO 3166-1 alpha-2.
  final String? countryCode;

  /// The country's English name.
  final String? country;
  final String? region;
  final String? locality;
  final String? island;
  final String? bodyOfWater;
  final WaterType? waterType;

  /// Meters.
  final double? minDepth;

  /// Meters.
  final double? maxDepth;

  /// Built-in site type ids (`wreck`, `reef`).
  final List<String> typeIds;
  final List<EntryMethod> entryMethods;

  /// What the source said about the diving (drift, sharks). Kept for later
  /// use; adoption does not copy it.
  final List<String> features;
  final SiteDifficulty? difficulty;
  final String? hazards;
  final String? description;
  final String? website;

  /// The key of the [CatalogueSource] this record came from.
  final String source;

  /// The record's origin: an OpenStreetMap object, or the page a curated
  /// position cites.
  final String? sourceRef;
  final CatalogueTrust trust;
  final CatalogueKind kind;

  const CatalogueSite({
    required this.id,
    required this.name,
    this.location,
    this.countryCode,
    this.country,
    this.region,
    this.locality,
    this.island,
    this.bodyOfWater,
    this.waterType,
    this.minDepth,
    this.maxDepth,
    this.typeIds = const [],
    this.entryMethods = const [],
    this.features = const [],
    this.difficulty,
    this.hazards,
    this.description,
    this.website,
    required this.source,
    this.sourceRef,
    this.trust = CatalogueTrust.verified,
    this.kind = CatalogueKind.site,
  });

  bool get hasCoordinates => location != null;

  @override
  List<Object?> get props => [
    id,
    name,
    location,
    countryCode,
    country,
    region,
    locality,
    island,
    bodyOfWater,
    waterType,
    minDepth,
    maxDepth,
    typeIds,
    entryMethods,
    features,
    difficulty,
    hazards,
    description,
    website,
    source,
    sourceRef,
    trust,
    kind,
  ];
}

/// Where a set of catalogue records came from, and under what licence.
class CatalogueSource extends Equatable {
  final String key;
  final String name;

  /// An SPDX-style identifier (`ODbL-1.0`).
  final String licence;
  final String? licenceUrl;

  /// The text to credit (`OpenStreetMap contributors`).
  final String credit;

  const CatalogueSource({
    required this.key,
    required this.name,
    required this.licence,
    this.licenceUrl,
    required this.credit,
  });

  @override
  List<Object?> get props => [key, name, licence, licenceUrl, credit];
}
