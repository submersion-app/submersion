import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/data/services/photo_record_reader.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';

final photoRecordReaderProvider = Provider<PhotoRecordReader>(
  (ref) => PhotoRecordReader(
    media: ref.watch(mediaRepositoryProvider),
    species: ref.watch(mediaSpeciesRepositoryProvider),
    people: ref.watch(mediaPeopleRepositoryProvider),
    tags: ref.watch(tagLinkRepositoryProvider(TagScope.media)),
  ),
);

/// One photo as its editing sitting holds it (issue #4527); null when the
/// photo has no stored row. Ticks on the photo, its tags, the buddies they
/// name and its dive, so a sitting follows what changes underneath it.
/// Auto-disposed: one exists per photo the viewer shows.
final photoRecordProvider = FutureProvider.autoDispose
    .family<PhotoRecord?, String>((ref, mediaId) async {
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(mediaSpeciesRepositoryProvider).watchTagChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(mediaPeopleRepositoryProvider).watchTagChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(buddyRepositoryProvider).watchBuddiesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(tagLinkRepositoryProvider(TagScope.media)).watchChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return ref
          .watch(photoRecordReaderProvider)
          .read(mediaId, diverId: diverId);
    });

final photoEditSaveServiceProvider = Provider<PhotoEditSaveService>(
  (ref) => PhotoEditSaveService(
    reader: ref.watch(photoRecordReaderProvider),
    tagging: ref.watch(speciesTaggingServiceProvider),
    people: ref.watch(mediaPeopleRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
    colors: ref.watch(mediaColorAdjustmentRepositoryProvider),
    attachments: ref.watch(siteAttachmentRepositoryProvider),
    dives: ref.watch(diveRepositoryProvider),
    tags: ref.watch(tagLinkRepositoryProvider(TagScope.media)),
  ),
);
