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
    this.siteName,
  });

  final MediaItem item;
  final int? diveNumber;
  final DateTime? diveTime;
  final String? siteName;

  @override
  List<Object?> get props => [item.id, diveNumber, diveTime, siteName];
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
  });

  final MediaItem media;
  final MediaSpeciesTag? tag;
  final SpeciesSuggestion? suggestion;

  /// The app's score, when this device holds the identification.
  final double? score;

  /// The identification whose crop shows this item, when this device holds
  /// one; else the item's thumbnail is shown.
  final String? cropIdentificationId;

  bool get isTagged => tag != null;

  ReviewItem copyWith({double? score, String? cropIdentificationId}) =>
      ReviewItem(
        media: media,
        tag: tag,
        suggestion: suggestion,
        score: score ?? this.score,
        cropIdentificationId: cropIdentificationId ?? this.cropIdentificationId,
      );

  @override
  List<Object?> get props => [
    media.id,
    tag,
    suggestion,
    score,
    cropIdentificationId,
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

  String? get speciesId => species?.id;
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
    this.siteName,
  });

  final ReviewGroupKind kind;
  final String? diveId;
  final int? diveNumber;
  final DateTime? diveTime;
  final String? siteName;

  /// Species with at least one unconfirmed tag, by name.
  final List<ReviewRow> tagged;

  /// Species only suggested, best score first.
  final List<ReviewRow> suggested;

  @override
  List<Object?> get props => [
    kind,
    diveId,
    diveNumber,
    diveTime,
    siteName,
    tagged,
    suggested,
  ];
}
