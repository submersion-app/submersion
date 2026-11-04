import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// [values] over [document], as a key reads once a change applies.
Object? keyValue(WriteCheck check, String key) =>
    check.values.containsKey(key) ? check.values[key] : check.document?[key];

/// A block for a key the edit page would not save: one with neither a
/// serial nor a computer and its channel, a channel with no computer, a
/// cylinder that is not a tank in the kit, or an item that is not a
/// transmitter.
Future<PlanBlock?> transmitterKeyProblem(
  WriteCheck check,
  RecordRepositories r,
) async {
  final serial = normalizeTransmitterSerial(
    keyValue(check, 'transmitter_serial') as String?,
  );
  final computer = keyValue(check, 'dive_computer_id') as String?;
  final channel = keyValue(check, 'channel_index') as int?;
  if ((computer == null) != (channel == null)) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'dive_computer_id, channel_index: a channel belongs to a computer, so '
      'name both or neither.',
    );
  }
  if (serial == null && computer == null) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'transmitter_serial: a key is a serial (not blank or all zeros) or a '
      'computer and its channel.',
    );
  }
  final itemId = keyValue(check, 'transmitter_equipment_id') as String?;
  final item = itemId == null
      ? null
      : await r.equipment.getEquipmentById(itemId);
  if (item != null && item.type != EquipmentType.transmitter) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'transmitter_equipment_id: a key belongs to a transmitter item.',
    );
  }
  final cylinderId = check.values['equipment_id'] as String?;
  if (cylinderId != null) {
    final cylinder = await r.equipment.getEquipmentById(cylinderId);
    if (cylinder != null &&
        (cylinder.type != EquipmentType.tank ||
            !inKitSoFar(check.soFar, cylinderId, stored: cylinder.isActive))) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'equipment_id: the cylinder is a tank in the kit, as the picker offers.',
      );
    }
  }
  return null;
}

/// A block for a key another key of the owner holds, as the repository
/// refuses it: the same serial, or the same computer channel. An
/// unconfigured key a download made is no exception here; the agent updates
/// that key instead.
Future<PlanBlock?> transmitterConflict(
  WriteCheck check,
  RecordRepositories r,
) async {
  final serial = normalizeTransmitterSerial(
    keyValue(check, 'transmitter_serial') as String?,
  );
  final computer = keyValue(check, 'dive_computer_id') as String?;
  final channel = keyValue(check, 'channel_index') as int?;
  // Keys earlier in the set claim theirs too, whichever of the two they name.
  for (final earlier in check.soFar.created['transmitters'] ?? const []) {
    final sameSerial =
        serial != null &&
        normalizeTransmitterSerial(earlier['transmitter_serial'] as String?) ==
            serial;
    final sameChannel =
        computer != null &&
        earlier['dive_computer_id'] == computer &&
        earlier['channel_index'] == channel;
    if (sameSerial || sameChannel) {
      return PlanBlock(
        BlockReason.duplicateRecord,
        '${sameSerial ? 'transmitter_serial' : 'channel_index'}: a key '
        'earlier in this set holds it.',
      );
    }
  }
  final gone = check.soFar.deleted['transmitters'] ?? const <String>{};
  for (final other in await r.transmitters.getForDiver(check.ownerId)) {
    if (other.id == check.id || gone.contains(other.id)) continue;
    final sameSerial =
        serial != null &&
        normalizeTransmitterSerial(other.transmitterSerial) == serial;
    final sameChannel =
        computer != null &&
        other.diveComputerId == computer &&
        other.channelIndex == channel;
    if (sameSerial || sameChannel) {
      return PlanBlock(
        BlockReason.duplicateRecord,
        '${sameSerial ? 'transmitter_serial' : 'channel_index'}: key '
        '${other.id} (${other.label}) holds it; update that key instead.',
      );
    }
  }
  return null;
}

/// What a key claims in a set: its serial, else its computer channel.
UniqueClaim? transmitterClaim(WriteCheck check) {
  if (check.kind == ChangeKind.delete) return null;
  final serial = normalizeTransmitterSerial(
    keyValue(check, 'transmitter_serial') as String?,
  );
  if (serial != null) return UniqueClaim('serial/$serial');
  final computer = keyValue(check, 'dive_computer_id') as String?;
  if (computer == null) return null;
  return UniqueClaim('channel/$computer/${keyValue(check, 'channel_index')}');
}

/// The rows a save of [entry] for item [itemId] rewrites beyond the key:
/// the item's other keys, which take its setup; the item's serial when it
/// has none; and, when asked, the past dives' tanks the keys match.
Future<Map<String, int>> transmitterTouched(
  RecordRepositories r,
  String itemId,
  Transmitter entry, {
  required bool applyToDives,
}) async {
  final keys = await r.transmitters.getForEquipment(itemId);
  final others = [
    for (final k in keys)
      if (k.id != entry.id) k,
  ];
  final item = await r.equipment.getEquipmentById(itemId);
  final fillsSerial =
      normalizeTransmitterSerial(entry.transmitterSerial) != null &&
      normalizeTransmitterSerial(item?.serialNumber) == null;
  var tanks = 0;
  if (applyToDives) {
    for (final key in [entry, ...others]) {
      tanks += (await r.transmitters.previewApplyToExistingDives(
        key,
      )).tanksUpdated;
    }
  }
  return {
    if (others.isNotEmpty) 'transmitters': others.length,
    if (fillsSerial) 'equipment': 1,
    if (tanks > 0) 'dive_tanks': tanks,
  };
}
