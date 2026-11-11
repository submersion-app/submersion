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
/// vendor, when both sides have one, the manufacturer (compared by letters
/// and digits). A computer without a model matches nothing.
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
  // By letters and digits only, so a brand typed with a hyphen or a dot
  // ("Heinrichs-Weikamp") is still the vendor libdivecomputer names.
  final vendor = _brandKey(descriptorVendor);
  final maker = _brandKey(manufacturer);
  return vendor.isEmpty || maker.isEmpty || vendor == maker;
}

final RegExp _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]', unicode: true);

String _brandKey(String? brand) =>
    normalizeComputerIdentityPart(brand).replaceAll(_notLetterOrDigit, '');

/// Whether [source]'s snapshots name [computer] at all, by its model or, for
/// a computer saved with no model, by the manufacturer its full name fell
/// back to (`DiveComputer.fullName`), which only a serial can then confirm.
/// The precondition for any match, and a cheap test that a relink for one
/// computer has anything to look at.
bool orphanMayBelongTo(
  OrphanedSource source,
  ImportedComputerCandidate computer,
) {
  if (_namesModel(source, computer)) return true;
  final maker = normalizeComputerIdentityPart(computer.manufacturer);
  return normalizeComputerIdentityPart(computer.model).isEmpty &&
      maker.isNotEmpty &&
      normalizeComputerIdentityPart(source.computerModel) == maker;
}

bool _namesModel(OrphanedSource s, ImportedComputerCandidate c) =>
    sourceNamesComputerModel(
      computerModel: s.computerModel,
      descriptorVendor: s.descriptorVendor,
      descriptorProduct: s.descriptorProduct,
      manufacturer: c.manufacturer,
      model: c.model,
    );

/// The computer each of [sources] belongs to, as source id to computer id.
/// A source left out keeps no link.
///
/// A source with a serial snapshot goes to the one computer whose model it
/// names and whose serial is the same serial (Shearwater hex and decimal
/// included, #3106); a computer with no model is named by its manufacturer,
/// the snapshot it was saved under. Either way a source never goes to a
/// computer of a diver other than its dive's: a unit that changed hands
/// leaves its old dives with their diver.
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
    final fitting = computers.where((c) => _namesModel(source, c)).toList();
    if (!blank(source.computerSerial)) {
      final same = computers
          .where(
            (c) =>
                orphanMayBelongTo(source, c) &&
                serialsMatch(source.computerSerial, c) &&
                sameDiver(source, c),
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
            _namesModel(s, target) &&
            !serialsMatch(s.computerSerial, target),
      ),
    );
    if (otherUnit) continue;
    guesses[source] = target.id;
  }

  // A guess cannot tell a second unit of the model from this one, so it is
  // dropped when its dive already has a source of that computer, or gains
  // another in this match from a serial or from a second guess (a diver
  // carrying two units of the model). Serial matches are not held to this:
  // a dive merged from two dives of one computer rightly has two of its
  // sources, and each serial says whose it is.
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
