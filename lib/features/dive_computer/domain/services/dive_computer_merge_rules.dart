import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// Pure rules for reconciling dive computer records that describe one
/// physical device (issue #645).
///
/// A Bluetooth identifier is local to the host that discovered the computer,
/// so the same Petrel can be saved once per Mac, iPhone and iPad. The serial
/// number, with manufacturer and model, is the stable identity these rules
/// compare on. Everything here is side-effect free so the repository, the
/// merge sheet and the duplicate banner share one definition of "duplicate".

/// Other records in [all] that look like the same physical computer as
/// [target]: the same serial number, a compatible manufacturer and model,
/// and the same owner.
///
/// "The same serial" is the shared rule in `computer_serial_identity.dart`
/// (issue #3106): a Shearwater file import keeps the hex serial the computer
/// shows while a download reports it in decimal, and both name one device.
///
/// Manufacturer and model are compatible when they agree after normalisation
/// or when either side is blank; a file import can register a serial without
/// a manufacturer or a model, and that record is still the same device. A
/// model also agrees when one source folded the brand into it ("Shearwater
/// Teric" against "Shearwater" + "Teric").
List<DiveComputer> duplicateCandidatesFor(
  DiveComputer target,
  Iterable<DiveComputer> all,
) {
  if (normalizeComputerIdentityPart(target.serialNumber).isEmpty) {
    return const [];
  }
  final diver = normalizeComputerIdentityPart(target.diverId);
  return [
    for (final candidate in all)
      if (candidate.id != target.id &&
          normalizeComputerIdentityPart(candidate.diverId) == diver &&
          identityPartsCompatible(
            target.manufacturer,
            candidate.manufacturer,
          ) &&
          computerModelsCompatible(
            brandA: target.manufacturer,
            modelA: target.model,
            brandB: candidate.manufacturer,
            modelB: candidate.model,
          ) &&
          _sameSerial(target, candidate))
        candidate,
  ];
}

bool _sameSerial(DiveComputer a, DiveComputer b) => computerSerialsMatch(
  a.serialNumber,
  b.serialNumber,
  shearwater: shearwaterPair(
    manufacturerA: a.manufacturer,
    modelA: a.model,
    manufacturerB: b.manufacturer,
    modelB: b.model,
  ),
);

/// Whether two identity fragments agree after normalisation, or either is
/// blank.
bool identityPartsCompatible(String? a, String? b) {
  final left = normalizeComputerIdentityPart(a);
  final right = normalizeComputerIdentityPart(b);
  return left.isEmpty || right.isEmpty || left == right;
}

/// Whether two models are compatible: either is blank, or the two brand and
/// model pairs name the same device however each source split the name.
bool computerModelsCompatible({
  String? brandA,
  String? modelA,
  String? brandB,
  String? modelB,
}) {
  if (normalizeComputerIdentityPart(modelA).isEmpty ||
      normalizeComputerIdentityPart(modelB).isEmpty) {
    return true;
  }
  return computerNamesAgree(
    brandA: brandA,
    modelA: modelA,
    brandB: brandB,
    modelB: modelB,
  );
}

/// Whether [records] carry two serial numbers that are not the same serial
/// under the shared rule, which means the user is about to merge what are
/// probably different devices.
bool serialNumbersConflict(Iterable<DiveComputer> records) {
  final withSerial = [
    for (final record in records)
      if (normalizeComputerIdentityPart(record.serialNumber).isNotEmpty) record,
  ];
  for (var i = 0; i < withSerial.length; i++) {
    for (var j = i + 1; j < withSerial.length; j++) {
      if (!_sameSerial(withSerial[i], withSerial[j])) return true;
    }
  }
  return false;
}

/// The record a merge should keep unless the user says otherwise: the
/// favorite, else the one with the most dives, else the most recently
/// downloaded, else the first.
DiveComputer defaultSurvivor(List<DiveComputer> records) {
  assert(records.isNotEmpty, 'defaultSurvivor needs at least one record');
  var best = records.first;
  for (final candidate in records.skip(1)) {
    if (_ranksAbove(candidate, best)) best = candidate;
  }
  return best;
}

