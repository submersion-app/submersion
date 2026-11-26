import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

/// One animal of a species cut out of a photo or video frame: an accepted
/// identification whose tag for the species still exists (issue #5027).
///
/// A media item contributes at most one crop per species, its largest box,
/// so a school of fish on one photo shows once.
class SpeciesCrop extends Equatable {
  const SpeciesCrop({
    required this.identificationId,
    required this.mediaId,
    required this.box,
    required this.shorterSide,
    this.bestMs,
    required this.isVideo,
    this.takenAt,
    required this.confirmed,
  });

  final String identificationId;
  final String mediaId;

  /// Where the animal is, normalised 0 to 1 against the oriented image.
  final IdentificationBox box;

  /// The box's shorter side in the analysed image's pixels: what "best crop"
  /// ranks by.
  final int shorterSide;

  /// Video only: the moment the crop is from, in milliseconds.
  final int? bestMs;
  final bool isVideo;
  final DateTime? takenAt;

  /// Whether the diver confirmed the tag (the app may have applied it).
  final bool confirmed;

  SpeciesCrop copyWith({
    String? identificationId,
    String? mediaId,
    IdentificationBox? box,
    int? shorterSide,
    int? bestMs,
    bool? isVideo,
    DateTime? takenAt,
    bool? confirmed,
  }) => SpeciesCrop(
    identificationId: identificationId ?? this.identificationId,
    mediaId: mediaId ?? this.mediaId,
    box: box ?? this.box,
    shorterSide: shorterSide ?? this.shorterSide,
    bestMs: bestMs ?? this.bestMs,
    isVideo: isVideo ?? this.isVideo,
    takenAt: takenAt ?? this.takenAt,
    confirmed: confirmed ?? this.confirmed,
  );

  @override
  List<Object?> get props => [
    identificationId,
    mediaId,
    box,
    shorterSide,
    bestMs,
    isVideo,
    takenAt,
    confirmed,
  ];
}

/// The one picture that stands for a species.
sealed class SpeciesPicture extends Equatable {
  const SpeciesPicture();
}

/// A crop of the animal.
class CropPicture extends SpeciesPicture {
  const CropPicture(this.crop);
  final SpeciesCrop crop;

  @override
  List<Object?> get props => [crop];
}

/// A tagged photo with no crop (a hand tag, or media never analysed).
class PhotoPicture extends SpeciesPicture {
  const PhotoPicture(this.media);
  final MediaItem media;

  @override
  List<Object?> get props => [media];
}

/// Nothing to show: the category tile stands in.
class NoPicture extends SpeciesPicture {
  const NoPicture();

  @override
  List<Object?> get props => const [];
}

/// The picture for a species, in the order of preference: the cover (a crop,
/// else a photo), the best crop, the newest tagged photo, else nothing.
SpeciesPicture chooseSpeciesPicture({
  SpeciesCrop? cover,
  MediaItem? coverPhoto,
  SpeciesCrop? bestCrop,
  MediaItem? newestPhoto,
}) {
  if (cover != null) return CropPicture(cover);
  if (coverPhoto != null) return PhotoPicture(coverPhoto);
  if (bestCrop != null) return CropPicture(bestCrop);
  if (newestPhoto != null) return PhotoPicture(newestPhoto);
  return const NoPicture();
}
