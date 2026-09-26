import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

/// One row of cached provider output.
class ReefCacheEntry {
  final ReefDataStatus status;
  final String payloadJson;
  final DateTime fetchedAt;

  const ReefCacheEntry({
    required this.status,
    required this.payloadJson,
    required this.fetchedAt,
  });
}

/// Reads and writes the reef-data cache, applying per-provider expiry.
class ReefCacheDao {
  final LocalCacheDatabase _db;
  final DateTime Function() _now;

  /// Failures are retried sooner than successes so a provider outage neither
  /// gets hammered nor sticks for the provider's full lifetime.
  static const Duration failureTtl = Duration(hours: 1);

  ReefCacheDao(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Returns the cached entry, or null when absent or expired.
  Future<ReefCacheEntry?> read(
    ReefProviderId provider,
    String coordKey, {
    String variant = '',
  }) async {
    final row =
        await (_db.select(_db.reefDataCache)..where(
              (t) =>
                  t.provider.equals(provider.name) &
                  t.coordKey.equals(coordKey) &
                  t.variant.equals(variant),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final status = _statusOf(row.status);
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
      row.fetchedAt,
      isUtc: true,
    );

    if (_isExpired(provider, variant, status, fetchedAt, _now().toUtc())) {
      return null;
    }

    return ReefCacheEntry(
      status: status,
      payloadJson: row.payloadJson,
      fetchedAt: fetchedAt,
    );
  }

  Future<void> write({
    required ReefProviderId provider,
    required String coordKey,
    required ReefDataStatus status,
    required String payloadJson,
    String variant = '',
  }) async {
    await _db
        .into(_db.reefDataCache)
        .insertOnConflictUpdate(
          ReefDataCacheCompanion.insert(
            provider: provider.name,
            coordKey: coordKey,
            variant: Value(variant),
            payloadJson: payloadJson,
            status: status.name,
            fetchedAt: _now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  /// Deletes every row [read] would already refuse to return, and returns how
  /// many went. [read] only ignores an expired row, and a refetch overwrites
  /// it only if that coordinate is looked up again, so without this a site
  /// viewed once keeps its expired rows forever (issue #1929).
  ///
  /// A row naming a provider this build no longer has is deleted too: nothing
  /// can read it. Dated health readings never expire, so they stay; each one
  /// is the answer for a dive on that day and is read again with that dive.
  Future<int> deleteExpired() async {
    final t = _db.reefDataCache;
    final now = _now().toUtc();
    final providers = ReefProviderId.values.asNameMap();

    var deleted = 0;
    // The snapshot is taken inside the transaction so a refetch cannot land
    // between it and the deletes: writes from outside queue until this
    // commits, so the row each DELETE removes is the row that was evaluated,
    // never a fresh replacement under the same primary key.
    await _db.transaction(() async {
      final rows =
          await (_db.selectOnly(t)..addColumns([
                t.provider,
                t.coordKey,
                t.variant,
                t.status,
                t.fetchedAt,
              ]))
              .get();
      for (final row in rows) {
        final providerName = row.read(t.provider)!;
        final coordKey = row.read(t.coordKey)!;
        final variant = row.read(t.variant)!;
        final provider = providers[providerName];
        if (provider != null &&
            !_isExpired(
              provider,
              variant,
              _statusOf(row.read(t.status)!),
              DateTime.fromMillisecondsSinceEpoch(
                row.read(t.fetchedAt)!,
                isUtc: true,
              ),
              now,
            )) {
          continue;
        }
        deleted +=
            await (_db.delete(t)..where(
                  (r) =>
                      r.provider.equals(providerName) &
                      r.coordKey.equals(coordKey) &
                      r.variant.equals(variant),
                ))
                .go();
      }
    });
    return deleted;
  }

  static ReefDataStatus _statusOf(String name) =>
      ReefDataStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ReefDataStatus.unavailable,
      );

  bool _isExpired(
    ReefProviderId provider,
    String variant,
    ReefDataStatus status,
    DateTime fetchedAt,
    DateTime now,
  ) {
    final ttl = _ttlFor(provider, variant, status);
    return ttl != null && now.difference(fetchedAt) >= ttl;
  }

  /// Null means "never expires".
  Duration? _ttlFor(
    ReefProviderId provider,
    String variant,
    ReefDataStatus status,
  ) {
    if (status == ReefDataStatus.unavailable) return failureTtl;
    // A dated health reading is immutable once that day has passed.
    if (provider == ReefProviderId.health && variant.isNotEmpty) return null;
    return provider.ttl;
  }
}
