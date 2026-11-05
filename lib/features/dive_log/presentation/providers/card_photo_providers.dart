import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/card_photo_repository.dart';
import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

final cardPhotoRepositoryProvider = Provider<CardPhotoRepository>(
  (ref) => CardPhotoRepository(),
);

/// Every dive's candidate card photos, read once for the whole log and
/// refreshed when media changes.
final cardPhotosByDiveProvider = FutureProvider<Map<String, List<CardPhoto>>>((
  ref,
) async {
  ref.invalidateSelfWhen(
    ref.watch(mediaRepositoryProvider).watchMediaChanges(),
  );
  return ref.watch(cardPhotoRepositoryProvider).getCardPhotosByDive();
});

/// The photo behind [diveId]'s card, or null when it has none (or the
/// photos are still loading).
///
/// Watches only this dive's entry, so a refresh that leaves it unchanged
/// does not rebuild the card.
final cardPhotoForDiveProvider = Provider.family<CardPhoto?, String>((
  ref,
  diveId,
) {
  final photos = ref.watch(
    cardPhotosByDiveProvider.select((async) => async.value?[diveId]),
  );
  if (photos == null) return null;
  return pickCardPhoto(diveId, photos);
});

/// The shared, in-memory crop analysis for card photos.
final cardFocusAnalyzerProvider = Provider<CardFocusAnalyzer>(
  (ref) => CardFocusAnalyzer(),
);
