import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';

/// The Transmitter item the unknown-transmitter repair opens for [serial],
/// seen on [diveId] (issue #3676). A serial no registry row knows yet, from a
/// path that wrote it before #3676, is registered first, so the repair always
/// lands on an item. Null when the dive is gone.
Future<String?> transmitterItemForSetup({
  required String serial,
  required String diveId,
  TransmitterAutoRegistrar? registrar,
  TransmitterRepository? repository,
}) async {
  final repo = repository ?? TransmitterRepository();
  final db = DatabaseService.instance.database;
  final dive = await (db.select(
    db.dives,
  )..where((d) => d.id.equals(diveId))).getSingleOrNull();
  if (dive == null) return null;
  final found = await repo.itemIdForSerial(serial, diverId: dive.diverId);
  if (found != null) return found;
  await registerTransmittersForDives([diveId], registrar: registrar);
  return repo.itemIdForSerial(serial, diverId: dive.diverId);
}
