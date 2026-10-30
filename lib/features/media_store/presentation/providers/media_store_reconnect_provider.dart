import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_store_reconnect.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// The guided reconnect after a store marker mismatch (issue #2303). Reads
/// the account through the same adapter the runtime builds its store with,
/// so the marker it checks is the one the preflight checked.
final mediaStoreReconnectProvider = Provider<MediaStoreReconnect>((ref) {
  final accounts = ref.watch(connectedAccountsRepositoryProvider);
  final registry = ref.watch(accountProviderRegistryProvider);
  return MediaStoreReconnect(
    attachState: ref.watch(mediaStoreAttachStateProvider),
    service: ref.watch(mediaStoreServiceProvider),
    backfill: ref.watch(mediaBackfillServiceProvider),
    stores: ref.watch(mediaStoresRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    accountById: accounts.getById,
    storeFor: (account) => buildMediaObjectStoreForAccount(account, registry),
  );
});
