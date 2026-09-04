import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Opens an equipment item's product/receipt link in the external browser.
/// A provider so widget tests can record the URL instead of leaving the app,
/// mirroring `speciesSuggestionLaunchProvider`.
final equipmentWebLinkLaunchProvider = Provider<UrlLauncher>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// Launches [uri], falling back to a copy-link snackbar when the platform
/// refuses. No `canLaunchUrl` guard: it false-negatives for https on
/// Android 11+, the same call Settings' report-issue action makes.
///
/// [uri] must already have come from `parseWebLink`, which is what confines
/// the launch to http(s).
Future<void> launchEquipmentWebLink(
  BuildContext context,
  Uri uri, {
  required UrlLauncher launch,
}) async {
  // Both halves matter. Resolving the messenger and l10n BEFORE the await
  // keeps a BuildContext from being dereferenced across the gap (what the
  // use_build_context_synchronously lint is about), but it does not make the
  // captured ScaffoldMessengerState safe to use afterwards: showSnackBar
  // builds the SnackBar's AnimationController with `vsync: this`, so calling
  // it on a state that was disposed while the platform launch was in flight
  // throws. The mounted check is what covers that.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  var didLaunch = false;
  try {
    didLaunch = await launch(uri);
  } catch (_) {
    didLaunch = false;
  }
  if (didLaunch || !context.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.common_link_couldNotOpen),
      action: SnackBarAction(
        label: l10n.common_action_copyLink,
        onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
      ),
    ),
  );
}
