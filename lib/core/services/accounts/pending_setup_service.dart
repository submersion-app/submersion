import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

/// What a device still needs to set up to match the library's synced
/// configuration (program spec section 6).
enum SetupItemKind { mediaStoreAttach, accountSignIn }

/// One actionable "finish setting up this device" entry. [key] is stable
/// per underlying object so per-device dismissals stick.
class PendingSetupItem {
  final SetupItemKind kind;
  final String key;

  /// Display payload: the store hint for [SetupItemKind.mediaStoreAttach],
  /// the account label for [SetupItemKind.accountSignIn].
  final String label;

  /// For accountSignIn: the account's kind.
  final AccountKind? accountKind;

  /// The settings page that actually resolves this item. Computed by the
  /// service, which knows what the account drives (sync selection, media
  /// store descriptor, connector) - the card just navigates.
  final String route;

  const PendingSetupItem({
    required this.kind,
    required this.key,
    required this.label,
    required this.route,
    this.accountKind,
  });
}

/// Computes the device's pending setup items from synced descriptors and
/// records per-device dismissals. Never nags: a dismissed key stays
/// dismissed on this device until the underlying object changes identity.
class PendingSetupService {
  PendingSetupService({
    required SharedPreferences prefs,
    ConnectedAccountsRepository? accounts,
    MediaStoresRepository? stores,
    MediaStoreAttachState? attachState,
    SyncRepository? syncRepository,
    required AccountProviderRegistry registry,
  }) : _prefs = prefs,
       _accounts = accounts ?? ConnectedAccountsRepository(),
       _stores = stores ?? MediaStoresRepository(),
       // Same prefs instance as the dismissal store: one source of truth,
       // and overridden prefs in tests govern the attach state too.
       _attachState = attachState ?? MediaStoreAttachState(prefs: prefs),
       _syncRepository = syncRepository ?? SyncRepository(),
       _registry = registry;

  static const String _dismissedPrefix = 'setup_item_dismissed_';

  final SharedPreferences _prefs;
  final ConnectedAccountsRepository _accounts;
  final MediaStoresRepository _stores;
  final MediaStoreAttachState _attachState;
  final SyncRepository _syncRepository;
  final AccountProviderRegistry _registry;

  bool _isDismissed(String key) =>
      _prefs.getBool('$_dismissedPrefix$key') ?? false;

  Future<void> dismiss(String key) async {
    await _prefs.setBool('$_dismissedPrefix$key', true);
  }

  Future<List<PendingSetupItem>> compute() async {
    final items = <PendingSetupItem>[];

    // The library announces a media store (synced descriptor), but this
    // device is not attached to it - or is still attached to a DIFFERENT
    // store (switched on another device), which needs the same action.
    final store = await _stores.getActive();
    final attachedId = await _attachState.attachedStoreId();
    if (store != null && attachedId != store.id) {
      final key = 'store_${store.id}';
      if (!_isDismissed(key)) {
        items.add(
          PendingSetupItem(
            kind: SetupItemKind.mediaStoreAttach,
            key: key,
            label: store.displayHint,
            route: '/settings/media-storage',
          ),
        );
      }
    }

    // Roster accounts this device holds no working credentials for.
    // `unavailable` kinds (e.g. iCloud off-platform) are not actionable
    // here and are skipped.
    final syncAccountId = await _syncRepository.getSyncAccountId();
    for (final account in await _accounts.getAll()) {
      final adapter = _registry.capabilityFor<AccountProviderAdapter>(
        account.kind,
      );
      if (adapter == null) continue;
      if (await adapter.status(account) != AccountStatus.needsSignIn) {
        continue;
      }
      final key = 'account_${account.id}';
      if (_isDismissed(key)) continue;
      items.add(
        PendingSetupItem(
          kind: SetupItemKind.accountSignIn,
          key: key,
          label: account.label,
          accountKind: account.kind,
          route: _routeFor(account, syncAccountId: syncAccountId, store: store),
        ),
      );
    }
    return items;
  }

  /// The settings page that can actually sign this account in. Connectors
  /// have their own pages; the selected sync account belongs to Cloud
  /// Sync; an account matching the announced store's provider belongs to
  /// Media Storage; anything else defaults to Cloud Sync.
  String _routeFor(
    domain.ConnectedAccount account, {
    required String? syncAccountId,
    required MediaStoreDescriptor? store,
  }) {
    if (account.kind == AccountKind.adobeLightroom) {
      return '/settings/lightroom';
    }
    if (account.id == syncAccountId) return '/settings/cloud-sync';
    if (store != null &&
        account.kind.cloudProviderType?.name == store.providerType) {
      return '/settings/media-storage';
    }
    return '/settings/cloud-sync';
  }
}
