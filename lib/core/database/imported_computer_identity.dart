import 'package:uuid/uuid.dart';

/// Namespace for deterministic dive computer ids derived from file imports.
/// Frozen: every device must derive the same id from the same device
/// identity, so changing this would fork the registry across the fleet.
const String kImportedDiveComputerNamespace =
    '70658227-40eb-49bf-b86f-66dc22323d4b';

/// Normalize a computer identity fragment for comparison and id derivation.
///
/// Trims, collapses runs of internal whitespace, and lowercases, so
/// `'  PERDIX   2 '` and `'Perdix 2'` are one device rather than two.
String normalizeComputerIdentityPart(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// A registered dive computer, reduced to the fields the import match needs.
///
/// Lets the matching rule live in one place: the repository builds these from
/// domain entities, the `beforeOpen` self-heal from raw rows.
class ImportedComputerCandidate {
  const ImportedComputerCandidate({
    required this.id,
    this.diverId,
    this.manufacturer,
    this.model,
    this.serialNumber,
  });

  final String id;
  final String? diverId;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
}

/// The already-registered computer a file-imported dive belongs to, if any.
///
/// A file offers a weaker identity than a download does, so the rule has two
/// tiers:
///
/// - With a serial, match on the serial alone. The file's model spelling must
///   not defeat it, exactly as on the download path.
/// - Without one, match a candidate that also has no serial and whose model,
///   or whose manufacturer + model, normalizes to the same string. Comparing
///   the combined form is what lets a file's `'Shearwater Perdix'` find a
///   downloaded row stored as manufacturer `'Shearwater'`, model `'Perdix'`.
///
/// A serial-bearing candidate is deliberately never adopted by a serial-less
/// import: two units of one model are common, and collapsing them would
/// misattribute dives with no way to undo it.
///
/// [candidates] must already be ordered by preference (most recently updated
/// first) so every device resolves a tie the same way.
ImportedComputerCandidate? matchImportedComputer({
  required String model,
  String? serialNumber,
  String? diverId,
  required Iterable<ImportedComputerCandidate> candidates,
}) {
  final normalizedModel = normalizeComputerIdentityPart(model);
  if (normalizedModel.isEmpty) return null;
  final normalizedSerial = normalizeComputerIdentityPart(serialNumber);
  final normalizedDiver = normalizeComputerIdentityPart(diverId);

  for (final candidate in candidates) {
    if (normalizedDiver.isNotEmpty &&
        normalizeComputerIdentityPart(candidate.diverId) != normalizedDiver) {
      continue;
    }
    final candidateSerial = normalizeComputerIdentityPart(
      candidate.serialNumber,
    );
    if (normalizedSerial.isNotEmpty) {
      if (candidateSerial == normalizedSerial) return candidate;
      continue;
    }
    if (candidateSerial.isNotEmpty) continue;

    final candidateModel = normalizeComputerIdentityPart(candidate.model);
    final candidateManufacturer = normalizeComputerIdentityPart(
      candidate.manufacturer,
    );
    final candidateFullName = candidateManufacturer.isEmpty
        ? candidateModel
        : '$candidateManufacturer $candidateModel';
    if (candidateModel == normalizedModel ||
        candidateFullName == normalizedModel) {
      return candidate;
    }
  }
  return null;
}

/// The deterministic id for a dive computer named by a file import.
///
/// File imports register computers from two places that never see each
/// other: the import itself, and the `beforeOpen` self-heal that adopts
/// logbooks imported before registration existed. Both must land on the same
/// primary key, or a synced fleet ends up with one row per device for a
/// single physical computer; there is no merge action to clean that up.
///
/// Deriving the id from the identity rather than minting a v4 makes sync's
/// upsert-by-id merge the rows instead of unioning them. This is also why
/// `dive_computers` needs no unique index: a unique constraint on a
/// replicated table would make an inbound sync insert throw rather than
/// merge.
///
/// The serial is the strong key when the file supplies one. When it does
/// not, the model string carries the identity on its own, which is weaker
/// but is all most UDDF/MacDive/CSV exports offer.
String importedDiveComputerId({
  required String model,
  String? serialNumber,
  String? diverId,
}) {
  final normalizedSerial = normalizeComputerIdentityPart(serialNumber);
  final normalizedDiver = normalizeComputerIdentityPart(diverId);
  final key = normalizedSerial.isNotEmpty
      ? 'serial:$normalizedDiver|$normalizedSerial'
      : 'model:$normalizedDiver|${normalizeComputerIdentityPart(model)}';
  return const Uuid().v5(kImportedDiveComputerNamespace, key);
}
