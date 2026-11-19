import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';

import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// One check-in as a gear item's sitting holds it (issue #4527, phase 3,
/// plan 6): the row, the photos added to it and removed from it in the
/// sitting, and whether the sitting deleted it. Its photos are written with
/// it, after its row, so a new check-in exists before the photos that name
/// it.
@immutable
class HeldCheckIn {
  const HeldCheckIn({
    required this.observation,
    this.added = const [],
    this.removedPhotoIds = const {},
    this.deleted = false,
  });

  final EquipmentObservation observation;

  /// Photos picked for it in the sitting, not yet written.
  final List<HeldMediaAdd> added;

  /// Its stored photos the sitting removed.
  final Set<String> removedPhotoIds;

  /// Deleted in the sitting: written at Save with its photos unlinked, in
  /// the same write.
  final bool deleted;

  bool get hasPhotoChanges => added.isNotEmpty || removedPhotoIds.isNotEmpty;

  HeldCheckIn copyWith({
    EquipmentObservation? observation,
    List<HeldMediaAdd>? added,
    Set<String>? removedPhotoIds,
    bool? deleted,
  }) => HeldCheckIn(
    observation: observation ?? this.observation,
    added: added ?? this.added,
    removedPhotoIds: removedPhotoIds ?? this.removedPhotoIds,
    deleted: deleted ?? this.deleted,
  );

  @override
  bool operator ==(Object other) =>
      other is HeldCheckIn &&
      other.observation == observation &&
      other.deleted == deleted &&
      const ListEquality<String>().equals(
        [for (final a in other.added) a.preview.id],
        [for (final a in added) a.preview.id],
      ) &&
      const SetEquality<String>().equals(
        other.removedPhotoIds,
        removedPhotoIds,
      );

  @override
  int get hashCode => Object.hash(
    observation,
    deleted,
    Object.hashAll([for (final a in added) a.preview.id]),
    Object.hashAllUnordered(removedPhotoIds),
  );
}

/// The item's check-ins held in its page's sitting: added, edited and
/// deleted there, with their photos, written at Save through the writers
/// the sitting keeps ([holdCheckIns]).
final gearItemCheckInsList =
    SittingList<EquipmentItem, HeldCheckIn>.withSession(
      key: 'equipment.checkIns',
      cardId: GearItemCardId.observations.name,
      read: (item) async => [
        for (final o in await EquipmentObservationRepository().getForEquipment(
          item.id,
        ))
          HeldCheckIn(observation: o),
      ],
      writeIn: (session, loaded, current) async {
        final writers = checkInWriters(session);
        final repository = EquipmentObservationRepository();
        final byId = {for (final c in loaded) c.observation.id: c};
        final kept = {for (final c in current) c.observation.id};
        var changed = false;
        for (final row in current) {
          final before = byId[row.observation.id];
          if (row == before) continue;
          changed = true;
          if (row.deleted) {
            if (before == null) continue;
            await _deleteWithPhotos(repository, row.observation.id, writers);
            continue;
          }
          final o = row.observation;
          if (before == null) {
            await repository.create(
              id: o.id,
              equipmentId: o.equipmentId,
              diveId: o.diveId,
              diverId: o.diverId,
              observedAt: o.observedAt,
              status: o.status,
              issueTags: o.issueTags,
              unrecognizedTags: o.unrecognizedTags,
              note: o.note,
            );
          } else if (before.observation != o) {
            await repository.update(o);
          }
          // After its row, so a new check-in exists before its photos.
          await _writePhotos(row, writers);
        }
        for (final row in loaded) {
          if (kept.contains(row.observation.id)) continue;
          await _deleteWithPhotos(repository, row.observation.id, writers);
          changed = true;
        }
        return changed;
      },
    );

Future<void> _writePhotos(HeldCheckIn row, SittingMediaWriters? writers) async {
  if (writers == null || !row.hasPhotoChanges) return;
  final rows = [
    for (final a in row.added)
      if (a is HeldMediaRow) a.prepared,
  ];
  if (rows.isNotEmpty) await writers.writeRows(rows);
  final network = [
    for (final a in row.added)
      if (a is HeldNetworkMedia) a.request,
  ];
  if (network.isNotEmpty) await writers.insertNetwork(network);
  if (row.removedPhotoIds.isNotEmpty) {
    await writers.unlink(row.removedPhotoIds.toList());
  }
}

/// Deletes check-in [id] and unlinks its photos in the same write: today a
/// failed unlink after the delete is swallowed (issue #4527, plan 6).
Future<void> _deleteWithPhotos(
  EquipmentObservationRepository repository,
  String id,
  SittingMediaWriters? writers,
) async {
  final photos = await GearPhotoRepository().photosForObservation(id);
  await repository.delete(id);
  if (photos.isNotEmpty && writers != null) {
    await writers.unlink([for (final m in photos) m.id]);
  }
}

const String _writersNote = 'equipment.checkIns.writers';

/// Keeps the writers the check-ins' photos are written with.
void holdCheckIns(
  EditSession<EquipmentItem> session,
  SittingMediaWriters writers,
) => session.remember(_writersNote, writers);

/// The writers [holdCheckIns] kept, or null.
SittingMediaWriters? checkInWriters(EditSession<EquipmentItem> session) =>
    session.isDisposed
    ? null
    : session.recall<SittingMediaWriters>(_writersNote);

