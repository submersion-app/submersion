import 'package:flutter/foundation.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What to call each side of a conflict.
@immutable
class ConflictDeviceLabels {
  const ConflictDeviceLabels({required this.local, required this.remote});

  final String local;
  final String remote;
}

/// Names the two sides of a conflict by device. The remote side is named by
/// the device that last wrote the remote row (the nodeId in its hlc), looked
/// up in the names peers publish on their manifests.
///
/// The labels exist to tell the sides apart, so whenever they could read the
/// same (one name for both, or the remote row written by this device) both
/// fall back to the generic pair.
ConflictDeviceLabels conflictDeviceLabels({
  required AppLocalizations l10n,
  required String? localName,
  required String? localDeviceId,
  required Map<String, String> peerNames,
  required Map<String, dynamic> remoteData,
}) {
  final generic = ConflictDeviceLabels(
    local: l10n.settings_conflict_thisDevice,
    remote: l10n.settings_conflict_otherDevice,
  );
  final writer = _writerOf(remoteData);
  if (writer != null && writer == localDeviceId) return generic;

  final local = localName?.trim();
  final remote = writer == null ? null : peerNames[writer]?.trim();
  final localLabel = (local == null || local.isEmpty) ? generic.local : local;
  final remoteLabel = (remote == null || remote.isEmpty)
      ? generic.remote
      : remote;
  if (localLabel.toLowerCase() == remoteLabel.toLowerCase()) return generic;
  return ConflictDeviceLabels(local: localLabel, remote: remoteLabel);
}

String? _writerOf(Map<String, dynamic> data) {
  final hlc = data['hlc'];
  if (hlc is! String) return null;
  try {
    return Hlc.parse(hlc).nodeId;
  } on FormatException {
    return null;
  }
}
