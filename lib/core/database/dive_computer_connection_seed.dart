import 'package:drift/drift.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';
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
  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((c) => c.read<String>('name')).toSet();
  }

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

    final direct = switch (connectionType) {
      'bluetooth' || 'ble' => DiveComputerConnectionKind.ble,
      'bluetoothclassic' => DiveComputerConnectionKind.bluetoothClassic,
      'usb' => DiveComputerConnectionKind.usb,
      'infrared' => DiveComputerConnectionKind.infrared,
      _ => null,
    };
    if (direct != null) {
      final address = computer.readNullable<String>('bluetooth_address');
      await insert(
        computerId: id,
        kind: direct,
        firstUsedAt: createdAt,
        lastUsedAt: lastUsed,
        address: address?.trim().isEmpty ?? true ? null : address!.trim(),
        localLastUsedAt: lastUsed,
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

    if (hasSources) {
      // A Drift DateTimeColumn stores Unix seconds; connections use
      // milliseconds like the rest of the registry.
      final ownedBy = hasDiveComputer
          ? '(s.computer_id = ?1 OR (s.computer_id IS NULL AND '
                'd.computer_id = ?1))'
          : 's.computer_id = ?1';
      final formats = await db
          .customSelect(
            'SELECT s.source_file_format AS format, '
            'MIN(s.created_at) AS first_at, MAX(s.created_at) AS last_at '
            'FROM dive_data_sources s '
            '${hasDiveComputer ? 'LEFT JOIN dives d ON d.id = s.dive_id ' : ''}'
            'WHERE $ownedBy '
            "AND s.source_file_format IS NOT NULL "
            "AND TRIM(s.source_file_format) <> '' "
            "AND (s.source_format IS NULL OR s.source_format <> 'dive_computer') "
            'GROUP BY s.source_file_format',
            variables: [Variable<String>(id)],
          )
          .get();
      for (final format in formats) {
        await insert(
          computerId: id,
          kind: DiveComputerConnectionKind.file,
          detail: format.read<String>('format').trim(),
          firstUsedAt: format.read<int>('first_at') * 1000,
          lastUsedAt: format.read<int>('last_at') * 1000,
        );
      }
    }
  }
  return inserted;
}
