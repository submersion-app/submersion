import 'package:equatable/equatable.dart';

import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

/// What Species to review covers (issue #4727): one dive, or the log.
sealed class ReviewScope extends Equatable {
  const ReviewScope();
}

class DiveReviewScope extends ReviewScope {
  const DiveReviewScope(this.diveId);

  final String diveId;

  @override
  List<Object?> get props => [diveId];
}

class LogReviewScope extends ReviewScope {
  const LogReviewScope();

  @override
  List<Object?> get props => const [];
}

/// A media item to review, with what its group heading needs.
class ReviewMedia extends Equatable {
  const ReviewMedia({
    required this.item,
    this.diveNumber,
    this.diveTime,
    this.diveName,
  });

  final MediaItem item;
  final int? diveNumber;
  final DateTime? diveTime;

  /// The dive's name as its pages title it: its own, else its site's
  /// (`diveTitle`); null when it has neither.
  final String? diveName;

  ReviewMedia copyWith({
    MediaItem? item,
    int? Function()? diveNumber,
    DateTime? Function()? diveTime,
    String? Function()? diveName,
  }) => ReviewMedia(
    item: item ?? this.item,
    diveNumber: diveNumber == null ? this.diveNumber : diveNumber(),
    diveTime: diveTime == null ? this.diveTime : diveTime(),
    diveName: diveName == null ? this.diveName : diveName(),
  );

  @override
  List<Object?> get props => [item.id, diveNumber, diveTime, diveName];
}

/// One media item of a row: the app's unconfirmed [tag] on it, or a
/// [suggestion] of the row's species.
class ReviewItem extends Equatable {
  const ReviewItem({
    required this.media,
    this.tag,
    this.suggestion,
    this.score,
    this.cropIdentificationId,
    this.tagGbifKey,
  });

  final MediaItem media;
  final MediaSpeciesTag? tag;
  final SpeciesSuggestion? suggestion;

  /// The app's score, when this device holds the identification.
  final double? score;

  /// The identification whose crop shows this item, when this device holds
  /// one; else the item's thumbnail is shown.
  final String? cropIdentificationId;

  /// On an app tag, the GBIF key of the candidate the app tagged it from,
  /// when this device holds that identification. A species from outside
  /// the catalogue has no other key to match a nearby list by.
  final int? tagGbifKey;

  bool get isTagged => tag != null;

  ReviewItem copyWith({
    double? score,
    String? cropIdentificationId,
    int? tagGbifKey,
  }) => ReviewItem(
    media: media,
    tag: tag,
    suggestion: suggestion,
    score: score ?? this.score,
    cropIdentificationId: cropIdentificationId ?? this.cropIdentificationId,
    tagGbifKey: tagGbifKey ?? this.tagGbifKey,
  );

  @override
  List<Object?> get props => [
    media.id,
    tag,
    suggestion,
    score,
    cropIdentificationId,
    tagGbifKey,
  ];
}

/// One species on one dive (or group): tagged by the app on some media,
/// suggested on others, or both.
class ReviewRow extends Equatable {
  const ReviewRow({
    required this.key,
    required this.items,
    this.species,
    this.candidate,
  });

  /// Stable within its group: `s:<species id>` or `g:<GBIF key>`.
  final String key;

  /// The species the app tagged, for a row with tags.
  final Species? species;

  /// The app's name, for a row of suggestions only.
  final PackCandidate? candidate;
  final List<ReviewItem> items;

  ReviewRow copyWith({
    String? key,
    List<ReviewItem>? items,
    Species? Function()? species,
    PackCandidate? Function()? candidate,
  }) => ReviewRow(
    key: key ?? this.key,
    items: items ?? this.items,
    species: species == null ? this.species : species(),
    candidate: candidate == null ? this.candidate : candidate(),
  );

  String? get speciesId => species?.id;

  /// Every GBIF key this row's species is known by on this device, to
  /// match a nearby list by: its candidate's, each grouped suggestion's,
  /// and the key each of the app's tags was made from. A suggestion grouped
  /// under a tag by name may carry a synonym's key, so all are kept.
  Set<int> get gbifKeys => {
    ?candidate?.gbifKey,
    for (final i in items) ...[
      ?i.suggestion?.top.candidate.gbifKey,
      ?i.tagGbifKey,
    ],
  };

  int get taggedCount => items.where((i) => i.isTagged).length;
  int get suggestedCount => items.length - taggedCount;
  bool get isTagged => taggedCount > 0;

  /// The highest score among the items, when any has one.
  double? get bestScore {
    double? best;
    for (final i in items) {
      final s = i.score;
      if (s != null && (best == null || s > best)) best = s;
    }
    return best;
  }

  /// The item whose crop or thumbnail stands for the row.
  ReviewItem get best {
    var pick = items.first;
    for (final i in items.skip(1)) {
      if ((i.score ?? -1) > (pick.score ?? -1)) pick = i;
    }
    return pick;
  }

  @override
  List<Object?> get props => [key, species, candidate, items];
}

enum ReviewGroupKind { dive, sitePhotos, otherPhotos }

/// The rows of one dive, or of the photos with no dive.
class ReviewGroup extends Equatable {
  const ReviewGroup({
    required this.kind,
    required this.tagged,
    required this.suggested,
    this.diveId,
    this.diveNumber,
    this.diveTime,
    this.diveName,
  });

  final ReviewGroupKind kind;
  final String? diveId;
  final int? diveNumber;
  final DateTime? diveTime;

  /// The dive's name as its pages title it: its own, else its site's
  /// (`diveTitle`); null when it has neither.
  final String? diveName;

  /// Species with at least one unconfirmed tag, by name.
  final List<ReviewRow> tagged;

  /// Species only suggested, best score first.
  final List<ReviewRow> suggested;

  ReviewGroup copyWith({
    ReviewGroupKind? kind,
    List<ReviewRow>? tagged,
    List<ReviewRow>? suggested,
    String? Function()? diveId,
    int? Function()? diveNumber,
    DateTime? Function()? diveTime,
    String? Function()? diveName,
  }) => ReviewGroup(
    kind: kind ?? this.kind,
    tagged: tagged ?? this.tagged,
    suggested: suggested ?? this.suggested,
    diveId: diveId == null ? this.diveId : diveId(),
    diveNumber: diveNumber == null ? this.diveNumber : diveNumber(),
    diveTime: diveTime == null ? this.diveTime : diveTime(),
    diveName: diveName == null ? this.diveName : diveName(),
  );

  @override
  List<Object?> get props => [
    kind,
    diveId,
    diveNumber,
    diveTime,
    diveName,
    tagged,
    suggested,
  ];
}
