import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';

/// Reads a photo as its editing sitting holds it (issue #4527): the row, its
/// species and people tags, and its dive's media time shift.
class PhotoRecordReader {
  PhotoRecordReader({
    required MediaRepository media,
    required MediaSpeciesRepository species,
    required MediaPeopleRepository people,
    required TagLinkRepository tags,
  }) : _media = media,
       _species = species,
       _people = people,
       _tags = tags;

  final MediaRepository _media;
  final MediaSpeciesRepository _species;
  final MediaPeopleRepository _people;
  final TagLinkRepository _tags;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Null when the media row does not exist. [diverId] scopes the people
  /// tags to the active diver's buddies, as the viewer's chips are.
  Future<PhotoRecord?> read(String mediaId, {required String? diverId}) async {
    final item = await _media.getMediaById(mediaId);
    if (item == null) return null;
    final species = await _species.getTagChipsForMedia(mediaId);
    final people = await _people.getChipsForMedia(mediaId, diverId: diverId);
    final tags = await _tags.getTagsFor(mediaId);
    final diveId = item.diveId;
    return PhotoRecord(
      tags: tags,
      item: item,
      species: species,
      people: people,
      diveShiftSeconds: diveId == null ? null : await _diveShift(diveId),
    );
  }

  /// The dive's shift, read on its own: the dive repository's read brings
  /// the whole profile with it.
  Future<int?> _diveShift(String diveId) async {
    final dives = _db.dives;
    final row =
        await (_db.selectOnly(dives)
              ..addColumns([dives.mediaTimeOffsetSeconds])
              ..where(dives.id.equals(diveId)))
            .getSingleOrNull();
    return row?.read(dives.mediaTimeOffsetSeconds);
  }
}
