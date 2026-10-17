import 'package:equatable/equatable.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';

/// A feature that depends on a connected account (issue #3388).
enum AccountUsageKind { databaseSync, mediaStorage, sharedLibrary, lightroom }

/// One thing a connected account is used for on this device.
class AccountUsage extends Equatable {
  const AccountUsage(this.kind, {this.libraryName});

  final AccountUsageKind kind;

  /// The library's name, for [AccountUsageKind.sharedLibrary] only.
  final String? libraryName;

  @override
  List<Object?> get props => [kind, libraryName];
}

/// What each account is used for, read once. The roster syncs between
/// devices but every link to an account is device-local (sync selection in
/// sync_metadata, media attachment in prefs, the shared_libraries table), so
/// this answers for this device only.
class AccountUsageSnapshot {
  const AccountUsageSnapshot({
    this.syncAccountId,
    this.mediaStoreAccountId,
    this.libraryNamesByAccount = const {},
  });

  final String? syncAccountId;
  final String? mediaStoreAccountId;

  /// Library names per account id, each list sorted by name.
  final Map<String, List<String>> libraryNamesByAccount;

  /// [account]'s usages: database sync, media storage, shared libraries
  /// (by name), then Lightroom. Empty when nothing here uses it.
  List<AccountUsage> usagesOf(domain.ConnectedAccount account) => [
    if (account.id == syncAccountId)
      const AccountUsage(AccountUsageKind.databaseSync),
    if (account.id == mediaStoreAccountId)
      const AccountUsage(AccountUsageKind.mediaStorage),
    for (final name in libraryNamesByAccount[account.id] ?? const <String>[])
      AccountUsage(AccountUsageKind.sharedLibrary, libraryName: name),
    // The Lightroom account IS the connector: it exists only to drive it.
    if (account.kind == AccountKind.adobeLightroom)
      const AccountUsage(AccountUsageKind.lightroom),
  ];
}

/// Reads which features on this device point at which connected account.
/// Shared by the Connected Accounts page and the pending-setup card, so the
/// two cannot disagree about what an account drives.
class AccountUsageService {
  AccountUsageService({
    required MediaStoreAttachState attachState,
    SyncRepository? syncRepository,
    SharedLibraryStore? libraries,
  }) : _attachState = attachState,
       _syncRepository = syncRepository ?? SyncRepository(),
       _libraries = libraries ?? SharedLibraryStore();

  final MediaStoreAttachState _attachState;
  final SyncRepository _syncRepository;
  final SharedLibraryStore _libraries;

  Future<AccountUsageSnapshot> load() async {
    // Independent reads: run them together.
    final (
      libraries,
      syncAccountId,
      attachedStoreId,
      attachedAccountId,
    ) = await (
      _libraries.getLibraries(),
      _syncRepository.getSyncAccountId(),
      _attachState.attachedStoreId(),
      _attachState.attachedAccountId(),
    ).wait;
    final libraryNames = <String, List<String>>{};
    for (final library in libraries) {
      libraryNames.update(
        library.connectedAccountId,
        (names) => [...names, library.name],
        ifAbsent: () => [library.name],
      );
    }
    return AccountUsageSnapshot(
      syncAccountId: syncAccountId,
      // Only account-layer attachments carry an id; the startup migration
      // gave every pre-account attachment one, so null means none attached.
      mediaStoreAccountId: attachedStoreId == null ? null : attachedAccountId,
      libraryNamesByAccount: {
        for (final MapEntry(:key, :value) in libraryNames.entries)
          key: [...value]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      },
    );
  }
}
