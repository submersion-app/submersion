import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_dive_import_core.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the sign-in step can advance (a usable session was obtained).
final suuntoCloudSignedInProvider = StateProvider<bool>((ref) => false);

/// The keychain-backed session cache the sign-in step reads and writes.
/// Injected rather than constructed inline so a widget test can supply an
/// in-memory store instead of hitting the platform keychain.
final suuntoSessionStoreProvider = Provider<SuuntoSessionStore>(
  (ref) => SuuntoSessionStore(),
);

/// Builds the client the sign-in step authenticates with. Injected for the
/// same reason as [suuntoSessionStoreProvider]: overriding it keeps a test
/// from ever reaching api.sports-tracker.com.
final suuntoCloudClientFactoryProvider = Provider<SuuntoCloudClient Function()>(
  (ref) => SuuntoCloudClient.new,
);

/// Signals that the fetch step can advance (dives have been downloaded and
/// converted).
final suuntoCloudDivesFetchedProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for dives pulled from the Suunto cloud
/// (app.suunto.com), via the undocumented Sports-Tracker API.
///
/// Two acquisition steps: sign in (email/password, with a cached-session
/// fast path), then fetch (list + download + convert every scuba/freediving
/// workout). Everything after acquisition is [SuuntoDiveImportCore], shared
/// with the Suunto JSON file import.
class SuuntoCloudAdapter extends SuuntoDiveImportCore {
  SuuntoCloudAdapter({
    required super.importService,
    required super.computerRepository,
    required super.diveRepository,
    required super.consolidationService,
    required super.diverId,
    super.routeWriter,
    super.ref,
  });

  /// The authenticated client obtained by the sign-in step, reused by the
  /// fetch step to list and download dives.
  SuuntoCloudClient? _client;

  /// Set by the sign-in step widget once a session has been established
  /// (either from a cached session or a fresh login).
  void setClient(SuuntoCloudClient client) {
    _client = client;
  }

  /// The account the sign-in step signed in with, shown on the Review step
  /// (issue #161).
  String? _account;

  /// Set by the sign-in step alongside [setClient].
  void setAccount(String? account) {
    _account = account;
  }

  @override
  String? get sourceAccount => _account;

  /// The authenticated client set by the sign-in step. Only meaningful once
  /// the sign-in acquisition step has completed.
  SuuntoCloudClient? get client => _client;

  @override
  void resetState() {
    super.resetState();
    _client = null;
    _account = null;
    final ref = this.ref;
    if (ref == null) return;
    ref.invalidate(suuntoCloudSignedInProvider);
    ref.invalidate(suuntoCloudDivesFetchedProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.suuntoCloud;

  @override
  String get displayName => 'Suunto Cloud';

  @override
  String get defaultTagName => 'Suunto Cloud Import ${todayIsoDate()}';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.login,
      builder: (context) => SuuntoCloudSignInStep(
        onSignedIn: setClient,
        onAccountSignedIn: setAccount,
      ),
      canAdvance: suuntoCloudSignedInProvider,
      autoAdvance: true,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.cloud_download,
      builder: (context) =>
          SuuntoCloudFetchStep(client: _client, onDivesFetched: setParsedDives),
      canAdvance: suuntoCloudDivesFetchedProvider,
      // Not auto-advance: the fetch step lets the diver move on as soon as
      // the newest page of dives is ready without waiting for the rest of a
      // large account's history, via an explicit Load More button. Auto-
      // advancing on that same canAdvance flip would whisk the diver away
      // the instant it turns true, before they ever see that button.
      autoAdvance: false,
    ),
  ];
}
