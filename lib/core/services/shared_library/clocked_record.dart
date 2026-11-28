import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// A record of a shared site library that merges field by field (issue
/// #2567): a site, or a document shared with the library (issue #4713).
/// Each field has its own clock; [deleted] is clocked under [deletedField].
/// [extra] holds keys this build does not know, kept on round trip.
abstract class ClockedRecord {
  const ClockedRecord();

  /// The clock name of the tombstone flag.
  static const String deletedField = 'deleted';

  String get id;
  bool get deleted;
  Map<String, Object?> get fields;
  Map<String, FieldClock> get clocks;
  Map<String, Object?> get extra;

  /// The tag a field signature of this kind of record starts with, so a
  /// signature made for one kind never verifies for another.
  String get signatureDomain;

  /// The same record (its id and kind-specific identity) with this content.
  ClockedRecord withContent({
    required bool deleted,
    required Map<String, Object?> fields,
    required Map<String, FieldClock> clocks,
    required Map<String, Object?> extra,
  });
}

/// Result of folding a remote record into the local one.
class MergeOutcome<T extends ClockedRecord> {
  const MergeOutcome({
    required this.merged,
    required this.remoteWon,
    required this.localWon,
  });

  final T merged;

  /// Fields taken from the remote record: apply them to the local row.
  final Set<String> remoteWon;

  /// Fields the remote record lacked or lost: the merged record must be
  /// uploaded so the folder carries them.
  final Set<String> localWon;

  bool get needsUpload => localWon.isNotEmpty;
  bool get changesLocal => remoteWon.isNotEmpty;
}

/// Per-field last-writer-wins. The greater clock wins; a tie keeps local,
/// and an identical clock (the same edit) needs no upload; a missing clock
/// is oldest. The merged document carries the winning
/// value and clock of every field either side has, so merging is
/// commutative up to the tie rule and idempotent.
MergeOutcome<T> mergeClockedRecords<T extends ClockedRecord>({
  required T local,
  required T remote,
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

  final ld = local.clocks[ClockedRecord.deletedField];
  final rd = remote.clocks[ClockedRecord.deletedField];
  final deletedDiffers = local.deleted != remote.deleted || ld != rd;
  final bool deleted;
  if (_newer(rd, ld)) {
    deleted = remote.deleted;
    if (rd != null) clocks[ClockedRecord.deletedField] = rd;
    if (deletedDiffers) remoteWon.add(ClockedRecord.deletedField);
  } else {
    deleted = local.deleted;
    if (ld != null) clocks[ClockedRecord.deletedField] = ld;
    if (deletedDiffers) localWon.add(ClockedRecord.deletedField);
  }

  return MergeOutcome<T>(
    merged:
        local.withContent(
              deleted: deleted,
              fields: fields,
              clocks: clocks,
              extra: {...remote.extra, ...local.extra},
            )
            as T,
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
