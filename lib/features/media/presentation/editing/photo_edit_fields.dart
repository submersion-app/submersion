import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What a photo's sitting changed, as named in its History label and in
/// [EditSession.changedCardIds] (issue #4527). The viewer has no cards; these
/// ids only name the kinds of change.
const photoSpeciesCardId = 'species';
const photoPeopleCardId = 'people';
const photoTimeCardId = 'time';
const photoColorCardId = 'color';
const photoDetailsCardId = 'details';
const photoFileCardId = 'file';
const photoTagsCardId = 'tags';

/// The species tagged and untagged, as edits on the stored tags.
final photoSpeciesField = EditField<PhotoRecord, SpeciesTagEdits>(
  id: 'photoSpecies',
  cardId: photoSpeciesCardId,
  read: (_) => SpeciesTagEdits.none,
  write: (record, edits) =>
      record.copyWith(species: edits.applyTo(record.species)),
);

/// The people tagged, moved, re-assigned and removed, as edits.
final photoPeopleField = EditField<PhotoRecord, PersonTagEdits>(
  id: 'photoPeople',
  cardId: photoPeopleCardId,
  read: (_) => PersonTagEdits.none,
  write: (record, edits) =>
      record.copyWith(people: edits.applyTo(record.people)),
);

/// The photo's own tags (#1970), as edits.
final photoTagsField = EditField<PhotoRecord, MediaTagEdits>(
  id: 'photoTags',
  cardId: photoTagsCardId,
  read: (_) => MediaTagEdits.none,
  write: (record, edits) => record.copyWith(tags: edits.applyTo(record.tags)),
);

/// The moment in the dive the diver pinned the photo to.
final photoPinField = EditField<PhotoRecord, int?>(
  id: 'photoPin',
  cardId: photoTimeCardId,
  read: (record) => record.item.manualElapsedSeconds,
  write: (record, seconds) => record.copyWith(
    item: record.item.copyWith(manualElapsedSeconds: seconds),
  ),
);

/// The shift the photo's dive gives every photo on it.
final photoDiveShiftField = EditField<PhotoRecord, int?>(
  id: 'photoDiveShift',
  cardId: photoTimeCardId,
  read: (record) => record.diveShiftSeconds,
  write: (record, seconds) => PhotoRecord(
    item: record.item,
    species: record.species,
    people: record.people,
    diveShiftSeconds: seconds,
    tags: record.tags,
  ),
);

/// The colour the photo is drawn with.
final photoColorField = EditField<PhotoRecord, ColorAdjustment?>(
  id: 'photoColor',
  cardId: photoColorCardId,
  read: (record) => record.item.colorAdjustment,
  write: (record, color) =>
      record.copyWith(item: record.item.copyWith(colorAdjustment: color)),
  // The repository stores a cleared adjustment as the neutral one, so the
  // two are the same colour.
  equals: (a, b) =>
      (a ?? const ColorAdjustment()) == (b ?? const ColorAdjustment()),
);

/// A site attachment's category.
final photoSiteCategoryField = EditField<PhotoRecord, SiteAttachmentCategory?>(
  id: 'photoSiteCategory',
  cardId: photoDetailsCardId,
  read: (record) => record.item.siteCategory,
  write: (record, category) =>
      record.copyWith(item: record.item.copyWith(siteCategory: category)),
);

/// A site attachment's display size, or null to follow its category.
final photoDisplaySizeField = EditField<PhotoRecord, AttachmentDisplaySize?>(
  id: 'photoDisplaySize',
  cardId: photoDetailsCardId,
  read: (record) => record.item.displaySizeOverride,
  write: (record, size) =>
      record.copyWith(item: record.item.copyWith(displaySizeOverride: size)),
);

const _automaticKey = 'photo:automatic';

/// Holds the Set time dialog's [choice] in the sitting, as
/// `MediaTimePinner.apply` would write it: a pin, its removal, a shift for
/// the whole dive (which drops this photo's pin), or no shift.
///
/// [automatic] is where the photo sits by its capture time, kept so the
/// sitting can show the photo where a shift or a removed pin puts it.
void applyTimeChoice(
  EditSession<PhotoRecord> session,
  MediaTimeChoice choice, {
  MediaAutomaticTime? automatic,
}) {
  if (automatic != null) session.remember(_automaticKey, automatic);
  switch (choice) {
    case MediaTimePinned(:final elapsedSeconds):
      session.set(photoPinField, elapsedSeconds);
    case MediaTimeReset():
      session.set(photoPinField, null);
    case MediaTimeDiveShifted(:final shiftSeconds):
      session.set(photoDiveShiftField, shiftSeconds);
      session.set(photoPinField, null);
    case MediaTimeDiveShiftRemoved():
      session.set(photoDiveShiftField, 0);
  }
}

