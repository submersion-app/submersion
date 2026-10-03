import 'package:submersion/l10n/arb/app_localizations.dart';

/// The peers a sync banner names, joined into one localized list ("A, B and
/// C"). A peer that published no name is shown as `device <shortId>`.
String peerDeviceList(
  AppLocalizations l10n,
  List<({String? name, String shortId})> peers,
) {
  final labels = peers
      .map(
        (p) =>
            p.name ??
            l10n.settings_cloudSync_peerNeedsAdopt_unnamedDevice(p.shortId),
      )
      .toList();
  if (labels.length == 1) return labels.single;
  return labels
          .sublist(0, labels.length - 1)
          .join(l10n.settings_cloudSync_peerNeedsAdopt_listSeparator) +
      l10n.settings_cloudSync_peerNeedsAdopt_listLastSeparator +
      labels.last;
}
