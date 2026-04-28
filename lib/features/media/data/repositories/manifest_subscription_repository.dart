// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 8. Implementation matches the plan verbatim; the only deviations are
// the shared test helpers (see the test file for details). Schema column
// names match the v72 migration (`MediaSubscriptions` synced + per-device
// `MediaSubscriptionState` with FK cascade on `subscription_id`).
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Domain entity joining `MediaSubscriptions` (synced) with
/// `MediaSubscriptionState` (per-device).
class ManifestSubscription extends Equatable {
  final String id;
  final String manifestUrl;
  final ManifestFormat format;
  final String? displayName;
  final int pollIntervalSeconds;
  final bool isActive;
  final String? credentialsHostId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Per-device state (nullable until first poll cycle).
  final DateTime? lastPolledAt;
  final DateTime? nextPollAt;
  final String? lastEtag;
  final String? lastModified;
  final String? lastError;
  final DateTime? lastErrorAt;

  const ManifestSubscription({
    required this.id,
    required this.manifestUrl,
    required this.format,
    this.displayName,
    required this.pollIntervalSeconds,
    required this.isActive,
    this.credentialsHostId,
    required this.createdAt,
    required this.updatedAt,
    this.lastPolledAt,
    this.nextPollAt,
    this.lastEtag,
    this.lastModified,
    this.lastError,
    this.lastErrorAt,
  });

  @override
  List<Object?> get props => [
    id,
    manifestUrl,
    format,
    displayName,
    pollIntervalSeconds,
    isActive,
    credentialsHostId,
    createdAt,
    updatedAt,
    lastPolledAt,
    nextPollAt,
    lastEtag,
    lastModified,
    lastError,
    lastErrorAt,
  ];
}

class ManifestSubscriptionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ManifestSubscriptionRepository);

  Future<ManifestSubscription> createSubscription({
    required String manifestUrl,
    required ManifestFormat format,
    String? displayName,
    int pollIntervalSeconds = 86400,
    bool isActive = true,
    String? credentialsHostId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();
      final nowMs = now.millisecondsSinceEpoch;
      await _db.transaction(() async {
        await _db
            .into(_db.mediaSubscriptions)
            .insert(
              MediaSubscriptionsCompanion(
                id: Value(id),
                manifestUrl: Value(manifestUrl),
                format: Value(format.name),
                displayName: Value(displayName),
                pollIntervalSeconds: Value(pollIntervalSeconds),
                isActive: Value(isActive),
                credentialsHostId: Value(credentialsHostId),
                createdAt: Value(nowMs),
                updatedAt: Value(nowMs),
              ),
            );
        await _db
            .into(_db.mediaSubscriptionState)
            .insert(MediaSubscriptionStateCompanion(subscriptionId: Value(id)));
      });
      final fetched = await getById(id);
      return fetched!;
    } catch (e, st) {
      _log.error('createSubscription failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<ManifestSubscription?> getById(String id) async {
    try {
      final query = _db.select(_db.mediaSubscriptions).join([
        leftOuterJoin(
          _db.mediaSubscriptionState,
          _db.mediaSubscriptionState.subscriptionId.equalsExp(
            _db.mediaSubscriptions.id,
          ),
        ),
      ])..where(_db.mediaSubscriptions.id.equals(id));
      final row = await query.getSingleOrNull();
      if (row == null) return null;
      return _toEntity(
        row.readTable(_db.mediaSubscriptions),
        row.readTableOrNull(_db.mediaSubscriptionState),
      );
    } catch (e, st) {
      _log.error('getById failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<ManifestSubscription>> listActiveDue(DateTime now) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final query =
          _db.select(_db.mediaSubscriptions).join([
              leftOuterJoin(
                _db.mediaSubscriptionState,
                _db.mediaSubscriptionState.subscriptionId.equalsExp(
                  _db.mediaSubscriptions.id,
                ),
              ),
            ])
            ..where(_db.mediaSubscriptions.isActive.equals(true))
            ..where(
              _db.mediaSubscriptionState.nextPollAt.isNull() |
                  _db.mediaSubscriptionState.nextPollAt.isSmallerOrEqualValue(
                    nowMs,
                  ),
            );
      final rows = await query.get();
      return rows
          .map(
            (r) => _toEntity(
              r.readTable(_db.mediaSubscriptions),
              r.readTableOrNull(_db.mediaSubscriptionState),
            ),
          )
          .toList();
    } catch (e, st) {
      _log.error('listActiveDue failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollSuccess(
    String id, {
    required int pollIntervalSeconds,
    required String? etag,
    required String? lastModified,
    required DateTime now,
  }) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final next = now.add(Duration(seconds: pollIntervalSeconds));
      await (_db.update(
        _db.mediaSubscriptionState,
      )..where((t) => t.subscriptionId.equals(id))).write(
        MediaSubscriptionStateCompanion(
          lastPolledAt: Value(nowMs),
          nextPollAt: Value(next.millisecondsSinceEpoch),
          lastEtag: Value(etag),
          lastModified: Value(lastModified),
          lastError: const Value(null),
          lastErrorAt: const Value(null),
        ),
      );
    } catch (e, st) {
      _log.error('recordPollSuccess failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollNotModified(
    String id, {
    required int pollIntervalSeconds,
    required DateTime now,
  }) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final next = now.add(Duration(seconds: pollIntervalSeconds));
      await (_db.update(
        _db.mediaSubscriptionState,
      )..where((t) => t.subscriptionId.equals(id))).write(
        MediaSubscriptionStateCompanion(
          lastPolledAt: Value(nowMs),
          nextPollAt: Value(next.millisecondsSinceEpoch),
          lastError: const Value(null),
          lastErrorAt: const Value(null),
        ),
      );
    } catch (e, st) {
      _log.error('recordPollNotModified failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollFailure(
    String id, {
    required int pollIntervalSeconds,
    required String error,
    required DateTime now,
  }) async {
    try {
      const cap = Duration(hours: 24);
      final backoff = Duration(seconds: pollIntervalSeconds * 2);
      final delay = backoff > cap ? cap : backoff;
      final nowMs = now.millisecondsSinceEpoch;
      await (_db.update(
        _db.mediaSubscriptionState,
      )..where((t) => t.subscriptionId.equals(id))).write(
        MediaSubscriptionStateCompanion(
          lastError: Value(error),
          lastErrorAt: Value(nowMs),
          nextPollAt: Value(now.add(delay).millisecondsSinceEpoch),
        ),
      );
    } catch (e, st) {
      _log.error('recordPollFailure failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> setActive(String id, bool isActive) async {
    try {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.mediaSubscriptions,
      )..where((t) => t.id.equals(id))).write(
        MediaSubscriptionsCompanion(
          isActive: Value(isActive),
          updatedAt: Value(nowMs),
        ),
      );
    } catch (e, st) {
      _log.error('setActive failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteById(String id) async {
    try {
      await _db.transaction(() async {
        // State has a foreign-key cascade on subscriptionId, but we delete
        // explicitly for clarity.
        await (_db.delete(
          _db.mediaSubscriptionState,
        )..where((t) => t.subscriptionId.equals(id))).go();
        await (_db.delete(
          _db.mediaSubscriptions,
        )..where((t) => t.id.equals(id))).go();
      });
    } catch (e, st) {
      _log.error('deleteById failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  ManifestSubscription _toEntity(
    MediaSubscription sub,
    MediaSubscriptionStateData? state,
  ) {
    return ManifestSubscription(
      id: sub.id,
      manifestUrl: sub.manifestUrl,
      format: ManifestFormat.fromString(sub.format) ?? ManifestFormat.json,
      displayName: sub.displayName,
      pollIntervalSeconds: sub.pollIntervalSeconds,
      isActive: sub.isActive,
      credentialsHostId: sub.credentialsHostId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        sub.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        sub.updatedAt,
        isUtc: true,
      ),
      lastPolledAt: state?.lastPolledAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              state!.lastPolledAt!,
              isUtc: true,
            ),
      nextPollAt: state?.nextPollAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              state!.nextPollAt!,
              isUtc: true,
            ),
      lastEtag: state?.lastEtag,
      lastModified: state?.lastModified,
      lastError: state?.lastError,
      lastErrorAt: state?.lastErrorAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              state!.lastErrorAt!,
              isUtc: true,
            ),
    );
  }
}
