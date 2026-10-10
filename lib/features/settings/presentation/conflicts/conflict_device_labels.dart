import 'package:flutter/foundation.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether a side is called by its device name or by a generic fallback.
/// Sentences select on [name] to word the generic sides as a phrase ("this
/// device's version") instead of splicing in the standalone label.
enum ConflictDeviceKind { named, thisDevice, otherDevice }

/// What to call each side of a conflict.
@immutable
class ConflictDeviceLabels {
  const ConflictDeviceLabels({
    required this.local,
    required this.remote,
    this.localKind = ConflictDeviceKind.named,
    this.remoteKind = ConflictDeviceKind.named,
  });

  /// Standalone labels, for headers and the start of a sentence.
  final String local;
  final String remote;

  final ConflictDeviceKind localKind;
  final ConflictDeviceKind remoteKind;
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
    localKind: ConflictDeviceKind.thisDevice,
    remoteKind: ConflictDeviceKind.otherDevice,
  );
  final writer = _writerOf(remoteData);
  if (writer != null && writer == localDeviceId) return generic;

  final local = localName?.trim();
  final remote = writer == null ? null : peerNames[writer]?.trim();
  final localNamed = local != null && local.isNotEmpty;
  final remoteNamed = remote != null && remote.isNotEmpty;
  final localLabel = localNamed ? local : generic.local;
  final remoteLabel = remoteNamed ? remote : generic.remote;
  if (localLabel.toLowerCase() == remoteLabel.toLowerCase()) return generic;
  return ConflictDeviceLabels(
    local: localLabel,
    remote: remoteLabel,
    localKind: localNamed ? ConflictDeviceKind.named : generic.localKind,
    remoteKind: remoteNamed ? ConflictDeviceKind.named : generic.remoteKind,
  );
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
