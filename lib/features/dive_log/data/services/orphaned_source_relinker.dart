import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/orphaned_source_match.dart';
import 'package:submersion/core/database/snapshot_serial_heal.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// Gives downloaded `dive_data_sources` rows with no computer link back to
/// the registered computer they came from: the rows a deleted computer left
/// behind, once that hardware is set up again (issue #4465). Which computer
/// a source belongs to is decided by [matchOrphanedSources].
///
/// For every source it links, the source takes the computer's serial when
/// its own snapshot is empty, its dive takes the computer when the source is
/// the dive's primary and no computer claims the dive, and the dive's
/// profile series take it where the dive has no other computer source. Each
/// relinked source and dive is restamped and marked pending, so the links
/// reach the diver's other devices.
class OrphanedSourceRelinker {
  OrphanedSourceRelinker({
    SyncRepository? syncRepository,
    ProfileSeriesRepository? profileSeries,
  }) : _syncRepository = syncRepository ?? SyncRepository(),
       _profileSeries = profileSeries ?? ProfileSeriesRepository();

  final SyncRepository _syncRepository;
  final ProfileSeriesRepository _profileSeries;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Relinks what can be matched and returns how many sources it linked.
  /// With [computerId], only links to that computer are made; the match is
  /// still decided over the whole library. Runs in the caller's transaction
  /// when there is one.
  Future<int> relink({String? computerId}) async {
    final orphans = await _orphans();
    if (orphans.isEmpty) return 0;
    final matches = matchOrphanedSources(
      sources: orphans.map((o) => o.source).toList(),
      computers: await _computers(),
      linkedSources: await _linkedSourcesOnOrphanDives(),
    );

    final byComputer = <String, List<_Orphan>>{};
    for (final orphan in orphans) {
      final target = matches[orphan.source.id];
      if (target == null) continue;
      if (computerId != null && target != computerId) continue;
      (byComputer[target] ??= []).add(orphan);
    }
    var linked = 0;
    for (final entry in byComputer.entries) {
      await _link(entry.key, entry.value);
      linked += entry.value.length;
    }
    if (linked > 0) {
      // An empty serial snapshot takes its computer's serial now, so a later
      // delete of that computer leaves the source something to match on.
      // Once for the run: one computer's copies when only one was linked,
      // else the whole library's, as every open does anyway.
      await healDownloadedSnapshotSerials(
        _db,
        computerId: byComputer.length == 1 ? byComputer.keys.single : null,
      );
    }
    return linked;
  }

  Future<void> _link(String computerId, List<_Orphan> orphans) async {
    final sourceIds = [for (final o in orphans) o.source.id];
    final clock = await _syncRepository.issueRowClock();
    for (final chunk in seriesIdChunks(sourceIds)) {
      await _db.customStatement(
        'UPDATE dive_data_sources SET computer_id = ?, hlc = ? '
        'WHERE id IN (${_placeholders(chunk.length)})',
        [computerId, clock, ...chunk],
      );
    }
    // Each source is published on its own (#2644): its dive is staged below
    // only when the source is the primary, so a secondary source would
    // otherwise never leave this device, and a peer's newer copy, still
    // unlinked, would clear the link again.
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in sourceIds) {
      await _syncRepository.markRecordPending(
        entityType: 'diveDataSources',
        recordId: id,
        localUpdatedAt: now,
      );
    }

    final primaryDiveIds = {
      for (final o in orphans)
        if (o.isPrimary) o.source.diveId,
    }.toList();
    for (final chunk in seriesIdChunks(primaryDiveIds)) {
      final claimable = await _db
          .customSelect(
            'SELECT id FROM dives '
            'WHERE computer_id IS NULL AND id IN '
            '(${_placeholders(chunk.length)})',
            variables: [for (final id in chunk) Variable<String>(id)],
            readsFrom: {_db.dives},
          )
          .map((r) => r.read<String>('id'))
          .get();
      if (claimable.isEmpty) continue;
      await _db.customStatement(
        'UPDATE dives SET computer_id = ?, updated_at = ? '
        'WHERE id IN (${_placeholders(claimable.length)})',
        [computerId, now, ...claimable],
      );
      for (final diveId in claimable) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
    }

    // Profiles carry no serial snapshot of their own, so they follow only
    // where the dive's computer attribution is unambiguous.
    final diveIds = {for (final o in orphans) o.source.diveId}.toList();
    for (final chunk in seriesIdChunks(diveIds)) {
      await _profileSeries.relinkComputer(computerId, chunk, now: now);
    }
  }

  Future<List<_Orphan>> _orphans() => _db
      .customSelect(
        'SELECT s.id, s.dive_id, s.is_primary, s.computer_model, '
        's.computer_serial, s.descriptor_vendor, s.descriptor_product, '
        'd.diver_id '
        'FROM dive_data_sources s JOIN dives d ON d.id = s.dive_id '
        "WHERE s.computer_id IS NULL AND s.source_format = 'dive_computer' "
        'ORDER BY s.id',
        readsFrom: {_db.diveDataSources, _db.dives},
      )
      .map(
        (r) => _Orphan(
          OrphanedSource(
            id: r.read<String>('id'),
            diveId: r.read<String>('dive_id'),
            diverId: r.readNullable<String>('diver_id'),
            computerModel: r.readNullable<String>('computer_model'),
            computerSerial: r.readNullable<String>('computer_serial'),
            descriptorVendor: r.readNullable<String>('descriptor_vendor'),
            descriptorProduct: r.readNullable<String>('descriptor_product'),
          ),
          isPrimary: r.read<bool>('is_primary'),
        ),
      )
      .get();

  Future<List<ImportedComputerCandidate>> _computers() async {
    final rows = await _db.select(_db.diveComputers).get();
    return [
      for (final c in rows)
        ImportedComputerCandidate(
          id: c.id,
          diverId: c.diverId,
          manufacturer: c.manufacturer,
          model: c.model,
          serialNumber: c.serialNumber,
        ),
    ];
  }

  /// The computers already linked to a source on a dive that also holds an
  /// unlinked downloaded source.
  Future<Set<LinkedSource>> _linkedSourcesOnOrphanDives() async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT dive_id, computer_id FROM dive_data_sources '
          'WHERE computer_id IS NOT NULL AND dive_id IN ('
          'SELECT dive_id FROM dive_data_sources WHERE computer_id IS NULL '
          "AND source_format = 'dive_computer')",
          readsFrom: {_db.diveDataSources},
        )
        .get();
    return {
      for (final r in rows)
        (
          diveId: r.read<String>('dive_id'),
          computerId: r.read<String>('computer_id'),
        ),
    };
  }

  static String _placeholders(int count) => List.filled(count, '?').join(', ');
}

class _Orphan {
  const _Orphan(this.source, {required this.isPrimary});

  final OrphanedSource source;
  final bool isPrimary;
}
