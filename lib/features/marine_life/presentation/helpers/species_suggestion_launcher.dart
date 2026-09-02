import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Opens URLs in the external browser. A provider so widget tests can
/// record the URL instead of leaving the app.
final speciesSuggestionLaunchProvider = Provider<UrlLauncher>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// Same shape as Settings' report-issue action: no `canLaunchUrl` guard (it
/// false-negatives for https on Android 11+), external mode, and a copy-link
/// snackbar when the launch fails.
Future<void> launchSpeciesSuggestion(
  BuildContext context,
  Uri uri, {
  required UrlLauncher launch,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  var didLaunch = false;
  try {
    didLaunch = await launch(uri);
  } catch (_) {
    didLaunch = false;
  }
  if (didLaunch) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.marineLife_suggest_couldNotOpen),
      action: SnackBarAction(
        label: l10n.marineLife_suggest_copyLink,
        onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
      ),
    ),
  );
}
