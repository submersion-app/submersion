import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/link_open.dart';

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Opens URLs in the external browser. A provider so widget tests can
/// record the URL instead of leaving the app.
final speciesSuggestionLaunchProvider = Provider<UrlLauncher>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// Opens the suggestion in the browser through the shared
/// [openLinkOrOfferCopy]: no `canLaunchUrl` guard (it false-negatives for
/// https on Android 11+), external mode, and a copy-link snackbar when the
/// launch fails.
Future<void> launchSpeciesSuggestion(
  BuildContext context,
  Uri uri, {
  required UrlLauncher launch,
}) => openLinkOrOfferCopy(
  context,
  uri,
  launch: launch,
  failureMessage: context.l10n.marineLife_suggest_couldNotOpen,
);
