import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

/// Where one animal was at one sampled moment of a video (issue #4675).
class TrackSample extends Equatable {
  const TrackSample({required this.ms, required this.box});

  /// Milliseconds from the start of the video.
  final int ms;

  /// Normalised against the video as the player displays it.
  final IdentificationBox box;

  TrackSample copyWith({int? ms, IdentificationBox? box}) =>
      TrackSample(ms: ms ?? this.ms, box: box ?? this.box);

  @override
  List<Object?> get props => [ms, box];
}
