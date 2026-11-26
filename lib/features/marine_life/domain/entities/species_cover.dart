import 'package:equatable/equatable.dart';

/// The picture a diver chose to stand for a species (issue #5027): a crop
/// when [identificationId] is set, else the whole tagged photo.
class SpeciesCover extends Equatable {
  const SpeciesCover({
    required this.speciesId,
    required this.mediaId,
    this.identificationId,
  });

  final String speciesId;
  final String mediaId;
  final String? identificationId;

  SpeciesCover copyWith({
    String? speciesId,
    String? mediaId,
    String? identificationId,
  }) => SpeciesCover(
    speciesId: speciesId ?? this.speciesId,
    mediaId: mediaId ?? this.mediaId,
    identificationId: identificationId ?? this.identificationId,
  );

  @override
  List<Object?> get props => [speciesId, mediaId, identificationId];
}
