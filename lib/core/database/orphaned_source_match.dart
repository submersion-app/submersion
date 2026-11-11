import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';

/// A downloaded `dive_data_sources` row with no computer link, reduced to
/// what deciding its computer needs (issue #4465).
class OrphanedSource {
  const OrphanedSource({
    required this.id,
    required this.diveId,
    this.diverId,
    this.computerModel,
    this.computerSerial,
    this.descriptorVendor,
    this.descriptorProduct,
  });

  final String id;
  final String diveId;

  /// The diver of the source's dive.
  final String? diverId;

  /// The model snapshot: the computer's full name at the download.
  final String? computerModel;

  /// The serial snapshot, empty when the computer had none at the download.
  final String? computerSerial;

  /// The device as libdivecomputer reported it in the raw data.
  final String? descriptorVendor;
  final String? descriptorProduct;
}

/// A dive that already holds a source linked to a computer.
typedef LinkedSource = ({String diveId, String computerId});

/// Whether a source's snapshots name the model of the computer stored as
/// [manufacturer] / [model]. The model snapshot names the computer as it was
/// labeled at the download, by its model or its full name; the descriptor
/// names what the device reported, so its product must be the model and its
/// vendor, when both sides have one, the manufacturer. A computer without a
/// model matches nothing.
bool sourceNamesComputerModel({
  String? computerModel,
  String? descriptorVendor,
  String? descriptorProduct,
  String? manufacturer,
  String? model,
}) {
  final modelKey = normalizeComputerIdentityPart(model);
  if (modelKey.isEmpty) return false;
  final brand = normalizeComputerIdentityPart(manufacturer);
  final fullKey = normalizeComputerIdentityPart(
    brand.isEmpty ? model : '$manufacturer $model',
  );
  final snapshot = normalizeComputerIdentityPart(computerModel);
  if (snapshot == modelKey || snapshot == fullKey) return true;

  if (normalizeComputerIdentityPart(descriptorProduct) != modelKey) {
    return false;
  }
  final vendor = normalizeComputerIdentityPart(descriptorVendor);
  return vendor.isEmpty || brand.isEmpty || vendor == brand;
}

/// The computer each of [sources] belongs to, as source id to computer id.
/// A source left out keeps no link.
///
/// A source with a serial snapshot goes to the one computer whose model it
/// names and whose serial is the same serial (Shearwater hex and decimal
/// included, #3106). Either way a source never goes to a computer of a
/// diver other than its dive's: a unit that changed hands leaves its old
/// dives with their diver.
///
/// A source without one can only say which model it came from, so it is
/// given a computer only when nothing suggests another unit could be its:
/// exactly one computer in [computers] has that model, whichever diver it
/// belongs to; that computer is not another diver's; no source in [sources]
/// of that model names a serial other than the computer's; and the dive
/// neither holds a source of that computer already ([linkedSources]) nor
/// gains another in this match. Two units of one model are never told apart
/// this way, so their sources stay as they are, including two serial-less
/// sources of the model on one dive.
///
/// [sources] and [computers] must be the whole library's, even when only one
/// computer's matches are wanted: whether a model is unambiguous depends on
/// every entry.
Map<String, String> matchOrphanedSources({
  required List<OrphanedSource> sources,
  required List<ImportedComputerCandidate> computers,
  Set<LinkedSource> linkedSources = const {},
}) {
  bool names(OrphanedSource s, ImportedComputerCandidate c) =>
      sourceNamesComputerModel(
        computerModel: s.computerModel,
        descriptorVendor: s.descriptorVendor,
        descriptorProduct: s.descriptorProduct,
        manufacturer: c.manufacturer,
        model: c.model,
      );
  bool serialsMatch(String? serial, ImportedComputerCandidate c) =>
      computerSerialsMatch(
        serial,
        c.serialNumber,
        shearwater: isShearwaterFamily(
          manufacturer: c.manufacturer,
          model: c.model,
        ),
      );
  bool blank(String? v) => normalizeComputerIdentityPart(v).isEmpty;
  // A computer that names no diver, or the source's dive's diver.
  bool sameDiver(OrphanedSource s, ImportedComputerCandidate c) =>
      blank(s.diverId) || blank(c.diverId) || s.diverId == c.diverId;

  final matches = <String, String>{};
  // Serial-less sources that pass every check but the per-dive one.
  final guesses = <OrphanedSource, String>{};
  // Per computer: whether an orphan of its model names another serial.
  final otherUnitSeen = <String, bool>{};
  for (final source in sources) {
    final fitting = computers.where((c) => names(source, c)).toList();
    if (!blank(source.computerSerial)) {
      final same = fitting
          .where(
            (c) =>
                serialsMatch(source.computerSerial, c) && sameDiver(source, c),
          )
          .toList();
      if (same.length == 1) matches[source.id] = same.single.id;
      continue;
    }

    if (fitting.length != 1) continue;
    final target = fitting.single;
    if (!sameDiver(source, target)) continue;
    final otherUnit = otherUnitSeen.putIfAbsent(
      target.id,
      () => sources.any(
        (s) =>
            !blank(s.computerSerial) &&
            names(s, target) &&
            !serialsMatch(s.computerSerial, target),
      ),
    );
    if (otherUnit) continue;
    guesses[source] = target.id;
  }

  // A dive holds at most one source of a computer, so a guess is dropped
  // when its dive already has a source of that computer, or gains another
  // in this match from a serial or from a second guess (a diver carrying
  // two units of the model).
  final claims = <LinkedSource, int>{};
  for (final source in sources) {
    final target = matches[source.id] ?? guesses[source];
    if (target == null) continue;
    final key = (diveId: source.diveId, computerId: target);
    claims[key] = (claims[key] ?? 0) + 1;
  }
  for (final MapEntry(key: source, value: target) in guesses.entries) {
    final key = (diveId: source.diveId, computerId: target);
    if (linkedSources.contains(key) || claims[key]! > 1) continue;
    matches[source.id] = target;
  }
  return matches;
}
