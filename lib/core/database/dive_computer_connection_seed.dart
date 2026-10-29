import 'package:drift/drift.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/table_columns.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

/// Give every computer registered before connections existed the
/// connections its stored data already proves (issue #3106). Returns how many
/// rows it inserted.
///
/// - Its single `connection_type` becomes a direct connection, carrying this
///   device's `bluetooth_address` as the local address.
/// - `connection_type = 'cloud'` becomes a cloud connection, the provider
///   named by the manufacturer.
/// - Each distinct `dive_data_sources.source_file_format` among its file
///   imports becomes a file connection.
///
/// Only computers with no connection row at all are seeded, so a computer
/// whose connections arrived from an upgraded peer is left alone, and the
/// heal runs once per computer.
///
/// Local-only and idempotent: no HLC bump, nothing marked pending. The ids
/// are deterministic ([diveComputerConnectionId]), so every device on this
/// version derives the same rows from the same synced data and a fleet
/// converges without sending them.
Future<int> seedDiveComputerConnections(DatabaseConnectionUser db) async {
  Future<Set<String>> columnsOf(String table) => tableColumnNames(db, table);

  final connectionCols = await columnsOf('dive_computer_connections');
  if (!connectionCols.containsAll({
    'id',
    'computer_id',
    'kind',
    'detail',
    'first_used_at',
    'last_used_at',
    'address',
    'local_last_used_at',
    'created_at',
    'updated_at',
  })) {
    return 0;
  }
  final computerCols = await columnsOf('dive_computers');
  if (!computerCols.containsAll({
    'id',
    'manufacturer',
    'connection_type',
    'bluetooth_address',
    'last_download_timestamp',
    'created_at',
    'updated_at',
  })) {
    return 0;
  }
  final sourceCols = await columnsOf('dive_data_sources');
  final hasSources = sourceCols.containsAll({
    'dive_id',
    'computer_id',
    'source_format',
    'source_file_format',
    'created_at',
  });
  final diveCols = await columnsOf('dives');
  final hasDiveComputer = diveCols.containsAll({'id', 'computer_id'});

  final computers = await db.customSelect('''
    SELECT c.id, c.manufacturer, c.connection_type, c.bluetooth_address,
      c.last_download_timestamp, c.created_at, c.updated_at
    FROM dive_computers c
    WHERE NOT EXISTS (
      SELECT 1 FROM dive_computer_connections x WHERE x.computer_id = c.id
    )
  ''').get();

  // Every unseeded computer's file formats in one read, before any row is
  // inserted (the NOT EXISTS would otherwise drop a computer this pass just
  // gave a direct connection). A source belongs to its own computer, or to
  // its dive's when it names none. A Drift DateTimeColumn stores Unix
  // seconds; connections use milliseconds like the rest of the registry.
  final formatsByComputer =
      <String, List<({String format, int firstAt, int lastAt})>>{};
  if (hasSources && computers.isNotEmpty) {
    final owner = hasDiveComputer
        ? 'COALESCE(s.computer_id, d.computer_id)'
        : 's.computer_id';
    final rows = await db
        .customSelect(
          'SELECT $owner AS owner, s.source_file_format AS format, '
          'MIN(s.created_at) AS first_at, MAX(s.created_at) AS last_at '
          'FROM dive_data_sources s '
          '${hasDiveComputer ? 'LEFT JOIN dives d ON d.id = s.dive_id ' : ''}'
          'WHERE $owner IN (SELECT c.id FROM dive_computers c WHERE NOT EXISTS '
          '(SELECT 1 FROM dive_computer_connections x '
          'WHERE x.computer_id = c.id)) '
          'AND s.source_file_format IS NOT NULL '
          "AND TRIM(s.source_file_format) <> '' "
          "AND (s.source_format IS NULL OR s.source_format <> 'dive_computer') "
          'GROUP BY owner, s.source_file_format',
        )
        .get();
    for (final row in rows) {
      (formatsByComputer[row.read<String>('owner')] ??= []).add((
        format: row.read<String>('format').trim(),
        firstAt: row.read<int>('first_at') * 1000,
        lastAt: row.read<int>('last_at') * 1000,
      ));
    }
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  var inserted = 0;

  Future<void> insert({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    required int firstUsedAt,
    required int lastUsedAt,
    String? address,
    int? localLastUsedAt,
  }) async {
    final id = diveComputerConnectionId(
      computerId: computerId,
      kind: kind,
      detail: detail,
    );
    final changed = await db.customUpdate(
      'INSERT OR IGNORE INTO dive_computer_connections '
      '(id, computer_id, kind, detail, first_used_at, last_used_at, address, '
      'local_last_used_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(id),
        Variable<String>(computerId),
        Variable<String>(kind.name),
        Variable<String>(detail),
        Variable<int>(firstUsedAt),
        Variable<int>(lastUsedAt),
        Variable<String>(address),
        Variable<int>(localLastUsedAt),
        Variable<int>(now),
        Variable<int>(now),
      ],
    );
    inserted += changed;
  }

  for (final computer in computers) {
    final id = computer.read<String>('id');
    final createdAt = computer.read<int>('created_at');
    final lastUsed =
        computer.readNullable<int>('last_download_timestamp') ??
        computer.read<int>('updated_at');
    final connectionType = normalizeComputerIdentityPart(
      computer.readNullable<String>('connection_type'),
    );

    final rawAddress = computer.readNullable<String>('bluetooth_address');
    final address = rawAddress?.trim().isEmpty ?? true
        ? null
        : rawAddress!.trim();
    final direct = _directKind(connectionType, address);
    if (direct != null) {
      await insert(
        computerId: id,
        kind: direct,
        firstUsedAt: createdAt,
        lastUsedAt: lastUsed,
        address: address,
        // Used here only if this device holds an address for it.
        localLastUsedAt: address == null ? null : lastUsed,
      );
    }

    if (connectionType == 'cloud') {
      final provider = switch (normalizeComputerIdentityPart(
        computer.readNullable<String>('manufacturer'),
      )) {
        'garmin' => 'garminConnect',
        'suunto' => 'suuntoCloud',
        _ => null,
      };
      if (provider != null) {
        await insert(
          computerId: id,
          kind: DiveComputerConnectionKind.cloud,
          detail: provider,
          firstUsedAt: createdAt,
          lastUsedAt: lastUsed,
        );
      }
    }

    for (final format in formatsByComputer[id] ?? const []) {
      await insert(
        computerId: id,
        kind: DiveComputerConnectionKind.file,
        detail: format.format,
        firstUsedAt: format.firstAt,
        lastUsedAt: format.lastAt,
      );
    }
  }

  // A computer whose rows all came from other devices keeps the legacy
  // address this device downloads from: a peer's rows can arrive by sync
  // before this device seeded its own, and the pass above then skips the
  // computer, leaving the saved download with connections none of which it
  // can reach. Only this device's columns change, so nothing is stamped.
  final unreachable = await db
      .customSelect(
        'SELECT c.id, c.connection_type, c.bluetooth_address, '
        'c.last_download_timestamp, c.created_at, c.updated_at '
        'FROM dive_computers c '
        "WHERE TRIM(COALESCE(c.bluetooth_address, '')) <> '' "
        'AND EXISTS (SELECT 1 FROM dive_computer_connections x '
        'WHERE x.computer_id = c.id) '
        'AND NOT EXISTS (SELECT 1 FROM dive_computer_connections x '
        "WHERE x.computer_id = c.id AND TRIM(COALESCE(x.address, '')) <> '')",
      )
      .get();
  for (final computer in unreachable) {
    final id = computer.read<String>('id');
    final address = computer.read<String>('bluetooth_address').trim();
    final kind = _directKind(
      normalizeComputerIdentityPart(
        computer.readNullable<String>('connection_type'),
      ),
      address,
    );
    if (kind == null) continue;
    final lastUsed =
        computer.readNullable<int>('last_download_timestamp') ??
        computer.read<int>('updated_at');
    final updated = await db.customUpdate(
      'UPDATE dive_computer_connections SET address = ?, '
      'local_last_used_at = COALESCE(local_last_used_at, ?) WHERE id = ?',
      variables: [
        Variable<String>(address),
        Variable<int>(lastUsed),
        Variable<String>(diveComputerConnectionId(computerId: id, kind: kind)),
      ],
    );
    if (updated > 0) {
      inserted += updated;
      continue;
    }
    await insert(
      computerId: id,
      kind: kind,
      firstUsedAt: computer.read<int>('created_at'),
      lastUsedAt: lastUsed,
      address: address,
      localLastUsedAt: lastUsed,
    );
  }
  return inserted;
}

