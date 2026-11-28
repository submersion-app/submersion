import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart'
    show mergedIds;
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The ids of the photos linked to a gear item (issue #5046), held in its
/// page's sitting: linked and unlinked on the In dive photos card, written
/// at Save.
///
/// Ids only, so an item linked to thousands of photos opens without reading
/// them: the card reads the rows of the few it draws. Holds every linked
/// photo, whoever's dive it is on; the card shows only those the diver can
/// see ([gearItemDivePhotosShown]). A photo the card never showed is never
/// removed from the list, so Save keeps its link, and only the difference
/// is written, onto the links as stored then.
final gearItemDivePhotosList = SittingList<EquipmentItem, String>(
  key: 'equipment.divePhotos',
  cardId: GearItemCardId.divePhotos.name,
  read: (item) => MediaGearRepository().mediaIdsFor(item.id),
  write: (item, loaded, current) async {
    final repository = MediaGearRepository();
    final now = await repository.mediaIdsFor(item.id);
    final merged = mergedIds(stored: now, loaded: loaded, current: current);
    // Nothing to write when a sync made the same change meanwhile.
    if (sameIdSets(merged, now, (id) => id)) return false;
    await repository.replaceMedia(item.id, merged, notify: false);
    return true;
  },
  same: (a, b) => sameIdSets(a, b, (id) => id),
);

/// [current] with [keep] in place of the photos the card showed
/// ([shownNow]): links the diver cannot see stay, and no photo is listed
/// twice, even when the picker opened before the card knew what it showed.
List<String> replaceShownLinks({
  required List<String> current,
  required List<String> shownNow,
  required List<String> keep,
}) {
  final shown = shownNow.toSet();
  final kept = keep.toSet();
  final seen = <String>{};
  return [
    for (final id in [
      for (final id in current)
        if (!shown.contains(id) && !kept.contains(id)) id,
      ...keep,
    ])
      if (seen.add(id)) id,
  ];
}

/// Unlinks photo [mediaId] in [session]'s list, reading the list first when
/// the sitting has not yet: the card shows the stored photos, with their
/// unlink buttons, before that read answers.
Future<void> unlinkHeldPhoto(
  EditSession<EquipmentItem> session,
  String mediaId,
) async {
  final current = await gearItemDivePhotosList.currentOrRead(session);
  if (current == null || session.isDisposed || session.isFrozen) return;
  gearItemDivePhotosList.set(session, [
    for (final id in current)
      if (id != mediaId) id,
  ]);
}

/// The photos the card shows from [session]'s list, newest link first: each
/// photo linked in this sitting (the picker offers only what the diver can
/// see), then the stored links the diver can see ([visibleIds], newest
/// first) that the sitting still holds. Null until the list has been read.
List<String>? gearItemDivePhotosShown(
  EditSession<EquipmentItem> session, {
  required List<String> visibleIds,
}) {
  final current = gearItemDivePhotosList.current(session);
  if (current == null) return null;
  final loaded = {...?gearItemDivePhotosList.loaded(session)};
  final visible = visibleIds.toSet();
  final held = current.toSet();
  return [
    // Once each: a photo also linked elsewhere since takes its stored place.
    for (final id in current.reversed)
      if (!loaded.contains(id) && !visible.contains(id)) id,
    for (final id in visibleIds)
      if (held.contains(id)) id,
  ];
}