bool _ranksAbove(DiveComputer candidate, DiveComputer incumbent) {
  if (candidate.isFavorite != incumbent.isFavorite) return candidate.isFavorite;
  if (candidate.diveCount != incumbent.diveCount) {
    return candidate.diveCount > incumbent.diveCount;
  }
  return _isLater(candidate.lastDownload, incumbent.lastDownload);
}

bool _isLater(DateTime? a, DateTime? b) {
  if (a == null) return false;
  if (b == null) return true;
  return a.isAfter(b);
}

/// The surviving record after [duplicates] fold into [survivor].
///
/// Identity fields (id, name, owner) stay the survivor's. Blank descriptive
/// fields are filled from the first duplicate that has them. Dive counts add
/// up, favorite status is kept if any record had it, the newest download wins,
/// and distinct notes are appended.
///
/// `lastDiveFingerprint` is picked by download recency rather than by list
/// order: it is the cursor the next incremental download resumes from, so it
/// has to come from the most recent download that actually recorded one. A
/// record can hold a `lastDownload` with no fingerprint (the two are written
/// separately), and taking the survivor's stale cursor in that case would
/// resume from the wrong dive.
DiveComputer mergedDiveComputer(
  DiveComputer survivor,
  List<DiveComputer> duplicates,
) {
  final records = [survivor, ...duplicates];
  final newest = records.reduce(
    (best, candidate) =>
        _isLater(candidate.lastDownload, best.lastDownload) ? candidate : best,
  );
  final fingerprint = _newestFingerprint(records);

  return survivor.copyWith(
    manufacturer: _firstNonBlank([
      survivor.manufacturer,
      ...duplicates.map((d) => d.manufacturer),
    ]),
    model: _firstNonBlank([survivor.model, ...duplicates.map((d) => d.model)]),
    serialNumber: _firstNonBlank([
      survivor.serialNumber,
      ...duplicates.map((d) => d.serialNumber),
    ]),
    firmwareVersion: _firstNonBlank([
      survivor.firmwareVersion,
      ...duplicates.map((d) => d.firmwareVersion),
    ]),
    connectionType: _firstNonBlank([
      survivor.connectionType,
      ...duplicates.map((d) => d.connectionType),
    ]),
    bluetoothAddress: _firstNonBlank([
      survivor.bluetoothAddress,
      ...duplicates.map((d) => d.bluetoothAddress),
    ]),
    equipmentId: _firstNonBlankId([
      survivor.equipmentId,
      ...duplicates.map((d) => d.equipmentId),
    ]),
    lastDownload: newest.lastDownload,
    lastDiveFingerprint: fingerprint,
    diveCount: duplicates.fold<int>(
      survivor.diveCount,
      (sum, d) => sum + d.diveCount,
    ),
    isFavorite: survivor.isFavorite || duplicates.any((d) => d.isFavorite),
    notes: _mergedNotes(survivor.notes, duplicates.map((d) => d.notes)),
  );
}

/// The `lastDiveFingerprint` of the most recently downloaded record that has
/// one. Records without a fingerprint are skipped rather than shadowing an
/// older record's cursor, and ties keep the earliest entry, which is the
/// survivor.
String? _newestFingerprint(List<DiveComputer> records) {
  DiveComputer? best;
  for (final record in records) {
    final fingerprint = record.lastDiveFingerprint;
    if (fingerprint == null || fingerprint.trim().isEmpty) continue;
    if (best == null || _isLater(record.lastDownload, best.lastDownload)) {
      best = record;
    }
  }
  return best?.lastDiveFingerprint;
}

/// The first value that is not blank, trimmed. A record can carry padding
/// from a file import, and the survivor should not inherit it along with the
/// value; the identity rules compare through [normalizeComputerIdentityPart],
/// so a padded serial matched here would be stored padded and displayed that
/// way. Mirrors [_mergedNotes], which trims for the same reason.
String? _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// The first value that is not blank, verbatim. For `equipmentId`, which is a
/// foreign key into `equipment.id` and has to match the stored row exactly;
/// the repository picks the merged gear twin the same way.
String? _firstNonBlankId(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}

String _mergedNotes(String survivorNotes, Iterable<String> duplicateNotes) {
  final parts = <String>[];
  final seen = <String>{};
  for (final notes in [survivorNotes, ...duplicateNotes]) {
    final trimmed = notes.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    parts.add(trimmed);
  }
  return parts.join('\n\n');
}
