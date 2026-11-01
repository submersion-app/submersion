import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/data/documents/dive_summary_document.dart';
import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A tank read as a record of its own: the tank entity does not name its dive.
typedef _DiveTankRow = ({String diveId, DiveTank tank});

final _viaDive = viaParent('dives', 'dive_id', rootScope(QuerySubject.dives));

/// Dives and their child records.
List<RecordEntry> diveEntries(RecordRepositories r) => [
  RecordEntity<Dive>(
    name: 'dives',
    table: 'dives',
    scope: rootScope(QuerySubject.dives),
    load: (ids, load) => _loadDives(r, ids, load),
    document: diveDocument,
    summaryKeys: const [],
    summarize: (ids, _) => _diveSummaries(r, ids),
    blocks: {
      'tanks': (dive, _) async => [
        for (final t in dive.tanks) diveTankDocument(t),
      ],
      'buddies': (dive, _) async => [
        for (final b in await r.buddies.getBuddiesForDive(dive.id))
          diveBuddyDocument(b),
      ],
      'tags': (dive, _) async => [for (final tag in dive.tags) tag.name],
      'types': (dive, load) async {
        final names = {
          for (final t in await r.diveTypes.getAllDiveTypes(
            diverId: load.diverId,
          ))
            t.id: t.name,
        };
        return [
          for (final id in dive.diveTypeIds) {'id': id, 'name': names[id]},
        ];
      },
      'weights': (dive, _) async => [
        for (final w in dive.weights) diveWeightDocument(w),
      ],
      'sightings': (dive, _) async => [
        for (final s in await r.species.getSightingsForDive(dive.id))
          sightingDocument(s),
      ],
      'media': (dive, _) async => [
        for (final m in await r.media.getMediaForDive(dive.id))
          mediaDocument(m),
      ],
      'profile': (dive, load) async => diveProfileDocument(
        dive.profile,
        load.profileOffset,
        load.profileLimit,
      ),
    },
  ),
  RecordEntity<_DiveTankRow>(
    name: 'dive_tanks',
    table: 'dive_tanks',
    scope: _viaDive,
    parentColumn: 'dive_id',
    orderBy: 'r0.dive_id, r0.tank_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'dive_tanks',
      parentColumn: 'dive_id',
      ids: ids,
      idOf: (row) => row.tank.id,
      byParents: (diveIds) async => {
        for (final dive in await r.dives.getDivesByIdsWithoutSamples(diveIds))
          dive.id: [
            for (final tank in dive.tanks) (diveId: dive.id, tank: tank),
          ],
      },
    ),
    document: (row) => diveTankDocument(row.tank, diveId: row.diveId),
    summaryKeys: const ['dive_id', 'name', 'volume_l', 'o2_fraction', 'role'],
  ),
];

/// The profile is the one expensive part of a dive; decode it only when the
/// caller asked for that block, and load the rest in one batch.
Future<Map<String, Dive>> _loadDives(
  RecordRepositories r,
  List<String> ids,
  RecordLoad load,
) async {
  if (load.include.contains('profile')) {
    return loadEach(ids, r.dives.getDiveById);
  }
  return byId(await r.dives.getDivesByIdsWithoutSamples(ids), (d) => d.id);
}

Future<List<Map<String, Object?>>> _diveSummaries(
  RecordRepositories r,
  List<String> ids,
) async {
  final rows = <String, Map<String, Object?>>{};
  for (final chunk in seriesIdChunks(ids)) {
    for (final s in await r.dives.getSummariesByIds(chunk)) {
      rows[s.id] = diveSummaryDocument(s);
    }
  }
  return [
    for (final id in ids)
      ?rows[id],
  ];
}
