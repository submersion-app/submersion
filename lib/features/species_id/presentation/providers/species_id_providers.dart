import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

/// Marine life identification (issue #4668).

final mediaIdentificationRepositoryProvider =
    Provider<MediaIdentificationRepository>(
      (ref) => MediaIdentificationRepository(),
    );

final identificationEmbeddingRepositoryProvider =
    Provider<IdentificationEmbeddingRepository>(
      (ref) => IdentificationEmbeddingRepository(),
    );

final identificationCropStoreProvider = Provider<IdentificationCropStore>(
  (ref) => IdentificationCropStore(supportPath: AppDirectories.support),
);

final identificationCleanupProvider = Provider<IdentificationCleanup>(
  (ref) => IdentificationCleanup(
    identifications: ref.watch(mediaIdentificationRepositoryProvider),
    embeddings: ref.watch(identificationEmbeddingRepositoryProvider),
    crops: ref.watch(identificationCropStoreProvider),
  ),
);
