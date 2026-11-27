import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/maps_link.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Hands a link to another app; true when it was taken.
typedef SiteLinkLauncher = Future<bool> Function(Uri uri);

/// How the site page opens phone, mail, web and maps links (issue #5073).
/// A seam, so tests can see what would open.
final siteLinkLauncherProvider = Provider<SiteLinkLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Which maps app directions are built for.
final mapsPlatformProvider = Provider<MapsPlatform>(
  (ref) => currentMapsPlatform(),
);

/// Opens [uri], saying [failure] when no app takes it. `launchUrl` refuses
/// by returning false as often as by throwing.
Future<void> openSiteLink(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  String? failure,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = failure ?? context.l10n.diveSites_contact_linkFailed;
  bool launched;
  try {
    launched = await ref.read(siteLinkLauncherProvider)(uri);
  } catch (_) {
    launched = false;
  }
  if (!launched) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Opens the site in the diver's maps app: at its address when it has one,
/// else at its pin. Does nothing when it has neither.
Future<void> openSiteDirections(
  BuildContext context,
  WidgetRef ref,
  DiveSite site,
) async {
  final uri = siteDirectionsUri(
    address: site.address,
    latitude: site.location?.latitude,
    longitude: site.location?.longitude,
    label: site.name,
    platform: ref.read(mapsPlatformProvider),
  );
  if (uri == null) return;
  await openSiteLink(
    context,
    ref,
    uri,
    failure: context.l10n.diveSites_contact_mapsFailed,
  );
}

/// A phone number as a `tel:` link: digits, with a leading plus kept.
Uri phoneUri(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri(
    scheme: 'tel',
    path: trimmed.startsWith('+') ? '+$digits' : digits,
  );
}

/// A website as shown: no scheme, no trailing slash.
String displayWebsite(String website) => website
    .trim()
    .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
    .replaceFirst(RegExp(r'/$'), '');