/// Puts [row] into the sitting's check-ins, in place of the one with its id
/// or first as the newest. Does nothing before they are read.
void holdCheckIn(EditSession<EquipmentItem> session, HeldCheckIn row) {
  final rows = gearItemCheckInsList.current(session);
  if (rows == null) return;
  final known = rows.any((c) => c.observation.id == row.observation.id);
  gearItemCheckInsList.set(session, [
    if (!known) row,
    for (final c in rows) c.observation.id == row.observation.id ? row : c,
  ]);
}

/// Deletes the check-in [id] in the sitting: one added in it is dropped,
/// a stored one marked to be deleted with its photos at Save.
void deleteHeldCheckIn(EditSession<EquipmentItem> session, String id) {
  final rows = gearItemCheckInsList.current(session);
  if (rows == null) return;
  final stored = {
    for (final c
        in gearItemCheckInsList.loaded(session) ?? const <HeldCheckIn>[])
      c.observation.id,
  };
  gearItemCheckInsList.set(session, [
    for (final c in rows)
      if (c.observation.id != id)
        c
      else if (stored.contains(id))
        c.copyWith(deleted: true),
  ]);
}

/// What must happen once the sitting's write has committed: an upload
/// queued for each photo it wrote (none for a check-in it deleted), the
/// remote deletes its unlinks held, and the item's condition findings
/// refreshed from what is now stored.
List<Future<void> Function()> checkInsAfterCommit(
  EditSession<EquipmentItem> session,
) {
  final writers = checkInWriters(session);
  final rows = gearItemCheckInsList.current(session);
  if (writers == null ||
      rows == null ||
      !gearItemCheckInsList.isChanged(session)) {
    return const [];
  }
  final unlinked = rows.any((c) => c.deleted || c.removedPhotoIds.isNotEmpty);
  final itemId = session.stored.id;
  return [
    for (final c in rows)
      if (!c.deleted)
        for (final a in c.added)
          if (a is HeldMediaRow)
            () async => writers.enqueueUpload(a.prepared.item.id),
    if (unlinked) writers.drainDeletes,
    () async => scheduleConditionFindingsRefresh([itemId]),
  ];
}

/// [held] with [adds] put after it, less any photo [held] already has (the
/// same gallery asset, file or address), or that the sitting holds
/// elsewhere ([heldElsewhere], same-file keys): a photo picked twice is
/// held once.
List<HeldMediaAdd> withHeldPhotosAdded(
  List<HeldMediaAdd> held,
  List<HeldMediaAdd> adds, {
  Set<String> heldElsewhere = const {},
}) {
  final seen = {
    ...heldElsewhere,
    for (final a in held) ?mediaSameFileKey(a.preview),
  };
  return [
    ...held,
    for (final a in adds)
      if (switch (mediaSameFileKey(a.preview)) {
        null => true,
        final key => seen.add(key),
      })
        a,
  ];
}

/// The same-file keys of the photos held on the sitting's check-ins, check-in
/// [except]'s left out. The item has each photo once, as its stored photos
/// already are: a pick of one held here is not held again elsewhere.
Set<String> checkInPhotoKeys(
  EditSession<EquipmentItem> session, {
  String? except,
}) => {
  for (final c
      in gearItemCheckInsList.current(session) ?? const <HeldCheckIn>[])
    if (c.observation.id != except && !c.deleted)
      for (final a in c.added) ?mediaSameFileKey(a.preview),
};

/// The stored photos the sitting's check-ins unlink, check-in [except]'s
/// left out: gone from the item at Save, so a pick of one elsewhere is
/// taken back. A check-in deleted in the sitting unlinks its photos too,
/// but they are known only at Save, and are not among these.
Set<String> checkInPhotoUnlinks(
  EditSession<EquipmentItem> session, {
  String? except,
}) => {
  for (final c
      in gearItemCheckInsList.current(session) ?? const <HeldCheckIn>[])
    if (c.observation.id != except && !c.deleted) ...c.removedPhotoIds,
};

/// What the sitting holds outside one check-in: the photos it adds there,
/// by same-file key, and the stored photos it unlinks there.
typedef PhotosHeldElsewhere = ({Set<String> keys, Set<String> unlinked});

/// Nothing held elsewhere: a sheet opened outside a sitting.
const PhotosHeldElsewhere noPhotosHeldElsewhere = (keys: {}, unlinked: {});

/// The photos the sitting holds outside check-in [checkIn] (none for a new
/// one): on the Photos card and on every other check-in.
PhotosHeldElsewhere photosHeldOutside(
  EditSession<EquipmentItem> session, {
  String? checkIn,
}) {
  final media = sittingMedia(session);
  return (
    keys: {
      for (final a in media.added) ?mediaSameFileKey(a.preview),
      ...checkInPhotoKeys(session, except: checkIn),
    },
    unlinked: {
      ...media.unlinked,
      ...checkInPhotoUnlinks(session, except: checkIn),
    },
  );
}

/// [adds] less those whose file is among [keys].
List<HeldMediaAdd> photosNotHeld(List<HeldMediaAdd> adds, Set<String> keys) => [
  for (final a in adds)
    if (!keys.contains(mediaSameFileKey(a.preview))) a,
];
