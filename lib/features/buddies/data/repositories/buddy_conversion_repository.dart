import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';

/// Reads and writes that turn legacy buddy text into buddy records (#1831).
///
/// Reached through [BuddyRepository]'s delegating methods, the same shape as
/// [BuddyMergeRepository]. Sync marks go on the `buddies` and `diveBuddies`
/// rows only, never on the parent dive: `diveBuddies` is a parent-gated
/// child that exports on its own pending mark (#1769), and restamping the
/// dive would let this device's whole dive row win last-writer-wins over a
/// newer edit made on another device.
class BuddyConversionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _sync = SyncRepository();
  final CertificationRepository _certRepo = CertificationRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(BuddyConversionRepository);

  /// The buddies a legacy name may match: [diverId]'s own and unowned ones,
  /// each with the number of dives it is linked to.
  Future<List<MatchCandidate>> candidateBuddies(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT b.id, b.name, b.diver_id, b.created_at,
        (SELECT COUNT(*) FROM dive_buddies db WHERE db.buddy_id = b.id)
          AS dive_count
      FROM buddies b
      WHERE b.diver_id = ? OR b.diver_id IS NULL
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.buddies, _db.diveBuddies},
        )
        .get();
    return [
      for (final row in rows)
        MatchCandidate(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          diverId: row.readNullable<String>('diver_id'),
          diveCount: row.read<int>('dive_count'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at'),
          ),
        ),
    ];
  }

  /// [diverId]'s dives that have legacy buddy or dive-master text and no
  /// linked buddy, newest first. Scoped with `diver_id = ?` exactly like the
  /// dive list, so both surfaces show the same dives.
  Future<List<UnlinkedTextDive>> unlinkedTextDives(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT d.id, d.dive_number, d.dive_date_time, d.buddy, d.dive_master,
        s.name AS site_name
      FROM dives d
      LEFT JOIN dive_sites s ON s.id = d.site_id
      WHERE d.diver_id = ?
        AND NOT EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
        AND (TRIM(COALESCE(d.buddy, '')) <> ''
          OR TRIM(COALESCE(d.dive_master, '')) <> '')
      ORDER BY d.dive_date_time DESC, d.id
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.dives, _db.diveBuddies, _db.diveSites},
        )
        .get();
    return [
      for (final row in rows)
        UnlinkedTextDive(
          diveId: row.read<String>('id'),
          diveNumber: row.readNullable<int>('dive_number'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          siteName: row.readNullable<String>('site_name'),
          buddyText: row.readNullable<String>('buddy'),
          diveMasterText: row.readNullable<String>('dive_master'),
        ),
    ];
  }

  /// Writes [plans] in one transaction and returns what it wrote. Dives that
  /// are gone, gained links, or had their buddy or dive-master text changed
  /// since planning are skipped, so a stale preview can neither double-link
  /// nor link names the diver never reviewed. Announces the change once,
  /// after the commit.
  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) async {
    try {
      final receipt = await _db.transaction(() async {
        final run = _ApplyRun(
          matcher: BuddyNameMatcher(
            await candidateBuddies(diverId),
            diverId: diverId,
          ),
          diverId: diverId,
          newBuddyNote: newBuddyNote,
          now: DateTime.now().millisecondsSinceEpoch,
        );
        for (final plan in plans) {
          if (plan.isEmpty || !await _isStillAsPlanned(plan)) continue;
          final linked = <String>{};
          for (final link in plan.links) {
            final buddyId = await _resolve(link.target, run);
            if (!linked.add(buddyId)) continue;
            final linkId = _uuid.v4();
            await _db
                .into(_db.diveBuddies)
                .insert(
                  DiveBuddiesCompanion(
                    id: Value(linkId),
                    diveId: Value(plan.diveId),
                    buddyId: Value(buddyId),
                    role: Value(link.roleId),
                    createdAt: Value(run.now),
                  ),
                );
            await _sync.markRecordPending(
              entityType: 'diveBuddies',
              recordId: linkId,
              localUpdatedAt: run.now,
            );
            run.linkIds.add(linkId);
          }
          run.diveIds.add(plan.diveId);
        }
        return run.toReceipt();
      });
      if (!receipt.isEmpty) SyncEventBus.notifyLocalChange();
      return receipt;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link legacy buddy text',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reverses [receipt]: its links, the buddies it created that nothing else
  /// has linked since, and its ownership claims on buddies none of the
  /// diver's dives link any more. One transaction, one notify.
  Future<void> undo(ConversionReceipt receipt) async {
    if (receipt.isEmpty) return;
    try {
      await _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (receipt.linkIds.isNotEmpty) {
          final present = await (_db.select(
            _db.diveBuddies,
          )..where((t) => t.id.isIn(receipt.linkIds))).get();
          await (_db.delete(
            _db.diveBuddies,
          )..where((t) => t.id.isIn(receipt.linkIds))).go();
          for (final row in present) {
            await _sync.logDeletion(
              entityType: 'diveBuddies',
              recordId: row.id,
            );
          }
        }
        for (final id in receipt.createdBuddyIds) {
          await _deleteIfUnlinked(id);
        }
        if (receipt.claimedBuddyIds.isNotEmpty) {
          final claimed =
              await (_db.select(_db.buddies)..where(
                    (t) =>
                        t.id.isIn(receipt.claimedBuddyIds) &
                        t.diverId.equals(receipt.diverId),
                  ))
                  .get();
          for (final row in claimed) {
            // A dive of this diver linked it since (or before): returning it
            // to unowned would drop it from the diver's buddy list while
            // that dive still shows it, so the claim stays.
            if (await _linkedOnDiverDive(row.id, receipt.diverId)) continue;
            await (_db.update(
              _db.buddies,
            )..where((t) => t.id.equals(row.id))).write(
              BuddiesCompanion(
                diverId: const Value(null),
                updatedAt: Value(now),
              ),
            );
            await _sync.markRecordPending(
              entityType: 'buddies',
              recordId: row.id,
              localUpdatedAt: now,
            );
          }
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to undo a legacy buddy conversion',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes buddy [id] if it still exists and no dive links it, tombstoning
  /// its certifications first: the FK cascade deletes them but writes no
  /// deletion_log, so without a tombstone they would come back on sync.
  Future<void> _deleteIfUnlinked(String id) async {
    final stillLinked =
        await (_db.select(_db.diveBuddies)
              ..where((t) => t.buddyId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (stillLinked != null) return;
    final buddy = await (_db.select(
      _db.buddies,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (buddy == null) return;
    for (final cert in await _certRepo.getCertificationsByBuddy(id)) {
      await (_db.delete(
        _db.certifications,
      )..where((t) => t.id.equals(cert.id))).go();
      await _sync.logDeletion(entityType: 'certifications', recordId: cert.id);
    }
    await (_db.delete(_db.buddies)..where((t) => t.id.equals(id))).go();
    await _sync.logDeletion(entityType: 'buddies', recordId: id);
  }

  /// Whether [plan]'s dive still exists, has no links, and holds the buddy
  /// and dive-master text it was planned from. A sync or another window can
  /// change the text while a review is open; the names then need a new
  /// review, and the links would hide the new text on the Buddies card.
  Future<bool> _isStillAsPlanned(ConversionPlan plan) async {
    final row = await _db
        .customSelect(
          'SELECT d.buddy, d.dive_master, '
          '(SELECT COUNT(*) FROM dive_buddies WHERE dive_id = d.id) AS links '
          'FROM dives d WHERE d.id = ?',
          variables: [Variable.withString(plan.diveId)],
        )
        .getSingleOrNull();
    return row != null &&
        row.read<int>('links') == 0 &&
        _sameText(row.readNullable<String>('buddy'), plan.buddyText) &&
        _sameText(row.readNullable<String>('dive_master'), plan.diveMasterText);
  }

  /// Null and blank are the same empty text, and surrounding whitespace
  /// changes no name.
  static bool _sameText(String? current, String? planned) =>
      (current ?? '').trim() == (planned ?? '').trim();

  /// Whether any dive owned by [diverId] links buddy [buddyId].
  Future<bool> _linkedOnDiverDive(String buddyId, String diverId) async {
    final row = await _db
        .customSelect(
          'SELECT 1 FROM dive_buddies db JOIN dives d ON d.id = db.dive_id '
          'WHERE db.buddy_id = ? AND d.diver_id = ? LIMIT 1',
          variables: [
            Variable.withString(buddyId),
            Variable.withString(diverId),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  /// The buddy [target] writes to, creating or claiming it as needed.
  Future<String> _resolve(LinkTarget target, _ApplyRun run) async {
    if (target case ExistingBuddyTarget(:final buddyId)) {
      final row = await (_db.select(
        _db.buddies,
      )..where((t) => t.id.equals(buddyId))).getSingleOrNull();
      // Only a buddy the diver may link: another diver can claim an unowned
      // one while the review is open, and linking it then would tie this
      // dive to their record.
      if (row != null && (row.diverId == null || row.diverId == run.diverId)) {
        await _claimIfUnowned(row.id, row.diverId, run);
        return row.id;
      }
      // Deleted or claimed by another diver since planning (a sync, another
      // window): resolve by name among the diver's own and unowned buddies.
    }
    final key = legacyNameKey(target.name);
    final created = run.createdByKey[key];
    if (created != null) return created;
    if (run.matcher.match(target.name) case ExactMatch(:final candidate)) {
      await _claimIfUnowned(candidate.id, candidate.diverId, run);
      return candidate.id;
    }
    final id = _uuid.v4();
    await _db
        .into(_db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            diverId: Value(run.diverId),
            name: Value(target.name.trim()),
            notes: Value(run.newBuddyNote),
            createdAt: Value(run.now),
            updatedAt: Value(run.now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'buddies',
      recordId: id,
      localUpdatedAt: run.now,
    );
    run.createdByKey[key] = id;
    run.createdIds.add(id);
    return id;
  }

  /// Gives an unowned buddy to the diver, as the UDDF importer does (#1806):
  /// `getAllBuddies(diverId:)` filters strictly on `diver_id`, so an
  /// unclaimed buddy would be linked yet missing from the diver's list.
  Future<void> _claimIfUnowned(
    String id,
    String? ownerId,
    _ApplyRun run,
  ) async {
    if (ownerId != null || run.claimedIds.contains(id)) return;
    await (_db.update(_db.buddies)..where((t) => t.id.equals(id))).write(
      BuddiesCompanion(diverId: Value(run.diverId), updatedAt: Value(run.now)),
    );
    await _sync.markRecordPending(
      entityType: 'buddies',
      recordId: id,
      localUpdatedAt: run.now,
    );
    run.claimedIds.add(id);
  }
}

/// What one [BuddyConversionRepository.apply] run has written so far.
class _ApplyRun {
  _ApplyRun({
    required this.matcher,
    required this.diverId,
    required this.newBuddyNote,
    required this.now,
  });

  final BuddyNameMatcher matcher;
  final String diverId;
  final String newBuddyNote;
  final int now;
  final Map<String, String> createdByKey = {};
  final List<String> createdIds = [];
  final Set<String> claimedIds = {};
  final List<String> linkIds = [];
  final List<String> diveIds = [];

  ConversionReceipt toReceipt() => ConversionReceipt(
    diverId: diverId,
    diveIds: List.unmodifiable(diveIds),
    linkIds: List.unmodifiable(linkIds),
    createdBuddyIds: List.unmodifiable(createdIds),
    claimedBuddyIds: List.unmodifiable(claimedIds),
  );
}
