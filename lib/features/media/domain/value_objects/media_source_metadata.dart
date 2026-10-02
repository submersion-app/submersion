import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';

/// Metadata extracted from a media source at link time.
///
/// Read before the `MediaItem` row exists, by the flow that adds the item:
/// `ExifExtractor` for local files, the photo picker for gallery assets.
/// All fields except [mimeType] are nullable to accommodate sources that
/// don't expose them.
class MediaSourceMetadata extends Equatable {
  final DateTime? takenAt;

  /// Which tier of the extraction cascade produced [takenAt].
  ///
  /// Defaults to [TakenAtSource.none] so sources that do not run the
  /// cascade (gallery assets, Lightroom, network imports) keep constructing
  /// this object unchanged.
  final TakenAtSource takenAtSource;
  final double? latitude;
  final double? longitude;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String mimeType;

  const MediaSourceMetadata({
    this.takenAt,
    this.takenAtSource = TakenAtSource.none,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.durationSeconds,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [
    takenAt,
    takenAtSource,
    latitude,
    longitude,
    width,
    height,
    durationSeconds,
    mimeType,
  ];
}
