import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
