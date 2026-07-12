import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/resolvers/connector_media_resolver.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Connect-time IMS auth manager on the legacy single-connection key: the
/// OAuth dance runs before any account row exists, so its tokens land here
/// and are copied to the per-account key once the account is created.
final lightroomAuthManagerProvider = Provider<AdobeImsAuthManager>(
  (ref) => AdobeImsAuthManager(),
);

/// The library's Lightroom account (synced roster row), or null when none
/// exists. Invalidate after connect/disconnect.
final lightroomAccountProvider = FutureProvider<domain.ConnectedAccount?>(
  (ref) => ref
      .watch(connectedAccountsRepositoryProvider)
      .getByKind(AccountKind.adobeLightroom),
);

/// API client on the account's own auth manager once an account exists;
/// the legacy connect-time manager before that (the connect flow fetches
/// identity/catalog before the account row is created).
final lightroomApiClientProvider = Provider<LightroomApiClient>((ref) {
  final account = ref.watch(lightroomAccountProvider).value;
  final auth = account == null
      ? ref.watch(lightroomAuthManagerProvider)
      : (ref
                    .watch(accountProviderRegistryProvider)
                    .adapterFor(AccountKind.adobeLightroom)
                as LightroomAccountAdapter)
            .authManagerFor(account);
  return LightroomApiClient(auth: auth);
});

/// Per-account scan state (poll cursor, album filter, auto-poll, last
/// error), keyed by connector account id.
final lightroomConnectorStateProvider =
    Provider.family<LightroomConnectorState, String>(
      (ref, accountId) => LightroomConnectorState(
        prefs: ref.watch(sharedPreferencesProvider),
        accountId: accountId,
      ),
    );

final lightroomScanServiceProvider = Provider<LightroomScanService>(
  (ref) => LightroomScanService(
    api: ref.watch(lightroomApiClientProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
    enrichmentService: ref.watch(enrichmentServiceProvider),
    enqueueUpload: ref.watch(mediaStoreEnqueueProvider),
  ),
);

/// The `serviceConnector` slot of the resolver registry.
///
/// Watches the account's loaded value on purpose: the registry (and with
/// it this resolver) rebuilds when the account future resolves, flipping
/// `hasLightroomAccount` from its initial false. Devices without an
/// account keep a declining resolver, which routes their display through
/// the media store fallback and keeps the upload pipeline from
/// enqueueing work it cannot materialize.
final connectorMediaResolverProvider = Provider<ConnectorMediaResolver>((ref) {
  final account = ref.watch(lightroomAccountProvider).value;
  return ConnectorMediaResolver(
    hasLightroomAccount: account != null,
    apiClient: () async =>
        account == null ? null : ref.read(lightroomApiClientProvider),
    catalogId: () async => account?.accountIdentifier,
    cache: () => ref
        .read(mediaStoreRuntimeProvider.future)
        .then((runtime) => runtime?.cache),
  );
});

/// Live pending suggestions for a dive (gallery and connector alike).
final pendingSuggestionsForDiveProvider =
    FutureProvider.family<List<domain.PendingPhotoSuggestion>, String>(
      (ref, diveId) => ref
          .watch(mediaRepositoryProvider)
          .getPendingSuggestionsForDive(diveId),
    );

/// Fire-and-forget startup poll. Runs at most once per 6 hours per
/// device, only when an account exists and auto-poll is enabled. Errors
/// are recorded on the connector state and logged, never surfaced.
final lightroomAutoPollProvider = FutureProvider<void>((ref) async {
  final account = await ref.watch(lightroomAccountProvider.future);
  if (account == null) return;
  final state = ref.read(lightroomConnectorStateProvider(account.id));
  if (!await state.autoPollEnabled()) return;
  final last = await state.lastPollAt();
  if (last != null &&
      DateTime.now().difference(last) < const Duration(hours: 6)) {
    return;
  }
  try {
    await ref
        .read(lightroomScanServiceProvider)
        .poll(account: account, state: state);
    await state.setLastError(null);
  } on Exception catch (e, st) {
    await state.setLastError(e.toString());
    LoggerService.forClass(
      LightroomScanService,
    ).warning('Lightroom auto-poll failed: $e', stackTrace: st);
  }
});
