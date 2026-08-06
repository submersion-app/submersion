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

    final status = ReefDataStatus.values.firstWhere(
      (s) => s.name == row.status,
      orElse: () => ReefDataStatus.unavailable,
    );
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
      row.fetchedAt,
      isUtc: true,
    );

    final ttl = _ttlFor(provider, variant, status);
    if (ttl != null && _now().toUtc().difference(fetchedAt) >= ttl) {
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
