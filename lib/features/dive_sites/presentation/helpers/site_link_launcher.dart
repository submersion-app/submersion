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

/// A phone number as a `tel:` link: its digits, with a plus before them
/// kept.
///
/// - A "(0)" written after the country code is the national trunk digit,
///   not part of the international number.
/// - An extension after a marker ("ext. 12", "x7", "#12") is dropped: a
///   dialler cannot take it.
/// - Capitals are a vanity number's letters ("1-800-SCUBA-GO") and dial
///   their keypad digits; the first word with a small letter after the
///   digits ("(office)") ends the number, and a label before them ("Tel:")
///   is skipped.
Uri phoneUri(String phone) {
  final text = phone
      .trim()
      .replaceAll(RegExp(r'\(\s*0\s*\)'), '')
      .replaceFirst(_phoneExtension, '');
  final first = text.indexOf(RegExp(r'\d'));
  if (first < 0) return Uri(scheme: 'tel', path: '');
  final plus = RegExp(r'\+\s*$').hasMatch(text.substring(0, first));
  final rest = text.substring(first);
  final note = RegExp(r'[A-Za-z]*[a-z][A-Za-z]*').firstMatch(rest);
  final number = note == null ? rest : rest.substring(0, note.start);
  final digits = StringBuffer();
  for (final char in number.split('')) {
    if (RegExp(r'\d').hasMatch(char)) {
      digits.write(char);
    } else if (_keypad[char] case final digit?) {
      digits.write(digit);
    }
  }
  return Uri(scheme: 'tel', path: plus ? '+$digits' : '$digits');
}

/// An extension at the end of a number, after its marker. An X inside a
/// word ("FIX") is a vanity letter, so the marker must not follow a letter.
final RegExp _phoneExtension = RegExp(
  r'\s*(?:(?<![A-Za-z])(?:ext|extn|extension|x)\.?|#)\s*\d*\s*$',
  caseSensitive: false,
);

/// The digit each capital shares a key with on a phone keypad.
final Map<String, String> _keypad = {
  for (final (letters, digit) in const [
    ('ABC', '2'),
    ('DEF', '3'),
    ('GHI', '4'),
    ('JKL', '5'),
    ('MNO', '6'),
    ('PQRS', '7'),
    ('TUV', '8'),
    ('WXYZ', '9'),
  ])
    for (final letter in letters.split('')) letter: digit,
};

/// A website as shown: no scheme, no trailing slash.
String displayWebsite(String website) => website
    .trim()
    .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
    .replaceFirst(RegExp(r'/$'), '');
