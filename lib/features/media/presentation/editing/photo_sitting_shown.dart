import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Whether a read of a photo's stored row ([row], `mediaByIdProvider`)
/// leaves it without one: not answered yet, or answered with none (a photo
/// held only in a dive's sitting). Nothing that acts on the stored row is
/// offered then. A read that failed is not taken as no row.
bool noStoredRow(AsyncValue<MediaItem?> row) =>
    row.hasValue ? row.value == null : row.isLoading;

/// Whether [sitting] is a sitting over the photo [mediaId].
bool sittingIsOver(EditSession<PhotoRecord>? sitting, String mediaId) =>
    sitting != null && !sitting.isDisposed && sitting.stored.item.id == mediaId;

/// The species chips to show for [mediaId] (issue #4527): the sitting's when
/// it is over that photo, the stored ones otherwise.
List<SpeciesTagChip> speciesChipsShown(
  WidgetRef ref,
  String mediaId,
  EditSession<PhotoRecord>? sitting,
) {
  if (sittingIsOver(sitting, mediaId)) return sitting!.working.species;
  return ref.watch(mediaTagChipsProvider(mediaId)).value ?? const [];
}

/// The people chips to show for [mediaId], as [speciesChipsShown] does.
List<MediaPersonChip> peopleChipsShown(
  WidgetRef ref,
  String mediaId,
  EditSession<PhotoRecord>? sitting,
) {
  if (sittingIsOver(sitting, mediaId)) return sitting!.working.people;
  return ref.watch(mediaPeopleChipsProvider(mediaId)).value ?? const [];
}
