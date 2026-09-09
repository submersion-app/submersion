import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_photos_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_picker_client.dart';
import 'package:submersion/core/services/google_photos/google_photos_redirect_capture.dart';

/// Connect-time auth manager on the default single-connection key: the OAuth
/// dance runs before any account row exists, so its tokens land here and are
/// copied to the per-account key once the account is created. Mirrors
/// `lightroomAuthManagerProvider`.
final googlePhotosAuthManagerProvider = Provider<GooglePhotosAuthManager>(
  (ref) => GooglePhotosAuthManager(),
);

/// The redirect capturer for the connect flow. Overridden with a fake in
/// tests.
final googlePhotosRedirectCaptureProvider =
    Provider<GooglePhotosRedirectCapture>(
      (ref) => const FlutterWebAuthGooglePhotosRedirectCapture(),
    );

/// The library's Google Photos account (synced roster row), or null when
/// none exists. Invalidate after connect/disconnect.
final googlePhotosAccountProvider = FutureProvider<domain.ConnectedAccount?>((
  ref,
) {
  final repository = ref.watch(connectedAccountsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchAccountsChanges());
  return repository.getByKind(AccountKind.googlePhotos);
});

/// The Google Photos adapter, checked. A non-matching adapter registered
/// for the kind (only reachable via a test override) fails with a
/// diagnosable message rather than an opaque cast error.
final googlePhotosAccountAdapterProvider = Provider<GooglePhotosAccountAdapter>(
  (ref) {
    final adapter = ref
        .watch(accountProviderRegistryProvider)
        .adapterFor(AccountKind.googlePhotos);
    if (adapter is! GooglePhotosAccountAdapter) {
      throw StateError(
        'Expected a GooglePhotosAccountAdapter for '
        'AccountKind.googlePhotos, got ${adapter.runtimeType}',
      );
    }
    return adapter;
  },
);

/// This device's Google Photos connection state. The roster row syncs but
/// credentials are per-device, so a device that received the synced account
/// without a local keychain blob is [needsSignIn], NOT [connected].
enum GooglePhotosDeviceStatus { notConnected, needsSignIn, connected }

final googlePhotosDeviceStatusProvider =
    FutureProvider<GooglePhotosDeviceStatus>((ref) async {
      final account = await ref.watch(googlePhotosAccountProvider.future);
      if (account == null) return GooglePhotosDeviceStatus.notConnected;
      final status = await ref
          .watch(googlePhotosAccountAdapterProvider)
          .status(account);
      return status == AccountStatus.signedIn
          ? GooglePhotosDeviceStatus.connected
          : GooglePhotosDeviceStatus.needsSignIn;
    });

/// Picker client on the account's own auth manager once an account exists;
/// the connect-time manager before that.
final googlePhotosPickerClientProvider = Provider<GooglePhotosPickerClient>((
  ref,
) {
  final account = ref.watch(googlePhotosAccountProvider).value;
  final auth = account == null
      ? ref.watch(googlePhotosAuthManagerProvider)
      : ref.watch(googlePhotosAccountAdapterProvider).authManagerFor(account);
  return GooglePhotosPickerClient(auth: auth);
});
