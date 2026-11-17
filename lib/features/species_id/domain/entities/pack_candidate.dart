import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// One species a crop can be named as: a row of the pack's candidate table.
class PackCandidate extends Equatable {
  const PackCandidate({
    required this.gbifKey,
    required this.scientificName,
    required this.commonName,
    required this.category,
    this.catalogId,
  });

  /// The GBIF species key. One candidate per key.
  final int gbifKey;
  final String scientificName;

  /// English. Candidates outside the built-in catalogue have no translation.
  final String commonName;
  final SpeciesCategory category;

  /// The built-in catalogue species this is, when it is one.
  final String? catalogId;

  factory PackCandidate.fromJson(Map<String, Object?> json) {
    final key = json['gbifKey'];
    final scientific = json['scientificName'];
    final common = json['commonName'];
    if (key is! int || scientific is! String || scientific.isEmpty) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'candidate without a key or a scientific name',
      );
    }
    final categoryName = json['category'];
    final catalogId = json['catalogId'];
    if (catalogId != null && catalogId is! String) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'catalogue id is not text',
      );
    }
    return PackCandidate(
      gbifKey: key,
      scientificName: scientific,
      commonName: common is String && common.isNotEmpty ? common : scientific,
      category: SpeciesCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => SpeciesCategory.other,
      ),
      catalogId: catalogId as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'gbifKey': gbifKey,
    'scientificName': scientificName,
    'commonName': commonName,
    'category': category.name,
    if (catalogId != null) 'catalogId': catalogId,
  };

  PackCandidate copyWith({
    int? gbifKey,
    String? scientificName,
    String? commonName,
    SpeciesCategory? category,
    String? Function()? catalogId,
  }) => PackCandidate(
    gbifKey: gbifKey ?? this.gbifKey,
    scientificName: scientificName ?? this.scientificName,
    commonName: commonName ?? this.commonName,
    category: category ?? this.category,
    catalogId: catalogId == null ? this.catalogId : catalogId(),
  );

  @override
  List<Object?> get props => [
    gbifKey,
    scientificName,
    commonName,
    category,
    catalogId,
  ];
}

/// A candidate with the score a crop gave it. Stored with the
/// identification, names and all, so a suggestion can still be shown and
/// added after the model pack is removed.
class NamedCandidate extends Equatable {
  const NamedCandidate({required this.candidate, required this.score});

  final PackCandidate candidate;
  final double score;

  factory NamedCandidate.fromJson(Map<String, Object?> json) {
    final score = json['score'];
    return NamedCandidate(
      candidate: PackCandidate.fromJson(json),
      score: score is num ? score.toDouble() : 0,
    );
  }

  Map<String, Object?> toJson() => {...candidate.toJson(), 'score': score};

  NamedCandidate copyWith({PackCandidate? candidate, double? score}) =>
      NamedCandidate(
        candidate: candidate ?? this.candidate,
        score: score ?? this.score,
      );

  @override
  List<Object?> get props => [candidate, score];
}

/// The pack's `candidates.json`, in table order.
List<PackCandidate> parseCandidates(String source) {
  final Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException catch (e) {
    throw PackManifestException(PackManifestFailure.malformed, e.message);
  }
  if (json is! List) {
    throw const PackManifestException(
      PackManifestFailure.malformed,
      'candidates is not a list',
    );
  }
  return [
    for (final entry in json)
      if (entry is Map)
        PackCandidate.fromJson(entry.cast<String, Object?>())
      else
        throw const PackManifestException(
          PackManifestFailure.malformed,
          'candidate is not an object',
        ),
  ];
}
