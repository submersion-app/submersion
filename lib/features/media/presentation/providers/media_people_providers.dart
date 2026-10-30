import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

final mediaPeopleRepositoryProvider = Provider<MediaPeopleRepository>(
  (ref) => MediaPeopleRepository(),
);

/// The people tagged on one photo or video, as the viewer shows them, for
/// the active diver (issue #1745). Ticks on tags and on buddy renames.
/// Auto-disposed: one exists per media item shown, and a non-disposing
/// family would keep one alive, with its table subscriptions, for every
/// item ever viewed.
final mediaPeopleChipsProvider = FutureProvider.autoDispose
    .family<List<MediaPersonChip>, String>((ref, mediaId) async {
      final repository = ref.watch(mediaPeopleRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(buddyRepositoryProvider).watchBuddiesChanges(),
      );
      return repository.getChipsForMedia(mediaId, diverId: diverId);
    });

/// Every photo and video a buddy is tagged in, newest first, for the
/// active diver. Ticks on tags and on media.
final mediaForBuddyProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, buddyId) async {
      final repository = ref.watch(mediaPeopleRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      return repository.getMediaForBuddy(buddyId, diverId: diverId);
    });

/// The buddies tagged on at least one photo or video, for the library's
/// People filter: a buddy nobody has tagged would only ever match nothing.
final taggedBuddyIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final repository = ref.watch(mediaPeopleRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  return repository.getTaggedBuddyIds(diverId: diverId);
});

/// Who the person picker offers, in its order: Me (the active diver), the
/// buddies logged on the dive, then everyone else by name.
class PersonPickerOptions {
  /// The active diver a Me tag names; null when there is no diver at all.
  final String? meDiverId;
  final List<Buddy> onThisDive;
  final List<Buddy> everyoneElse;

  const PersonPickerOptions({
    required this.meDiverId,
    required this.onThisDive,
    required this.everyoneElse,
  });
}

/// The picker's people for a photo on [diveId]; with no dive, nobody is
/// "on this dive" and every buddy is listed under everyone else.
final personPickerOptionsProvider = FutureProvider.autoDispose
    .family<PersonPickerOptions, String?>((ref, diveId) async {
      final meDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final all = await ref.watch(allBuddiesProvider.future);
      final onDive = diveId == null
          ? const <String>{}
          : {
              for (final b in await ref.watch(
                buddiesForDiveProvider(diveId).future,
              ))
                b.buddy.id,
            };
      final byName = [...all]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return PersonPickerOptions(
        meDiverId: meDiverId,
        onThisDive: [
          for (final b in byName)
            if (onDive.contains(b.id)) b,
        ],
        everyoneElse: [
          for (final b in byName)
            if (!onDive.contains(b.id)) b,
        ],
      );
    });
