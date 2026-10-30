import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// "{copied} of {total} copied" for the Photos page (issue #3482), counted
/// with the backfill's own rule. Re-counts when media change and as the
/// transfer queue moves, so uploads landing tick the count up.
final mediaUploadProgressProvider =
    FutureProvider.autoDispose<({int copied, int total})>((ref) async {
      final repository = ref.watch(mediaRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchMediaChanges());
      ref.watch(mediaTransferSummaryProvider.select((s) => s.value?.total));
      // A store the library no longer announces leaves out rows another
      // device moved to the announced one (issue #3569). Watched before the
      // first await, like every dependency here, so a tick during the wait
      // cannot meet a build that is already gone.
      final stores = ref.watch(mediaStoresRepositoryProvider);
      ref.invalidateSelfWhen(stores.watchStoresChanges());
      // Counted for the attached store: copies in another store are not
      // copies here (issue #3482).
      final storeId = await ref.watch(mediaAttachedStoreIdProvider.future);
      final announced = (await stores.getActive())?.id;
      return repository.countUploadProgress(
        storeId: storeId,
        takesOver: takesOverStores(storeId, announced),
      );
    }, retry: (_, _) => null);
