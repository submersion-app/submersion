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

  /// True when a name lookup failed, so [unmatchedNames] may be short. Never
  /// persisted: a result with a gap must not be kept for the cache's 30-day
  /// lifetime.
  final bool namesIncomplete;

  /// The GBIF species key of every species the search returned, matched or
  /// not, so a marine life suggestion can be checked against the list by its
  /// key. Not shown: [isEmpty] and the site page read only the two tiers.
  ///
  /// Wider than [unmatchedNames]: it also holds species past the 25 names
  /// looked up, and any the site page drops as terrestrial (Araceae). No
  /// marine life suggestion is one of those, so a match stays meaningful.
  final Set<int> speciesKeys;

  const NearbySpecies({
    this.matched = const [],
    this.unmatchedNames = const [],
    this.namesIncomplete = false,
    this.speciesKeys = const {},
  });

  bool get isEmpty => matched.isEmpty && unmatchedNames.isEmpty;

  NearbySpecies copyWith({
    List<MatchedNearbySpecies>? matched,
    List<String>? unmatchedNames,
    bool? namesIncomplete,
    Set<int>? speciesKeys,
  }) => NearbySpecies(
    matched: matched ?? this.matched,
    unmatchedNames: unmatchedNames ?? this.unmatchedNames,
    namesIncomplete: namesIncomplete ?? this.namesIncomplete,
    speciesKeys: speciesKeys ?? this.speciesKeys,
  );

  Map<String, dynamic> toJson() => {
    'matched': matched.map((m) => m.toJson()).toList(),
    'unmatchedNames': unmatchedNames,
    'speciesKeys': speciesKeys.toList()..sort(),
  };

  factory NearbySpecies.fromJson(Map<String, dynamic> json) => NearbySpecies(
    matched: (json['matched'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(MatchedNearbySpecies.fromJson)
        .toList(),
    unmatchedNames: (json['unmatchedNames'] as List? ?? [])
        .cast<String>()
        .toList(),
    speciesKeys: {
      for (final key in json['speciesKeys'] as List? ?? const [])
        (key as num).toInt(),
    },
  );

  @override
  List<Object?> get props => [
    matched,
    unmatchedNames,
    namesIncomplete,
    speciesKeys,
  ];
}
