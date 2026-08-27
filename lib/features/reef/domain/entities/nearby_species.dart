import 'package:equatable/equatable.dart';

/// A nearby occurrence record matched to the app's built-in species catalog.
///
/// Matched records render with a common name, category icon and colour, and
/// can be added to a site's Expected list in one tap.
class MatchedNearbySpecies extends Equatable {
  /// Id of the species in `assets/data/species.json`.
  final String speciesId;

  /// GBIF occurrence count near the site, used for relevance ordering.
  final int occurrenceCount;

  const MatchedNearbySpecies({
    required this.speciesId,
    required this.occurrenceCount,
  });

  Map<String, dynamic> toJson() => {
    'speciesId': speciesId,
    'occurrenceCount': occurrenceCount,
  };

  factory MatchedNearbySpecies.fromJson(Map<String, dynamic> json) =>
      MatchedNearbySpecies(
        speciesId: json['speciesId'] as String,
        occurrenceCount: (json['occurrenceCount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [speciesId, occurrenceCount];
}

/// Species recorded near a dive site, in two tiers.
class NearbySpecies extends Equatable {
  /// Present in the built-in catalog. Rendered richly, ordered by count.
  final List<MatchedNearbySpecies> matched;

  /// Scientific names only, for the regional long tail.
  final List<String> unmatchedNames;

  const NearbySpecies({
    this.matched = const [],
    this.unmatchedNames = const [],
  });

  bool get isEmpty => matched.isEmpty && unmatchedNames.isEmpty;

  Map<String, dynamic> toJson() => {
    'matched': matched.map((m) => m.toJson()).toList(),
    'unmatchedNames': unmatchedNames,
  };

  factory NearbySpecies.fromJson(Map<String, dynamic> json) => NearbySpecies(
    matched: (json['matched'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(MatchedNearbySpecies.fromJson)
        .toList(),
    unmatchedNames: (json['unmatchedNames'] as List? ?? [])
        .cast<String>()
        .toList(),
  );

  @override
  List<Object?> get props => [matched, unmatchedNames];
}
