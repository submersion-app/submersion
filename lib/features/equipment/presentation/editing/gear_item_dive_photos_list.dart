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
