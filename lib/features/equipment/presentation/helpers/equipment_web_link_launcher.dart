import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/shared/utils/link_open.dart';

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
}) => openLinkOrOfferCopy(context, uri, launch: launch);
