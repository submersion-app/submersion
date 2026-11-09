import 'package:equatable/equatable.dart';

/// Whose curated "expected" lists the species map draws (issue #4358).
enum ExpectedSiteScope {
  /// Sites the diver owns or has logged a dive at.
  mine,

  /// Every site the diver can see (own, shared, shared site libraries),
  /// minus the ones they hid, plus the [mine] sites.
  allVisible,
}

/// One site on the species map's places view: how much the diver has logged
/// there.
class SiteSpeciesPin extends Equatable {
  final String siteId;
  final String siteName;
  final double latitude;
  final double longitude;

  /// Distinct species the diver has logged at the site.
  final int speciesCount;

  /// Sum of the sightings' counts at the site.
  final int sightingCount;

  const SiteSpeciesPin({
    required this.siteId,
    required this.siteName,
    required this.latitude,
    required this.longitude,
    required this.speciesCount,
    required this.sightingCount,
  });

  SiteSpeciesPin copyWith({
    String? siteId,
    String? siteName,
    double? latitude,
    double? longitude,
    int? speciesCount,
    int? sightingCount,
  }) {
    return SiteSpeciesPin(
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speciesCount: speciesCount ?? this.speciesCount,
      sightingCount: sightingCount ?? this.sightingCount,
    );
  }

  @override
  List<Object?> get props => [
    siteId,
    siteName,
    latitude,
    longitude,
    speciesCount,
    sightingCount,
  ];
}

/// Why a site is on one species' map.
enum SpeciesPinKind {
  /// The diver logged the species there.
  logged,

  /// The site's expected list names it, and the diver has not logged it
  /// there.
  expected,
}

/// One site on a species' map.
class SpeciesSitePin extends Equatable {
  final String siteId;
  final String siteName;
  final double latitude;
  final double longitude;
  final SpeciesPinKind kind;

  /// Sum of the sightings' counts at the site; 0 for an expected pin.
  final int sightingCount;

  const SpeciesSitePin({
    required this.siteId,
    required this.siteName,
    required this.latitude,
    required this.longitude,
    required this.kind,
    required this.sightingCount,
  });

  SpeciesSitePin copyWith({
    String? siteId,
    String? siteName,
    double? latitude,
    double? longitude,
    SpeciesPinKind? kind,
    int? sightingCount,
  }) {
    return SpeciesSitePin(
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      kind: kind ?? this.kind,
      sightingCount: sightingCount ?? this.sightingCount,
    );
  }

  @override
  List<Object?> get props => [
    siteId,
    siteName,
    latitude,
    longitude,
    kind,
    sightingCount,
  ];
}

/// A species the diver logged at one site, with its summed count.
class LoggedSpeciesAtSite extends Equatable {
  final String speciesId;
  final int sightingCount;

  const LoggedSpeciesAtSite({
    required this.speciesId,
    required this.sightingCount,
  });

  LoggedSpeciesAtSite copyWith({String? speciesId, int? sightingCount}) {
    return LoggedSpeciesAtSite(
      speciesId: speciesId ?? this.speciesId,
      sightingCount: sightingCount ?? this.sightingCount,
    );
  }

  @override
  List<Object?> get props => [speciesId, sightingCount];
}