/// Holds the Set time dialog's [choice] for [mediaId] in [session], once
/// [automatic] (the dialog's own lookup) has answered. Does nothing when the
/// sitting ended, is being saved, or is over another photo by then.
Future<void> holdTimeChoice(
  EditSession<PhotoRecord> session,
  String mediaId,
  MediaTimeChoice choice,
  Future<MediaAutomaticTime?> automatic,
) async {
  final place = await automatic;
  if (session.isDisposed ||
      session.isFrozen ||
      session.stored.item.id != mediaId) {
    return;
  }
  applyTimeChoice(session, choice, automatic: place);
}

/// Where the sitting puts the photo in its dive, in seconds from the
/// start; null when its time is as stored, or when where it lands is not
/// known (no automatic time), so the stored position stands.
int? elapsedInSitting(EditSession<PhotoRecord> session) {
  final stored = session.stored;
  final pin = session.valueOf(photoPinField);
  final shift = session.valueOf(photoDiveShiftField);
  final pinChanged = pin != stored.item.manualElapsedSeconds;
  final shiftChanged = shift != stored.diveShiftSeconds;
  if (!pinChanged && !shiftChanged) return null;
  if (pin != null) return pin;
  final automatic = session.recall<MediaAutomaticTime>(_automaticKey);
  if (automatic == null) return null;
  return automatic.elapsedSeconds + ((shift ?? 0) - automatic.diveShiftSeconds);
}

/// The held change of Locate (Task 13): the photo relinked at Save.
const photoRelinkKey = 'photo:relink';

/// The note under which the sitting keeps the relink it holds.
const photoRelinkProposalKey = 'photo:relink.proposal';

/// The relink [session] holds for its photo, or null.
RepairProposal? heldRelink(EditSession<PhotoRecord> session) =>
    session.isDisposed || !session.isHeld(photoRelinkKey)
    ? null
    : session.recall<RepairProposal>(photoRelinkProposalKey);

/// [item] pointing at the file [session]'s held relink found, as the relink
/// will write it ([relinkedToFile], the repair's own rule); [item] itself
/// with none held.
///
/// Its last check is left unknown until Save makes one. A file is linked
/// on this device ([thisDevice], unknown when null).
MediaItem withHeldRelink(
  EditSession<PhotoRecord> session,
  MediaItem item, {
  String? thisDevice,
}) {
  final candidate = heldRelink(session)?.candidate;
  if (candidate == null || candidate.path == null) return item;
  return relinkedToFile(
    item,
    candidate,
    originDeviceId: thisDevice,
    verifiedAt: null,
  );
}

const _enrichment = EnrichmentService();

/// The photo as the sitting has it, with its position worked out from
/// [profile] when the sitting moved it in time, so the chips, the mini
/// profile and the dive computer face show the held time at once, and with
/// the file a held relink found.
MediaItem photoShownItem(
  EditSession<PhotoRecord> session,
  List<DiveProfilePoint> profile,
) {
  final item = withHeldRelink(session, session.working.item);
  final elapsed = elapsedInSitting(session);
  if (elapsed == null) return item;
  final result = _enrichment.calculateEnrichmentAtElapsed(
    profile: profile,
    elapsedSeconds: elapsed,
  );
  final existing = item.enrichment;
  final pinned = item.manualElapsedSeconds != null;
  // A shift places the photo by its capture time, so it keeps the stored
  // match's confidence; the calculation reports every placement as manual.
  final confidence =
      pinned || result.matchConfidence == MatchConfidence.noProfile
      ? result.matchConfidence
      : existing == null || existing.isManual
      ? MatchConfidence.interpolated
      : existing.matchConfidence;
  return item.copyWith(
    enrichment: MediaEnrichment(
      id: existing?.id ?? '',
      mediaId: item.id,
      diveId: item.diveId ?? existing?.diveId ?? '',
      depthMeters: result.depthMeters,
      temperatureCelsius: result.temperatureCelsius,
      elapsedSeconds: result.elapsedSeconds,
      matchConfidence: confidence,
      timestampOffsetSeconds: result.timestampOffsetSeconds,
      createdAt: existing?.createdAt ?? DateTime.now(),
    ),
  );
}
