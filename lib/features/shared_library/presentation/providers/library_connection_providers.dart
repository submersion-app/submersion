import 'package:collection/collection.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/library_connection_service.dart';
import 'package:submersion/core/services/shared_library/library_details_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

// no-tick: a service object; it writes info.json at action time.
final libraryDetailsServiceProvider = Provider<LibraryDetailsService>(
  (ref) => LibraryDetailsService(
    store: ref.watch(sharedLibraryStoreProvider),
    transportFor: ref.watch(sharedLibraryTransportFactoryProvider),
  ),
);

// no-tick: a service object; it reads the library row at action time.
final libraryConnectionServiceProvider = Provider<LibraryConnectionService>(
  (ref) => LibraryConnectionService(
    store: ref.watch(sharedLibraryStoreProvider),
    transportFor: ref.watch(sharedLibraryAccountTransportProvider),
  ),
);

/// Where this device reaches a library (issue #3389).
class LibraryConnectionDetails {
  const LibraryConnectionDetails({
    required this.account,
    required this.prefix,
    this.bucket,
    this.server,
  });

  /// Null when the account is no longer on this device.
  final ConnectedAccount? account;
  final String prefix;
  final String? bucket;
  final String? server;

  /// The library's folder as the storage shows it.
  String get folder => prefix.isEmpty
      ? SharedLibraryLayout.librariesDir
      : '${SharedLibraryLayout.librariesDir}/$prefix';
}

/// The connection of the library with this id; null when it is not
/// connected here. Follows the library row and the accounts.
final libraryConnectionDetailsProvider = FutureProvider.autoDispose
    .family<LibraryConnectionDetails?, String>((ref, libraryId) async {
      final accounts = ref.watch(connectedAccountsRepositoryProvider);
      final accountById = ref.watch(libraryAccountLookupProvider);
      ref.invalidateSelfWhen(accounts.watchAccountsChanges());
      // Only the account and folder: a sync rewrites the row every run.
      final where = await ref.watch(
        sharedLibrariesProvider.selectAsync((libraries) {
          final l = libraries.firstWhereOrNull((l) => l.id == libraryId);
          return l == null
              ? null
              : (accountId: l.connectedAccountId, prefix: l.prefix);
        }),
      );
      if (where == null) return null;
      // A row the roster lost is put back from the keys held here (#3563).
      final account = await accountById(where.accountId);
      final setup = ref.watch(libraryAccountSetupProvider);
      return LibraryConnectionDetails(
        account: account,
        prefix: where.prefix,
        bucket: account?.kind == AccountKind.s3
            ? await setup.s3Bucket(account!.id)
            : null,
        server: account?.kind == AccountKind.webdav
            ? await setup.webdavServer(account!.id)
            : null,
      );
    });
