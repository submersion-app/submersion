import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/domain/entities/connector_account.dart'
    as domain;

/// CRUD for external media service connections (`connector_accounts`).
/// The table is per-device and never synced; secrets live in secure
/// storage behind `credentialsRef`.
class ConnectorAccountsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();

  /// The account for [connectorType], newest first when several exist,
  /// or null when the service is not connected on this device.
  Future<domain.ConnectorAccount?> getByType(String connectorType) async {
    final query = _db.select(_db.connectorAccounts)
      ..where((t) => t.connectorType.equals(connectorType))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<domain.ConnectorAccount> create({
    required String connectorType,
    required String displayName,
    required String credentialsRef,
    String? accountIdentifier,
    String? baseUrl,
    DateTime? addedAt,
  }) async {
    final id = _uuid.v4();
    final added = addedAt ?? DateTime.now();
    await _db
        .into(_db.connectorAccounts)
        .insert(
          ConnectorAccountsCompanion.insert(
            id: id,
            connectorType: connectorType,
            displayName: displayName,
            credentialsRef: credentialsRef,
            accountIdentifier: Value(accountIdentifier),
            baseUrl: Value(baseUrl),
            addedAt: added.millisecondsSinceEpoch,
          ),
        );
    return domain.ConnectorAccount(
      id: id,
      connectorType: connectorType,
      displayName: displayName,
      credentialsRef: credentialsRef,
      accountIdentifier: accountIdentifier,
      baseUrl: baseUrl,
      addedAt: added,
    );
  }

  Future<void> updateDisplay(
    String id, {
    String? displayName,
    String? accountIdentifier,
  }) async {
    await (_db.update(
      _db.connectorAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectorAccountsCompanion(
        displayName: displayName == null
            ? const Value.absent()
            : Value(displayName),
        accountIdentifier: accountIdentifier == null
            ? const Value.absent()
            : Value(accountIdentifier),
      ),
    );
  }

  Future<void> touchLastUsed(String id) async {
    await (_db.update(
      _db.connectorAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectorAccountsCompanion(
        lastUsedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.connectorAccounts,
    )..where((t) => t.id.equals(id))).go();
  }

  domain.ConnectorAccount _toDomain(ConnectorAccount row) {
    return domain.ConnectorAccount(
      id: row.id,
      connectorType: row.connectorType,
      displayName: row.displayName,
      baseUrl: row.baseUrl,
      accountIdentifier: row.accountIdentifier,
      credentialsRef: row.credentialsRef,
      addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt, isUtc: true),
      lastUsedAt: row.lastUsedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastUsedAt!, isUtc: true),
    );
  }
}
