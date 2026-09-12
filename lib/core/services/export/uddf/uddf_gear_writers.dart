import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Gear elements shared by the full backup and the dives-only export.
///
/// Items themselves are declared in the private
/// `<applicationdata><submersion><equipment>` block; the only standard
/// declarations are the dive computers, which live under the owner.
abstract final class UddfGearWriters {
  /// The id a `<divecomputer>` is declared under in the UDDF standard
  /// sections, and therefore the only id a `<link ref>` may point at.
  ///
  /// Built from model and serial rather than the `dive_computers` row id: the
  /// standard `<divecomputer>` elements are minted from the dives' display
  /// snapshots, and the row's UUID appears only inside
  /// `<applicationdata><submersion><divecomputers>`, which is not a valid
  /// IDREF target.
  static String computerRefId(String model, String? serial) =>
      'dc_${model.replaceAll(' ', '_')}_${serial ?? 'unknown'}';

  /// The `<divecomputer>` id of each distinct computer on [dives], first
  /// seen first. A dive with no computer model contributes nothing.
  static Set<String> computerIds(Iterable<Dive> dives) => {
    for (final dive in dives)
      if (dive.diveComputerModel case final model? when model.isNotEmpty)
        computerRefId(model, dive.diveComputerSerial),
  };

  /// The owner's `<equipment>` block declaring each computer on [dives],
  /// and the ids it declared. Writes nothing and returns an empty set when
  /// no dive names a computer. The caller writes the `<owner>` around it,
  /// so a backup can carry the owner's details and a shared file need not.
  static Set<String> writeOwnerComputers(
    XmlBuilder builder,
    Iterable<Dive> dives,
  ) {
    final computers = <String, ({String model, String serial})>{};
    for (final dive in dives) {
      final model = dive.diveComputerModel;
      if (model == null || model.isEmpty) continue;
      computers[computerRefId(model, dive.diveComputerSerial)] = (
        model: model,
        serial: dive.diveComputerSerial ?? '',
      );
    }
    if (computers.isEmpty) return const {};
    builder.element(
      'equipment',
      nest: () {
        for (final entry in computers.entries) {
          builder.element(
            'divecomputer',
            attributes: {'id': entry.key},
            nest: () {
              builder.element('model', nest: entry.value.model);
              if (entry.value.serial.isNotEmpty) {
                builder.element('serialnumber', nest: entry.value.serial);
              }
            },
          );
        }
      },
    );
    return computers.keys.toSet();
  }

  /// The dive's `<equipmentused>`: one `<equipmentref>` per gear row, then
  /// a link to its dive computer. Nothing when it has neither.
  static void writeEquipmentUsed(XmlBuilder builder, Dive dive) {
    final model = dive.diveComputerModel;
    final computerRef = model != null && model.isNotEmpty
        ? computerRefId(model, dive.diveComputerSerial)
        : null;
    if (dive.equipment.isEmpty && computerRef == null) return;
    builder.element(
      'equipmentused',
      nest: () {
        for (final item in dive.equipment) {
          builder.element('equipmentref', nest: 'equip_${item.id}');
        }
        if (computerRef != null) {
          builder.element('link', attributes: {'ref': computerRef});
        }
      },
    );
  }
}
