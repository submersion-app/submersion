import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

const _log = LoggerService('TransmitterKeyAdoption');

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
/// serial because a download registered it and the diver never set it up
/// (issue #3367). The serial is then [entry]'s to take: a diver who made an
/// item by hand before downloading is giving the download's transmitter its
/// real entry, not naming a second one.
bool isUnclaimedKeyFor(Transmitter entry, Transmitter holder) {
  final serial = normalizeTransmitterSerial(entry.transmitterSerial);
  final item = holder.transmitterEquipmentId;
  final target = entry.transmitterEquipmentId;
  return !holder.isConfigured &&
      serial != null &&
      normalizeTransmitterSerial(holder.transmitterSerial) == serial &&
      item != null &&
      target != null &&
      item != target;
}

/// Saves [entry] over [unclaimed] and, when the download minted the item
/// [unclaimed] was on, folds that placeholder into [entry]'s, so the diver
/// sees one transmitter and keeps anything they put on it. An item the diver
/// made, which the download only matched by its serial number, stays: only
/// its key moves. Returns the saved key.
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
  // A row that went, or let the serial go, since the clash was not taken over.
  if (saved.id != unclaimed.id) return saved;
  final placeholder = unclaimed.transmitterEquipmentId!;
  if (!isDownloadedTransmitterItem(
    placeholder,
    diverId: saved.diverId,
    serial: saved.transmitterSerial!,
  )) {
    return saved;
  }
  try {
    final folded = await (itemFold ?? EquipmentItemFold()).fold(
      fromId: placeholder,
      intoId: saved.transmitterEquipmentId!,
    );
    if (!folded) {
      _log.info('Kept the placeholder transmitter item the fold refused');
    }
  } catch (e, stackTrace) {
    _log.warning(
      'Could not fold the placeholder transmitter item',
      error: e,
      stackTrace: stackTrace,
    );
  }
  return saved;
}

/// Whether [itemId] is the item a download mints for [serial]: its seed id,
/// or one of the ids a deletion moves it along (`liveGearId` walks the same
/// chain, bounded the same way).
bool isDownloadedTransmitterItem(
  String itemId, {
  required String? diverId,
  required String serial,
}) {
  final deviceKey = transmitterGearDeviceKey(diverId, serial);
  var id = transmitterGearSeedId(diverId, serial);
  for (var step = 0; step <= 64; step++) {
    if (id == itemId) return true;
    id = nextGearRemintId(deviceKey, id);
  }
  return false;
}
