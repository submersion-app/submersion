import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the photos tagged with the species on its page
/// (issue #4527, phase 3).
const String speciesTagsKey = 'species.tags';

const String _itemsKey = 'species.tags.items';

/// The photos the sitting will tag with its species at Save, in the order
/// they were chosen.
List<MediaItem> heldSpeciesTags(EditSession<Species> session) =>
    session.isDisposed
    ? const []
    : session.recall<List<MediaItem>>(_itemsKey) ?? const [];

/// Holds [items] to be tagged with the sitting's species at Save, with
/// those already held: one change of the Photos card. Each is tagged as the
/// tag picker tags it ([SpeciesTaggingService.tagPhoto]), which also logs
/// the sighting a dive photo needs, inside the sitting's transaction; one
/// that cannot be tagged fails the whole Save.
void holdSpeciesTags(
  EditSession<Species> session,
  Iterable<MediaItem> items,
  SpeciesTaggingService tagging,
) {
  if (session.isDisposed || session.isFrozen) return;
  final held = heldSpeciesTags(session);
  final ids = {for (final m in held) m.id};
  _hold(session, [
    ...held,
    for (final m in items)
      if (ids.add(m.id)) m,
  ], tagging);
}

/// Takes [mediaId] out of the photos to tag; none left is no change.
void releaseSpeciesTag(EditSession<Species> session, String mediaId) {
  if (session.isDisposed || session.isFrozen) return;
  final tagging = session.recall<SpeciesTaggingService>('$_itemsKey.service');
  if (tagging == null) return;
  _hold(session, [
    for (final m in heldSpeciesTags(session))
      if (m.id != mediaId) m,
  ], tagging);
}

void _hold(
  EditSession<Species> session,
  List<MediaItem> items,
  SpeciesTaggingService tagging,
) {
  session
    ..remember(_itemsKey, List<MediaItem>.unmodifiable(items))
    ..remember('$_itemsKey.service', tagging);
  if (items.isEmpty) {
    session.releaseWrite(speciesTagsKey);
    return;
  }
  final speciesId = session.stored.id;
  final ids = [for (final m in items) m.id];
  session.holdChange(
    speciesTagsKey,
    cardId: SpeciesCardId.photos.name,
    write: () async {
      for (final id in ids) {
        await tagging.tagPhoto(mediaId: id, speciesId: speciesId);
      }
    },
  );
}
