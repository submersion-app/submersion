import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// What one photo's editing sitting is over (issue #4527): the photo or
/// video itself, its species and people tags, and the time shift its dive
/// gives every photo on it.
///
/// The tags and the shift live in other tables, so they are read with the
/// row and carried here: the viewer's lock covers everything its controls
/// change, and a sitting compares and saves them as one record.
@immutable
class PhotoRecord extends Equatable {
  const PhotoRecord({
    required this.item,
    required this.species,
    required this.people,
    this.diveShiftSeconds,
    this.tags = const [],
  });

  final MediaItem item;

  /// The species tagged on the photo, as its chips show them.
  final List<SpeciesTagChip> species;

  /// The people tagged on the photo, as its chips and boxes show them.
  final List<MediaPersonChip> people;

  /// The dive's `mediaTimeOffsetSeconds`; null for media with no dive.
  final int? diveShiftSeconds;

  /// The photo's own tags (#1970).
  final List<Tag> tags;

  PhotoRecord copyWith({
    MediaItem? item,
    List<SpeciesTagChip>? species,
    List<MediaPersonChip>? people,
    int? diveShiftSeconds,
    List<Tag>? tags,
  }) => PhotoRecord(
    item: item ?? this.item,
    species: species ?? this.species,
    people: people ?? this.people,
    diveShiftSeconds: diveShiftSeconds ?? this.diveShiftSeconds,
    tags: tags ?? this.tags,
  );

  @override
  List<Object?> get props => [item, species, people, diveShiftSeconds, tags];
}
