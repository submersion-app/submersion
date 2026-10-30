import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Raised when the user dismisses the browser-wait dialog.
///
/// Cancelling is a decision, not a failure. Callers catch this ahead of their
/// generic handler and roll back quietly, so a deliberate "no" never reaches
/// the user as a red connection-failed snackbar with an untranslated English
/// fragment embedded in it.
class CloudAuthCancelled implements Exception {
  const CloudAuthCancelled();
}

/// On desktop, Google Drive authentication round-trips through the
/// system browser (loopback OAuth); keep a cancellable waiting dialog up
/// while it completes so the caller's page does not look frozen. Other
/// providers and platforms authenticate directly.
///
/// Shared by Cloud Sync settings and the setup wizard's Backup & Sync step so
/// both connect surfaces behave identically: a wizard that authenticated
/// without the dialog would sit on a dead first-run screen for the whole
/// OAuth round trip, with no way to back out.
///
/// Throws [CloudAuthCancelled] if the user cancels.
///
/// [signIn] replaces [CloudStorageProvider.authenticate] for a caller that
/// has more to say about the sign-in, such as which account it expects.
///
/// [debugForceBrowserWait] overrides the platform check so the dialog branch
/// is reachable in tests on any host; production callers leave it null.
Future<void> authenticateWithBrowserWait(
  BuildContext context,
  CloudStorageProvider cloudProvider,
  CloudProviderType provider, {
  Future<void> Function()? signIn,
  @visibleForTesting bool? debugForceBrowserWait,
}) async {
  final authenticate = signIn ?? cloudProvider.authenticate;
  final needsDialog =
      debugForceBrowserWait ??
      (provider == CloudProviderType.googledrive &&
          (Platform.isWindows || Platform.isLinux));
  if (!needsDialog) {
    await authenticate();
    return;
  }

  // Single synchronously-checked guard: whichever happens first -- auth
  // settling or the user tapping Cancel -- closes the dialog exactly once.
  // Because dialogClosed is checked and set with no intervening await, the
  // two paths can never interleave, so the pop always targets the dialog
  // (showDialog pushes it synchronously below, before any await yields to
  // the auth microtask) and never the page route.
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogClosed = false;
  void closeDialog(bool cancelled) {
    if (dialogClosed) return;
    dialogClosed = true;
    navigator.pop(cancelled);
  }

  final auth = authenticate();
  unawaited(
    auth.then((_) => closeDialog(false), onError: (_) => closeDialog(false)),
  );
  final cancelled =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        // Stated explicitly to pair with the rootNavigator lookup above:
        // closeDialog pops the root navigator, so this dialog must be pushed
        // onto it even if a nested navigator ever wraps a call site.
        useRootNavigator: true,
        // Cancel is the only way out: a system back gesture or Escape that
        // popped the route would leave dialogClosed false, so the pending
        // auth's later closeDialog would pop whatever route is underneath --
        // the caller's page, or the wizard's first-run screen.
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              dialogContext
                  .l10n
                  .settings_cloudSync_googleDrive_browserWait_title,
            ),
            content: Text(
              dialogContext
                  .l10n
                  .settings_cloudSync_googleDrive_browserWait_message,
            ),
            actions: [
              TextButton(
                onPressed: () => closeDialog(true),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ),
      ) ??
      false;
  // Belt and braces for the same hazard: whatever closed the route -- Cancel,
  // the auth settling, or a pop that slipped past PopScope -- the dialog is
  // gone by the time showDialog returns, so latch the flag here rather than
  // trusting every future dismissal path to run through closeDialog.
  dialogClosed = true;
  if (cancelled) {
    // Abandon the pending flow; the loopback listener times out on its
    // own. Swallow its eventual error so nothing surfaces later.
    unawaited(auth.catchError((_) {}));
    throw const CloudAuthCancelled();
  }
  await auth;
}
