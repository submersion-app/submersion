// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 4. Schema deviations applied vs. plan code:
//
// - `network_credential_hosts.id` is TEXT (String) PRIMARY KEY, not INTEGER —
//   IDs are UUIDs generated on insert. `delete`/`findById`/`touchLastUsed`
//   take String ids and `upsert` returns String.
// - `addedAt` is required `INTEGER` (epoch millis); set on insert.
// - `lastUsedAt` is `INTEGER?` (epoch millis), not DateTime — `touchLastUsed`
//   writes `DateTime.now().toUtc().millisecondsSinceEpoch`.
// - `credentialsRef` is required NOT NULL TEXT. The plan does not surface this
//   column in the repo signature; we default it to the hostname so the table
//   constraint is satisfied. The Phase 3a `NetworkCredentialsService` (Task 6)
//   stores the actual secret under its own secure-storage key derived from
//   hostname, so this column is informational only at this layer.
//
// All public surface (upsert, list, findByHostname, findById, delete,
// touchLastUsed) preserves the plan's intent.
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:uuid/uuid.dart';

class NetworkCredentialsRepository {
  NetworkCredentialsRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<String> upsert({
    required String hostname,
    required String authType,
    String? displayName,
  }) async {
    final existing = await findByHostname(hostname);
    if (existing != null) {
      await (_db.update(
        _db.networkCredentialHosts,
      )..where((t) => t.id.equals(existing.id))).write(
        NetworkCredentialHostsCompanion(
          authType: Value(authType),
          displayName: Value(displayName),
        ),
      );
      return existing.id;
    }
    final id = _uuid.v4();
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.networkCredentialHosts)
        .insert(
          NetworkCredentialHostsCompanion.insert(
            id: id,
            hostname: hostname,
            authType: authType,
            displayName: Value(displayName),
            credentialsRef: hostname,
            addedAt: nowMillis,
          ),
        );
    return id;
  }

  Future<List<NetworkCredentialHost>> list() =>
      _db.select(_db.networkCredentialHosts).get();

  Future<NetworkCredentialHost?> findByHostname(String hostname) {
    return (_db.select(
      _db.networkCredentialHosts,
    )..where((t) => t.hostname.equals(hostname))).getSingleOrNull();
  }

  Future<NetworkCredentialHost?> findById(String id) => (_db.select(
    _db.networkCredentialHosts,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> delete(String id) => (_db.delete(
    _db.networkCredentialHosts,
  )..where((t) => t.id.equals(id))).go();

  Future<void> touchLastUsed(String id) async {
    await (_db.update(
      _db.networkCredentialHosts,
    )..where((t) => t.id.equals(id))).write(
      NetworkCredentialHostsCompanion(
        lastUsedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }
}
