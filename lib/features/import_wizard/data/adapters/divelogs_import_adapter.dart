import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_photo_linker.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_import_steps.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the sign-in step can advance.
final divelogsSignedInProvider = StateProvider<bool>((ref) => false);

/// Signals that the fetch step installed a payload.
final divelogsFetchedProvider = StateProvider<bool>((ref) => false);

/// Bumped every time the signed-in client changes. A fetch that started
/// under an earlier value belongs to a session that no longer exists, so
/// its result must not be installed.
final divelogsSessionGenerationProvider = StateProvider<int>((ref) => 0);

/// Whether the fetch lists photos. Only honoured where the Photos step can
/// pick a destination folder (desktop).
final divelogsIncludePhotosProvider = StateProvider<bool>((ref) => true);

/// The keychain-backed session cache. Injected so widget tests can use an
/// in-memory keychain.
final divelogsSessionStoreProvider = Provider<DivelogsSessionStore>(
  (ref) => DivelogsSessionStore(),
);

/// HTTP client for divelogs.de. Overridable with a `MockClient` in tests;
/// closed on dispose so sockets do not outlive the container.
final divelogsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Import source that pulls the user's logbook from divelogs.de.
///
/// Only acquisition differs from a file import: Sign In and Fetch replace
/// Select File, Confirm Source and Map Fields. The fetch installs its payload
/// through `UniversalImportNotifier.setExternalPayload`, so review, duplicate
/// handling and the importer are the universal ones. Listed photos are
/// downloaded at import time into the folder the Photos step chose.
class DivelogsImportAdapter extends UniversalAdapter {
  DivelogsImportAdapter({required super.ref})
    : super(displayName: 'divelogs.de');

  DivelogsSignedIn? _session;
  String? _lastUsername;
  Map<String, List<RemotePhoto>> _photos = const {};

  /// Set by the wizard: moves it back one step, from Fetch to Sign In when
  /// the session expires.
  VoidCallback? goBack;

  /// The signed-in session, set by the sign-in step.
  DivelogsSignedIn? get session => _session;

  /// The signed-in client.
  DivelogsApiClient? get client => _session?.client;

  /// The username last signed in with, kept after the session expires so
  /// the sign-in form can offer it again.
  String? get lastUsername => _lastUsername;

  /// Installs the client for a new sign-in, or clears it on sign-out.
  /// Either way the account may have changed, so anything fetched under the
  /// previous one is dropped and the Fetch step has to run again.
  void setClient(DivelogsApiClient? client) =>
      setSession(client == null ? null : (auth: null, client: client));

  /// Installs a new session, or clears it on sign-out, with the same resets
  /// as [setClient].
  void setSession(DivelogsSignedIn? session) {
    _session = session;
    _lastUsername = session?.auth?.username ?? _lastUsername;
    _photos = const {};
    widgetRef.read(divelogsFetchedProvider.notifier).state = false;
    widgetRef.read(divelogsSessionGenerationProvider.notifier).state++;
    widgetRef.read(universalImportNotifierProvider.notifier).reset();
  }

  /// Listed photos per payload dive `sourceUuid`, set by the fetch step.
  void setRemotePhotos(Map<String, List<RemotePhoto>> photos) =>
      _photos = Map.unmodifiable(photos);

  @override
  ImportSourceType get sourceType => ImportSourceType.divelogs;

  @override
  void resetState() {
    super.resetState();
    _session = null;
    _lastUsername = null;
    _photos = const {};
    widgetRef.invalidate(divelogsSignedInProvider);
    widgetRef.invalidate(divelogsFetchedProvider);
  }

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.login,
      builder: (context) => DivelogsSignInStep(
        onSignedIn: setSession,
        current: _session,
        prefillUsername: _lastUsername,
      ),
      canAdvance: divelogsSignedInProvider,
      autoAdvance: true,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.cloud_download,
      builder: (context) => DivelogsFetchStep(
        client: client,
        onPhotosListed: setRemotePhotos,
        onSessionExpired: _expireSession,
      ),
      canAdvance: divelogsFetchedProvider,
      // Not auto-advance: the step shows what was found, and any gear,
      // certification or photo listing that failed, before moving on.
      autoAdvance: false,
    ),
    ...payloadSteps,
  ];

  @override
  Future<RemotePhotoOutcome> attachAdditionalPhotos({
    required Map<int, String> photoDiveIds,
    required Set<String> removedDiveIds,
    required Map<String, DateTime> diveStartById,
    required List<Map<String, dynamic>> dives,
    required String destinationDir,
    ImportCancellationToken? cancelToken,
  }) async {
    final client = this.client;
    if (client == null || _photos.isEmpty) return (attached: 0, failed: 0);
    final linker = ImportPhotoLinker(
      widgetRef.read(localFileLinkServiceProvider),
    );
    final outcome = await attachRemotePhotos(
      photosBySourceUuid: _photos,
      diveIdByIndex: photoDiveIds,
      removedDiveIds: removedDiveIds,
      dives: dives,
      diveStartById: diveStartById,
      download: client.downloadPictureBytes,
      attach: (file, diveId, diveStart) => linker.linkBundled(
        file: file,
        diveId: diveId,
        diveStart: diveStart,
        destinationDir: destinationDir,
      ),
      cancelToken: cancelToken,
      stopOn: _sessionLost,
    );
    return (
      attached: outcome.attached - linker.alreadyLinked,
      failed: outcome.failed,
    );
  }

  /// Errors after which no further download can succeed: the session is
  /// gone, or renewing it failed. Retrying would log in once per photo.
  static bool _sessionLost(Object error) =>
      error is DivelogsSessionExpiredException ||
      error is DivelogsAuthException ||
      error is DivelogsUnauthorizedException;

  /// divelogs.de refused the session during the fetch: forget it, keep the
  /// username for the form, and go back to Sign In.
  void _expireSession() {
    setSession(null);
    goBack?.call();
  }

  @visibleForTesting
  void debugExpireSession() => _expireSession();

  @visibleForTesting
  Future<RemotePhotoOutcome> debugAttachAdditionalPhotosFor({
    required Map<int, String> photoDiveIds,
    required List<Map<String, dynamic>> dives,
    required String destinationDir,
  }) => attachAdditionalPhotos(
    photoDiveIds: photoDiveIds,
    removedDiveIds: const {},
    diveStartById: const {},
    dives: dives,
    destinationDir: destinationDir,
  );
}
