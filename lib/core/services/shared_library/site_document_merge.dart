import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

/// Result of folding a remote document into the local one (issue #2567).
class SiteMergeOutcome {
  const SiteMergeOutcome({
    required this.merged,
    required this.remoteWon,
    required this.localWon,
  });

  final SiteDocument merged;

  /// Fields taken from the remote document: apply them to the local row.
  final Set<String> remoteWon;

  /// Fields the remote document lacked or lost: the merged document must
  /// be uploaded so the folder carries them.
  final Set<String> localWon;

  bool get needsUpload => localWon.isNotEmpty;
  bool get changesLocal => remoteWon.isNotEmpty;
}

/// Per-field last-writer-wins. The greater clock wins; a tie keeps local,
/// and an identical clock (the same edit) needs no upload; a missing clock
/// is oldest. The merged document carries the winning
/// value and clock of every field either side has, so merging is
/// commutative up to the tie rule and idempotent.
SiteMergeOutcome mergeSiteDocuments({
  required SiteDocument local,
  required SiteDocument remote,
}) {
  final fields = <String, Object?>{};
  final clocks = <String, FieldClock>{};
  final remoteWon = <String>{};
  final localWon = <String>{};
  final names = {...local.fields.keys, ...remote.fields.keys};

  for (final name in names) {
    final inLocal = local.fields.containsKey(name);
    final inRemote = remote.fields.containsKey(name);
    final lc = local.clocks[name];
    final rc = remote.clocks[name];
    final takeRemote = inRemote && (!inLocal || _newer(rc, lc));
    // One clock is one edit: under it a differing value is only how each
    // device renders it (its own tag spelling, its own junction order), so
    // neither side applies nor uploads, or two devices trade uploads forever.
    final sameEdit = inLocal && inRemote && lc != null && lc == rc;
    final differs =
        !sameEdit &&
        (!inLocal ||
            !inRemote ||
            !_sameValue(local.fields[name], remote.fields[name]) ||
            lc != rc);
    if (takeRemote) {
      fields[name] = remote.fields[name];
      if (rc != null) clocks[name] = rc;
      if (differs) remoteWon.add(name);
    } else {
      fields[name] = local.fields[name];
      if (lc != null) clocks[name] = lc;
      if (differs) localWon.add(name);
    }
  }

  final ld = local.clocks[SiteDocument.deletedField];
  final rd = remote.clocks[SiteDocument.deletedField];
  final deletedDiffers = local.deleted != remote.deleted || ld != rd;
  final bool deleted;
  if (_newer(rd, ld)) {
    deleted = remote.deleted;
    if (rd != null) clocks[SiteDocument.deletedField] = rd;
    if (deletedDiffers) remoteWon.add(SiteDocument.deletedField);
  } else {
    deleted = local.deleted;
    if (ld != null) clocks[SiteDocument.deletedField] = ld;
    if (deletedDiffers) localWon.add(SiteDocument.deletedField);
  }

  return SiteMergeOutcome(
    merged: SiteDocument(
      id: local.id,
      deleted: deleted,
      fields: fields,
      clocks: clocks,
      extra: {...remote.extra, ...local.extra},
    ),
    remoteWon: remoteWon,
    localWon: localWon,
  );
}

/// True when [a] sorts strictly after [b]; a null clock is oldest.
bool _newer(FieldClock? a, FieldClock? b) {
  if (a == null) return false;
  if (b == null) return true;
  return a.hlc.compareTo(b.hlc) > 0;
}

/// Structural equality for JSON values (lists and maps compare by content).
bool _sameValue(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_sameValue(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  return a == b;
}
