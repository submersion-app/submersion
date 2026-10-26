import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_gear_linker.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Creates the Transmitter item and registry row for each transmitter serial
/// a download turns up that the diver has no row for (issue #3676), as
/// discovering a dive computer creates its item.
///
/// The row starts unconfigured: the registry matcher ignores it, so its
/// placeholder name and the guessed role never reach a tank, and the
/// unknown-transmitter nudge keeps asking for its cylinder until the diver
/// sets it up. Ids are derived, so two devices downloading the same serial
/// converge on one row and one item.
class TransmitterAutoRegistrar {
  TransmitterAutoRegistrar({
    required String Function(String serial) nameFor,
    SyncRepository? syncRepository,
  }) : _nameFor = nameFor,
       _syncRepository = syncRepository ?? SyncRepository();

  final String Function(String serial) _nameFor;
  final SyncRepository _syncRepository;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Registers each of [serials] that [diverId] has no row for. Returns the
  /// canonical serials it registered.
  Future<Set<String>> registerNewSerials(
    Iterable<String> serials, {
    required String? diverId,
  }) async {
    final wanted = {for (final s in serials) ?normalizeTransmitterSerial(s)};
    if (wanted.isEmpty) return const {};
    final known = Transmitter.knownSerials(await _rowsOf(diverId));
    final fresh = wanted.difference(known).toList()..sort();
    if (fresh.isEmpty) return const {};

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final serial in fresh) {
        final name = _nameFor(serial);
        final itemId =
            await matchTransmitterItem(_db, serial: serial, diverId: diverId) ??
            await liveGearId(
              _db,
              transmitterGearSeedId(diverId, serial),
              transmitterGearDeviceKey(diverId, serial),
              type: 'transmitter',
            );
        if (!await _exists(itemId)) {
          await mintDeviceGearItem(
            _db,
            id: itemId,
            diverId: diverId,
            name: name,
            type: EquipmentType.transmitter.name,
            serial: serial,
          );
          // Only our own insert is staged: a peer's copy landing in the race
          // window is not our write to re-stamp.
          if (await _inserted()) {
            await _syncRepository.markRecordPending(
              entityType: 'equipment',
              recordId: itemId,
              localUpdatedAt: now,
            );
          }
        }
        final rowId = autoTransmitterRowId(diverId, serial);
        await _db
            .into(_db.transmitters)
            .insert(
              mode: InsertMode.insertOrIgnore,
              TransmittersCompanion.insert(
                id: rowId,
                diverId: Value(diverId),
                transmitterSerial: Value(serial),
                label: name,
                tankRole: await _latestRole(serial, diverId),
                transmitterEquipmentId: Value(itemId),
                isConfigured: const Value(false),
                createdAt: now,
                updatedAt: now,
              ),
            );
        if (await _inserted()) {
          await _syncRepository.markRecordPending(
            entityType: 'transmitters',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }
      }
    });
    SyncEventBus.notifyLocalChange();
    return fresh.toSet();
  }

  Future<List<Transmitter>> _rowsOf(String? diverId) async {
    final query = _db.select(_db.transmitters);
    if (diverId != null) query.where((t) => t.diverId.equals(diverId));
    return [
      for (final r in await query.get())
        Transmitter(
          id: r.id,
          diverId: r.diverId,
          transmitterSerial: r.transmitterSerial,
          label: r.label,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
        ),
    ];
  }

  /// The role the computer most recently reported for the tank carrying
  /// [serial], else back gas.
  Future<String> _latestRole(String serial, String? diverId) async {
    final row = await _db
        .customSelect(
          'SELECT dt.tank_role AS role FROM dive_tanks dt '
          'JOIN dives d ON d.id = dt.dive_id '
          'WHERE TRIM(dt.transmitter_serial) = ? '
          'AND (? IS NULL OR d.diver_id = ?) '
          'ORDER BY d.dive_date_time DESC, d.id LIMIT 1',
          variables: [
            Variable<String>(serial),
            Variable<String>(diverId),
            Variable<String>(diverId),
          ],
        )
        .getSingleOrNull();
    final role = row?.read<String?>('role');
    return TankRole.values.any((r) => r.name == role)
        ? role!
        : TankRole.backGas.name;
  }

  Future<bool> _exists(String id) async =>
      await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  Future<bool> _inserted() async =>
      (await _db.customSelect('SELECT changes() AS changed').getSingle())
          .read<int>('changed') >
      0;
}

/// Registers and links the transmitters on [diveIds] for the paths that
/// write tanks without the download adapter (file import, reparse), so a
/// serial they bring in gets its item too (issue #3676). Grouped by each
/// dive's diver, since the registry is per diver. Best-effort: a failure
/// never fails the import that called it.
///
/// [registrar] defaults to one naming items in the platform language, for
/// callers that have no widget context.
Future<void> registerTransmittersForDives(
  Iterable<String> diveIds, {
  TransmitterAutoRegistrar? registrar,
  TransmitterGearLinker? linker,
}) async {
  final ids = diveIds.toSet().toList();
  if (ids.isEmpty || DatabaseService.instance.databaseOrNull == null) return;
  try {
    final db = DatabaseService.instance.database;
    final serialsByDiver = <String?, Set<String>>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, (i + 500).clamp(0, ids.length));
      final rows = await db
          .customSelect(
            'SELECT d.diver_id AS diver_id, dt.transmitter_serial AS serial '
            'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
            'WHERE dt.transmitter_serial IS NOT NULL AND d.id IN '
            '(${List.filled(chunk.length, '?').join(', ')})',
            variables: [for (final id in chunk) Variable<String>(id)],
          )
          .get();
      for (final r in rows) {
        final serial = normalizeTransmitterSerial(r.read<String?>('serial'));
        if (serial == null) continue;
        serialsByDiver
            .putIfAbsent(r.read<String?>('diver_id'), () => {})
            .add(serial);
      }
    }
    final reg =
        registrar ??
        TransmitterAutoRegistrar(
          nameFor: (serial) =>
              l10nForLocaleTag('system').transmitters_serial(serial),
        );
    final link = linker ?? TransmitterGearLinker();
    for (final e in serialsByDiver.entries) {
      await reg.registerNewSerials(e.value, diverId: e.key);
      await link.linkSerials(e.value, diverId: e.key);
    }
  } catch (e, stackTrace) {
    // Best-effort: the import has already persisted its dives.
    _log.warning(
      'Registering transmitters for imported dives failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

final _log = LoggerService.forClass(TransmitterAutoRegistrar);
