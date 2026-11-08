import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/card_photo_repository.dart';
import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

final cardPhotoRepositoryProvider = Provider<CardPhotoRepository>(
  (ref) => CardPhotoRepository(),
);

/// Every dive's candidate card photos, read once for the whole log, for the
/// active diver.
///
/// Refreshed when media changes, when a people tag is added, moved or
/// removed (the tags place the crop), and when the diver changes (only its
/// own tags count).
final cardPhotosByDiveProvider = FutureProvider<Map<String, List<CardPhoto>>>((
  ref,
) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(
    ref.watch(mediaRepositoryProvider).watchMediaChanges(),
  );
  ref.invalidateSelfWhen(
    ref.watch(mediaPeopleRepositoryProvider).watchTagChanges(),
  );
  return ref
      .watch(cardPhotoRepositoryProvider)
      .getCardPhotosByDive(diverId: diverId);
});

/// The photos that could not be drawn on this device this session: missing,
/// access denied, or bytes that do not decode. Kept in memory only, so a
/// photo that comes back (a reconnected drive, access granted) is tried
/// again on the next launch.
class FailedCardPhotosNotifier extends StateNotifier<Set<String>> {
  FailedCardPhotosNotifier() : super(const {});

  void markFailed(String mediaId) {
    if (state.contains(mediaId)) return;
    state = {...state, mediaId};
  }
}

final failedCardPhotosProvider =
    StateNotifierProvider<FailedCardPhotosNotifier, Set<String>>(
      (ref) => FailedCardPhotosNotifier(),
    );

/// The photo behind [diveId]'s card, or null when it has none (or the
/// photos are still loading).
///
/// A photo that failed to draw is passed over for another of the dive's,
/// up to [CardPhotoTuning.maxPhotoAttempts] of them; after that the card
/// shows the map or the attribute colour.
///
/// Watches only this dive's entry, so a refresh that leaves it unchanged
/// does not rebuild the card. A failure elsewhere recomputes the pick, which
/// comes out as the same photo, so the card does not rebuild either.
final cardPhotoForDiveProvider = Provider.family<CardPhoto?, String>((
  ref,
  diveId,
) {
  final photos = ref.watch(
    cardPhotosByDiveProvider.select((async) => async.value?[diveId]),
  );
  if (photos == null) return null;
  final failed = ref.watch(failedCardPhotosProvider);
  final usable = [
    for (final photo in photos)
      if (!failed.contains(photo.mediaId)) photo,
  ];
  if (photos.length - usable.length >= CardPhotoTuning.maxPhotoAttempts) {
    return null;
  }
  return pickCardPhoto(diveId, usable);
});

/// The shared, in-memory crop analysis for card photos.
final cardFocusAnalyzerProvider = Provider<CardFocusAnalyzer>(
  (ref) => CardFocusAnalyzer(),
);
