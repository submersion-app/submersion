import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart'
    show mergedIds;
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The photos linked to a gear item (issue #5046), held in its page's
/// sitting: linked and unlinked on the In dive photos card, written at Save.
///
/// Reads every linked photo, whoever's dive it is on; the card shows only
/// those the diver can see ([gearItemDivePhotosShown]). A photo the card
/// never showed is never removed from the list, so Save keeps its link,
/// and only the difference is written, onto the links as stored then.
final gearItemDivePhotosList = SittingList<EquipmentItem, MediaItem>(
  key: 'equipment.divePhotos',
  cardId: GearItemCardId.divePhotos.name,
  read: (item) => MediaGearRepository().linkedMediaFor(item.id, diverId: null),
  write: (item, loaded, current) async {
    final repository = MediaGearRepository();
    final now = await repository.mediaIdsFor(item.id);
    final merged = mergedIds(
      stored: now,
      loaded: [for (final m in loaded) m.id],
      current: [for (final m in current) m.id],
    );
    // Nothing to write when a sync made the same change meanwhile.
    if (sameIdSets(merged, now, (id) => id)) return false;
    await repository.replaceMedia(item.id, merged, notify: false);
    return true;
  },
  same: (a, b) => sameIdSets(a, b, (m) => m.id),
);

/// [current] with [keep] in place of the photos the card showed
/// ([shownNow]): links the diver cannot see stay, and no photo is listed
/// twice, even when the picker opened before the card knew what it showed.
List<MediaItem> replaceShownLinks({
  required List<MediaItem> current,
  required List<MediaItem> shownNow,
  required List<MediaItem> keep,
}) {
  final shownIds = {for (final m in shownNow) m.id};
  final keepIds = {for (final m in keep) m.id};
  final seen = <String>{};
  return [
    for (final m in [
      for (final m in current)
        if (!shownIds.contains(m.id) && !keepIds.contains(m.id)) m,
      ...keep,
    ])
      if (seen.add(m.id)) m,
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
    for (final m in current)
      if (m.id != mediaId) m,
  ]);
}

/// The photos the card shows from [session]'s list: those the diver can
/// see ([visibleIds], the stored links the Library scope lets through),
/// and every photo linked in this sitting, which the picker only offers
/// from what the diver can see. Null until the list has been read.
List<MediaItem>? gearItemDivePhotosShown(
  EditSession<EquipmentItem> session, {
  required Set<String> visibleIds,
}) {
  final current = gearItemDivePhotosList.current(session);
  if (current == null) return null;
  final loaded = {
    for (final m in gearItemDivePhotosList.loaded(session) ?? const []) m.id,
  };
  return [
    for (final m in current)
      if (visibleIds.contains(m.id) || !loaded.contains(m.id)) m,
  ];
}
