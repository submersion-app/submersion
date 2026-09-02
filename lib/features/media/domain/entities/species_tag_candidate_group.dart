import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// One dive on which a species was sighted, with the photos on that dive
/// that are not yet tagged with it. Feeds the tag picker's grouped grid.
class SpeciesTagCandidateGroup extends Equatable {
  final String diveId;
  final int? diveNumber;
  final DateTime diveDateTime;
  final String? siteName;

  /// The dive's sighting of the species; a tag made from this group links
  /// to it.
  final String sightingId;
  final List<MediaItem> items;

  const SpeciesTagCandidateGroup({
    required this.diveId,
    this.diveNumber,
    required this.diveDateTime,
    this.siteName,
    required this.sightingId,
    required this.items,
  });

  SpeciesTagCandidateGroup copyWith({
    String? diveId,
    int? diveNumber,
    DateTime? diveDateTime,
    String? siteName,
    String? sightingId,
    List<MediaItem>? items,
  }) {
    return SpeciesTagCandidateGroup(
      diveId: diveId ?? this.diveId,
      diveNumber: diveNumber ?? this.diveNumber,
      diveDateTime: diveDateTime ?? this.diveDateTime,
      siteName: siteName ?? this.siteName,
      sightingId: sightingId ?? this.sightingId,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    diveId,
    diveNumber,
    diveDateTime,
    siteName,
    sightingId,
    items,
  ];
}