/// The direct transport a computer's legacy columns describe on this device.
///
/// The synced type is whichever transport some device used last, while the
/// address is this device's own (issue #3106), so an address whose shape
/// names its transport wins. A Classic type keeps its name: a BLE and a
/// Classic address look alike.
DiveComputerConnectionKind? _directKind(
  String connectionType,
  String? address,
) {
  final byType = switch (connectionType) {
    'bluetooth' || 'ble' => DiveComputerConnectionKind.ble,
    'bluetoothclassic' => DiveComputerConnectionKind.bluetoothClassic,
    'usb' => DiveComputerConnectionKind.usb,
    'infrared' => DiveComputerConnectionKind.infrared,
    _ => null,
  };
  final byAddress = address == null ? null : _kindOfLocalAddress(address);
  if (byType == DiveComputerConnectionKind.bluetoothClassic &&
      byAddress == DiveComputerConnectionKind.ble) {
    return byType;
  }
  return byAddress ?? byType;
}

final RegExp _macAddress = RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$');
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _comPort = RegExp(r'^com\d+$');

/// The transport a stored local address names by its shape: a Bluetooth
/// MAC or a CoreBluetooth identifier, or a serial port path or `COMn`.
/// Null when the shape says nothing, which leaves the stored type to decide.
DiveComputerConnectionKind? _kindOfLocalAddress(String address) {
  final a = address.toLowerCase();
  if (_macAddress.hasMatch(a) || _uuid.hasMatch(a)) {
    return DiveComputerConnectionKind.ble;
  }
  if (a.startsWith('/dev/') || _comPort.hasMatch(a)) {
    return DiveComputerConnectionKind.usb;
  }
  return null;
}
