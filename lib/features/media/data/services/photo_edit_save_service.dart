import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/services/photo_record_reader.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';

/// Saves one editing sitting on a photo or video (issue #4527).
///
/// As `DiveEditSaveService` does for a dive: the diver's changes are applied
/// to the photo as it is stored at the moment of saving, so a value changed
/// underneath meanwhile on something the diver never touched is not written
/// back; everything is written in one database transaction, so a failure
/// leaves nothing half saved; and in one change log operation, so the
/// sitting is one History entry that reverts as a unit. A dive photo's rows
/// belong to its dive in the change log, so the entry sits in the dive's
/// History.
class PhotoEditSaveService {
  PhotoEditSaveService({
    required PhotoRecordReader reader,
    required SpeciesTaggingService tagging,
    required MediaPeopleRepository people,
    required MediaRepository media,
    required MediaColorAdjustmentRepository colors,
    required SiteAttachmentRepository attachments,
    required DiveRepository dives,
  }) : _reader = reader,
       _tagging = tagging,
       _people = people,
       _media = media,
       _colors = colors,
       _attachments = attachments,
       _dives = dives;

  final PhotoRecordReader _reader;
  final SpeciesTaggingService _tagging;
  final MediaPeopleRepository _people;
  final MediaRepository _media;
  final MediaColorAdjustmentRepository _colors;
  final SiteAttachmentRepository _attachments;
  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Applies [apply] to the photo as stored now and writes what differs,
  /// then [alsoWrite], the sitting's writes to other records (a buddy added
  /// to the dive, the colour applied to the dive's other photos).
  ///
  /// [changedCardIds] names what the sitting changed, for its History label.
  /// Returns the photo before and after, or null when nothing differed and
  /// [alsoWrite] is not a change in its own right ([alsoWriteIsAChange]).
  /// Throws [StateError] when the photo no longer exists. [diverId] scopes
  /// the people tags read, as the viewer's are.
  Future<({PhotoRecord before, PhotoRecord after})?> save({
    required String mediaId,
    required String? diverId,
    required PhotoRecord Function(PhotoRecord stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) {
    // The scope goes outside the transaction it covers, as its own contract
    // requires. An operation that ends with no events is removed when the
    // log settles, so returning early below leaves nothing behind.
    return ChangeLogScope.run(
      DatabaseService.instance.databaseOrNull,
      source: ChangeLogSource.manual,
      label: RecordEditLabel.encode(table: 'media', cardIds: changedCardIds),
      body: () => _db.transaction(() async {
        final stored = await _reader.read(mediaId, diverId: diverId);
        if (stored == null) {
          throw StateError('Media $mediaId no longer exists');
        }
        final merged = apply(stored);
        if (merged == stored) {
          if (!alsoWriteIsAChange || alsoWrite == null) return null;
          await alsoWrite();
          return (before: stored, after: stored);
        }
        await _write(stored, merged);
        await alsoWrite?.call();
        return (before: stored, after: merged);
      }),
    );
  }

  Future<void> _write(PhotoRecord before, PhotoRecord after) async {
    final id = after.item.id;
    await _writeSpecies(id, before, after);
    await _writePeople(id, before, after);
    final pin = after.item.manualElapsedSeconds;
    if (pin != before.item.manualElapsedSeconds) {
      await _media.setManualElapsedSeconds(id, pin);
    }
    final color = after.item.colorAdjustment;
    if (color != before.item.colorAdjustment) {
      await _colors.setColorAdjustment(id, color);
    }
    final details = diffAttachmentDetails(
      before.item,
      category: after.item.siteCategory,
      displaySize: after.item.displaySizeOverride,
    );
    if (!details.isEmpty) {
      await _attachments.setAttachmentDetails(id, details);
    }
    final diveId = after.item.diveId;
    final shift = after.diveShiftSeconds;
    if (diveId != null && shift != null && shift != before.diveShiftSeconds) {
      await _dives.setMediaTimeOffsetSeconds(diveId, shift);
    }
  }

  Future<void> _writeSpecies(
    String id,
    PhotoRecord before,
    PhotoRecord after,
  ) async {
    final had = {for (final chip in before.species) chip.speciesId};
    final has = {for (final chip in after.species) chip.speciesId};
    for (final speciesId in had.difference(has)) {
      await _tagging.untagPhoto(mediaId: id, speciesId: speciesId);
    }
    // A tag on a dive photo adds the dive's sighting when none exists.
    for (final speciesId in has.difference(had)) {
      await _tagging.tagPhoto(mediaId: id, speciesId: speciesId);
    }
  }

  Future<void> _writePeople(
    String id,
    PhotoRecord before,
    PhotoRecord after,
  ) async {
    final had = {for (final chip in before.people) chip.tag.id: chip.tag};
    final kept = {for (final chip in after.people) chip.tag.id};
    for (final tagId in had.keys) {
      if (!kept.contains(tagId)) await _people.removeTag(tagId);
    }
    for (final chip in after.people) {
      final tag = chip.tag;
      final stored = had[tag.id];
      if (stored == null) {
        // Made in the sitting under a local id: the repository gives it its
        // own, and keeps one tag per person as it always does.
        await _people.addTag(
          mediaId: id,
          buddyId: tag.buddyId,
          diverId: tag.diverId,
          box: tag.box,
          videoPosition: tag.videoPosition,
        );
      } else if (!samePersonTag(stored, tag)) {
        await _people.updateTag(tag);
      }
    }
  }
}
