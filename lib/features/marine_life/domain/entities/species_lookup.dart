import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A licensed photo shown next to a lookup hit, never stored.
class SpeciesLookupPhoto extends Equatable {
  final String squareUrl;
  final String attribution;

  const SpeciesLookupPhoto({
    required this.squareUrl,
    required this.attribution,
  });

  @override
  List<Object?> get props => [squareUrl, attribution];
}

/// One autocomplete result.
class SpeciesLookupHit extends Equatable {
  final int taxonId;
  final String scientificName;
  final String rank;

  /// iNaturalist's numeric rank; species is 10, coarser ranks are larger.
  final int rankLevel;

  /// The common name in the requested locale, else English, else null.
  final String? commonName;
  final String? matchedTerm;
  final int observationCount;
  final SpeciesLookupPhoto? photo;

  const SpeciesLookupHit({
    required this.taxonId,
    required this.scientificName,
    required this.rank,
    required this.rankLevel,
    this.commonName,
    this.matchedTerm,
    required this.observationCount,
    this.photo,
  });

  /// Only species-rank (or finer) hits become a species row.
  bool get isResolvable => rankLevel <= 10;

  @override
  List<Object?> get props => [
    taxonId,
    scientificName,
    rank,
    rankLevel,
    commonName,
    matchedTerm,
    observationCount,
    photo,
  ];
}

class TaxonAncestor extends Equatable {
  final String rank;
  final String name;

  const TaxonAncestor(this.rank, this.name);

  @override
  List<Object?> get props => [rank, name];
}

/// The taxon endpoint's answer for one hit: what the category mapper and
/// the species row need.
class TaxonDetail extends Equatable {
  final int taxonId;
  final String scientificName;
  final String? commonName;
  final String rank;
  final List<TaxonAncestor> ancestors;

  const TaxonDetail({
    required this.taxonId,
    required this.scientificName,
    this.commonName,
    required this.rank,
    required this.ancestors,
  });

  @override
  List<Object?> get props => [
    taxonId,
    scientificName,
    commonName,
    rank,
    ancestors,
  ];
}

/// What a lookup hands back to the caller that creates the species.
class SpeciesLookupResult extends Equatable {
  final int taxonId;
  final String commonName;
  final String scientificName;
  final SpeciesCategory category;
  final String? taxonomyClass;

  const SpeciesLookupResult({
    required this.taxonId,
    required this.commonName,
    required this.scientificName,
    required this.category,
    this.taxonomyClass,
  });

  SpeciesLookupResult copyWith({
    int? taxonId,
    String? commonName,
    String? scientificName,
    SpeciesCategory? category,
    String? taxonomyClass,
  }) {
    return SpeciesLookupResult(
      taxonId: taxonId ?? this.taxonId,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      taxonomyClass: taxonomyClass ?? this.taxonomyClass,
    );
  }

  @override
  List<Object?> get props => [
    taxonId,
    commonName,
    scientificName,
    category,
    taxonomyClass,
  ];
}

/// What the lookup sheet was closed with. Dismissal is the absence of an
/// outcome (a null future), so a caller can tell "the diver backed out" from
/// "the diver asked to skip the lookup" instead of guessing from a bare null.
sealed class SpeciesLookupOutcome {
  const SpeciesLookupOutcome();
}

/// The diver picked a taxon and it resolved.
class SpeciesLookupChosen extends SpeciesLookupOutcome {
  final SpeciesLookupResult result;

  const SpeciesLookupChosen(this.result);
}

/// The diver asked to create the species from the typed name alone.
class SpeciesLookupCreateWithout extends SpeciesLookupOutcome {
  const SpeciesLookupCreateWithout();
}

enum SpeciesLookupErrorKind { offline, timeout, server, malformed }

/// One message per kind in the sheet; nothing retries silently.
class SpeciesLookupException implements Exception {
  final SpeciesLookupErrorKind kind;
  final String? detail;

  const SpeciesLookupException(this.kind, [this.detail]);

  @override
  String toString() =>
      'SpeciesLookupException(${kind.name}'
      '${detail == null ? '' : ': $detail'})';
}
