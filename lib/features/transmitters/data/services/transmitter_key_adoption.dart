import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

final _log = LoggerService.forClass(EquipmentItemFold);

/// Writes [entry], a new key when [isNew]. A serial a download only parked on
/// a placeholder item moves to [entry] rather than refusing the save (issue
/// #3367): the diver who made an item by hand has no other way to give it the
/// serial. Any other clash throws [TransmitterConflictException], as a plain
/// write does. Returns the saved key, whose id differs from [entry]'s when it
/// took a placeholder's.
Future<Transmitter> saveTransmitterKey(
  Transmitter entry, {
  required bool isNew,
  required TransmitterRepository repository,
}) async {
  try {
    if (isNew) return await repository.create(entry);
    await repository.update(entry);
    return entry;
  } on TransmitterConflictException catch (e) {
    if (!isUnclaimedKeyFor(entry, e.existing)) rethrow;
    return adoptTransmitterKey(entry, e.existing, repository: repository);
  }
}

/// Whether [holder], which a save of [entry] clashed with, only holds the
/// serial because a download registered it on an item of its own and the
/// diver never set it up (issue #3367). The serial is then [entry]'s to take:
/// a diver who made an item by hand before downloading is giving the
/// placeholder's transmitter its real entry, not naming a second one.
bool isUnclaimedKeyFor(Transmitter entry, Transmitter holder) {
  final serial = normalizeTransmitterSerial(entry.transmitterSerial);
  final item = holder.transmitterEquipmentId;
  return !holder.isConfigured &&
      serial != null &&
      normalizeTransmitterSerial(holder.transmitterSerial) == serial &&
      item != null &&
      item != entry.transmitterEquipmentId;
}

/// Saves [entry] over [unclaimed] and folds the placeholder item into
/// [entry]'s, so the diver sees one transmitter and keeps anything they put on
/// the placeholder. Returns the saved key.
///
/// A placeholder that still has another key stays, as the fold refuses it.
/// The fold is best-effort: the key is saved, and an item left over is only
/// an empty entry the diver can delete.
Future<Transmitter> adoptTransmitterKey(
  Transmitter entry,
  Transmitter unclaimed, {
  required TransmitterRepository repository,
  EquipmentItemFold? itemFold,
}) async {
  final saved = await repository.takeOverKey(entry, unclaimed);
  try {
    await (itemFold ?? EquipmentItemFold()).fold(
      fromId: unclaimed.transmitterEquipmentId!,
      intoId: entry.transmitterEquipmentId!,
    );
  } catch (e, stackTrace) {
    _log.warning(
      'Could not fold the placeholder transmitter item',
      error: e,
      stackTrace: stackTrace,
    );
  }
  return saved;
}
